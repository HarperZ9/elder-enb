#include "elder/audit/LegacyPresetAudit.hpp"

#include <algorithm>
#include <charconv>
#include <cstdint>
#include <fstream>
#include <iterator>
#include <map>
#include <set>
#include <string>
#include <system_error>
#include <tuple>
#include <utility>

namespace elder::audit {
namespace {

namespace fs = std::filesystem;

[[nodiscard]] std::string Trim(const std::string_view value) {
    constexpr std::string_view whitespace = " \t\r\n";
    const auto first = value.find_first_not_of(whitespace);
    if (first == std::string_view::npos) {
        return {};
    }
    const auto last = value.find_last_not_of(whitespace);
    return std::string{value.substr(first, last - first + 1)};
}

[[nodiscard]] std::string LowerAscii(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](const unsigned char character) {
        if (character >= 'A' && character <= 'Z') {
            return static_cast<char>(character - 'A' + 'a');
        }
        return static_cast<char>(character);
    });
    return value;
}

[[nodiscard]] std::string PathToUtf8(const fs::path& path) {
    const auto utf8 = path.generic_u8string();
    return std::string{
        reinterpret_cast<const char*>(utf8.data()),
        utf8.size(),
    };
}

[[nodiscard]] fs::path Utf8ToPath(const std::string_view value) {
    const auto* begin = reinterpret_cast<const char8_t*>(value.data());
    return fs::path{std::u8string{begin, begin + value.size()}};
}

[[nodiscard]] bool IsValidUtf8(const std::string_view bytes) noexcept {
    std::size_t index = 0;
    while (index < bytes.size()) {
        const auto first = static_cast<unsigned char>(bytes[index]);
        if (first <= 0x7FU) {
            if (first == 0) {
                return false;
            }
            ++index;
            continue;
        }

        std::size_t continuation_count = 0;
        std::uint32_t codepoint = 0;
        std::uint32_t minimum = 0;
        if (first >= 0xC2U && first <= 0xDFU) {
            continuation_count = 1;
            codepoint = first & 0x1FU;
            minimum = 0x80U;
        } else if (first >= 0xE0U && first <= 0xEFU) {
            continuation_count = 2;
            codepoint = first & 0x0FU;
            minimum = 0x800U;
        } else if (first >= 0xF0U && first <= 0xF4U) {
            continuation_count = 3;
            codepoint = first & 0x07U;
            minimum = 0x10000U;
        } else {
            return false;
        }
        if (index + continuation_count >= bytes.size()) {
            return false;
        }
        for (std::size_t offset = 1; offset <= continuation_count; ++offset) {
            const auto continuation = static_cast<unsigned char>(bytes[index + offset]);
            if ((continuation & 0xC0U) != 0x80U) {
                return false;
            }
            codepoint = (codepoint << 6U) | (continuation & 0x3FU);
        }
        if (codepoint < minimum || codepoint > 0x10FFFFU
            || (codepoint >= 0xD800U && codepoint <= 0xDFFFU)) {
            return false;
        }
        index += continuation_count + 1;
    }
    return true;
}

[[nodiscard]] bool IsQuotedValue(const std::string_view value) noexcept {
    if (value.size() < 2 || value.front() != '"' || value.back() != '"') {
        return false;
    }
    bool escaped = false;
    for (std::size_t index = 1; index + 1 < value.size(); ++index) {
        const char character = value[index];
        if (escaped) {
            escaped = false;
            continue;
        }
        if (character == '\\') {
            escaped = true;
        } else if (character == '"' || character == '\r' || character == '\n') {
            return false;
        }
    }
    return !escaped;
}

[[nodiscard]] std::string Unquote(const std::string_view value) {
    std::string output;
    output.reserve(value.size() - 2);
    bool escaped = false;
    for (std::size_t index = 1; index + 1 < value.size(); ++index) {
        const char character = value[index];
        if (escaped) {
            output += character;
            escaped = false;
        } else if (character == '\\') {
            escaped = true;
        } else {
            output += character;
        }
    }
    return output;
}

[[nodiscard]] bool IsLegacyId(const std::string_view value) noexcept {
    if (value.size() < 3 || value.size() > 10 || value[0] != '0'
        || (value[1] != 'x' && value[1] != 'X')) {
        return false;
    }
    return std::ranges::all_of(value.substr(2), [](const unsigned char character) {
        return (character >= '0' && character <= '9')
            || (character >= 'a' && character <= 'f')
            || (character >= 'A' && character <= 'F');
    });
}

[[nodiscard]] bool IsSymbol(const std::string_view value) noexcept {
    if (value.empty()) {
        return false;
    }
    const auto first = static_cast<unsigned char>(value.front());
    if (!((first >= 'A' && first <= 'Z') || (first >= 'a' && first <= 'z')
          || first == '_')) {
        return false;
    }
    return std::ranges::all_of(value.substr(1), [](const unsigned char character) {
        return (character >= 'A' && character <= 'Z')
            || (character >= 'a' && character <= 'z')
            || (character >= '0' && character <= '9')
            || character == '_' || character == '.' || character == ':'
            || character == '/' || character == '\\' || character == '-';
    });
}

[[nodiscard]] bool IsBoolean(const std::string_view value) {
    const auto lower = LowerAscii(std::string{value});
    return lower == "true" || lower == "false";
}

[[nodiscard]] bool IsVersion(const std::string_view value) noexcept {
    if (value.empty() || value.front() == '.' || value.back() == '.') {
        return false;
    }
    bool last_was_dot = false;
    for (const unsigned char character : value) {
        if (character == '.') {
            if (last_was_dot) {
                return false;
            }
            last_was_dot = true;
        } else if (character >= '0' && character <= '9') {
            last_was_dot = false;
        } else {
            return false;
        }
    }
    return true;
}

enum class NumericStatus {
    Valid,
    Invalid,
    NonFinite,
};

[[nodiscard]] NumericStatus ParseNumeric(const std::string_view value) {
    std::size_t start = 0;
    bool saw_token = false;
    while (start <= value.size()) {
        const auto separator = value.find(',', start);
        const auto token = Trim(value.substr(
            start,
            separator == std::string_view::npos ? value.size() - start : separator - start));
        if (token.empty()) {
            return NumericStatus::Invalid;
        }
        saw_token = true;
        const auto lower = LowerAscii(token);
        if (lower == "nan" || lower == "+nan" || lower == "-nan"
            || lower == "inf" || lower == "+inf" || lower == "-inf"
            || lower == "infinity" || lower == "+infinity" || lower == "-infinity") {
            return NumericStatus::NonFinite;
        }
        if (IsLegacyId(token)) {
            // Hex references elsewhere in a record use the same lexical form as legacy IDs.
        } else {
            double number = 0.0;
            const auto* begin = token.data();
            const auto* end = begin + token.size();
            const auto conversion = std::from_chars(begin, end, number, std::chars_format::general);
            if (conversion.ec == std::errc::result_out_of_range) {
                return NumericStatus::NonFinite;
            }
            if (conversion.ec != std::errc{} || conversion.ptr != end) {
                return NumericStatus::Invalid;
            }
        }
        if (separator == std::string_view::npos) {
            break;
        }
        start = separator + 1;
    }
    return saw_token ? NumericStatus::Valid : NumericStatus::Invalid;
}

[[nodiscard]] bool HasIniExtension(const fs::path& path) {
    return LowerAscii(PathToUtf8(path.extension())) == ".ini";
}

[[nodiscard]] bool IsSuspiciousDuplicateFilename(const fs::path& path) {
    const auto stem = LowerAscii(PathToUtf8(path.stem()));
    const auto marker = stem.rfind("duplicate");
    if (marker == std::string::npos) {
        return false;
    }
    const auto digits = std::string_view{stem}.substr(marker + std::string_view{"duplicate"}.size());
    return !digits.empty() && std::ranges::all_of(digits, [](const unsigned char character) {
        return character >= '0' && character <= '9';
    });
}

[[nodiscard]] std::string CategoryFor(const std::string_view relative_path) {
    if (LowerAscii(std::string{relative_path}) == "presetinfo.ini") {
        return "PresetMetadata";
    }
    const auto separator = relative_path.find('/');
    if (separator == std::string_view::npos) {
        return "Root";
    }
    return std::string{relative_path.substr(0, separator)};
}

void AddDiagnostic(
    AuditResult& result,
    const AuditDiagnosticClass classification,
    const AuditDiagnosticCode code,
    const std::string& preset_id,
    const std::string& category,
    const std::string& relative_path,
    const std::size_t line = 0) {
    result.diagnostics.push_back(AuditDiagnostic{
        classification,
        code,
        preset_id,
        category,
        relative_path,
        line,
    });
}

struct ParsedFile {
    AuditedFile file;
    bool is_metadata{false};
    bool parse_fatal{false};
};

void ValidateOrdinaryValue(
    AuditResult& result,
    const AuditedFile& file,
    const std::string_view key,
    const std::string_view value,
    const std::size_t line,
    const bool is_metadata) {
    if (IsBoolean(value) || IsLegacyId(value)) {
        return;
    }
    const auto lower_key = LowerAscii(std::string{key});
    if (is_metadata && (lower_key == "configversion" || lower_key == "presetversion")) {
        if (!IsVersion(value)) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Finding,
                AuditDiagnosticCode::InvalidNumericToken,
                file.preset_id,
                file.category,
                file.relative_path,
                line);
        }
        return;
    }
    if (is_metadata && (lower_key == "author" || lower_key == "description")) {
        if (!IsQuotedValue(value)) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Finding,
                AuditDiagnosticCode::InvalidQuotedValue,
                file.preset_id,
                file.category,
                file.relative_path,
                line);
        }
        return;
    }
    if (!value.empty() && value.front() == '"') {
        if (!IsQuotedValue(value)) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Finding,
                AuditDiagnosticCode::InvalidQuotedValue,
                file.preset_id,
                file.category,
                file.relative_path,
                line);
        }
        return;
    }
    const auto status = ParseNumeric(value);
    if (status == NumericStatus::NonFinite) {
        AddDiagnostic(
            result,
            AuditDiagnosticClass::Finding,
            AuditDiagnosticCode::NonFiniteNumeric,
            file.preset_id,
            file.category,
            file.relative_path,
            line);
    } else if (status == NumericStatus::Invalid) {
        AddDiagnostic(
            result,
            AuditDiagnosticClass::Finding,
            AuditDiagnosticCode::InvalidNumericToken,
            file.preset_id,
            file.category,
            file.relative_path,
            line);
    }
}

[[nodiscard]] ParsedFile ParseFile(
    const fs::path& path,
    const std::string& preset_id,
    const std::string& relative_path,
    AuditResult& result) {
    ParsedFile parsed;
    parsed.file.preset_id = preset_id;
    parsed.file.relative_path = relative_path;
    parsed.file.category = CategoryFor(relative_path);
    parsed.is_metadata = LowerAscii(relative_path) == "presetinfo.ini";

    std::ifstream input{path, std::ios::binary};
    if (!input) {
        AddDiagnostic(
            result,
            AuditDiagnosticClass::Fatal,
            AuditDiagnosticCode::IoError,
            preset_id,
            parsed.file.category,
            relative_path);
        parsed.parse_fatal = true;
        return parsed;
    }
    std::string bytes{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{},
    };
    if (input.bad()) {
        AddDiagnostic(
            result,
            AuditDiagnosticClass::Fatal,
            AuditDiagnosticCode::IoError,
            preset_id,
            parsed.file.category,
            relative_path);
        parsed.parse_fatal = true;
        return parsed;
    }
    parsed.file.sha256 = bindings::Sha256(bytes);
    if (!IsValidUtf8(bytes)) {
        AddDiagnostic(
            result,
            AuditDiagnosticClass::Fatal,
            AuditDiagnosticCode::InvalidUtf8,
            preset_id,
            parsed.file.category,
            relative_path);
        parsed.parse_fatal = true;
        return parsed;
    }
    if (bytes.starts_with("\xEF\xBB\xBF")) {
        bytes.erase(0, 3);
    }

    std::set<std::string> sections;
    std::map<std::string, std::set<std::string>> keys_by_section;
    std::string section;
    std::size_t identity_count = 0;
    std::size_t optional_count = 0;
    std::size_t line_number = 0;
    std::size_t start = 0;
    while (start <= bytes.size()) {
        ++line_number;
        const auto newline = bytes.find('\n', start);
        auto line = std::string_view{bytes}.substr(
            start,
            newline == std::string::npos ? bytes.size() - start : newline - start);
        if (!line.empty() && line.back() == '\r') {
            line.remove_suffix(1);
        }
        const auto trimmed = Trim(line);
        if (!trimmed.empty() && trimmed.front() != ';' && trimmed.front() != '#') {
            if (trimmed.front() == '[') {
                if (trimmed.size() < 3 || trimmed.back() != ']') {
                    AddDiagnostic(
                        result,
                        AuditDiagnosticClass::Fatal,
                        AuditDiagnosticCode::MalformedSection,
                        preset_id,
                        parsed.file.category,
                        relative_path,
                        line_number);
                    parsed.parse_fatal = true;
                } else {
                    section = Trim(std::string_view{trimmed}.substr(1, trimmed.size() - 2));
                    if (section.empty()) {
                        AddDiagnostic(
                            result,
                            AuditDiagnosticClass::Fatal,
                            AuditDiagnosticCode::MalformedSection,
                            preset_id,
                            parsed.file.category,
                            relative_path,
                            line_number);
                        parsed.parse_fatal = true;
                    } else if (!sections.insert(LowerAscii(section)).second) {
                        AddDiagnostic(
                            result,
                            AuditDiagnosticClass::Finding,
                            AuditDiagnosticCode::DuplicateSection,
                            preset_id,
                            parsed.file.category,
                            relative_path,
                            line_number);
                    }
                }
            } else {
                const auto separator = trimmed.find('=');
                const auto key = separator == std::string::npos
                    ? std::string{}
                    : Trim(std::string_view{trimmed}.substr(0, separator));
                if (separator == std::string::npos || key.empty()) {
                    AddDiagnostic(
                        result,
                        AuditDiagnosticClass::Fatal,
                        AuditDiagnosticCode::MalformedIniLine,
                        preset_id,
                        parsed.file.category,
                        relative_path,
                        line_number);
                    parsed.parse_fatal = true;
                } else {
                    const auto value = Trim(std::string_view{trimmed}.substr(separator + 1));
                    const auto lower_section = LowerAscii(section);
                    const auto lower_key = LowerAscii(key);
                    if (!keys_by_section[lower_section].insert(lower_key).second) {
                        AddDiagnostic(
                            result,
                            AuditDiagnosticClass::Finding,
                            AuditDiagnosticCode::DuplicateKey,
                            preset_id,
                            parsed.file.category,
                            relative_path,
                            line_number);
                    }
                    if (section.empty() && (lower_key == "id" || lower_key == "symbol")) {
                        ++identity_count;
                        if (lower_key == "id") {
                            if (!IsLegacyId(value)) {
                                AddDiagnostic(
                                    result,
                                    AuditDiagnosticClass::Finding,
                                    AuditDiagnosticCode::MalformedLegacyId,
                                    preset_id,
                                    parsed.file.category,
                                    relative_path,
                                    line_number);
                            } else if (parsed.file.identity_kind == IdentityKind::None) {
                                parsed.file.identity_kind = IdentityKind::LegacyId;
                                parsed.file.relative_identity = LowerAscii(value);
                            }
                        } else {
                            const bool quoted = !value.empty() && value.front() == '"';
                            const auto symbol = quoted && IsQuotedValue(value)
                                ? Unquote(value)
                                : value;
                            if ((quoted && !IsQuotedValue(value)) || !IsSymbol(symbol)) {
                                AddDiagnostic(
                                    result,
                                    AuditDiagnosticClass::Finding,
                                    AuditDiagnosticCode::MalformedSymbol,
                                    preset_id,
                                    parsed.file.category,
                                    relative_path,
                                    line_number);
                            } else if (parsed.file.identity_kind == IdentityKind::None) {
                                parsed.file.identity_kind = IdentityKind::Symbol;
                                parsed.file.relative_identity = symbol;
                            }
                        }
                    } else if (section.empty() && lower_key == "optional") {
                        ++optional_count;
                        if (!IsBoolean(value)) {
                            AddDiagnostic(
                                result,
                                AuditDiagnosticClass::Finding,
                                AuditDiagnosticCode::InvalidOptional,
                                preset_id,
                                parsed.file.category,
                                relative_path,
                                line_number);
                        }
                    } else {
                        ValidateOrdinaryValue(
                            result,
                            parsed.file,
                            key,
                            value,
                            line_number,
                            parsed.is_metadata);
                    }
                }
            }
        }
        if (newline == std::string::npos) {
            break;
        }
        start = newline + 1;
    }

    if (!parsed.is_metadata) {
        if (identity_count == 0) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Finding,
                AuditDiagnosticCode::MissingIdentity,
                preset_id,
                parsed.file.category,
                relative_path);
        } else if (identity_count > 1) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Finding,
                AuditDiagnosticCode::MultipleIdentity,
                preset_id,
                parsed.file.category,
                relative_path);
        }
    }
    if (optional_count == 0) {
        AddDiagnostic(
            result,
            AuditDiagnosticClass::Finding,
            AuditDiagnosticCode::MissingOptional,
            preset_id,
            parsed.file.category,
            relative_path);
    }
    if (IsSuspiciousDuplicateFilename(path)) {
        AddDiagnostic(
            result,
            AuditDiagnosticClass::Finding,
            AuditDiagnosticCode::SuspiciousDuplicateFilename,
            preset_id,
            parsed.file.category,
            relative_path);
    }
    return parsed;
}

[[nodiscard]] bool PathStartsWith(const fs::path& path, const fs::path& root) {
    auto path_iterator = path.begin();
    auto root_iterator = root.begin();
    for (; root_iterator != root.end(); ++root_iterator, ++path_iterator) {
        if (path_iterator == path.end()) {
            return false;
        }
        if (LowerAscii(PathToUtf8(*path_iterator)) != LowerAscii(PathToUtf8(*root_iterator))) {
            return false;
        }
    }
    return true;
}

[[nodiscard]] fs::path AbsoluteNormalized(const fs::path& path) {
    std::error_code error;
    auto absolute = fs::absolute(path, error);
    if (error) {
        return path.lexically_normal();
    }
    return absolute.lexically_normal();
}

[[nodiscard]] std::string CsvField(const std::string_view value) {
    std::string output{"\""};
    for (const char character : value) {
        if (character == '"') {
            output += "\"\"";
        } else {
            output += character;
        }
    }
    output += '"';
    return output;
}

[[nodiscard]] bool OpenOutput(
    const fs::path& path,
    std::ofstream& output) {
    std::error_code error;
    if (!path.parent_path().empty()) {
        fs::create_directories(path.parent_path(), error);
        if (error) {
            return false;
        }
    }
    output.open(path, std::ios::binary | std::ios::trunc);
    return static_cast<bool>(output);
}

void SortAndRecount(AuditResult& result) {
    std::ranges::sort(result.files, [](const AuditedFile& left, const AuditedFile& right) {
        return std::tie(left.preset_id, left.relative_path)
            < std::tie(right.preset_id, right.relative_path);
    });
    std::ranges::sort(result.presets, [](const AuditedPreset& left, const AuditedPreset& right) {
        return left.preset_id < right.preset_id;
    });
    std::ranges::sort(result.diagnostics, [](const AuditDiagnostic& left, const AuditDiagnostic& right) {
        return std::tie(
                   left.classification,
                   left.code,
                   left.preset_id,
                   left.category,
                   left.relative_path,
                   left.line)
            < std::tie(
                   right.classification,
                   right.code,
                   right.preset_id,
                   right.category,
                   right.relative_path,
                   right.line);
    });

    result.counts.findings = CountDiagnostics(result, AuditDiagnosticClass::Finding);
    result.counts.fatal_errors = CountDiagnostics(result, AuditDiagnosticClass::Fatal);
    for (auto& preset : result.presets) {
        preset.findings = 0;
        preset.fatal_errors = 0;
        for (const auto& diagnostic : result.diagnostics) {
            if (diagnostic.preset_id != preset.preset_id) {
                continue;
            }
            if (diagnostic.classification == AuditDiagnosticClass::Finding) {
                ++preset.findings;
            } else {
                ++preset.fatal_errors;
            }
        }
    }
}

}  // namespace

bool AuditResult::completed() const noexcept {
    return CountDiagnostics(*this, AuditDiagnosticClass::Fatal) == 0;
}

bool AuditResult::clean() const noexcept {
    return diagnostics.empty();
}

AuditResult AuditLegacyPresets(
    const fs::path& preset_root,
    const bindings::DispositionCatalog& catalog) {
    AuditResult result;
    std::map<std::string, std::string> targets;
    for (const auto& binding : catalog.bindings) {
        if (!IsValidUtf8(binding.canonical_identity)
            || !IsValidUtf8(binding.preset_directory)) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Fatal,
                AuditDiagnosticCode::InvalidCatalog,
                {},
                {},
                {});
            continue;
        }
        const auto directory = Utf8ToPath(binding.preset_directory);
        if (binding.canonical_identity.empty() || binding.preset_directory.empty()
            || directory.is_absolute() || directory.has_root_path()
            || directory.has_parent_path() || binding.preset_directory == "."
            || binding.preset_directory == "..") {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Fatal,
                AuditDiagnosticCode::InvalidCatalog,
                binding.canonical_identity,
                {},
                {});
            continue;
        }
        const auto [iterator, inserted] = targets.emplace(
            binding.preset_directory,
            binding.canonical_identity);
        if (!inserted) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Fatal,
                AuditDiagnosticCode::DuplicateCatalogPreset,
                binding.canonical_identity,
                {},
                binding.preset_directory);
        }
    }
    result.counts.catalog_presets = targets.size();

    for (const auto& [directory_name, preset_id] : targets) {
        const auto preset_directory = preset_root / Utf8ToPath(directory_name);
        std::error_code status_error;
        if (!fs::is_directory(preset_directory, status_error) || status_error) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Fatal,
                AuditDiagnosticCode::MissingPresetDirectory,
                preset_id,
                {},
                {});
            continue;
        }

        std::vector<fs::path> paths;
        std::error_code iteration_error;
        fs::recursive_directory_iterator iterator{
            preset_directory,
            fs::directory_options::skip_permission_denied,
            iteration_error};
        const fs::recursive_directory_iterator end;
        while (!iteration_error && iterator != end) {
            std::error_code type_error;
            const auto symlink = iterator->is_symlink(type_error);
            if (type_error || symlink) {
                const auto relative = PathToUtf8(iterator->path().lexically_relative(preset_directory));
                AddDiagnostic(
                    result,
                    AuditDiagnosticClass::Fatal,
                    AuditDiagnosticCode::IoError,
                    preset_id,
                    CategoryFor(relative),
                    relative);
                if (iterator->is_directory(type_error)) {
                    iterator.disable_recursion_pending();
                }
            } else if (iterator->is_regular_file(type_error) && !type_error
                       && HasIniExtension(iterator->path())) {
                paths.push_back(iterator->path());
            }
            iterator.increment(iteration_error);
        }
        if (iteration_error) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Fatal,
                AuditDiagnosticCode::IoError,
                preset_id,
                {},
                {});
        }
        std::ranges::sort(paths, [&preset_directory](const fs::path& left, const fs::path& right) {
            return PathToUtf8(left.lexically_relative(preset_directory))
                < PathToUtf8(right.lexically_relative(preset_directory));
        });

        AuditedPreset preset;
        preset.preset_id = preset_id;
        std::map<std::pair<std::string, std::string>, std::string> identities;
        std::string tree_material{"ELDER_PRESET_TREE_V1\n"};
        bool has_preset_info = false;
        for (const auto& path : paths) {
            const auto relative = PathToUtf8(path.lexically_relative(preset_directory));
            auto parsed = ParseFile(path, preset_id, relative, result);
            ++preset.ini_files;
            ++result.counts.ini_files;
            if (parsed.is_metadata) {
                has_preset_info = true;
            } else {
                ++preset.record_files;
                ++result.counts.record_files;
            }
            if (!parsed.file.sha256.empty()) {
                const auto leaf = bindings::Sha256(
                    std::string{"ELDER_PRESET_BLOB_V1\n"} + relative + "\n"
                    + parsed.file.sha256 + "\n");
                tree_material += relative;
                tree_material += '\0';
                tree_material += leaf;
                tree_material += '\n';
            }
            if (!parsed.is_metadata && parsed.file.identity_kind != IdentityKind::None
                && !parsed.file.relative_identity.empty()) {
                const auto identity_key = std::string{ToString(parsed.file.identity_kind)} + ":"
                    + LowerAscii(parsed.file.relative_identity);
                const auto key = std::pair{parsed.file.category, identity_key};
                const auto [identity_iterator, inserted] = identities.emplace(key, relative);
                if (!inserted) {
                    AddDiagnostic(
                        result,
                        AuditDiagnosticClass::Finding,
                        AuditDiagnosticCode::DuplicateRecordIdentity,
                        preset_id,
                        parsed.file.category,
                        relative);
                }
            }
            result.files.push_back(std::move(parsed.file));
        }
        if (!has_preset_info) {
            AddDiagnostic(
                result,
                AuditDiagnosticClass::Finding,
                AuditDiagnosticCode::MissingPresetInfo,
                preset_id,
                "PresetMetadata",
                "PresetInfo.ini");
        }
        preset.tree_sha256 = bindings::Sha256(tree_material);
        result.presets.push_back(std::move(preset));
    }

    SortAndRecount(result);
    return result;
}

bool HasDiagnostic(
    const AuditResult& result,
    const AuditDiagnosticCode code) noexcept {
    return CountDiagnostics(result, code) != 0;
}

std::size_t CountDiagnostics(
    const AuditResult& result,
    const AuditDiagnosticCode code) noexcept {
    return static_cast<std::size_t>(std::ranges::count_if(
        result.diagnostics,
        [code](const AuditDiagnostic& diagnostic) {
            return diagnostic.code == code;
        }));
}

std::size_t CountDiagnostics(
    const AuditResult& result,
    const AuditDiagnosticClass classification) noexcept {
    return static_cast<std::size_t>(std::ranges::count_if(
        result.diagnostics,
        [classification](const AuditDiagnostic& diagnostic) {
            return diagnostic.classification == classification;
        }));
}

bool WriteAuditManifest(
    const fs::path& path,
    const AuditResult& result) {
    std::ofstream output;
    if (!OpenOutput(path, output)) {
        return false;
    }
    output << "preset_id,category,relative_path,identity_kind,relative_identity,sha256\n";
    for (const auto& file : result.files) {
        output << CsvField(file.preset_id) << ',' << CsvField(file.category) << ','
               << CsvField(file.relative_path) << ',' << CsvField(ToString(file.identity_kind))
               << ',' << CsvField(file.relative_identity) << ',' << CsvField(file.sha256) << '\n';
    }
    return static_cast<bool>(output);
}

bool WriteAuditReport(
    const fs::path& path,
    const AuditResult& result) {
    std::ofstream output;
    if (!OpenOutput(path, output)) {
        return false;
    }
    output << "format=elder-legacy-preset-audit-v1\n"
           << "catalog_presets=" << result.counts.catalog_presets << '\n'
           << "ini_files=" << result.counts.ini_files << '\n'
           << "record_files=" << result.counts.record_files << '\n'
           << "findings=" << result.counts.findings << '\n'
           << "fatal_errors=" << result.counts.fatal_errors << '\n';
    for (const auto& preset : result.presets) {
        output << "preset," << CsvField(preset.preset_id) << ',' << preset.ini_files << ','
               << preset.record_files << ',' << preset.findings << ',' << preset.fatal_errors
               << ',' << preset.tree_sha256 << '\n';
    }
    for (const auto& diagnostic : result.diagnostics) {
        output << "diagnostic," << ToString(diagnostic.classification) << ','
               << ToString(diagnostic.code) << ',' << CsvField(diagnostic.preset_id) << ','
               << CsvField(diagnostic.category) << ',' << CsvField(diagnostic.relative_path)
               << ',' << diagnostic.line << '\n';
    }
    return static_cast<bool>(output);
}

bool AuditOutputPathsAreSafe(
    const fs::path& preset_root,
    const fs::path& manifest_path,
    const fs::path& report_path) {
    if (preset_root.empty() || manifest_path.empty() || report_path.empty()) {
        return false;
    }
    const auto root = AbsoluteNormalized(preset_root);
    const auto manifest = AbsoluteNormalized(manifest_path);
    const auto report = AbsoluteNormalized(report_path);
    return manifest != report && !PathStartsWith(manifest, root) && !PathStartsWith(report, root);
}

int AuditExitCode(
    const AuditResult& result,
    const bool fail_on_findings) noexcept {
    if (!result.completed()) {
        return 1;
    }
    if (fail_on_findings && CountDiagnostics(result, AuditDiagnosticClass::Finding) != 0) {
        return 1;
    }
    return 0;
}

std::string_view ToString(const AuditDiagnosticCode code) noexcept {
    switch (code) {
        case AuditDiagnosticCode::IoError:
            return "IO_ERROR";
        case AuditDiagnosticCode::InvalidUtf8:
            return "INVALID_UTF8";
        case AuditDiagnosticCode::MalformedIniLine:
            return "MALFORMED_INI_LINE";
        case AuditDiagnosticCode::MalformedSection:
            return "MALFORMED_SECTION";
        case AuditDiagnosticCode::DuplicateSection:
            return "DUPLICATE_SECTION";
        case AuditDiagnosticCode::DuplicateKey:
            return "DUPLICATE_KEY";
        case AuditDiagnosticCode::MissingIdentity:
            return "MISSING_IDENTITY";
        case AuditDiagnosticCode::MultipleIdentity:
            return "MULTIPLE_IDENTITY";
        case AuditDiagnosticCode::MalformedLegacyId:
            return "MALFORMED_LEGACY_ID";
        case AuditDiagnosticCode::MalformedSymbol:
            return "MALFORMED_SYMBOL";
        case AuditDiagnosticCode::MissingOptional:
            return "MISSING_OPTIONAL";
        case AuditDiagnosticCode::InvalidOptional:
            return "INVALID_OPTIONAL";
        case AuditDiagnosticCode::NonFiniteNumeric:
            return "NON_FINITE_NUMERIC";
        case AuditDiagnosticCode::InvalidNumericToken:
            return "INVALID_NUMERIC_TOKEN";
        case AuditDiagnosticCode::InvalidQuotedValue:
            return "INVALID_QUOTED_VALUE";
        case AuditDiagnosticCode::DuplicateRecordIdentity:
            return "DUPLICATE_RECORD_IDENTITY";
        case AuditDiagnosticCode::SuspiciousDuplicateFilename:
            return "SUSPICIOUS_DUPLICATE_FILENAME";
        case AuditDiagnosticCode::MissingPresetInfo:
            return "MISSING_PRESET_INFO";
        case AuditDiagnosticCode::DuplicateCatalogPreset:
            return "DUPLICATE_CATALOG_PRESET";
        case AuditDiagnosticCode::MissingPresetDirectory:
            return "MISSING_PRESET_DIRECTORY";
        case AuditDiagnosticCode::InvalidCatalog:
            return "INVALID_CATALOG";
        case AuditDiagnosticCode::UnsafeOutputPath:
            return "UNSAFE_OUTPUT_PATH";
        case AuditDiagnosticCode::ExpectationMismatch:
            return "EXPECTATION_MISMATCH";
    }
    return "UNKNOWN_AUDIT_DIAGNOSTIC";
}

std::string_view ToString(const AuditDiagnosticClass classification) noexcept {
    switch (classification) {
        case AuditDiagnosticClass::Finding:
            return "FINDING";
        case AuditDiagnosticClass::Fatal:
            return "FATAL";
    }
    return "UNKNOWN_CLASS";
}

std::string_view ToString(const IdentityKind kind) noexcept {
    switch (kind) {
        case IdentityKind::None:
            return "NONE";
        case IdentityKind::LegacyId:
            return "LEGACY_ID";
        case IdentityKind::Symbol:
            return "SYMBOL";
    }
    return "UNKNOWN_IDENTITY";
}

}  // namespace elder::audit
