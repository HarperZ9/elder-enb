#include "elder/bindings/LegacyKreateBindings.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <charconv>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iterator>
#include <set>
#include <sstream>
#include <stdexcept>
#include <system_error>
#include <utility>

namespace elder::bindings {
namespace {

namespace fs = std::filesystem;

constexpr std::array<std::uint32_t, 64> kRoundConstants{
    0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U,
    0x3956c25bU, 0x59f111f1U, 0x923f82a4U, 0xab1c5ed5U,
    0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
    0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U,
    0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU,
    0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
    0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U,
    0xc6e00bf3U, 0xd5a79147U, 0x06ca6351U, 0x14292967U,
    0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
    0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U,
    0xa2bfe8a1U, 0xa81a664bU, 0xc24b8b70U, 0xc76c51a3U,
    0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
    0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U,
    0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU, 0x682e6ff3U,
    0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
    0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U,
};

class Sha256State final {
public:
    void Update(const unsigned char* bytes, const std::size_t size) {
        total_size_ += size;
        for (std::size_t index = 0; index < size; ++index) {
            buffer_[buffer_size_++] = bytes[index];
            if (buffer_size_ == buffer_.size()) {
                Transform();
                buffer_size_ = 0;
            }
        }
    }

    [[nodiscard]] std::string Finish() {
        const auto bit_size = static_cast<std::uint64_t>(total_size_) * 8U;
        buffer_[buffer_size_++] = 0x80U;

        if (buffer_size_ > 56) {
            while (buffer_size_ < buffer_.size()) {
                buffer_[buffer_size_++] = 0;
            }
            Transform();
            buffer_size_ = 0;
        }

        while (buffer_size_ < 56) {
            buffer_[buffer_size_++] = 0;
        }
        for (int shift = 56; shift >= 0; shift -= 8) {
            buffer_[buffer_size_++] = static_cast<unsigned char>(bit_size >> shift);
        }
        Transform();
        buffer_size_ = 0;

        std::ostringstream output;
        output << std::hex << std::setfill('0');
        for (const auto word : state_) {
            output << std::setw(8) << word;
        }
        return output.str();
    }

private:
    void Transform() {
        std::array<std::uint32_t, 64> words{};
        for (std::size_t index = 0; index < 16; ++index) {
            const auto offset = index * 4;
            words[index] =
                (static_cast<std::uint32_t>(buffer_[offset]) << 24U)
                | (static_cast<std::uint32_t>(buffer_[offset + 1]) << 16U)
                | (static_cast<std::uint32_t>(buffer_[offset + 2]) << 8U)
                | static_cast<std::uint32_t>(buffer_[offset + 3]);
        }
        for (std::size_t index = 16; index < words.size(); ++index) {
            const auto sigma0 = std::rotr(words[index - 15], 7)
                ^ std::rotr(words[index - 15], 18)
                ^ (words[index - 15] >> 3U);
            const auto sigma1 = std::rotr(words[index - 2], 17)
                ^ std::rotr(words[index - 2], 19)
                ^ (words[index - 2] >> 10U);
            words[index] = words[index - 16] + sigma0 + words[index - 7] + sigma1;
        }

        auto a = state_[0];
        auto b = state_[1];
        auto c = state_[2];
        auto d = state_[3];
        auto e = state_[4];
        auto f = state_[5];
        auto g = state_[6];
        auto h = state_[7];

        for (std::size_t index = 0; index < words.size(); ++index) {
            const auto big_sigma1 = std::rotr(e, 6) ^ std::rotr(e, 11) ^ std::rotr(e, 25);
            const auto choose = (e & f) ^ ((~e) & g);
            const auto temporary1 = h + big_sigma1 + choose + kRoundConstants[index] + words[index];
            const auto big_sigma0 = std::rotr(a, 2) ^ std::rotr(a, 13) ^ std::rotr(a, 22);
            const auto majority = (a & b) ^ (a & c) ^ (b & c);
            const auto temporary2 = big_sigma0 + majority;

            h = g;
            g = f;
            f = e;
            e = d + temporary1;
            d = c;
            c = b;
            b = a;
            a = temporary1 + temporary2;
        }

        state_[0] += a;
        state_[1] += b;
        state_[2] += c;
        state_[3] += d;
        state_[4] += e;
        state_[5] += f;
        state_[6] += g;
        state_[7] += h;
    }

    std::array<std::uint32_t, 8> state_{
        0x6a09e667U,
        0xbb67ae85U,
        0x3c6ef372U,
        0xa54ff53aU,
        0x510e527fU,
        0x9b05688cU,
        0x1f83d9abU,
        0x5be0cd19U,
    };
    std::array<unsigned char, 64> buffer_{};
    std::size_t buffer_size_{0};
    std::size_t total_size_{0};
};

[[nodiscard]] std::string Trim(const std::string_view value) {
    constexpr std::string_view whitespace = " \t\r\n";
    const auto first = value.find_first_not_of(whitespace);
    if (first == std::string_view::npos) {
        return {};
    }
    const auto last = value.find_last_not_of(whitespace);
    return std::string{value.substr(first, last - first + 1)};
}

[[nodiscard]] std::string Unquote(const std::string_view value) {
    auto result = Trim(value);
    if (result.size() >= 2 && result.front() == '"' && result.back() == '"') {
        result = result.substr(1, result.size() - 2);
    }
    return result;
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
    const auto utf8 = path.u8string();
    return std::string{
        reinterpret_cast<const char*>(utf8.data()),
        utf8.size(),
    };
}

[[nodiscard]] bool IsSha256(const std::string_view value) {
    if (value.size() != 64) {
        return false;
    }
    return std::ranges::all_of(value, [](const unsigned char character) {
        return (character >= '0' && character <= '9')
            || (character >= 'a' && character <= 'f');
    });
}

struct ParsedOverlay {
    OverlayMetadata metadata;
    bool found_section{false};
    bool has_ui_name{false};
    bool has_ui_groups{false};
    bool has_ui_ordering{false};
};

[[nodiscard]] ParsedOverlay ParseOverlayMetadataOnly(const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("cannot open overlay metadata");
    }

    ParsedOverlay parsed;
    parsed.metadata.filename = PathToUtf8(path.filename());
    bool in_overlay_info = false;
    std::string line;
    while (std::getline(input, line)) {
        const auto trimmed = Trim(line);
        if (trimmed.size() >= 2 && trimmed.front() == '[' && trimmed.back() == ']') {
            const auto section = trimmed.substr(1, trimmed.size() - 2);
            if (in_overlay_info && section != "OVERLAYINFO") {
                break;
            }
            in_overlay_info = section == "OVERLAYINFO";
            parsed.found_section = parsed.found_section || in_overlay_info;
            continue;
        }
        if (!in_overlay_info) {
            continue;
        }

        const auto separator = trimmed.find('=');
        if (separator == std::string::npos) {
            continue;
        }
        const auto key = Trim(std::string_view{trimmed}.substr(0, separator));
        const auto value = Unquote(std::string_view{trimmed}.substr(separator + 1));
        if (key == "UIName") {
            parsed.metadata.ui_name = value;
            parsed.has_ui_name = !value.empty();
        } else if (key == "UIGroups") {
            parsed.metadata.ui_groups = value;
            parsed.has_ui_groups = !value.empty();
        } else if (key == "UIOrdering") {
            int ordering = 0;
            const auto* begin = value.data();
            const auto* end = begin + value.size();
            const auto conversion = std::from_chars(begin, end, ordering);
            if (conversion.ec == std::errc{} && conversion.ptr == end) {
                parsed.metadata.ui_ordering = ordering;
                parsed.has_ui_ordering = true;
            }
        }
    }
    return parsed;
}

struct ParsedPreset {
    PresetMetadata metadata;
    bool complete{false};
};

[[nodiscard]] ParsedPreset ParsePresetMetadataOnly(const fs::path& directory) {
    const auto info_path = directory / "PresetInfo.ini";
    std::ifstream input{info_path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("cannot open PresetInfo.ini");
    }

    static const std::set<std::string> allowed_keys{
        "Author",
        "ConfigVersion",
        "Description",
        "Optional",
        "PresetVersion",
    };

    ParsedPreset parsed;
    parsed.metadata.directory_name = PathToUtf8(directory.filename());
    std::string line;
    while (std::getline(input, line)) {
        const auto trimmed = Trim(line);
        const auto separator = trimmed.find('=');
        if (separator == std::string::npos) {
            continue;
        }
        const auto key = Trim(std::string_view{trimmed}.substr(0, separator));
        if (!allowed_keys.contains(key)) {
            continue;
        }
        parsed.metadata.identity_metadata[key] =
            Unquote(std::string_view{trimmed}.substr(separator + 1));
    }
    parsed.complete = parsed.metadata.identity_metadata.size() == allowed_keys.size();
    parsed.metadata.sha256 = Sha256File(info_path);
    return parsed;
}

[[nodiscard]] std::vector<std::string> ParseCsvRow(
    const std::string_view row,
    bool& valid) {
    std::vector<std::string> fields;
    std::string field;
    bool quoted = false;
    bool after_quote = false;
    valid = true;

    for (std::size_t index = 0; index < row.size(); ++index) {
        const char character = row[index];
        if (quoted) {
            if (character == '"') {
                if (index + 1 < row.size() && row[index + 1] == '"') {
                    field += '"';
                    ++index;
                } else {
                    quoted = false;
                    after_quote = true;
                }
            } else {
                field += character;
            }
        } else if (character == ',' && !quoted) {
            fields.push_back(Trim(field));
            field.clear();
            after_quote = false;
        } else if (character == '"' && field.empty() && !after_quote) {
            quoted = true;
        } else if (after_quote) {
            if (character != ' ' && character != '\t' && character != '\r') {
                valid = false;
            }
        } else {
            field += character;
        }
    }
    if (quoted) {
        valid = false;
    }
    fields.push_back(Trim(field));
    return fields;
}

void AddCatalogDiagnostic(
    DispositionCatalog& catalog,
    const BindingDiagnosticCode code,
    std::string identity,
    std::string entry) {
    catalog.diagnostics.push_back(
        BindingDiagnostic{code, std::move(identity), std::move(entry)});
}

void AddResultDiagnostic(
    CompileResult& result,
    const BindingDiagnosticCode code,
    std::string identity,
    std::string entry) {
    result.diagnostics.push_back(
        BindingDiagnostic{code, std::move(identity), std::move(entry)});
}

[[nodiscard]] std::string OverlayIdentity(const std::string_view ui_name) {
    constexpr std::string_view prefix = "STYLE - ";
    if (ui_name.starts_with(prefix)) {
        return std::string{ui_name.substr(prefix.size())};
    }
    return std::string{ui_name};
}

[[nodiscard]] std::string CsvField(const std::string_view value) {
    std::string encoded{"\""};
    for (const char character : value) {
        if (character == '"') {
            encoded += "\"\"";
        } else {
            encoded += character;
        }
    }
    encoded += '"';
    return encoded;
}

[[nodiscard]] std::string Join(const std::vector<std::string>& values) {
    std::string joined;
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index != 0) {
            joined += ';';
        }
        joined += values[index];
    }
    return joined;
}

[[nodiscard]] bool PrepareOutput(const fs::path& path) {
    std::error_code error;
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        fs::create_directories(parent, error);
        if (error) {
            return false;
        }
    }
    return true;
}

[[nodiscard]] fs::path NormalizedPath(const fs::path& path) {
    std::error_code error;
    auto normalized = fs::weakly_canonical(path, error);
    if (!error) {
        return normalized;
    }
    error.clear();
    normalized = fs::absolute(path, error);
    return error ? path.lexically_normal() : normalized.lexically_normal();
}

[[nodiscard]] bool PathIsWithin(const fs::path& root, const fs::path& candidate) {
    const auto normalized_root = NormalizedPath(root);
    const auto normalized_candidate = NormalizedPath(candidate);
    auto root_part = normalized_root.begin();
    auto candidate_part = normalized_candidate.begin();
    for (; root_part != normalized_root.end(); ++root_part, ++candidate_part) {
        if (candidate_part == normalized_candidate.end()
            || LowerAscii(PathToUtf8(*root_part)) != LowerAscii(PathToUtf8(*candidate_part))) {
            return false;
        }
    }
    return true;
}

}  // namespace

bool CompileResult::success() const noexcept {
    return diagnostics.empty();
}

std::string Sha256(const std::string_view bytes) {
    Sha256State state;
    state.Update(
        reinterpret_cast<const unsigned char*>(bytes.data()),
        bytes.size());
    return state.Finish();
}

std::string Sha256File(const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("cannot open file for SHA-256");
    }

    Sha256State state;
    std::array<char, 16 * 1024> buffer{};
    while (input) {
        input.read(buffer.data(), static_cast<std::streamsize>(buffer.size()));
        const auto read = input.gcount();
        if (read > 0) {
            state.Update(
                reinterpret_cast<const unsigned char*>(buffer.data()),
                static_cast<std::size_t>(read));
        }
    }
    if (!input.eof()) {
        throw std::runtime_error("cannot read file for SHA-256");
    }
    return state.Finish();
}

OverlayMetadata ReadOverlayMetadata(const fs::path& path) {
    auto parsed = ParseOverlayMetadataOnly(path);
    if (!parsed.found_section || !parsed.has_ui_name || !parsed.has_ui_groups
        || !parsed.has_ui_ordering) {
        throw std::runtime_error("invalid OVERLAYINFO metadata");
    }
    parsed.metadata.sha256 = Sha256File(path);
    return parsed.metadata;
}

PresetMetadata ReadPresetMetadata(const fs::path& directory) {
    auto parsed = ParsePresetMetadataOnly(directory);
    if (!parsed.complete) {
        throw std::runtime_error("invalid PresetInfo.ini metadata");
    }
    return parsed.metadata;
}

DispositionCatalog LoadDispositionCatalog(const fs::path& path) {
    DispositionCatalog catalog;
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        AddCatalogDiagnostic(catalog, BindingDiagnosticCode::IoError, {}, PathToUtf8(path));
        return catalog;
    }

    const std::array<std::string, 7> expected_header{
        "record_type",
        "canonical_identity",
        "overlay_file",
        "overlay_sha256",
        "preset_directory",
        "preset_info_sha256",
        "alias",
    };

    std::string line;
    std::size_t line_number = 0;
    while (std::getline(input, line)) {
        ++line_number;
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        if (line.empty()) {
            continue;
        }

        bool valid_row = false;
        auto fields = ParseCsvRow(line, valid_row);
        if (line_number == 1 && !fields.empty() && fields.front().starts_with("\xEF\xBB\xBF")) {
            fields.front().erase(0, 3);
        }
        if (!valid_row || fields.size() != expected_header.size()) {
            AddCatalogDiagnostic(
                catalog,
                BindingDiagnosticCode::InvalidCatalog,
                {},
                "line " + std::to_string(line_number));
            continue;
        }
        if (line_number == 1) {
            if (!std::equal(fields.begin(), fields.end(), expected_header.begin())) {
                AddCatalogDiagnostic(
                    catalog,
                    BindingDiagnosticCode::InvalidCatalog,
                    {},
                    "header");
            }
            continue;
        }

        const auto& record_type = fields[0];
        const auto& canonical = fields[1];
        if (record_type == "BINDING") {
            if (canonical.empty() || fields[2].empty() || !IsSha256(fields[3])
                || fields[4].empty() || !IsSha256(fields[5]) || !fields[6].empty()) {
                AddCatalogDiagnostic(
                    catalog,
                    BindingDiagnosticCode::InvalidCatalog,
                    canonical,
                    "line " + std::to_string(line_number));
                continue;
            }
            catalog.bindings.push_back(BindingDisposition{
                canonical,
                fields[2],
                fields[3],
                fields[4],
                fields[5],
            });
        } else if (record_type == "RETIRED") {
            if (canonical.empty() || fields[2].empty() || !IsSha256(fields[3])
                || !fields[4].empty() || !fields[5].empty() || !fields[6].empty()) {
                AddCatalogDiagnostic(
                    catalog,
                    BindingDiagnosticCode::InvalidCatalog,
                    canonical,
                    "line " + std::to_string(line_number));
                continue;
            }
            catalog.retired.push_back(RetiredDisposition{canonical, fields[2], fields[3]});
        } else if (record_type == "ALIAS") {
            if (canonical.empty() || !fields[2].empty() || !fields[3].empty()
                || !fields[4].empty() || !fields[5].empty() || fields[6].empty()) {
                AddCatalogDiagnostic(
                    catalog,
                    BindingDiagnosticCode::InvalidCatalog,
                    canonical,
                    "line " + std::to_string(line_number));
                continue;
            }
            catalog.aliases.push_back(AliasDisposition{fields[6], canonical});
        } else {
            AddCatalogDiagnostic(
                catalog,
                BindingDiagnosticCode::InvalidCatalog,
                canonical,
                "line " + std::to_string(line_number));
        }
    }
    return catalog;
}

CompileResult CompileBindings(
    const fs::path& overlay_root,
    const fs::path& preset_root,
    const DispositionCatalog& catalog) {
    CompileResult result;
    result.diagnostics = catalog.diagnostics;
    result.counts.retired_overlays = catalog.retired.size();
    result.counts.aliases = catalog.aliases.size();

    std::map<std::string, const BindingDisposition*> bindings_by_identity;
    std::map<std::string, const BindingDisposition*> selected_by_file;
    std::map<std::string, const BindingDisposition*> bindings_by_preset;
    for (const auto& binding : catalog.bindings) {
        if (binding.canonical_identity.empty() || binding.selected_overlay_file.empty()
            || !IsSha256(binding.selected_overlay_sha256)
            || binding.preset_directory.empty() || !IsSha256(binding.preset_info_sha256)) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::InvalidCatalog,
                binding.canonical_identity,
                binding.selected_overlay_file);
        }
        if (!bindings_by_identity.emplace(binding.canonical_identity, &binding).second) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::DuplicateCatalogEntry,
                binding.canonical_identity,
                binding.selected_overlay_file);
        }
        if (!selected_by_file.emplace(binding.selected_overlay_file, &binding).second) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::DuplicateCatalogEntry,
                binding.canonical_identity,
                binding.selected_overlay_file);
        }
        if (!bindings_by_preset.emplace(binding.preset_directory, &binding).second) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::DuplicateCatalogEntry,
                binding.canonical_identity,
                binding.preset_directory);
        }
    }

    std::map<std::string, const RetiredDisposition*> retired_by_file;
    for (const auto& retired : catalog.retired) {
        if (retired.canonical_identity.empty() || retired.overlay_file.empty()
            || !IsSha256(retired.overlay_sha256)
            || !bindings_by_identity.contains(retired.canonical_identity)) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::InvalidCatalog,
                retired.canonical_identity,
                retired.overlay_file);
        }
        if (!retired_by_file.emplace(retired.overlay_file, &retired).second
            || selected_by_file.contains(retired.overlay_file)) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::DuplicateCatalogEntry,
                retired.canonical_identity,
                retired.overlay_file);
        }
    }

    std::map<std::string, std::string> aliases;
    for (const auto& alias : catalog.aliases) {
        if (alias.alias.empty() || alias.canonical_identity.empty()
            || !bindings_by_identity.contains(alias.canonical_identity)) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::InvalidCatalog,
                alias.canonical_identity,
                alias.alias);
            continue;
        }
        if (const auto canonical_collision = bindings_by_identity.find(alias.alias);
            canonical_collision != bindings_by_identity.end()
            && alias.alias != alias.canonical_identity) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::AmbiguousAlias,
                alias.canonical_identity,
                alias.alias);
            ++result.counts.ambiguous_aliases;
        }
        const auto [existing, inserted] = aliases.emplace(alias.alias, alias.canonical_identity);
        if (!inserted) {
            const auto code = existing->second == alias.canonical_identity
                ? BindingDiagnosticCode::DuplicateCatalogEntry
                : BindingDiagnosticCode::AmbiguousAlias;
            AddResultDiagnostic(result, code, alias.canonical_identity, alias.alias);
            if (code == BindingDiagnosticCode::AmbiguousAlias) {
                ++result.counts.ambiguous_aliases;
            }
        }
    }

    std::vector<fs::path> overlay_paths;
    try {
        for (const auto& entry : fs::directory_iterator{overlay_root}) {
            if (entry.is_regular_file()
                && LowerAscii(PathToUtf8(entry.path().extension())) == ".ini") {
                overlay_paths.push_back(entry.path());
            }
        }
    } catch (const std::exception&) {
        AddResultDiagnostic(
            result,
            BindingDiagnosticCode::IoError,
            {},
            PathToUtf8(overlay_root));
    }
    std::ranges::sort(overlay_paths, {}, [](const fs::path& path) {
        return PathToUtf8(path.filename());
    });

    std::vector<OverlayMetadata> overlays;
    for (const auto& path : overlay_paths) {
        try {
            auto parsed = ParseOverlayMetadataOnly(path);
            if (!parsed.has_ui_groups || parsed.metadata.ui_groups != kKreateOverlayGroup) {
                continue;
            }
            ++result.counts.discovered_overlays;
            parsed.metadata.sha256 = Sha256File(path);
            if (!parsed.found_section || !parsed.has_ui_name || !parsed.has_ui_ordering) {
                AddResultDiagnostic(
                    result,
                    BindingDiagnosticCode::InvalidOverlayMetadata,
                    OverlayIdentity(parsed.metadata.ui_name),
                    parsed.metadata.filename);
                ++result.counts.unresolved_entries;
                continue;
            }
            overlays.push_back(std::move(parsed.metadata));
        } catch (const std::exception&) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::IoError,
                {},
                PathToUtf8(path.filename()));
        }
    }

    std::map<std::string, const OverlayMetadata*> overlays_by_file;
    std::map<std::string, std::vector<const OverlayMetadata*>> overlays_by_identity;
    std::map<std::string, std::string> resolved_identity_by_file;
    for (const auto& overlay : overlays) {
        overlays_by_file.emplace(overlay.filename, &overlay);
        const auto raw_identity = OverlayIdentity(overlay.ui_name);
        std::string canonical_identity;
        if (bindings_by_identity.contains(raw_identity)) {
            canonical_identity = raw_identity;
        } else if (const auto alias = aliases.find(raw_identity); alias != aliases.end()) {
            canonical_identity = alias->second;
        } else {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::UnknownIdentity,
                raw_identity,
                overlay.filename);
            ++result.counts.unresolved_entries;
        }

        if (!canonical_identity.empty()) {
            overlays_by_identity[canonical_identity].push_back(&overlay);
            resolved_identity_by_file.emplace(overlay.filename, canonical_identity);
        }

        const auto selected = selected_by_file.find(overlay.filename);
        const auto retired = retired_by_file.find(overlay.filename);
        if (selected == selected_by_file.end() && retired == retired_by_file.end()) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::UnaccountedOverlay,
                canonical_identity.empty() ? raw_identity : canonical_identity,
                overlay.filename);
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::UnboundOverlay,
                canonical_identity.empty() ? raw_identity : canonical_identity,
                overlay.filename);
            ++result.counts.unbound_overlays;
        } else if (selected != selected_by_file.end()) {
            if (!canonical_identity.empty()
                && selected->second->canonical_identity != canonical_identity) {
                AddResultDiagnostic(
                    result,
                    BindingDiagnosticCode::InvalidCatalog,
                    canonical_identity,
                    overlay.filename);
            }
            if (overlay.sha256 != selected->second->selected_overlay_sha256) {
                AddResultDiagnostic(
                    result,
                    BindingDiagnosticCode::SelectedHashChanged,
                    selected->second->canonical_identity,
                    overlay.filename);
            }
        } else {
            if (!canonical_identity.empty()
                && retired->second->canonical_identity != canonical_identity) {
                AddResultDiagnostic(
                    result,
                    BindingDiagnosticCode::InvalidCatalog,
                    canonical_identity,
                    overlay.filename);
            }
            if (overlay.sha256 != retired->second->overlay_sha256) {
                AddResultDiagnostic(
                    result,
                    BindingDiagnosticCode::RetiredHashChanged,
                    retired->second->canonical_identity,
                    overlay.filename);
            }
        }
    }

    for (const auto& binding : catalog.bindings) {
        if (!overlays_by_file.contains(binding.selected_overlay_file)) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::MissingSelectedOverlay,
                binding.canonical_identity,
                binding.selected_overlay_file);
        }
    }
    for (const auto& retired : catalog.retired) {
        if (!overlays_by_file.contains(retired.overlay_file)) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::MissingRetiredOverlay,
                retired.canonical_identity,
                retired.overlay_file);
        }
    }

    for (const auto& [identity, identity_overlays] : overlays_by_identity) {
        if (identity_overlays.size() < 2) {
            continue;
        }
        std::set<std::string> hashes;
        bool has_unaccounted = false;
        for (const auto* overlay : identity_overlays) {
            hashes.insert(overlay->sha256);
            has_unaccounted = has_unaccounted
                || (!selected_by_file.contains(overlay->filename)
                    && !retired_by_file.contains(overlay->filename));
        }
        if (hashes.size() > 1 && has_unaccounted) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::DivergentDuplicateWithoutDisposition,
                identity,
                {});
        }
    }

    std::vector<fs::path> preset_directories;
    try {
        for (const auto& entry : fs::directory_iterator{preset_root}) {
            if (entry.is_directory()) {
                preset_directories.push_back(entry.path());
            }
        }
    } catch (const std::exception&) {
        AddResultDiagnostic(
            result,
            BindingDiagnosticCode::IoError,
            {},
            PathToUtf8(preset_root));
    }
    std::ranges::sort(preset_directories, {}, [](const fs::path& path) {
        return PathToUtf8(path.filename());
    });

    std::set<std::string> present_presets;
    std::map<std::string, PresetMetadata> valid_presets;
    for (const auto& directory : preset_directories) {
        const auto directory_name = PathToUtf8(directory.filename());
        present_presets.insert(directory_name);
        try {
            auto parsed = ParsePresetMetadataOnly(directory);
            if (!parsed.complete) {
                AddResultDiagnostic(
                    result,
                    BindingDiagnosticCode::InvalidPresetMetadata,
                    directory_name,
                    "PresetInfo.ini");
            } else {
                valid_presets.emplace(directory_name, std::move(parsed.metadata));
            }
        } catch (const std::exception&) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::InvalidPresetMetadata,
                directory_name,
                "PresetInfo.ini");
        }

        if (!bindings_by_preset.contains(directory_name)) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::OrphanPreset,
                directory_name,
                directory_name);
            ++result.counts.orphan_presets;
        }
    }

    for (const auto& binding : catalog.bindings) {
        if (!present_presets.contains(binding.preset_directory)) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::MissingPreset,
                binding.canonical_identity,
                binding.preset_directory);
            continue;
        }
        if (const auto preset = valid_presets.find(binding.preset_directory);
            preset != valid_presets.end()
            && preset->second.sha256 != binding.preset_info_sha256) {
            AddResultDiagnostic(
                result,
                BindingDiagnosticCode::PresetHashChanged,
                binding.canonical_identity,
                binding.preset_directory);
        }
    }

    if (result.diagnostics.empty()) {
        for (const auto& binding : catalog.bindings) {
            CompiledBinding compiled{
                binding.canonical_identity,
                binding.selected_overlay_file,
                binding.selected_overlay_sha256,
                binding.preset_directory,
                binding.preset_info_sha256,
                {},
                {},
            };
            for (const auto& alias : catalog.aliases) {
                if (alias.canonical_identity == binding.canonical_identity) {
                    compiled.aliases.push_back(alias.alias);
                }
            }
            for (const auto& retired : catalog.retired) {
                if (retired.canonical_identity == binding.canonical_identity) {
                    compiled.retired_overlay_ids.push_back(retired.overlay_file);
                }
            }
            std::ranges::sort(compiled.aliases);
            std::ranges::sort(compiled.retired_overlay_ids);
            result.bindings.push_back(std::move(compiled));
        }
        std::ranges::sort(result.bindings, {}, &CompiledBinding::canonical_identity);
        result.counts.compiled_bindings = result.bindings.size();
    } else {
        result.bindings.clear();
        result.counts.compiled_bindings = 0;
    }
    return result;
}

bool HasDiagnostic(const CompileResult& result, const BindingDiagnosticCode code) noexcept {
    return std::ranges::any_of(result.diagnostics, [code](const BindingDiagnostic& diagnostic) {
        return diagnostic.code == code;
    });
}

bool WriteManifest(const fs::path& path, const CompileResult& result) {
    if (!result.success() || !PrepareOutput(path)) {
        return false;
    }
    std::ofstream output{path, std::ios::binary | std::ios::trunc};
    if (!output) {
        return false;
    }
    output << "canonical_identity,overlay_id,overlay_sha256,preset_id,preset_info_sha256,"
              "aliases,retired_overlay_ids\n";
    for (const auto& binding : result.bindings) {
        output << CsvField(binding.canonical_identity) << ','
               << CsvField(binding.overlay_id) << ','
               << CsvField(binding.overlay_sha256) << ','
               << CsvField(binding.preset_id) << ','
               << CsvField(binding.preset_info_sha256) << ','
               << CsvField(Join(binding.aliases)) << ','
               << CsvField(Join(binding.retired_overlay_ids)) << '\n';
    }
    return static_cast<bool>(output);
}

bool WriteReport(const fs::path& path, const CompileResult& result) {
    if (!PrepareOutput(path)) {
        return false;
    }
    std::ofstream output{path, std::ios::binary | std::ios::trunc};
    if (!output) {
        return false;
    }
    output << "status=" << (result.success() ? "OK" : "FAILED") << '\n'
           << "discovered_overlays=" << result.counts.discovered_overlays << '\n'
           << "compiled_bindings=" << result.counts.compiled_bindings << '\n'
           << "retired_overlays=" << result.counts.retired_overlays << '\n'
           << "aliases=" << result.counts.aliases << '\n'
           << "unresolved_entries=" << result.counts.unresolved_entries << '\n'
           << "ambiguous_aliases=" << result.counts.ambiguous_aliases << '\n'
           << "orphan_presets=" << result.counts.orphan_presets << '\n'
           << "unbound_overlays=" << result.counts.unbound_overlays << '\n'
           << "diagnostics=" << result.diagnostics.size() << '\n';
    for (const auto& diagnostic : result.diagnostics) {
        output << "diagnostic=" << ToString(diagnostic.code) << '|'
               << diagnostic.identity << '|' << diagnostic.entry << '\n';
    }
    return static_cast<bool>(output);
}

bool OutputPathsAreSafe(
    const fs::path& overlay_root,
    const fs::path& preset_root,
    const fs::path& manifest_path,
    const fs::path& report_path) {
    return NormalizedPath(manifest_path) != NormalizedPath(report_path)
        && !PathIsWithin(overlay_root, manifest_path)
        && !PathIsWithin(overlay_root, report_path)
        && !PathIsWithin(preset_root, manifest_path)
        && !PathIsWithin(preset_root, report_path);
}

std::optional<profiles::ProfilePackage> MakeProfilePackage(
    const CompileResult& result,
    const std::string_view identity,
    std::vector<profiles::ProfileOperation> operations) {
    if (!result.success()) {
        return std::nullopt;
    }
    for (const auto& binding : result.bindings) {
        const auto matches_alias = std::ranges::find(binding.aliases, identity)
            != binding.aliases.end();
        if (binding.canonical_identity == identity || matches_alias) {
            return profiles::ProfilePackage{
                binding.overlay_id,
                binding.preset_id,
                std::move(operations),
            };
        }
    }
    return std::nullopt;
}

std::string_view ToString(const BindingDiagnosticCode code) noexcept {
    switch (code) {
    case BindingDiagnosticCode::InvalidCatalog:
        return "INVALID_CATALOG";
    case BindingDiagnosticCode::DuplicateCatalogEntry:
        return "DUPLICATE_CATALOG_ENTRY";
    case BindingDiagnosticCode::AmbiguousAlias:
        return "AMBIGUOUS_ALIAS";
    case BindingDiagnosticCode::UnknownIdentity:
        return "UNKNOWN_IDENTITY";
    case BindingDiagnosticCode::InvalidOverlayMetadata:
        return "INVALID_OVERLAY_METADATA";
    case BindingDiagnosticCode::InvalidPresetMetadata:
        return "INVALID_PRESET_METADATA";
    case BindingDiagnosticCode::MissingSelectedOverlay:
        return "MISSING_SELECTED_OVERLAY";
    case BindingDiagnosticCode::MissingRetiredOverlay:
        return "MISSING_RETIRED_OVERLAY";
    case BindingDiagnosticCode::MissingPreset:
        return "MISSING_PRESET";
    case BindingDiagnosticCode::SelectedHashChanged:
        return "SELECTED_HASH_CHANGED";
    case BindingDiagnosticCode::RetiredHashChanged:
        return "RETIRED_HASH_CHANGED";
    case BindingDiagnosticCode::PresetHashChanged:
        return "PRESET_HASH_CHANGED";
    case BindingDiagnosticCode::UnaccountedOverlay:
        return "UNACCOUNTED_OVERLAY";
    case BindingDiagnosticCode::UnboundOverlay:
        return "UNBOUND_OVERLAY";
    case BindingDiagnosticCode::DivergentDuplicateWithoutDisposition:
        return "DIVERGENT_DUPLICATE_WITHOUT_DISPOSITION";
    case BindingDiagnosticCode::OrphanPreset:
        return "ORPHAN_PRESET";
    case BindingDiagnosticCode::UnsafeOutputPath:
        return "UNSAFE_OUTPUT_PATH";
    case BindingDiagnosticCode::ExpectationMismatch:
        return "EXPECTATION_MISMATCH";
    case BindingDiagnosticCode::IoError:
        return "IO_ERROR";
    }
    return "UNKNOWN_BINDING_DIAGNOSTIC";
}

}  // namespace elder::bindings
