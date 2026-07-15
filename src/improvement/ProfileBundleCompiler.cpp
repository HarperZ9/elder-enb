#include "elder/improvement/ProfileBundleCompiler.hpp"

#include "elder/audit/LegacyPresetAudit.hpp"

#include <algorithm>
#include <charconv>
#include <cmath>
#include <fstream>
#include <iterator>
#include <map>
#include <optional>
#include <set>
#include <sstream>
#include <system_error>
#include <tuple>
#include <utility>

namespace elder::improvement {
namespace {

namespace fs = std::filesystem;

constexpr std::string_view kManifestHeader =
    "record_type,bundle_id,profile_id,overlay_file,overlay_sha256,preset_directory,"
    "preset_tree_sha256,expected_repairs,art_direction,layer,relative_path,file_sha256,"
    "section,key,semantic_type,guard_value,operation,operand,min_value,max_value,rationale";

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
    const auto value = path.generic_u8string();
    return std::string{
        reinterpret_cast<const char*>(value.data()),
        value.size(),
    };
}

[[nodiscard]] fs::path Utf8ToPath(const std::string_view value) {
    const auto* begin = reinterpret_cast<const char8_t*>(value.data());
    return fs::path{std::u8string{begin, begin + value.size()}};
}

[[nodiscard]] bool IsSha256(const std::string_view value) {
    if (value.size() != 64) {
        return false;
    }
    return std::ranges::all_of(value, [](const unsigned char character) {
        return (character >= '0' && character <= '9')
            || (character >= 'a' && character <= 'f')
            || (character >= 'A' && character <= 'F');
    });
}

[[nodiscard]] bool IsSafeRelativePath(const std::string_view value) {
    if (value.empty()) {
        return false;
    }
    const auto path = Utf8ToPath(value);
    if (path.is_absolute() || path.has_root_path()) {
        return false;
    }
    for (const auto& component : path) {
        if (component == "." || component == "..") {
            return false;
        }
    }
    return true;
}

[[nodiscard]] bool IsSafeBundleId(const std::string_view value) {
    return !value.empty() && std::ranges::all_of(value, [](const unsigned char character) {
        return (character >= 'a' && character <= 'z')
            || (character >= '0' && character <= '9')
            || character == '.' || character == '_' || character == '-';
    });
}

[[nodiscard]] std::optional<double> ParseDouble(const std::string_view value) {
    const auto trimmed = Trim(value);
    if (trimmed.empty()) {
        return std::nullopt;
    }
    double parsed = 0.0;
    const auto* begin = trimmed.data();
    const auto* end = begin + trimmed.size();
    const auto conversion = std::from_chars(begin, end, parsed, std::chars_format::general);
    if (conversion.ec != std::errc{} || conversion.ptr != end || !std::isfinite(parsed)) {
        return std::nullopt;
    }
    return parsed;
}

[[nodiscard]] std::optional<std::size_t> ParseCount(const std::string_view value) {
    const auto trimmed = Trim(value);
    std::size_t parsed = 0;
    const auto* begin = trimmed.data();
    const auto* end = begin + trimmed.size();
    const auto conversion = std::from_chars(begin, end, parsed);
    if (conversion.ec != std::errc{} || conversion.ptr != end) {
        return std::nullopt;
    }
    return parsed;
}

[[nodiscard]] std::optional<std::vector<double>> ParseVector(
    const std::string_view value,
    const std::optional<std::size_t> expected = std::nullopt) {
    std::vector<double> values;
    std::size_t start = 0;
    while (start <= value.size()) {
        const auto separator = value.find(',', start);
        const auto token = value.substr(
            start,
            separator == std::string_view::npos ? value.size() - start : separator - start);
        const auto number = ParseDouble(token);
        if (!number.has_value()) {
            return std::nullopt;
        }
        values.push_back(*number);
        if (separator == std::string_view::npos) {
            break;
        }
        start = separator + 1;
    }
    if (expected.has_value() && values.size() != *expected) {
        return std::nullopt;
    }
    return values;
}

[[nodiscard]] std::string FormatDouble(const double value) {
    char buffer[64]{};
    const auto conversion = std::to_chars(
        std::begin(buffer),
        std::end(buffer),
        value == 0.0 ? 0.0 : value,
        std::chars_format::fixed,
        6);
    if (conversion.ec != std::errc{}) {
        return {};
    }
    std::string output{buffer, conversion.ptr};
    while (output.contains('.') && output.ends_with('0')) {
        output.pop_back();
    }
    if (output.ends_with('.')) {
        output.pop_back();
    }
    return output;
}

[[nodiscard]] std::string FormatVector(const std::vector<double>& values) {
    std::string output;
    for (std::size_t index = 0; index < values.size(); ++index) {
        if (index != 0) {
            output += ", ";
        }
        output += FormatDouble(values[index]);
    }
    return output;
}

[[nodiscard]] std::optional<std::vector<double>> ParseOverlayOperation(
    const std::string_view value) {
    if (value.size() < 5 || value.front() != '"' || value.back() != '"') {
        return std::nullopt;
    }
    const auto body = Trim(value.substr(1, value.size() - 2));
    if (!(body.starts_with("+") || body.starts_with("="))) {
        return std::nullopt;
    }
    return ParseVector(Trim(std::string_view{body}.substr(1)));
}

[[nodiscard]] std::optional<std::vector<double>> SemanticValues(
    const SemanticType type,
    const std::string_view value) {
    switch (type) {
        case SemanticType::Scalar: {
            const auto parsed = ParseVector(value, 1);
            return parsed;
        }
        case SemanticType::Vector3:
            return ParseVector(value, 3);
        case SemanticType::Vector4:
            return ParseVector(value, 4);
        case SemanticType::OverlayOperation:
            return ParseOverlayOperation(value);
    }
    return std::nullopt;
}

[[nodiscard]] bool ValuesInBounds(
    const std::vector<double>& values,
    const double minimum,
    const double maximum) {
    return std::ranges::all_of(values, [minimum, maximum](const double value) {
        return std::isfinite(value) && value >= minimum && value <= maximum;
    });
}

struct TransformResult {
    bool valid{false};
    bool bounds_valid{false};
    std::string value;
};

[[nodiscard]] TransformResult TransformValue(const TransformRule& rule) {
    TransformResult result;
    if (!(std::isfinite(rule.min_value) && std::isfinite(rule.max_value))
        || rule.min_value > rule.max_value) {
        return result;
    }
    if (rule.operation == RuleOperation::Set) {
        const auto values = SemanticValues(rule.semantic_type, rule.operand);
        if (!values.has_value()) {
            return result;
        }
        result.valid = true;
        result.bounds_valid = ValuesInBounds(*values, rule.min_value, rule.max_value);
        result.value = rule.operand;
        return result;
    }

    const auto guarded = SemanticValues(rule.semantic_type, rule.guard_value);
    if (!guarded.has_value() || rule.semantic_type == SemanticType::OverlayOperation) {
        return result;
    }
    auto transformed = *guarded;
    if (rule.operation == RuleOperation::Scale) {
        const auto factor = ParseDouble(rule.operand);
        if (!factor.has_value()) {
            return result;
        }
        for (auto& value : transformed) {
            value *= *factor;
        }
    } else if (rule.operation == RuleOperation::ScaleRgb) {
        const auto factors = ParseVector(rule.operand, 3);
        if (!factors.has_value() || transformed.size() != 3) {
            return result;
        }
        for (std::size_t index = 0; index < transformed.size(); ++index) {
            transformed[index] *= (*factors)[index];
        }
    }
    result.valid = true;
    result.bounds_valid = ValuesInBounds(transformed, rule.min_value, rule.max_value);
    if (rule.semantic_type == SemanticType::Scalar) {
        result.value = FormatDouble(transformed.front());
    } else {
        result.value = FormatVector(transformed);
    }
    return result;
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
        } else if (after_quote) {
            if (character == ',') {
                fields.push_back(field);
                field.clear();
                after_quote = false;
            } else if (character != ' ' && character != '\t' && character != '\r') {
                valid = false;
                return {};
            }
        } else if (character == ',' ) {
            fields.push_back(Trim(field));
            field.clear();
        } else if (character == '"') {
            if (!Trim(field).empty()) {
                valid = false;
                return {};
            }
            field.clear();
            quoted = true;
        } else if (character != '\r') {
            field += character;
        }
    }
    if (quoted) {
        valid = false;
        return {};
    }
    fields.push_back(after_quote ? field : Trim(field));
    return fields;
}

[[nodiscard]] std::optional<RuleLayer> ParseLayer(const std::string_view value) {
    if (value == "OVERLAY") {
        return RuleLayer::Overlay;
    }
    if (value == "KREATE") {
        return RuleLayer::Kreate;
    }
    return std::nullopt;
}

[[nodiscard]] std::optional<SemanticType> ParseSemantic(const std::string_view value) {
    if (value == "SCALAR") {
        return SemanticType::Scalar;
    }
    if (value == "VECTOR3") {
        return SemanticType::Vector3;
    }
    if (value == "VECTOR4") {
        return SemanticType::Vector4;
    }
    if (value == "OVERLAY_OPERATION") {
        return SemanticType::OverlayOperation;
    }
    return std::nullopt;
}

[[nodiscard]] std::optional<RuleOperation> ParseOperation(const std::string_view value) {
    if (value == "SET") {
        return RuleOperation::Set;
    }
    if (value == "SCALE") {
        return RuleOperation::Scale;
    }
    if (value == "SCALE_RGB") {
        return RuleOperation::ScaleRgb;
    }
    return std::nullopt;
}

void AddDiagnostic(
    BundleCompileResult& result,
    const BundleDiagnosticCode code,
    const std::string& profile = {},
    const std::string& path = {},
    const std::string& section = {},
    const std::string& key = {}) {
    result.diagnostics.push_back(BundleDiagnostic{code, profile, path, section, key});
}

void AddManifestDiagnostic(ImprovementManifest& manifest) {
    manifest.diagnostics.push_back(BundleDiagnostic{
        BundleDiagnosticCode::InvalidManifest,
        {},
        {},
        {},
        {},
    });
}

[[nodiscard]] std::string ReadFile(const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("read failure");
    }
    std::string bytes{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{},
    };
    if (input.bad()) {
        throw std::runtime_error("read failure");
    }
    return bytes;
}

void WriteFile(const fs::path& path, const std::string_view bytes) {
    fs::create_directories(path.parent_path());
    std::ofstream output{path, std::ios::binary | std::ios::trunc};
    if (!output) {
        throw std::runtime_error("write failure");
    }
    output.write(bytes.data(), static_cast<std::streamsize>(bytes.size()));
    if (!output) {
        throw std::runtime_error("write failure");
    }
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

[[nodiscard]] std::map<std::pair<std::string, std::string>, std::size_t> IniSchema(
    const std::string_view bytes) {
    std::map<std::pair<std::string, std::string>, std::size_t> schema;
    std::string section;
    std::size_t start = 0;
    while (start <= bytes.size()) {
        const auto newline = bytes.find('\n', start);
        auto line = bytes.substr(
            start,
            newline == std::string_view::npos ? bytes.size() - start : newline - start);
        if (!line.empty() && line.back() == '\r') {
            line.remove_suffix(1);
        }
        const auto trimmed = Trim(line);
        if (trimmed.size() >= 2 && trimmed.front() == '[' && trimmed.back() == ']') {
            section = Trim(std::string_view{trimmed}.substr(1, trimmed.size() - 2));
        } else if (!trimmed.empty() && trimmed.front() != ';' && trimmed.front() != '#') {
            const auto separator = trimmed.find('=');
            if (separator != std::string::npos) {
                const auto key = Trim(std::string_view{trimmed}.substr(0, separator));
                ++schema[{section, key}];
            }
        }
        if (newline == std::string_view::npos) {
            break;
        }
        start = newline + 1;
    }
    return schema;
}

enum class OverlayBindingStatus {
    Resolved,
    Missing,
    Ambiguous,
    Unsupported,
};

struct ResolvedOverlayBinding {
    OverlayBindingStatus status{OverlayBindingStatus::Missing};
    std::string target_filename;
    std::string target_category;
    std::string target_key;
    std::string target_type;
};

[[nodiscard]] bool IsOverlayTargetToken(const std::string_view value) {
    return !value.empty() && std::ranges::all_of(value, [](const unsigned char character) {
        return (character >= 'A' && character <= 'Z')
            || (character >= 'a' && character <= 'z')
            || (character >= '0' && character <= '9')
            || character == '.' || character == '_' || character == '-';
    });
}

[[nodiscard]] ResolvedOverlayBinding ResolveOverlayBinding(
    const std::string_view bytes,
    const TransformRule& rule) {
    ResolvedOverlayBinding resolved;
    if (!rule.section.starts_with("OVERLAYPARAM") || rule.key != "Operation"
        || rule.semantic_type != SemanticType::OverlayOperation) {
        resolved.status = OverlayBindingStatus::Unsupported;
        return resolved;
    }

    std::map<std::string, std::vector<std::string>> fields;
    std::string section;
    std::size_t start = 0;
    while (start <= bytes.size()) {
        const auto newline = bytes.find('\n', start);
        const auto line_end = newline == std::string_view::npos ? bytes.size() : newline;
        auto content = bytes.substr(start, line_end - start);
        if (!content.empty() && content.back() == '\r') {
            content.remove_suffix(1);
        }
        const auto trimmed = Trim(content);
        if (trimmed.size() >= 2 && trimmed.front() == '[' && trimmed.back() == ']') {
            section = Trim(std::string_view{trimmed}.substr(1, trimmed.size() - 2));
        } else if (section == rule.section && !trimmed.empty()
                   && trimmed.front() != ';' && trimmed.front() != '#') {
            const auto separator = content.find('=');
            if (separator != std::string_view::npos) {
                const auto key = Trim(content.substr(0, separator));
                if (key == "Category" || key == "Name" || key == "Operation") {
                    fields[key].push_back(Trim(content.substr(separator + 1)));
                }
            }
        }
        if (newline == std::string_view::npos) {
            break;
        }
        start = newline + 1;
    }

    for (const std::string_view field : {"Category", "Name", "Operation"}) {
        const auto found = fields.find(std::string{field});
        if (found == fields.end() || found->second.empty()) {
            resolved.status = OverlayBindingStatus::Missing;
            return resolved;
        }
        if (found->second.size() != 1) {
            resolved.status = OverlayBindingStatus::Ambiguous;
            return resolved;
        }
    }

    resolved.target_filename = fields.at("Category").front();
    const auto& name = fields.at("Name").front();
    const auto delimiter = name.find('|');
    if (!IsOverlayTargetToken(resolved.target_filename)
        || !resolved.target_filename.ends_with(".FX")
        || delimiter == std::string::npos || name.find('|', delimiter + 1) != std::string::npos) {
        resolved.status = OverlayBindingStatus::Unsupported;
        return resolved;
    }
    resolved.target_category = Trim(std::string_view{name}.substr(0, delimiter));
    resolved.target_key = Trim(std::string_view{name}.substr(delimiter + 1));
    if (!IsOverlayTargetToken(resolved.target_category) || resolved.target_key.empty()) {
        resolved.status = OverlayBindingStatus::Unsupported;
        return resolved;
    }

    const auto& operation = fields.at("Operation").front();
    const auto values = ParseOverlayOperation(operation);
    if (!values.has_value() || values->empty() || values->size() > 4
        || operation.size() < 3) {
        resolved.status = OverlayBindingStatus::Unsupported;
        return resolved;
    }
    const auto body = Trim(std::string_view{operation}.substr(1, operation.size() - 2));
    if (body.empty() || (body.front() != '+' && body.front() != '=')) {
        resolved.status = OverlayBindingStatus::Unsupported;
        return resolved;
    }
    resolved.target_type = body.front() == '+' ? "ADD_" : "SET_";
    if (values->size() == 1) {
        resolved.target_type += "SCALAR";
    } else {
        resolved.target_type += "VECTOR" + std::to_string(values->size());
    }
    resolved.status = OverlayBindingStatus::Resolved;
    return resolved;
}

enum class RepairStatus {
    None,
    Repaired,
    Ambiguous,
};

struct RepairResult {
    RepairStatus status{RepairStatus::None};
    std::string bytes;
    std::string vector;
};

[[nodiscard]] RepairResult RepairFusedDepthOfField(const std::string_view bytes) {
    constexpr std::string_view marker = "[DepthOfField]";
    RepairResult result;
    result.bytes.reserve(bytes.size() + 2);
    std::size_t exact_count = 0;
    bool ambiguous = false;
    std::size_t start = 0;
    while (start <= bytes.size()) {
        const auto newline = bytes.find('\n', start);
        const auto line_end = newline == std::string_view::npos ? bytes.size() : newline;
        auto raw_line = bytes.substr(start, line_end - start);
        const bool has_cr = !raw_line.empty() && raw_line.back() == '\r';
        auto content = raw_line;
        if (has_cr) {
            content.remove_suffix(1);
        }
        const auto trimmed = Trim(content);
        const auto marker_position = trimmed.find(marker);
        if (marker_position != std::string::npos) {
            if (trimmed == marker) {
                // Already a valid standalone section.
            } else if (marker_position + marker.size() == trimmed.size()
                       && trimmed.find(marker, marker_position + 1) == std::string::npos) {
                const auto prefix = std::string_view{trimmed}.substr(0, marker_position);
                const auto separator = prefix.find('=');
                const auto key = separator == std::string_view::npos
                    ? std::string{}
                    : Trim(prefix.substr(0, separator));
                const auto value = separator == std::string_view::npos
                    ? std::string{}
                    : Trim(prefix.substr(separator + 1));
                const auto vector = ParseVector(value, 4);
                if (key != "Tint" || !vector.has_value()
                    || !ValuesInBounds(*vector, 0.0, 1.0)) {
                    ambiguous = true;
                } else {
                    ++exact_count;
                    result.vector = value;
                    const auto absolute_marker = content.find(marker);
                    result.bytes.append(content.substr(0, absolute_marker));
                    result.bytes += has_cr ? "\r\n" : "\n";
                    result.bytes += marker;
                    if (has_cr) {
                        result.bytes += '\r';
                    }
                }
            } else {
                ambiguous = true;
            }
        }
        if (marker_position == std::string::npos || trimmed == marker) {
            result.bytes.append(raw_line);
        }
        if (newline == std::string_view::npos) {
            break;
        }
        result.bytes += '\n';
        start = newline + 1;
    }
    if (ambiguous || exact_count > 1) {
        result.status = RepairStatus::Ambiguous;
        return result;
    }
    if (exact_count == 1) {
        result.status = RepairStatus::Repaired;
        return result;
    }
    result.status = RepairStatus::None;
    result.bytes = std::string{bytes};
    return result;
}

struct ApplyResult {
    bool found{false};
    bool duplicate{false};
    bool guard_match{false};
    bool transform_valid{false};
    bool bounds_valid{false};
    std::string output_value;
    std::string bytes;
};

[[nodiscard]] ApplyResult ApplyRuleToIni(
    const std::string_view bytes,
    const TransformRule& rule) {
    ApplyResult result;
    result.bytes.reserve(bytes.size() + 32);
    const auto transformed = TransformValue(rule);
    result.transform_valid = transformed.valid;
    result.bounds_valid = transformed.bounds_valid;
    if (!transformed.valid || !transformed.bounds_valid) {
        result.bytes = std::string{bytes};
        return result;
    }
    result.output_value = transformed.value;

    std::string section;
    std::size_t matches = 0;
    std::size_t start = 0;
    while (start <= bytes.size()) {
        const auto newline = bytes.find('\n', start);
        const auto line_end = newline == std::string_view::npos ? bytes.size() : newline;
        auto raw_line = bytes.substr(start, line_end - start);
        const bool has_cr = !raw_line.empty() && raw_line.back() == '\r';
        auto content = raw_line;
        if (has_cr) {
            content.remove_suffix(1);
        }
        const auto trimmed = Trim(content);
        if (trimmed.size() >= 2 && trimmed.front() == '[' && trimmed.back() == ']') {
            section = Trim(std::string_view{trimmed}.substr(1, trimmed.size() - 2));
        }

        bool replaced = false;
        if (section == rule.section && !trimmed.empty() && trimmed.front() != ';'
            && trimmed.front() != '#' && trimmed.front() != '[') {
            const auto separator = content.find('=');
            if (separator != std::string_view::npos
                && Trim(content.substr(0, separator)) == rule.key) {
                ++matches;
                const auto value_start = content.find_first_not_of(" \t", separator + 1);
                const auto guarded_value = value_start == std::string_view::npos
                    ? std::string{}
                    : Trim(content.substr(value_start));
                if (guarded_value == rule.guard_value) {
                    result.guard_match = true;
                    const auto prefix_length = value_start == std::string_view::npos
                        ? separator + 1
                        : value_start;
                    result.bytes.append(content.substr(0, prefix_length));
                    result.bytes += transformed.value;
                    if (has_cr) {
                        result.bytes += '\r';
                    }
                    replaced = true;
                }
            }
        }
        if (!replaced) {
            result.bytes.append(raw_line);
        }
        if (newline == std::string_view::npos) {
            break;
        }
        result.bytes += '\n';
        start = newline + 1;
    }
    result.found = matches == 1;
    result.duplicate = matches > 1;
    return result;
}

[[nodiscard]] fs::path AbsoluteNormalized(const fs::path& path) {
    std::error_code error;
    const auto absolute = fs::absolute(path, error);
    return error ? path.lexically_normal() : absolute.lexically_normal();
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

[[nodiscard]] bool OutputIsSafe(
    const fs::path& overlay_root,
    const fs::path& preset_root,
    const fs::path& output_root) {
    if (output_root.empty() || output_root == output_root.root_path()) {
        return false;
    }
    const auto output = AbsoluteNormalized(output_root);
    const auto overlays = AbsoluteNormalized(overlay_root);
    const auto presets = AbsoluteNormalized(preset_root);
    return output != overlays && output != presets
        && !PathStartsWith(output, overlays) && !PathStartsWith(output, presets)
        && !PathStartsWith(overlays, output) && !PathStartsWith(presets, output);
}

[[nodiscard]] bool CopyTree(
    const fs::path& source,
    const fs::path& target,
    std::size_t& copied_files) {
    std::error_code error;
    fs::create_directories(target, error);
    if (error) {
        return false;
    }
    fs::recursive_directory_iterator iterator{
        source,
        fs::directory_options::skip_permission_denied,
        error};
    const fs::recursive_directory_iterator end;
    while (!error && iterator != end) {
        std::error_code type_error;
        if (iterator->is_symlink(type_error) || type_error) {
            return false;
        }
        const auto relative = iterator->path().lexically_relative(source);
        const auto destination = target / relative;
        if (iterator->is_directory(type_error) && !type_error) {
            fs::create_directories(destination, error);
        } else if (iterator->is_regular_file(type_error) && !type_error) {
            const auto bytes = ReadFile(iterator->path());
            WriteFile(destination, bytes);
            ++copied_files;
        }
        if (error || type_error) {
            return false;
        }
        iterator.increment(error);
    }
    return !error;
}

[[nodiscard]] std::uintmax_t DirectoryBytes(const fs::path& root) {
    std::uintmax_t total = 0;
    std::error_code error;
    for (fs::recursive_directory_iterator iterator{root, error}, end;
         !error && iterator != end;
         iterator.increment(error)) {
        std::error_code type_error;
        if (iterator->is_regular_file(type_error) && !type_error) {
            total += iterator->file_size(type_error);
        }
        if (type_error) {
            return 0;
        }
    }
    return error ? 0 : total;
}

[[nodiscard]] std::string BundlePayloadHash(const CompiledBundle& bundle) {
    return bindings::Sha256(
        std::string{"ELDER_PAIRED_BUNDLE_V1\n"}
        + bundle.bundle_id + "\n"
        + bundle.profile_id + "\n"
        + bundle.overlay_file + "\n"
        + bundle.overlay_sha256 + "\n"
        + bundle.preset_directory + "\n"
        + bundle.preset_tree_sha256 + "\n");
}

void WriteBundleMetadata(const fs::path& root, const CompiledBundle& bundle) {
    std::string csv =
        "bundle_id,profile_id,overlay_path,overlay_sha256,preset_path,preset_tree_sha256,"
        "bundle_sha256\n";
    csv += CsvField(bundle.bundle_id) + ',' + CsvField(bundle.profile_id) + ','
        + CsvField("overlay/" + bundle.overlay_file) + ',' + CsvField(bundle.overlay_sha256)
        + ',' + CsvField("preset/" + bundle.preset_directory) + ','
        + CsvField(bundle.preset_tree_sha256) + ',' + CsvField(bundle.bundle_sha256) + '\n';
    WriteFile(root / "bundle.csv", csv);
}

void WriteGlobalArtifacts(
    const fs::path& root,
    const BundleCompileResult& result) {
    std::string index =
        "bundle_id,profile_id,overlay_file,preset_directory,repairs,overlay_changes,"
        "kreate_changes,export_name_debt,record_files,overlay_sha256,preset_tree_sha256,"
        "bundle_sha256,bundle_bytes\n";
    for (const auto& bundle : result.bundles) {
        index += CsvField(bundle.bundle_id) + ',' + CsvField(bundle.profile_id) + ','
            + CsvField(bundle.overlay_file) + ',' + CsvField(bundle.preset_directory) + ','
            + std::to_string(bundle.repairs) + ',' + std::to_string(bundle.overlay_changes)
            + ',' + std::to_string(bundle.kreate_changes) + ','
            + std::to_string(bundle.export_name_debt) + ','
            + std::to_string(bundle.record_files) + ',' + CsvField(bundle.overlay_sha256)
            + ',' + CsvField(bundle.preset_tree_sha256) + ',' + CsvField(bundle.bundle_sha256)
            + ',' + std::to_string(bundle.bundle_bytes) + '\n';
    }
    WriteFile(root / "bundle-index.csv", index);

    std::string provenance =
        "profile_id,layer,relative_path,source_sha256,section,key,semantic_type,guard_value,"
        "operation,operand,output_value,target_filename,target_category,target_key,target_type,"
        "rationale_basis,rationale\n";
    for (const auto& entry : result.provenance) {
        provenance += CsvField(entry.profile_id) + ',' + CsvField(entry.layer) + ','
            + CsvField(entry.relative_path) + ',' + CsvField(entry.source_sha256) + ','
            + CsvField(entry.section) + ',' + CsvField(entry.key) + ','
            + CsvField(entry.semantic_type) + ',' + CsvField(entry.guard_value) + ','
            + CsvField(entry.operation) + ',' + CsvField(entry.operand) + ','
            + CsvField(entry.output_value) + ',' + CsvField(entry.target_filename) + ','
            + CsvField(entry.target_category) + ',' + CsvField(entry.target_key) + ','
            + CsvField(entry.target_type) + ',' + CsvField(entry.rationale_basis) + ','
            + CsvField(entry.rationale) + '\n';
    }
    WriteFile(root / "provenance.csv", provenance);

    std::string report =
        "format=elder-paired-profile-bundles-v1\n"
        "profiles=" + std::to_string(result.counts.profiles) + "\n"
        "copied_files=" + std::to_string(result.counts.copied_files) + "\n"
        "repairs=" + std::to_string(result.counts.repairs) + "\n"
        "overlay_changes=" + std::to_string(result.counts.overlay_changes) + "\n"
        "kreate_changes=" + std::to_string(result.counts.kreate_changes) + "\n"
        "export_name_debt=" + std::to_string(result.counts.export_name_debt) + "\n"
        "record_files=" + std::to_string(result.counts.record_files) + "\n";
    for (const auto& bundle : result.bundles) {
        report += "bundle," + CsvField(bundle.bundle_id) + ',' + CsvField(bundle.profile_id)
            + ',' + std::to_string(bundle.repairs) + ','
            + std::to_string(bundle.overlay_changes) + ','
            + std::to_string(bundle.kreate_changes) + ','
            + std::to_string(bundle.export_name_debt) + ','
            + std::to_string(bundle.record_files) + ',' + bundle.overlay_sha256 + ','
            + bundle.preset_tree_sha256 + ',' + bundle.bundle_sha256 + ','
            + std::to_string(bundle.bundle_bytes) + '\n';
    }
    WriteFile(root / "report.txt", report);
}

[[nodiscard]] std::vector<TransformRule> RulesFor(
    const ImprovementManifest& manifest,
    const std::string& profile) {
    std::vector<TransformRule> rules;
    std::ranges::copy_if(
        manifest.rules,
        std::back_inserter(rules),
        [&profile](const TransformRule& rule) {
            return rule.profile_id == profile;
        });
    return rules;
}

}  // namespace

bool BundleCompileResult::success() const noexcept {
    return diagnostics.empty();
}

ImprovementManifest LoadImprovementManifest(const fs::path& path) {
    ImprovementManifest manifest;
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        AddManifestDiagnostic(manifest);
        return manifest;
    }
    std::string line;
    if (!std::getline(input, line) || Trim(line) != kManifestHeader) {
        AddManifestDiagnostic(manifest);
        return manifest;
    }
    while (std::getline(input, line)) {
        if (Trim(line).empty()) {
            continue;
        }
        bool valid = false;
        const auto fields = ParseCsvRow(line, valid);
        if (!valid || fields.size() != 21) {
            AddManifestDiagnostic(manifest);
            continue;
        }
        if (fields[0] == "PROFILE") {
            const auto repairs = ParseCount(fields[7]);
            if (!repairs.has_value()) {
                AddManifestDiagnostic(manifest);
                continue;
            }
            manifest.profiles.push_back(ProfileSpec{
                fields[1], fields[2], fields[3], LowerAscii(fields[4]), fields[5],
                LowerAscii(fields[6]), *repairs, fields[8],
            });
        } else if (fields[0] == "RULE") {
            const auto layer = ParseLayer(fields[9]);
            const auto semantic = ParseSemantic(fields[14]);
            const auto operation = ParseOperation(fields[16]);
            const auto minimum = ParseDouble(fields[18]);
            const auto maximum = ParseDouble(fields[19]);
            if (!layer.has_value() || !semantic.has_value() || !operation.has_value()
                || !minimum.has_value() || !maximum.has_value()) {
                AddManifestDiagnostic(manifest);
                continue;
            }
            manifest.rules.push_back(TransformRule{
                fields[2], *layer, fields[10], LowerAscii(fields[11]), fields[12], fields[13],
                *semantic, fields[15], *operation, fields[17], *minimum, *maximum, fields[20],
            });
        } else {
            AddManifestDiagnostic(manifest);
        }
    }
    if (input.bad() || manifest.profiles.empty()) {
        AddManifestDiagnostic(manifest);
    }
    return manifest;
}

BundleCompileResult CompileImprovedBundles(
    const fs::path& overlay_root,
    const fs::path& preset_root,
    const fs::path& output_root,
    const ImprovementManifest& manifest,
    const bindings::DispositionCatalog& catalog) {
    BundleCompileResult result;
    if (!manifest.diagnostics.empty() || manifest.profiles.empty()) {
        AddDiagnostic(result, BundleDiagnosticCode::InvalidManifest);
        return result;
    }
    if (!OutputIsSafe(overlay_root, preset_root, output_root)) {
        AddDiagnostic(result, BundleDiagnosticCode::UnsafeOutputPath);
        return result;
    }

    std::map<std::string, bindings::BindingDisposition> bindings_by_profile;
    for (const auto& binding : catalog.bindings) {
        bindings_by_profile.emplace(binding.canonical_identity, binding);
    }
    std::set<std::string> profiles_seen;
    std::set<std::string> bundles_seen;
    std::set<std::tuple<std::string, RuleLayer, std::string, std::string, std::string>> rules_seen;
    for (const auto& profile : manifest.profiles) {
        if (!profiles_seen.insert(profile.profile_id).second) {
            AddDiagnostic(result, BundleDiagnosticCode::DuplicateProfile, profile.profile_id);
        }
        if (!bundles_seen.insert(profile.bundle_id).second || !IsSafeBundleId(profile.bundle_id)) {
            AddDiagnostic(result, BundleDiagnosticCode::DuplicateBundle, profile.profile_id);
        }
        if (!IsSafeRelativePath(profile.overlay_file)
            || !IsSafeRelativePath(profile.preset_directory)
            || !IsSha256(profile.overlay_sha256) || !IsSha256(profile.preset_tree_sha256)
            || profile.art_direction.empty()) {
            AddDiagnostic(result, BundleDiagnosticCode::InvalidManifest, profile.profile_id);
        }
        const auto binding = bindings_by_profile.find(profile.profile_id);
        if (binding == bindings_by_profile.end()) {
            AddDiagnostic(result, BundleDiagnosticCode::MissingProfileBinding, profile.profile_id);
        } else if (binding->second.selected_overlay_file != profile.overlay_file
                   || binding->second.preset_directory != profile.preset_directory
                   || LowerAscii(binding->second.selected_overlay_sha256)
                       != LowerAscii(profile.overlay_sha256)) {
            AddDiagnostic(result, BundleDiagnosticCode::PairingMismatch, profile.profile_id);
        }
    }
    for (const auto& rule : manifest.rules) {
        const auto key = std::tuple{
            rule.profile_id, rule.layer, rule.relative_path, rule.section, rule.key};
        if (!rules_seen.insert(key).second) {
            AddDiagnostic(
                result,
                BundleDiagnosticCode::DuplicateRule,
                rule.profile_id,
                rule.relative_path,
                rule.section,
                rule.key);
        }
        if (!profiles_seen.contains(rule.profile_id) || !IsSafeRelativePath(rule.relative_path)
            || !IsSha256(rule.file_sha256) || rule.key.empty() || rule.rationale.empty()
            || !std::isfinite(rule.min_value) || !std::isfinite(rule.max_value)
            || rule.min_value > rule.max_value) {
            AddDiagnostic(
                result,
                BundleDiagnosticCode::InvalidManifest,
                rule.profile_id,
                rule.relative_path,
                rule.section,
                rule.key);
        }
    }
    if (!result.success()) {
        return result;
    }

    const auto stage = output_root.parent_path()
        / ("." + PathToUtf8(output_root.filename()) + ".staging");
    std::error_code cleanup_error;
    fs::remove_all(stage, cleanup_error);
    cleanup_error.clear();
    fs::create_directories(stage / "profiles", cleanup_error);
    if (cleanup_error) {
        AddDiagnostic(result, BundleDiagnosticCode::IoError);
        return result;
    }

    try {
        for (const auto& profile : manifest.profiles) {
            const auto& binding = bindings_by_profile.at(profile.profile_id);
            const auto source_overlay = overlay_root / Utf8ToPath(profile.overlay_file);
            const auto source_preset = preset_root / Utf8ToPath(profile.preset_directory);
            if (!fs::is_regular_file(source_overlay) || !fs::is_directory(source_preset)) {
                AddDiagnostic(result, BundleDiagnosticCode::MissingSource, profile.profile_id);
                break;
            }
            if (LowerAscii(bindings::Sha256File(source_overlay))
                != LowerAscii(profile.overlay_sha256)) {
                AddDiagnostic(
                    result,
                    BundleDiagnosticCode::SourceHashMismatch,
                    profile.profile_id,
                    profile.overlay_file);
                break;
            }
            bindings::DispositionCatalog one_catalog;
            one_catalog.bindings.push_back(binding);
            const auto source_audit = audit::AuditLegacyPresets(preset_root, one_catalog);
            if (!source_audit.completed() || source_audit.presets.size() != 1
                || LowerAscii(source_audit.presets.front().tree_sha256)
                    != LowerAscii(profile.preset_tree_sha256)) {
                AddDiagnostic(result, BundleDiagnosticCode::SourceTreeHashMismatch, profile.profile_id);
                break;
            }

            const auto bundle_root = stage / "profiles" / profile.bundle_id;
            const auto output_overlay = bundle_root / "overlay" / Utf8ToPath(profile.overlay_file);
            const auto output_preset_root = bundle_root / "preset";
            const auto output_preset = output_preset_root / Utf8ToPath(profile.preset_directory);
            WriteFile(output_overlay, ReadFile(source_overlay));
            ++result.counts.copied_files;
            if (!CopyTree(source_preset, output_preset, result.counts.copied_files)) {
                AddDiagnostic(result, BundleDiagnosticCode::IoError, profile.profile_id);
                break;
            }

            CompiledBundle bundle;
            bundle.bundle_id = profile.bundle_id;
            bundle.profile_id = profile.profile_id;
            bundle.overlay_file = profile.overlay_file;
            bundle.preset_directory = profile.preset_directory;
            bundle.record_files = source_audit.counts.record_files;

            const auto image_spaces = output_preset / "ImageSpaces";
            std::size_t repairs = 0;
            if (fs::is_directory(image_spaces)) {
                std::vector<fs::path> image_files;
                for (const auto& entry : fs::directory_iterator{image_spaces}) {
                    if (entry.is_regular_file()
                        && LowerAscii(PathToUtf8(entry.path().extension())) == ".ini") {
                        image_files.push_back(entry.path());
                    }
                }
                std::ranges::sort(image_files, [](const fs::path& left, const fs::path& right) {
                    return PathToUtf8(left.filename()) < PathToUtf8(right.filename());
                });
                for (const auto& path : image_files) {
                    const auto source_bytes = ReadFile(path);
                    const auto repaired = RepairFusedDepthOfField(source_bytes);
                    if (repaired.status == RepairStatus::Ambiguous) {
                        AddDiagnostic(
                            result,
                            BundleDiagnosticCode::AmbiguousFusedDepthOfField,
                            profile.profile_id,
                            "ImageSpaces/" + PathToUtf8(path.filename()),
                            {},
                            "Tint");
                        break;
                    }
                    if (repaired.status == RepairStatus::Repaired) {
                        WriteFile(path, repaired.bytes);
                        ++repairs;
                        result.provenance.push_back(ProvenanceEntry{
                            profile.profile_id,
                            "KREATE_REPAIR",
                            "ImageSpaces/" + PathToUtf8(path.filename()),
                            bindings::Sha256(source_bytes),
                            "",
                            "Tint",
                            "VECTOR4",
                            repaired.vector,
                            "REPAIR_FUSED_SECTION",
                            "[DepthOfField]",
                            repaired.vector,
                            "restore_depth_of_field_section_boundary",
                            {},
                            {},
                            "Tint",
                            "VECTOR4",
                            "VERIFIED_REPAIR",
                        });
                    }
                }
            }
            if (!result.success()) {
                break;
            }
            if (repairs != profile.expected_repairs) {
                AddDiagnostic(result, BundleDiagnosticCode::RepairCountMismatch, profile.profile_id);
                break;
            }
            bundle.repairs = repairs;

            const auto rules = RulesFor(manifest, profile.profile_id);
            for (const auto& rule : rules) {
                const auto source_path = rule.layer == RuleLayer::Overlay
                    ? overlay_root / Utf8ToPath(rule.relative_path)
                    : source_preset / Utf8ToPath(rule.relative_path);
                const auto output_path = rule.layer == RuleLayer::Overlay
                    ? bundle_root / "overlay" / Utf8ToPath(rule.relative_path)
                    : output_preset / Utf8ToPath(rule.relative_path);
                if (!fs::is_regular_file(source_path) || !fs::is_regular_file(output_path)) {
                    AddDiagnostic(
                        result,
                        BundleDiagnosticCode::MissingSource,
                        profile.profile_id,
                        rule.relative_path,
                        rule.section,
                        rule.key);
                    break;
                }
                const auto source_hash = LowerAscii(bindings::Sha256File(source_path));
                if (source_hash != LowerAscii(rule.file_sha256)) {
                    AddDiagnostic(
                        result,
                        BundleDiagnosticCode::SourceHashMismatch,
                        profile.profile_id,
                        rule.relative_path,
                        rule.section,
                        rule.key);
                    break;
                }
                const auto output_bytes = ReadFile(output_path);
                ResolvedOverlayBinding overlay_binding;
                if (rule.layer == RuleLayer::Overlay) {
                    overlay_binding = ResolveOverlayBinding(output_bytes, rule);
                    if (overlay_binding.status != OverlayBindingStatus::Resolved) {
                        BundleDiagnosticCode code =
                            BundleDiagnosticCode::UnsupportedOverlayBinding;
                        if (overlay_binding.status == OverlayBindingStatus::Missing) {
                            code = BundleDiagnosticCode::MissingOverlayBindingField;
                        } else if (overlay_binding.status == OverlayBindingStatus::Ambiguous) {
                            code = BundleDiagnosticCode::AmbiguousOverlayBindingField;
                        }
                        AddDiagnostic(
                            result,
                            code,
                            profile.profile_id,
                            rule.relative_path,
                            rule.section,
                            rule.key);
                        break;
                    }
                }
                const auto applied = ApplyRuleToIni(output_bytes, rule);
                if (!applied.transform_valid) {
                    AddDiagnostic(
                        result,
                        BundleDiagnosticCode::InvalidTransform,
                        profile.profile_id,
                        rule.relative_path,
                        rule.section,
                        rule.key);
                    break;
                }
                if (!applied.bounds_valid) {
                    AddDiagnostic(
                        result,
                        BundleDiagnosticCode::ValueOutOfBounds,
                        profile.profile_id,
                        rule.relative_path,
                        rule.section,
                        rule.key);
                    break;
                }
                if (applied.duplicate) {
                    AddDiagnostic(
                        result,
                        BundleDiagnosticCode::DuplicateGuardedKey,
                        profile.profile_id,
                        rule.relative_path,
                        rule.section,
                        rule.key);
                    break;
                }
                if (!applied.found) {
                    AddDiagnostic(
                        result,
                        BundleDiagnosticCode::MissingGuardedKey,
                        profile.profile_id,
                        rule.relative_path,
                        rule.section,
                        rule.key);
                    break;
                }
                if (!applied.guard_match) {
                    AddDiagnostic(
                        result,
                        BundleDiagnosticCode::GuardValueMismatch,
                        profile.profile_id,
                        rule.relative_path,
                        rule.section,
                        rule.key);
                    break;
                }
                WriteFile(output_path, applied.bytes);
                if (rule.layer == RuleLayer::Overlay) {
                    ++bundle.overlay_changes;
                } else {
                    ++bundle.kreate_changes;
                }
                result.provenance.push_back(ProvenanceEntry{
                    profile.profile_id,
                    std::string{ToString(rule.layer)},
                    rule.relative_path,
                    rule.file_sha256,
                    rule.section,
                    rule.key,
                    std::string{ToString(rule.semantic_type)},
                    rule.guard_value,
                    std::string{ToString(rule.operation)},
                    rule.operand,
                    applied.output_value,
                    rule.rationale,
                    rule.layer == RuleLayer::Overlay
                        ? overlay_binding.target_filename
                        : rule.relative_path,
                    rule.layer == RuleLayer::Overlay
                        ? overlay_binding.target_category
                        : rule.section,
                    rule.layer == RuleLayer::Overlay
                        ? overlay_binding.target_key
                        : rule.key,
                    rule.layer == RuleLayer::Overlay
                        ? overlay_binding.target_type
                        : std::string{ToString(rule.semantic_type)},
                    "INTENDED_OUTCOME",
                });
            }
            if (!result.success()) {
                break;
            }

            const auto source_overlay_schema = IniSchema(ReadFile(source_overlay));
            const auto output_overlay_bytes = ReadFile(output_overlay);
            if (source_overlay_schema != IniSchema(output_overlay_bytes)) {
                AddDiagnostic(result, BundleDiagnosticCode::UnsupportedOverlayKey, profile.profile_id);
                break;
            }
            const auto generated_audit = audit::AuditLegacyPresets(output_preset_root, one_catalog);
            if (!generated_audit.completed()
                || audit::HasDiagnostic(
                    generated_audit,
                    audit::AuditDiagnosticCode::InvalidNumericToken)
                || audit::HasDiagnostic(
                    generated_audit,
                    audit::AuditDiagnosticCode::NonFiniteNumeric)
                || audit::HasDiagnostic(
                    generated_audit,
                    audit::AuditDiagnosticCode::MalformedIniLine)
                || audit::HasDiagnostic(
                    generated_audit,
                    audit::AuditDiagnosticCode::MalformedSection)) {
                AddDiagnostic(result, BundleDiagnosticCode::GeneratedAuditFailed, profile.profile_id);
                break;
            }
            if (generated_audit.counts.record_files != source_audit.counts.record_files) {
                AddDiagnostic(result, BundleDiagnosticCode::IdentityCountChanged, profile.profile_id);
                break;
            }
            bundle.export_name_debt = audit::CountDiagnostics(
                generated_audit,
                audit::AuditDiagnosticCode::SuspiciousDuplicateFilename);
            bundle.overlay_sha256 = bindings::Sha256(output_overlay_bytes);
            bundle.preset_tree_sha256 = generated_audit.presets.front().tree_sha256;
            bundle.bundle_sha256 = BundlePayloadHash(bundle);
            WriteBundleMetadata(bundle_root, bundle);
            bundle.bundle_bytes = DirectoryBytes(bundle_root);

            if (LowerAscii(bindings::Sha256File(source_overlay))
                    != LowerAscii(profile.overlay_sha256)
                || audit::AuditLegacyPresets(preset_root, one_catalog).presets.front().tree_sha256
                    != profile.preset_tree_sha256) {
                AddDiagnostic(result, BundleDiagnosticCode::SourceChanged, profile.profile_id);
                break;
            }
            result.counts.repairs += bundle.repairs;
            result.counts.overlay_changes += bundle.overlay_changes;
            result.counts.kreate_changes += bundle.kreate_changes;
            result.counts.export_name_debt += bundle.export_name_debt;
            result.counts.record_files += bundle.record_files;
            result.bundles.push_back(std::move(bundle));
        }
    } catch (const std::exception&) {
        AddDiagnostic(result, BundleDiagnosticCode::IoError);
    }

    if (!result.success()) {
        std::error_code ignored;
        fs::remove_all(stage, ignored);
        return result;
    }
    result.counts.profiles = result.bundles.size();
    std::ranges::sort(result.bundles, [](const CompiledBundle& left, const CompiledBundle& right) {
        return left.bundle_id < right.bundle_id;
    });
    std::ranges::sort(result.provenance, [](const ProvenanceEntry& left, const ProvenanceEntry& right) {
        return std::tie(left.profile_id, left.layer, left.relative_path, left.section, left.key)
            < std::tie(right.profile_id, right.layer, right.relative_path, right.section, right.key);
    });
    try {
        WriteGlobalArtifacts(stage, result);
        std::error_code publish_error;
        fs::remove_all(output_root, publish_error);
        if (publish_error) {
            AddDiagnostic(result, BundleDiagnosticCode::IoError);
        } else {
            fs::rename(stage, output_root, publish_error);
            if (publish_error) {
                AddDiagnostic(result, BundleDiagnosticCode::IoError);
            }
        }
    } catch (const std::exception&) {
        AddDiagnostic(result, BundleDiagnosticCode::IoError);
    }
    if (!result.success()) {
        std::error_code ignored;
        fs::remove_all(stage, ignored);
    }
    return result;
}

bool HasDiagnostic(
    const BundleCompileResult& result,
    const BundleDiagnosticCode code) noexcept {
    return std::ranges::any_of(result.diagnostics, [code](const BundleDiagnostic& diagnostic) {
        return diagnostic.code == code;
    });
}

std::string DirectoryTreeHash(const fs::path& root) {
    std::vector<fs::path> paths;
    std::error_code error;
    for (fs::recursive_directory_iterator iterator{root, error}, end;
         !error && iterator != end;
         iterator.increment(error)) {
        std::error_code type_error;
        if (iterator->is_symlink(type_error) || type_error) {
            return {};
        }
        if (iterator->is_regular_file(type_error) && !type_error) {
            paths.push_back(iterator->path());
        }
    }
    if (error) {
        return {};
    }
    std::ranges::sort(paths, [&root](const fs::path& left, const fs::path& right) {
        return PathToUtf8(left.lexically_relative(root))
            < PathToUtf8(right.lexically_relative(root));
    });
    std::string material{"ELDER_DIRECTORY_TREE_V1\n"};
    for (const auto& path : paths) {
        const auto relative = PathToUtf8(path.lexically_relative(root));
        const auto hash = bindings::Sha256File(path);
        const auto leaf = bindings::Sha256(
            std::string{"ELDER_DIRECTORY_BLOB_V1\n"} + relative + "\n" + hash + "\n");
        material += relative;
        material += '\0';
        material += leaf;
        material += '\n';
    }
    return bindings::Sha256(material);
}

std::string_view ToString(const BundleDiagnosticCode code) noexcept {
    switch (code) {
        case BundleDiagnosticCode::InvalidManifest: return "INVALID_MANIFEST";
        case BundleDiagnosticCode::UnsafeOutputPath: return "UNSAFE_OUTPUT_PATH";
        case BundleDiagnosticCode::MissingProfileBinding: return "MISSING_PROFILE_BINDING";
        case BundleDiagnosticCode::DuplicateProfile: return "DUPLICATE_PROFILE";
        case BundleDiagnosticCode::DuplicateBundle: return "DUPLICATE_BUNDLE";
        case BundleDiagnosticCode::DuplicateRule: return "DUPLICATE_RULE";
        case BundleDiagnosticCode::MissingSource: return "MISSING_SOURCE";
        case BundleDiagnosticCode::SourceHashMismatch: return "SOURCE_HASH_MISMATCH";
        case BundleDiagnosticCode::SourceTreeHashMismatch: return "SOURCE_TREE_HASH_MISMATCH";
        case BundleDiagnosticCode::AmbiguousFusedDepthOfField:
            return "AMBIGUOUS_FUSED_DEPTH_OF_FIELD";
        case BundleDiagnosticCode::RepairCountMismatch: return "REPAIR_COUNT_MISMATCH";
        case BundleDiagnosticCode::MissingGuardedKey: return "MISSING_GUARDED_KEY";
        case BundleDiagnosticCode::DuplicateGuardedKey: return "DUPLICATE_GUARDED_KEY";
        case BundleDiagnosticCode::GuardValueMismatch: return "GUARD_VALUE_MISMATCH";
        case BundleDiagnosticCode::InvalidTransform: return "INVALID_TRANSFORM";
        case BundleDiagnosticCode::ValueOutOfBounds: return "VALUE_OUT_OF_BOUNDS";
        case BundleDiagnosticCode::UnsupportedOverlayKey: return "UNSUPPORTED_OVERLAY_KEY";
        case BundleDiagnosticCode::MissingOverlayBindingField:
            return "MISSING_OVERLAY_BINDING_FIELD";
        case BundleDiagnosticCode::AmbiguousOverlayBindingField:
            return "AMBIGUOUS_OVERLAY_BINDING_FIELD";
        case BundleDiagnosticCode::UnsupportedOverlayBinding:
            return "UNSUPPORTED_OVERLAY_BINDING";
        case BundleDiagnosticCode::GeneratedAuditFailed: return "GENERATED_AUDIT_FAILED";
        case BundleDiagnosticCode::IdentityCountChanged: return "IDENTITY_COUNT_CHANGED";
        case BundleDiagnosticCode::PairingMismatch: return "PAIRING_MISMATCH";
        case BundleDiagnosticCode::SourceChanged: return "SOURCE_CHANGED";
        case BundleDiagnosticCode::IoError: return "IO_ERROR";
    }
    return "UNKNOWN_BUNDLE_DIAGNOSTIC";
}

std::string_view ToString(const RuleLayer layer) noexcept {
    switch (layer) {
        case RuleLayer::Overlay: return "OVERLAY";
        case RuleLayer::Kreate: return "KREATE";
    }
    return "UNKNOWN_LAYER";
}

std::string_view ToString(const SemanticType type) noexcept {
    switch (type) {
        case SemanticType::Scalar: return "SCALAR";
        case SemanticType::Vector3: return "VECTOR3";
        case SemanticType::Vector4: return "VECTOR4";
        case SemanticType::OverlayOperation: return "OVERLAY_OPERATION";
    }
    return "UNKNOWN_SEMANTIC";
}

std::string_view ToString(const RuleOperation operation) noexcept {
    switch (operation) {
        case RuleOperation::Set: return "SET";
        case RuleOperation::Scale: return "SCALE";
        case RuleOperation::ScaleRgb: return "SCALE_RGB";
    }
    return "UNKNOWN_OPERATION";
}

}  // namespace elder::improvement
