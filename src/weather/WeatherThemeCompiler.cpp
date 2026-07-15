#include "elder/weather/WeatherThemeCompiler.hpp"

#include "elder/audit/LegacyPresetAudit.hpp"
#include "elder/improvement/ProfileBundleCompiler.hpp"
#include "elder/weather/detail/OwnedOutputTransaction.hpp"

#include <algorithm>
#include <charconv>
#include <cmath>
#include <fstream>
#include <iterator>
#include <limits>
#include <optional>
#include <ranges>
#include <set>
#include <sstream>
#include <stdexcept>
#include <system_error>
#include <tuple>
#include <utility>

namespace elder::weather {
namespace {

namespace fs = std::filesystem;

constexpr std::array<std::string_view, 4> kTimeNames{
    "Sunrise", "Day", "Sunset", "Night"};
constexpr std::array<std::string_view, 9> kColorBases{
    "SkyUpper",
    "SkyLower",
    "Horizon",
    "FogNear",
    "FogFar",
    "Sunlight",
    "Ambient",
    "CloudLodDiffuse",
    "CloudLodAmbient",
};
constexpr std::array<std::string_view, 3> kAmbientBases{"Top", "Middle", "Bottom"};
constexpr std::array<double, 4> kCloudSeparation{0.020, 0.035, 0.020, 0.008};

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
    std::ranges::transform(value, value.begin(), [](const unsigned char character) {
        if (character >= 'A' && character <= 'Z') {
            return static_cast<char>(character - 'A' + 'a');
        }
        return static_cast<char>(character);
    });
    return value;
}

[[nodiscard]] std::optional<std::vector<std::string>> ParseRequiredProfiles(
    const std::string_view value) {
    std::vector<std::string> profiles;
    std::set<std::string> seen;
    std::size_t begin = 0;
    while (begin <= value.size()) {
        const auto end = value.find(';', begin);
        const auto profile = Trim(value.substr(
            begin,
            end == std::string_view::npos ? value.size() - begin : end - begin));
        if (profile.empty() || !seen.insert(profile).second) {
            return std::nullopt;
        }
        profiles.push_back(profile);
        if (end == std::string_view::npos) {
            break;
        }
        begin = end + 1;
    }
    return profiles.empty() ? std::nullopt
                            : std::optional<std::vector<std::string>>{
                                  std::move(profiles)};
}

[[nodiscard]] bool ContainsAny(
    const std::string_view value,
    const std::initializer_list<std::string_view> needles) {
    return std::ranges::any_of(needles, [value](const std::string_view needle) {
        return value.contains(needle);
    });
}

[[nodiscard]] std::string ReadFile(const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("cannot read weather theme input");
    }
    return {
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{},
    };
}

void WriteFile(const fs::path& path, const std::string_view bytes) {
    std::error_code error;
    fs::create_directories(path.parent_path(), error);
    if (error) {
        throw std::runtime_error("cannot create weather theme output directory");
    }
    std::ofstream output{path, std::ios::binary | std::ios::trunc};
    if (!output) {
        throw std::runtime_error("cannot write weather theme output");
    }
    output.write(bytes.data(), static_cast<std::streamsize>(bytes.size()));
    if (!output) {
        throw std::runtime_error("cannot finish weather theme output");
    }
}

[[nodiscard]] std::string PathToUtf8(const fs::path& path) {
    const auto value = path.generic_u8string();
    return {reinterpret_cast<const char*>(value.data()), value.size()};
}

[[nodiscard]] fs::path Utf8ToPath(const std::string_view value) {
    const auto* begin = reinterpret_cast<const char8_t*>(value.data());
    return fs::path{std::u8string{begin, begin + value.size()}};
}

[[nodiscard]] bool IsSha256(const std::string_view value) {
    return value.size() == 64
        && std::ranges::all_of(value, [](const unsigned char character) {
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
    return std::ranges::none_of(path, [](const fs::path& component) {
        return component == "." || component == "..";
    });
}

[[nodiscard]] std::optional<double> ParseDouble(const std::string_view value) {
    const auto text = Trim(value);
    if (text.empty()) {
        return std::nullopt;
    }
    double parsed = 0.0;
    const auto conversion = std::from_chars(
        text.data(), text.data() + text.size(), parsed, std::chars_format::general);
    if (conversion.ec != std::errc{} || conversion.ptr != text.data() + text.size()
        || !std::isfinite(parsed)) {
        return std::nullopt;
    }
    return parsed;
}

[[nodiscard]] std::optional<std::size_t> ParseCount(const std::string_view value) {
    const auto text = Trim(value);
    std::size_t parsed = 0;
    const auto conversion = std::from_chars(text.data(), text.data() + text.size(), parsed);
    if (conversion.ec != std::errc{} || conversion.ptr != text.data() + text.size()) {
        return std::nullopt;
    }
    return parsed;
}

[[nodiscard]] bool IsBindingType(const std::string_view binding_type) {
    return binding_type == "ADD_SCALAR" || binding_type == "MULTIPLY_SCALAR"
        || binding_type == "SET_SCALAR" || binding_type == "SET_VECTOR3"
        || binding_type == "SET_VECTOR4";
}

[[nodiscard]] bool IsOpaqueId(const std::string_view value) {
    return !value.empty()
        && std::ranges::all_of(value, [](const unsigned char character) {
               return (character >= 'a' && character <= 'z')
                   || (character >= '0' && character <= '9') || character == '-';
           });
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
        } else if (character == '"' && field.empty()) {
            quoted = true;
        } else if (character == ',') {
            fields.push_back(Trim(field));
            field.clear();
        } else {
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

void AddDiagnostic(
    WeatherCompileResult& result,
    const WeatherDiagnosticCode code,
    const std::string& profile = {},
    const std::string& path = {},
    const std::string& key = {}) {
    result.diagnostics.push_back({code, profile, path, key});
}

void AddDiagnostic(
    SemanticVerificationResult& result,
    const WeatherDiagnosticCode code,
    const std::string& path = {},
    const std::string& key = {}) {
    result.diagnostics.push_back({code, {}, path, key});
}

[[nodiscard]] bool CopyTree(const fs::path& source, const fs::path& target) {
    std::error_code error;
    fs::create_directories(target, error);
    if (error) {
        return false;
    }
    for (fs::recursive_directory_iterator iterator{source, error}, end;
         !error && iterator != end;
         iterator.increment(error)) {
        std::error_code type_error;
        if (iterator->is_symlink(type_error) || type_error) {
            return false;
        }
        const auto relative = iterator->path().lexically_relative(source);
        const auto destination = target / relative;
        if (iterator->is_directory(type_error) && !type_error) {
            fs::create_directories(destination, error);
        } else if (iterator->is_regular_file(type_error) && !type_error) {
            WriteFile(destination, ReadFile(iterator->path()));
        }
        if (error || type_error) {
            return false;
        }
    }
    return !error;
}

class OwnedTreeCleanup final {
public:
    OwnedTreeCleanup(
        fs::path root,
        const detail::OwnedTreeRole role,
        std::string transaction_id)
        : root_(std::move(root)), role_(role), transaction_id_(std::move(transaction_id)) {}

    OwnedTreeCleanup(const OwnedTreeCleanup&) = delete;
    OwnedTreeCleanup& operator=(const OwnedTreeCleanup&) = delete;

    ~OwnedTreeCleanup() {
        static_cast<void>(Cleanup());
    }

    [[nodiscard]] bool Cleanup() noexcept {
        if (!active_) {
            return true;
        }
        try {
            std::error_code error;
            const bool exists = fs::exists(root_, error);
            if (error) {
                return false;
            }
            if (!exists) {
                active_ = false;
                return true;
            }
            if (!detail::RemoveOwnedTree(root_, role_, transaction_id_)) {
                return false;
            }
            active_ = false;
            return true;
        } catch (...) {
            return false;
        }
    }

private:
    fs::path root_;
    detail::OwnedTreeRole role_;
    std::string transaction_id_;
    bool active_{true};
};

[[nodiscard]] std::uintmax_t DirectoryBytes(const fs::path& root) {
    std::uintmax_t bytes = 0;
    std::error_code error;
    for (fs::recursive_directory_iterator iterator{root, error}, end;
         !error && iterator != end;
         iterator.increment(error)) {
        std::error_code type_error;
        if (iterator->is_regular_file(type_error) && !type_error) {
            bytes += iterator->file_size(type_error);
        }
        if (type_error) {
            return 0;
        }
    }
    return error ? 0 : bytes;
}

struct InputBundleMetadata {
    std::string bundle_id;
    std::string profile_id;
    std::string overlay_path;
    std::string overlay_sha256;
    std::string preset_path;
    std::string preset_tree_sha256;
    std::string bundle_sha256;
};

[[nodiscard]] std::optional<InputBundleMetadata> ReadBundleMetadata(
    const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        return std::nullopt;
    }
    std::string header;
    std::string row;
    if (!std::getline(input, header) || !std::getline(input, row)) {
        return std::nullopt;
    }
    bool header_valid = false;
    bool row_valid = false;
    const auto columns = ParseCsvRow(header, header_valid);
    const auto values = ParseCsvRow(row, row_valid);
    constexpr std::array<std::string_view, 7> expected_header{
        "bundle_id",
        "profile_id",
        "overlay_path",
        "overlay_sha256",
        "preset_path",
        "preset_tree_sha256",
        "bundle_sha256",
    };
    std::string trailing;
    if (!header_valid || !row_valid || columns.size() != expected_header.size()
        || values.size() != expected_header.size()
        || !std::ranges::equal(columns, expected_header)
        || std::getline(input, trailing)) {
        return std::nullopt;
    }
    if (std::ranges::any_of(values, [](const std::string& value) {
            return value.empty();
        })
        || !IsSha256(values[3]) || !IsSha256(values[5]) || !IsSha256(values[6])) {
        return std::nullopt;
    }
    return InputBundleMetadata{
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
        values[5],
        values[6],
    };
}

[[nodiscard]] std::string PairedBundleHash(
    const WeatherProfileTheme& profile,
    const std::string_view overlay_sha256,
    const std::string_view preset_tree_sha256) {
    return bindings::Sha256(
        std::string{"ELDER_PAIRED_BUNDLE_V1\n"} + profile.bundle_id + "\n"
        + profile.profile_id + "\n" + profile.overlay_file + "\n"
        + std::string{overlay_sha256} + "\n" + profile.preset_directory + "\n"
        + std::string{preset_tree_sha256} + "\n");
}

struct Rgb {
    double red{0.0};
    double green{0.0};
    double blue{0.0};
};

struct ParsedColor {
    Rgb rgb;
    std::optional<std::string> alpha_token;
};

[[nodiscard]] double Luminance(const Rgb& color) {
    return color.red * 0.2126 + color.green * 0.7152 + color.blue * 0.0722;
}

[[nodiscard]] Rgb SetLuminance(
    const Rgb& color,
    const double target,
    const double maximum) {
    const auto source = Luminance(color);
    const std::array<double, 3> delta{
        color.red - source,
        color.green - source,
        color.blue - source,
    };
    double scale = 1.0;
    for (const auto value : delta) {
        if (value > 0.0) {
            scale = std::min(scale, (maximum - target) / value);
        } else if (value < 0.0) {
            scale = std::min(scale, target / -value);
        }
    }
    scale = std::clamp(scale, 0.0, 1.0);
    return {
        target + delta[0] * scale,
        target + delta[1] * scale,
        target + delta[2] * scale,
    };
}

[[nodiscard]] std::optional<ParsedColor> ParseColor(const std::string_view value) {
    std::vector<std::string> tokens;
    std::size_t start = 0;
    while (start <= value.size()) {
        const auto delimiter = value.find(',', start);
        tokens.push_back(Trim(value.substr(
            start,
            delimiter == std::string_view::npos ? value.size() - start : delimiter - start)));
        if (delimiter == std::string_view::npos) {
            break;
        }
        start = delimiter + 1;
    }
    if (tokens.size() != 3 && tokens.size() != 4) {
        return std::nullopt;
    }
    const auto red = ParseDouble(tokens[0]);
    const auto green = ParseDouble(tokens[1]);
    const auto blue = ParseDouble(tokens[2]);
    if (!red.has_value() || !green.has_value() || !blue.has_value()) {
        return std::nullopt;
    }
    ParsedColor color{{*red, *green, *blue}, std::nullopt};
    if (tokens.size() == 4) {
        if (!ParseDouble(tokens[3]).has_value()) {
            return std::nullopt;
        }
        color.alpha_token = tokens[3];
    }
    return color;
}

[[nodiscard]] std::string FormatColor(const ParsedColor& color) {
    std::string output = FormatDouble(color.rgb.red) + ", "
        + FormatDouble(color.rgb.green) + ", " + FormatDouble(color.rgb.blue);
    if (color.alpha_token.has_value()) {
        output += ", " + *color.alpha_token;
    }
    return output;
}

[[nodiscard]] ThemeAxis ResolveTarget(
    const WeatherProfileTheme& profile,
    const WeatherFamily family,
    const WeatherTime time) {
    const auto& family_axis = profile.families.at(family);
    const auto& time_axis = profile.times.at(time);
    ThemeAxis target;
    target.exposure_ev = profile.base.exposure_ev + family_axis.exposure_ev
        + time_axis.exposure_ev;
    target.chroma = profile.base.chroma * family_axis.chroma * time_axis.chroma;
    for (std::size_t index = 0; index < target.tint.size(); ++index) {
        target.tint[index] = profile.base.tint[index] * family_axis.tint[index]
            * time_axis.tint[index];
    }
    target.blend = std::clamp(
        profile.base.blend * family_axis.blend * time_axis.blend,
        0.0,
        1.0);
    target.min_luminance = std::max({
        profile.base.min_luminance,
        family_axis.min_luminance,
        time_axis.min_luminance,
    });
    target.max_luminance = std::min({
        profile.base.max_luminance,
        family_axis.max_luminance,
        time_axis.max_luminance,
    });
    return target;
}

[[nodiscard]] Rgb ApplyTheme(const Rgb& source, const ThemeAxis& target) {
    const auto luminance = Luminance(source);
    Rgb themed{
        luminance + (source.red - luminance) * target.chroma,
        luminance + (source.green - luminance) * target.chroma,
        luminance + (source.blue - luminance) * target.chroma,
    };
    const auto exposure = std::exp2(target.exposure_ev);
    themed.red *= target.tint[0] * exposure;
    themed.green *= target.tint[1] * exposure;
    themed.blue *= target.tint[2] * exposure;
    Rgb result{
        std::lerp(source.red, themed.red, target.blend),
        std::lerp(source.green, themed.green, target.blend),
        std::lerp(source.blue, themed.blue, target.blend),
    };
    result.red = std::clamp(result.red, 0.0, target.max_luminance);
    result.green = std::clamp(result.green, 0.0, target.max_luminance);
    result.blue = std::clamp(result.blue, 0.0, target.max_luminance);
    return result;
}

struct IniLine {
    std::string bytes;
    std::string section;
    std::string key;
    std::string value;
    std::size_t value_offset{0};
};

struct IniDocument {
    std::vector<IniLine> lines;
    bool crlf{false};
    bool trailing_newline{false};
};

[[nodiscard]] IniDocument ParseIni(const std::string_view bytes) {
    IniDocument document;
    document.crlf = bytes.contains("\r\n");
    document.trailing_newline = bytes.ends_with('\n');
    std::string section;
    std::size_t start = 0;
    while (start < bytes.size()) {
        const auto newline = bytes.find('\n', start);
        const auto end = newline == std::string_view::npos ? bytes.size() : newline;
        auto line = std::string{bytes.substr(start, end - start)};
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        IniLine parsed;
        parsed.bytes = line;
        const auto trimmed = Trim(line);
        if (trimmed.size() >= 2 && trimmed.front() == '[' && trimmed.back() == ']') {
            section = Trim(std::string_view{trimmed}.substr(1, trimmed.size() - 2));
        } else if (!trimmed.empty() && trimmed.front() != ';' && trimmed.front() != '#') {
            const auto equals = line.find('=');
            if (equals != std::string::npos) {
                parsed.section = section;
                parsed.key = Trim(std::string_view{line}.substr(0, equals));
                const auto offset = line.find_first_not_of(" \t", equals + 1);
                parsed.value_offset = offset == std::string::npos ? line.size() : offset;
                parsed.value = offset == std::string::npos
                    ? std::string{}
                    : Trim(std::string_view{line}.substr(offset));
            }
        }
        document.lines.push_back(std::move(parsed));
        if (newline == std::string_view::npos) {
            break;
        }
        start = newline + 1;
    }
    return document;
}

[[nodiscard]] std::string SerializeIni(const IniDocument& document) {
    std::string output;
    const std::string_view newline = document.crlf ? "\r\n" : "\n";
    for (std::size_t index = 0; index < document.lines.size(); ++index) {
        output += document.lines[index].bytes;
        if (index + 1 < document.lines.size() || document.trailing_newline) {
            output += newline;
        }
    }
    return output;
}

[[nodiscard]] std::vector<std::pair<std::string, std::string>> TargetGroups(
    const std::size_t cloud_layers) {
    std::vector<std::pair<std::string, std::string>> groups;
    for (const auto base : kColorBases) {
        groups.emplace_back("Colors", base);
    }
    for (const auto base : kAmbientBases) {
        groups.emplace_back("DirAmbient", base);
    }
    for (std::size_t layer = 0; layer < cloud_layers; ++layer) {
        groups.emplace_back("Clouds", "Layer" + std::to_string(layer) + "Color");
    }
    return groups;
}

using WeatherFieldIdentity = std::pair<std::string, std::string>;

[[nodiscard]] std::set<WeatherFieldIdentity> TargetFields(
    const std::size_t cloud_layers) {
    std::set<WeatherFieldIdentity> fields;
    for (const auto& [section, base] : TargetGroups(cloud_layers)) {
        for (const auto time : kTimeNames) {
            fields.emplace(section, base + std::string{time});
        }
    }
    return fields;
}

[[nodiscard]] std::optional<int> WeatherClassificationValue(const IniDocument& document) {
    for (const auto& line : document.lines) {
        if (line.section == "Misc" && line.key == "WeatherClassification") {
            int value = 0;
            const auto conversion = std::from_chars(
                line.value.data(), line.value.data() + line.value.size(), value);
            if (conversion.ec == std::errc{}
                && conversion.ptr == line.value.data() + line.value.size()) {
                return value;
            }
        }
    }
    return std::nullopt;
}

struct FileTransformResult {
    bool success{false};
    WeatherDiagnosticCode error{WeatherDiagnosticCode::InvalidWeatherValue};
    std::string key;
    std::string bytes;
    std::size_t fields{0};
    std::size_t alpha_values{0};
    std::string protected_hash;
    std::string source_color_hash;
    std::string output_color_hash;
    WeatherCompileCounts validation;
};

[[nodiscard]] FileTransformResult TransformWeather(
    const std::string_view bytes,
    const WeatherProfileTheme& profile,
    const WeatherFamily family) {
    FileTransformResult result;
    auto document = ParseIni(bytes);
    const auto groups = TargetGroups(profile.expected_cloud_layers);
    const auto target_fields = TargetFields(profile.expected_cloud_layers);
    std::map<std::pair<std::string, std::string>, std::size_t> indices;
    std::string protected_material{"ELDER_WEATHER_PROTECTED_V1\n"};
    std::string source_color_material{"ELDER_WEATHER_COLORS_V1\n"};
    std::string alpha_material{"ELDER_WEATHER_ALPHA_V1\n"};
    for (std::size_t index = 0; index < document.lines.size(); ++index) {
        const auto& line = document.lines[index];
        if (line.key.empty()) {
            continue;
        }
        const auto identity = std::pair{line.section, line.key};
        if (!indices.emplace(identity, index).second) {
            result.error = WeatherDiagnosticCode::DuplicateWeatherField;
            result.key = line.section + "." + line.key;
            return result;
        }
        if (target_fields.contains(identity)) {
            source_color_material += line.section + "." + line.key + "=" + line.value + "\n";
        } else {
            protected_material += line.section + "." + line.key + "=" + line.value + "\n";
        }
    }

    using TimeColors = std::array<ParsedColor, 4>;
    std::map<std::pair<std::string, std::string>, TimeColors> transformed;
    for (const auto& [section, base] : groups) {
        TimeColors colors;
        for (std::size_t time_index = 0; time_index < kTimeNames.size(); ++time_index) {
            const auto key = base + std::string{kTimeNames[time_index]};
            const auto found = indices.find({section, key});
            if (found == indices.end()) {
                result.error = WeatherDiagnosticCode::MissingWeatherField;
                result.key = section + "." + key;
                return result;
            }
            const auto parsed = ParseColor(document.lines[found->second].value);
            if (!parsed.has_value()) {
                result.error = WeatherDiagnosticCode::InvalidWeatherValue;
                result.key = section + "." + key;
                return result;
            }
            if (section == "Clouds" && parsed->alpha_token.has_value()) {
                const auto alpha = ParseDouble(*parsed->alpha_token);
                if (!alpha.has_value() || *alpha < 0.0) {
                    result.error = WeatherDiagnosticCode::InvalidWeatherValue;
                    result.key = section + "." + key;
                    return result;
                }
            }
            colors[time_index] = *parsed;
            if (parsed->alpha_token.has_value()) {
                ++result.alpha_values;
                alpha_material += section + "." + key + "=" + *parsed->alpha_token + "\n";
            }
            const auto time = AllWeatherTimes()[time_index];
            colors[time_index].rgb = ApplyTheme(parsed->rgb, ResolveTarget(profile, family, time));
        }

        const auto sunrise_target = ResolveTarget(profile, family, WeatherTime::Sunrise);
        const auto day_target = ResolveTarget(profile, family, WeatherTime::Day);
        const auto sunset_target = ResolveTarget(profile, family, WeatherTime::Sunset);
        const auto night_target = ResolveTarget(profile, family, WeatherTime::Night);
        auto day_luminance = std::clamp(
            Luminance(colors[1].rgb),
            std::max({
                day_target.min_luminance,
                sunrise_target.min_luminance,
                sunset_target.min_luminance,
                night_target.min_luminance,
            }),
            day_target.max_luminance);
        const auto night_ceiling = std::max(
            night_target.min_luminance,
            std::min(night_target.max_luminance, day_luminance * 0.45));
        const auto night_luminance = std::clamp(
            Luminance(colors[3].rgb),
            night_target.min_luminance,
            night_ceiling);
        const auto sunrise_luminance = std::clamp(
            Luminance(colors[0].rgb),
            std::max(sunrise_target.min_luminance, night_luminance),
            std::min(sunrise_target.max_luminance, day_luminance));
        const auto sunset_luminance = std::clamp(
            Luminance(colors[2].rgb),
            std::max(sunset_target.min_luminance, night_luminance),
            std::min(sunset_target.max_luminance, day_luminance));
        day_luminance = std::max({day_luminance, sunrise_luminance, sunset_luminance});
        colors[0].rgb = SetLuminance(
            colors[0].rgb,
            sunrise_luminance,
            sunrise_target.max_luminance);
        colors[1].rgb = SetLuminance(colors[1].rgb, day_luminance, day_target.max_luminance);
        colors[2].rgb = SetLuminance(colors[2].rgb, sunset_luminance, sunset_target.max_luminance);
        colors[3].rgb = SetLuminance(colors[3].rgb, night_luminance, night_target.max_luminance);
        transformed.emplace(std::pair{section, base}, std::move(colors));
        ++result.validation.temporal_sequences;
    }

    auto& horizon = transformed.at({"Colors", "Horizon"});
    auto& fog_far = transformed.at({"Colors", "FogFar"});
    for (std::size_t time_index = 0; time_index < 4; ++time_index) {
        fog_far[time_index].rgb = horizon[time_index].rgb;
    }

    auto& sky = transformed.at({"Colors", "SkyUpper"});
    std::vector<std::pair<std::string, std::string>> separated_clouds{
        {"Colors", "CloudLodDiffuse"},
    };
    for (std::size_t layer = 0; layer < profile.expected_cloud_layers; ++layer) {
        separated_clouds.emplace_back(
            "Clouds",
            "Layer" + std::to_string(layer) + "Color");
    }
    for (std::size_t time_index = 0; time_index < 4; ++time_index) {
        const auto target = ResolveTarget(profile, family, AllWeatherTimes()[time_index]);
        const auto maximum_sky = target.max_luminance - kCloudSeparation[time_index];
        const auto sky_luminance = std::min(Luminance(sky[time_index].rgb), maximum_sky);
        sky[time_index].rgb = SetLuminance(sky[time_index].rgb, sky_luminance, maximum_sky);
        for (const auto& cloud_identity : separated_clouds) {
            auto& cloud_color = transformed.at(cloud_identity)[time_index];
            const auto separated_luminance = std::max(
                Luminance(cloud_color.rgb),
                sky_luminance + kCloudSeparation[time_index]);
            cloud_color.rgb = SetLuminance(
                cloud_color.rgb,
                separated_luminance,
                target.max_luminance);
        }
    }

    std::string output_color_material{"ELDER_WEATHER_COLORS_V1\n"};
    for (const auto& [identity, colors] : transformed) {
        for (std::size_t time_index = 0; time_index < 4; ++time_index) {
            const auto key = identity.second + std::string{kTimeNames[time_index]};
            const auto index = indices.at({identity.first, key});
            auto& line = document.lines[index];
            const auto value = FormatColor(colors[time_index]);
            line.bytes = line.bytes.substr(0, line.value_offset) + value;
            line.value = value;
            output_color_material += identity.first + "." + key + "=" + value + "\n";
            ++result.fields;

            const auto& rgb = colors[time_index].rgb;
            for (const auto channel : {rgb.red, rgb.green, rgb.blue}) {
                if (!std::isfinite(channel)) {
                    ++result.validation.non_finite_values;
                }
                if (channel < -1e-9 || channel > 1.0 + 1e-9) {
                    ++result.validation.range_violations;
                }
                if ((family == WeatherFamily::Snow || family == WeatherFamily::Storm)
                    && time_index == 1 && channel > 0.960001) {
                    ++result.validation.snow_clip_violations;
                }
            }
        }

        const auto night = Luminance(colors[3].rgb);
        const auto sunrise = Luminance(colors[0].rgb);
        const auto day = Luminance(colors[1].rgb);
        const auto sunset = Luminance(colors[2].rgb);
        if (night > sunrise + 1e-8 || sunrise > day + 1e-8
            || night > sunset + 1e-8 || sunset > day + 1e-8) {
            ++result.validation.temporal_order_violations;
        }
        const auto night_target = ResolveTarget(profile, family, WeatherTime::Night);
        if (night + 1e-8 < night_target.min_luminance) {
            ++result.validation.unreadable_night_violations;
        }
    }

    for (std::size_t time_index = 0; time_index < 4; ++time_index) {
        ++result.validation.fog_horizon_checks;
        const auto& fog = fog_far[time_index].rgb;
        const auto& horizon_color = horizon[time_index].rgb;
        const auto error = std::max({
            std::abs(fog.red - horizon_color.red),
            std::abs(fog.green - horizon_color.green),
            std::abs(fog.blue - horizon_color.blue),
        });
        if (error > 1e-8) {
            ++result.validation.fog_horizon_violations;
        }
        for (std::size_t layer = 0; layer < profile.expected_cloud_layers; ++layer) {
            ++result.validation.cloud_sky_separation_checks;
            const auto& layer_color = transformed.at(
                {"Clouds", "Layer" + std::to_string(layer) + "Color"})[time_index];
            double authored_alpha = 1.0;
            if (layer_color.alpha_token.has_value()) {
                authored_alpha = std::clamp(
                    *ParseDouble(*layer_color.alpha_token),
                    0.0,
                    1.0);
            }
            const auto visible_separation =
                (Luminance(layer_color.rgb) - Luminance(sky[time_index].rgb))
                * authored_alpha;
            if (visible_separation + 1e-8
                < kCloudSeparation[time_index] * authored_alpha) {
                ++result.validation.cloud_sky_separation_violations;
            }
        }
    }

    std::string output_protected_material{"ELDER_WEATHER_PROTECTED_V1\n"};
    std::string output_alpha_material{"ELDER_WEATHER_ALPHA_V1\n"};
    for (const auto& line : document.lines) {
        if (line.key.empty()) {
            continue;
        }
        if (target_fields.contains({line.section, line.key})) {
            const auto parsed = ParseColor(line.value);
            if (!parsed.has_value()) {
                ++result.validation.alpha_preservation_violations;
            } else if (parsed->alpha_token.has_value()) {
                output_alpha_material += line.section + "." + line.key + "="
                    + *parsed->alpha_token + "\n";
            }
        } else {
            output_protected_material += line.section + "." + line.key + "="
                + line.value + "\n";
        }
    }
    result.protected_hash = bindings::Sha256(protected_material);
    if (bindings::Sha256(output_protected_material) != result.protected_hash) {
        ++result.validation.protected_value_changes;
    }
    if (bindings::Sha256(output_alpha_material) != bindings::Sha256(alpha_material)) {
        ++result.validation.alpha_preservation_violations;
    }
    result.source_color_hash = bindings::Sha256(source_color_material);
    result.output_color_hash = bindings::Sha256(output_color_material);
    result.bytes = SerializeIni(document);
    result.success = result.validation.non_finite_values == 0
        && result.validation.range_violations == 0
        && result.validation.alpha_preservation_violations == 0
        && result.validation.protected_value_changes == 0
        && result.validation.temporal_order_violations == 0
        && result.validation.fog_horizon_violations == 0
        && result.validation.cloud_sky_separation_violations == 0
        && result.validation.unreadable_night_violations == 0
        && result.validation.snow_clip_violations == 0;
    if (!result.success) {
        result.error = WeatherDiagnosticCode::InvariantViolation;
    }
    return result;
}

void AddCounts(WeatherCompileCounts& target, const WeatherCompileCounts& addition) {
    target.protected_value_changes += addition.protected_value_changes;
    target.non_finite_values += addition.non_finite_values;
    target.range_violations += addition.range_violations;
    target.temporal_sequences += addition.temporal_sequences;
    target.temporal_order_violations += addition.temporal_order_violations;
    target.fog_horizon_checks += addition.fog_horizon_checks;
    target.fog_horizon_violations += addition.fog_horizon_violations;
    target.cloud_sky_separation_checks += addition.cloud_sky_separation_checks;
    target.cloud_sky_separation_violations += addition.cloud_sky_separation_violations;
    target.unreadable_night_violations += addition.unreadable_night_violations;
    target.snow_clip_violations += addition.snow_clip_violations;
    target.alpha_preservation_violations += addition.alpha_preservation_violations;
}

[[nodiscard]] std::optional<double> OverlayTintAlpha(const std::string_view overlay) {
    auto document = ParseIni(overlay);
    struct OverlayFields {
        std::string name;
        std::string operation;
    };
    std::map<std::string, OverlayFields> sections;
    for (const auto& line : document.lines) {
        if (line.key == "Name") {
            sections[line.section].name = line.value;
        } else if (line.key == "Operation") {
            sections[line.section].operation = line.value;
        }
    }
    struct TintAlpha {
        std::string scope;
        double alpha{0.0};
    };
    std::vector<TintAlpha> tint_alphas;
    for (const auto& [section, fields] : sections) {
        static_cast<void>(section);
        const auto separator = fields.name.find('|');
        if (separator == std::string::npos
            || !std::string_view{fields.name}.substr(separator + 1).ends_with("Tint")) {
            continue;
        }
        auto value = Trim(fields.operation);
        if (value.size() >= 3 && value.front() == '"' && value.back() == '"') {
            value = Trim(std::string_view{value}.substr(1, value.size() - 2));
        }
        if (!value.starts_with('=')) {
            return std::nullopt;
        }
        const auto parsed = ParseColor(Trim(std::string_view{value}.substr(1)));
        if (!parsed.has_value() || !parsed->alpha_token.has_value()) {
            return std::nullopt;
        }
        const auto alpha = ParseDouble(*parsed->alpha_token);
        if (!alpha.has_value() || *alpha < 0.0 || *alpha > 1.0) {
            return std::nullopt;
        }
        const auto target_key = LowerAscii(fields.name.substr(separator + 1));
        std::string scope{"global"};
        for (const std::string_view candidate : {
                 "dawn", "sunrise", "day", "sunset", "dusk", "night", "interior"}) {
            if (target_key.contains("- " + std::string{candidate} + " -")) {
                scope = candidate;
                break;
            }
        }
        tint_alphas.push_back({std::move(scope), *alpha});
    }
    std::set<std::string> scopes;
    for (const auto& tint : tint_alphas) {
        if (tint.scope != "global") {
            scopes.insert(tint.scope);
        }
    }
    if (scopes.empty()) {
        scopes.insert("global");
    }
    double maximum = 0.0;
    for (const auto& scope : scopes) {
        double remaining = 1.0;
        for (const auto& tint : tint_alphas) {
            if (tint.scope == "global" || tint.scope == scope) {
                remaining *= 1.0 - tint.alpha;
            }
        }
        maximum = std::max(maximum, 1.0 - remaining);
    }
    return maximum;
}

using SemanticBindingIdentity =
    std::tuple<std::string, std::string, std::string, std::string>;

[[nodiscard]] std::optional<std::string> OverlayOperationType(
    std::string value) {
    value = Trim(value);
    if (value.size() >= 2 && value.front() == '"' && value.back() == '"') {
        value = Trim(std::string_view{value}.substr(1, value.size() - 2));
    }
    if (value.empty()) {
        return std::nullopt;
    }
    const char operation = value.front();
    const auto operand = Trim(std::string_view{value}.substr(1));
    if ((operation == '+' || operation == '*') && ParseDouble(operand).has_value()) {
        return operation == '+' ? "ADD_SCALAR" : "MULTIPLY_SCALAR";
    }
    if (operation != '=') {
        return std::nullopt;
    }
    if (ParseDouble(operand).has_value()) {
        return "SET_SCALAR";
    }
    const auto color = ParseColor(operand);
    if (!color.has_value()) {
        return std::nullopt;
    }
    return color->alpha_token.has_value() ? "SET_VECTOR4" : "SET_VECTOR3";
}

[[nodiscard]] std::set<SemanticBindingIdentity> OverlaySemanticBindings(
    const std::string_view overlay) {
    const auto document = ParseIni(overlay);
    struct Fields {
        std::string category;
        std::string name;
        std::string operation;
    };
    std::map<std::string, Fields> sections;
    for (const auto& line : document.lines) {
        auto& fields = sections[line.section];
        if (line.key == "Category") {
            fields.category = line.value;
        } else if (line.key == "Name") {
            fields.name = line.value;
        } else if (line.key == "Operation") {
            fields.operation = line.value;
        }
    }
    std::set<SemanticBindingIdentity> bindings;
    for (const auto& [section, fields] : sections) {
        static_cast<void>(section);
        const auto separator = fields.name.find('|');
        const auto operation_type = OverlayOperationType(fields.operation);
        if (fields.category.empty() || separator == std::string::npos
            || !operation_type.has_value()) {
            continue;
        }
        bindings.emplace(
            fields.category,
            fields.name.substr(0, separator),
            fields.name.substr(separator + 1),
            *operation_type);
    }
    return bindings;
}

[[nodiscard]] double WorldTintStrength(const WeatherProfileTheme& profile) {
    double maximum = 0.0;
    for (const auto family : AllWeatherFamilies()) {
        for (const auto time : AllWeatherTimes()) {
            const auto target = ResolveTarget(profile, family, time);
            for (const auto gain : target.tint) {
                maximum = std::max(maximum, std::abs(gain - 1.0) * target.blend);
            }
        }
    }
    return maximum;
}

struct InputTreeInventory {
    std::string manifest;
    std::string unexpected_path;
    bool valid{false};
};

[[nodiscard]] bool HasExactChildren(
    const fs::path& root,
    const std::map<std::string, bool>& expected,
    std::string& unexpected_path) {
    std::map<std::string, bool> actual;
    std::error_code error;
    for (fs::directory_iterator iterator{root, error}, end;
         !error && iterator != end;
         iterator.increment(error)) {
        std::error_code type_error;
        const bool is_symlink = iterator->is_symlink(type_error);
        const bool is_directory = !type_error && iterator->is_directory(type_error);
        const bool is_file = !type_error && iterator->is_regular_file(type_error);
        const auto name = PathToUtf8(iterator->path().filename());
        if (type_error || is_symlink || (!is_directory && !is_file)
            || !actual.emplace(name, is_directory).second) {
            unexpected_path = PathToUtf8(iterator->path().lexically_relative(root));
            return false;
        }
    }
    if (error || actual != expected) {
        unexpected_path = error ? "READ" : "CHILD_SET";
        return false;
    }
    return true;
}

[[nodiscard]] InputTreeInventory InventoryInputTree(
    const fs::path& root,
    const WeatherThemeConfig& config) {
    InputTreeInventory inventory;
    try {
        const std::map<std::string, bool> root_entries{
            {"bundle-index.csv", false},
            {"profiles", true},
            {"provenance.csv", false},
            {"report.txt", false},
        };
        if (!HasExactChildren(root, root_entries, inventory.unexpected_path)) {
            return inventory;
        }

        std::map<std::string, bool> expected_bundles;
        for (const auto& profile : config.profiles) {
            expected_bundles.emplace(profile.bundle_id, true);
        }
        if (expected_bundles.size() != config.profiles.size()
            || !HasExactChildren(
                root / "profiles",
                expected_bundles,
                inventory.unexpected_path)) {
            return inventory;
        }

        for (const auto& profile : config.profiles) {
            const auto bundle = root / "profiles" / Utf8ToPath(profile.bundle_id);
            if (!HasExactChildren(
                    bundle,
                    {{"bundle.csv", false}, {"overlay", true}, {"preset", true}},
                    inventory.unexpected_path)
                || !HasExactChildren(
                    bundle / "overlay",
                    {{profile.overlay_file, false}},
                    inventory.unexpected_path)
                || !HasExactChildren(
                    bundle / "preset",
                    {{profile.preset_directory, true}},
                    inventory.unexpected_path)) {
                return inventory;
            }
        }

        struct FileEntry {
            std::string path;
            std::uintmax_t bytes{0};
            std::string sha256;
        };
        std::vector<FileEntry> files;
        std::error_code error;
        for (fs::recursive_directory_iterator iterator{root, error}, end;
             !error && iterator != end;
             iterator.increment(error)) {
            std::error_code type_error;
            if (iterator->is_symlink(type_error) || type_error) {
                inventory.unexpected_path = PathToUtf8(
                    iterator->path().lexically_relative(root));
                return inventory;
            }
            if (iterator->is_directory(type_error) && !type_error) {
                continue;
            }
            if (!iterator->is_regular_file(type_error) || type_error) {
                inventory.unexpected_path = PathToUtf8(
                    iterator->path().lexically_relative(root));
                return inventory;
            }
            const auto relative = PathToUtf8(iterator->path().lexically_relative(root));
            files.push_back(FileEntry{
                relative,
                iterator->file_size(type_error),
                bindings::Sha256File(iterator->path()),
            });
            if (type_error || files.back().sha256.empty()) {
                inventory.unexpected_path = relative;
                return inventory;
            }
        }
        if (error) {
            inventory.unexpected_path = "READ";
            return inventory;
        }
        std::ranges::sort(files, [](const FileEntry& left, const FileEntry& right) {
            return left.path < right.path;
        });
        inventory.manifest = "relative_path,file_bytes,file_sha256\n";
        for (const auto& file : files) {
            inventory.manifest += CsvField(file.path) + ',' + std::to_string(file.bytes)
                + ',' + CsvField(file.sha256) + '\n';
        }
        inventory.valid = true;
    } catch (const std::exception&) {
        inventory.unexpected_path = "READ";
    }
    return inventory;
}

[[nodiscard]] bool MatchesExpectation(
    const std::optional<std::size_t>& expected,
    const std::size_t actual) {
    return !expected.has_value() || *expected == actual;
}

[[nodiscard]] bool MatchesExpectations(
    const WeatherCompileExpectations& expected,
    const WeatherCompileCounts& actual) {
    return MatchesExpectation(expected.profiles, actual.profiles)
        && MatchesExpectation(expected.weather_records, actual.weather_records)
        && MatchesExpectation(expected.transformed_fields, actual.transformed_fields)
        && MatchesExpectation(expected.semantic_verified, actual.semantic_verified)
        && MatchesExpectation(expected.semantic_unresolved, actual.semantic_unresolved);
}

void WriteArtifacts(
    const fs::path& root,
    const WeatherCompileResult& result,
    const std::string_view input_tree_manifest) {
    WriteFile(root / "input-tree-manifest.csv", input_tree_manifest);
    std::string index =
        "bundle_id,profile_id,weather_records,transformed_fields,alpha_values_preserved,"
        "overlay_tint_alpha,world_tint_strength,double_tint_budget,preset_tree_sha256,"
        "bundle_sha256,bundle_bytes\n";
    for (const auto& bundle : result.bundles) {
        index += CsvField(bundle.bundle_id) + ',' + CsvField(bundle.profile_id) + ','
            + std::to_string(bundle.weather_records) + ','
            + std::to_string(bundle.transformed_fields) + ','
            + std::to_string(bundle.alpha_values_preserved) + ','
            + FormatDouble(bundle.overlay_tint_alpha) + ','
            + FormatDouble(bundle.world_tint_strength) + ','
            + FormatDouble(bundle.double_tint_budget) + ','
            + CsvField(bundle.preset_tree_sha256) + ',' + CsvField(bundle.bundle_sha256) + ','
            + std::to_string(bundle.bundle_bytes) + '\n';
    }
    WriteFile(root / "weather-index.csv", index);

    std::string provenance =
        "profile_id,relative_path,family,family_basis,source_sha256,output_sha256,"
        "transformed_fields,alpha_values_preserved,protected_values_sha256,"
        "source_colors_sha256,output_colors_sha256\n";
    for (const auto& entry : result.provenance) {
        provenance += CsvField(entry.profile_id) + ',' + CsvField(entry.relative_path) + ','
            + CsvField(ToString(entry.family)) + ',' + CsvField(entry.family_basis) + ','
            + CsvField(entry.source_sha256) + ',' + CsvField(entry.output_sha256) + ','
            + std::to_string(entry.transformed_fields) + ','
            + std::to_string(entry.alpha_values_preserved) + ','
            + CsvField(entry.protected_values_sha256) + ','
            + CsvField(entry.source_colors_sha256) + ','
            + CsvField(entry.output_colors_sha256) + '\n';
    }
    WriteFile(root / "weather-provenance.csv", provenance);

    const auto& counts = result.counts;
    std::string report =
        "format=elder-weather-themes-v1\n"
        "profiles=" + std::to_string(counts.profiles) + "\n"
        "weather_records=" + std::to_string(counts.weather_records) + "\n"
        "transformed_records=" + std::to_string(counts.transformed_records) + "\n"
        "transformed_fields=" + std::to_string(counts.transformed_fields) + "\n"
        "alpha_values_preserved=" + std::to_string(counts.alpha_values_preserved) + "\n"
        "alpha_preservation_violations="
        + std::to_string(counts.alpha_preservation_violations) + "\n"
        "protected_value_changes=" + std::to_string(counts.protected_value_changes) + "\n"
        "non_finite_values=" + std::to_string(counts.non_finite_values) + "\n"
        "range_violations=" + std::to_string(counts.range_violations) + "\n"
        "temporal_sequences=" + std::to_string(counts.temporal_sequences) + "\n"
        "temporal_order_violations=" + std::to_string(counts.temporal_order_violations) + "\n"
        "fog_horizon_checks=" + std::to_string(counts.fog_horizon_checks) + "\n"
        "fog_horizon_violations=" + std::to_string(counts.fog_horizon_violations) + "\n"
        "cloud_sky_separation_checks="
            + std::to_string(counts.cloud_sky_separation_checks) + "\n"
        "cloud_sky_separation_violations="
            + std::to_string(counts.cloud_sky_separation_violations) + "\n"
        "unreadable_night_violations="
            + std::to_string(counts.unreadable_night_violations) + "\n"
        "snow_clip_violations=" + std::to_string(counts.snow_clip_violations) + "\n"
        "semantic_verified=" + std::to_string(counts.semantic_verified) + "\n"
        "semantic_unresolved=" + std::to_string(counts.semantic_unresolved) + "\n";
    WriteFile(root / "weather-report.txt", report);
}

}  // namespace

bool SemanticVerificationResult::success() const noexcept {
    return diagnostics.empty();
}

VerifiedSemanticRegistry::VerifiedSemanticRegistry(
    std::vector<ShaderSemanticEntry> entries,
    const std::size_t verified_entries,
    const std::size_t unresolved_entries)
    : entries_(std::move(entries)),
      verified_entries_(verified_entries),
      unresolved_entries_(unresolved_entries) {}

const std::vector<ShaderSemanticEntry>& VerifiedSemanticRegistry::entries() const noexcept {
    return entries_;
}

std::size_t VerifiedSemanticRegistry::verified_entries() const noexcept {
    return verified_entries_;
}

std::size_t VerifiedSemanticRegistry::unresolved_entries() const noexcept {
    return unresolved_entries_;
}

bool WeatherCompileResult::success() const noexcept {
    return diagnostics.empty();
}

WeatherClassification ClassifyWeather(
    const std::string_view record_identity,
    const int classification) {
    const auto identity = LowerAscii(std::string{record_identity});
    if (ContainsAny(identity, {"storm", "thunder", "tempest", "blizzard", "squall"})) {
        return {WeatherFamily::Storm, "IDENTITY_STORM"};
    }
    if (ContainsAny(identity, {"fog", "mist", "haze"})) {
        return {WeatherFamily::Fog, "IDENTITY_FOG"};
    }
    if (classification == 4 || ContainsAny(identity, {"snow", "flurr"})) {
        return {
            WeatherFamily::Snow,
            classification == 4 ? "CLASSIFICATION_SNOW" : "IDENTITY_SNOW",
        };
    }
    if (classification == 3 || ContainsAny(identity, {"rain", "drizz"})) {
        return {
            WeatherFamily::Rain,
            classification == 3 ? "CLASSIFICATION_RAIN" : "IDENTITY_RAIN",
        };
    }
    if (classification == 1
        || ContainsAny(identity, {"clear", "sunny", "pleasant", "aurora"})) {
        return {
            WeatherFamily::Clear,
            classification == 1 ? "CLASSIFICATION_CLEAR" : "IDENTITY_CLEAR",
        };
    }
    return {WeatherFamily::Cloudy, "CLASSIFICATION_OR_DEFAULT_CLOUDY"};
}

SemanticVerificationResult VerifyShaderSemanticRegistry(
    const ShaderSemanticRegistry& registry) {
    SemanticVerificationResult result;
    if (!registry.diagnostics.empty() || registry.entries.empty()) {
        AddDiagnostic(result, WeatherDiagnosticCode::InvalidSemanticRegistry);
        return result;
    }
    std::set<std::tuple<std::string, std::string, std::string, std::string>> seen;
    std::set<std::string> evidence_ids;
    for (const auto& entry : registry.entries) {
        const auto identity = std::tuple{
            entry.target_filename,
            entry.target_category,
            entry.binding_key,
            entry.binding_type,
        };
        std::set<std::string> required_profiles;
        const bool profiles_valid = !entry.required_profiles.empty()
            && std::ranges::all_of(
                entry.required_profiles,
                [&required_profiles](const std::string& profile) {
                    return !profile.empty() && required_profiles.insert(profile).second;
                });
        if (!seen.insert(identity).second || !evidence_ids.insert(entry.evidence_id).second
            || !IsOpaqueId(entry.evidence_id) || !IsBindingType(entry.binding_type)
            || entry.semantic_paraphrase.empty() || !profiles_valid) {
            AddDiagnostic(
                result,
                WeatherDiagnosticCode::InvalidSemanticRegistry,
                entry.evidence_id,
                entry.binding_key);
            continue;
        }
        if (entry.evidence == SemanticEvidence::UnresolvedStaleBinding) {
            if (entry.uncertainty.empty() || !entry.declaration_artifact_id.empty()
                || !entry.declaration_artifact_sha256.empty()
                || !entry.declaration_span_sha256.empty()
                || entry.declaration_span_bytes != 0
                || !entry.declaration_context_sha256.empty()
                || !entry.use_artifact_id.empty()
                || !entry.use_artifact_sha256.empty()
                || !entry.use_span_sha256.empty() || entry.use_span_bytes != 0
                || !entry.use_context_sha256.empty()) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InvalidSemanticRegistry,
                    entry.evidence_id,
                    entry.binding_key);
            } else {
                ++result.unresolved_entries;
            }
            continue;
        }
        if (!IsOpaqueId(entry.declaration_artifact_id)
            || !IsSha256(entry.declaration_artifact_sha256)
            || !IsSha256(entry.declaration_span_sha256)
            || entry.declaration_span_bytes == 0
            || !IsSha256(entry.declaration_context_sha256)
            || !IsOpaqueId(entry.use_artifact_id)
            || !IsSha256(entry.use_artifact_sha256)
            || !IsSha256(entry.use_span_sha256) || entry.use_span_bytes == 0
            || !IsSha256(entry.use_context_sha256)) {
            AddDiagnostic(
                result,
                WeatherDiagnosticCode::InvalidSemanticRegistry,
                entry.evidence_id,
                entry.binding_key);
            continue;
        }
        ++result.verified_entries;
    }
    return result;
}

SemanticVerificationResult VerifyShaderSemanticRegistry(
    const ShaderSemanticRegistry& registry,
    const fs::path& artifact_root,
    const fs::path& protected_sidecar) {
    auto result = VerifyShaderSemanticRegistry(registry);
    if (!result.success()) {
        return result;
    }
    struct SidecarSpan {
        std::string evidence_id;
        std::string role;
        std::string artifact_id;
        std::string source_path;
        std::size_t span_offset{0};
        std::string raw_span;
    };
    constexpr std::array<std::string_view, 6> expected_header{
        "evidence_id",
        "role",
        "artifact_id",
        "source_path",
        "span_offset",
        "raw_span",
    };
    std::map<std::pair<std::string, std::string>, SidecarSpan> spans;
    try {
        std::ifstream input{protected_sidecar, std::ios::binary};
        std::string line;
        bool valid = false;
        if (!input || !std::getline(input, line)) {
            AddDiagnostic(result, WeatherDiagnosticCode::InvalidSemanticRegistry, {}, "SIDECAR");
        } else {
            const auto header = ParseCsvRow(line, valid);
            if (!valid || header.size() != expected_header.size()
                || !std::ranges::equal(header, expected_header)) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InvalidSemanticRegistry,
                    {},
                    "SIDECAR_HEADER");
            }
        }
        while (result.diagnostics.empty() && std::getline(input, line)) {
            if (Trim(line).empty()) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InvalidSemanticRegistry,
                    {},
                    "SIDECAR_BLANK_ROW");
                break;
            }
            const auto fields = ParseCsvRow(line, valid);
            const auto offset = fields.size() == expected_header.size()
                ? ParseCount(fields[4])
                : std::nullopt;
            if (!valid || fields.size() != expected_header.size()
                || !IsOpaqueId(fields[0])
                || (fields[1] != "declaration" && fields[1] != "use")
                || !IsOpaqueId(fields[2]) || !IsSafeRelativePath(fields[3])
                || !offset.has_value() || fields[5].empty()
                || !spans.emplace(
                         std::pair{fields[0], fields[1]},
                         SidecarSpan{
                             fields[0], fields[1], fields[2], fields[3], *offset, fields[5]})
                         .second) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InvalidSemanticRegistry,
                    fields.empty() ? std::string{} : fields[0],
                    "SIDECAR_ROW");
                break;
            }
        }
        if (!input.eof() && result.diagnostics.empty()) {
            AddDiagnostic(result, WeatherDiagnosticCode::InvalidSemanticRegistry, {}, "SIDECAR_READ");
        }
    } catch (const std::exception&) {
        AddDiagnostic(result, WeatherDiagnosticCode::InvalidSemanticRegistry, {}, "SIDECAR_READ");
    }

    std::map<std::string, std::pair<std::string, std::string>> artifact_identity;
    if (result.diagnostics.empty()
        && spans.size() != result.verified_entries * 2) {
        AddDiagnostic(result, WeatherDiagnosticCode::InvalidSemanticRegistry, {}, "SIDECAR_COUNT");
    }
    for (const auto& entry : registry.entries) {
        if (!result.diagnostics.empty()) {
            break;
        }
        if (entry.evidence == SemanticEvidence::UnresolvedStaleBinding) {
            continue;
        }
        for (const std::string_view role : {"declaration", "use"}) {
            const auto found = spans.find({entry.evidence_id, std::string{role}});
            if (found == spans.end()) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InvalidSemanticRegistry,
                    entry.evidence_id,
                    std::string{role});
                break;
            }
            const auto& span = found->second;
            const bool declaration = role == "declaration";
            const auto& expected_artifact_id = declaration
                ? entry.declaration_artifact_id
                : entry.use_artifact_id;
            const auto& expected_artifact_hash = declaration
                ? entry.declaration_artifact_sha256
                : entry.use_artifact_sha256;
            const auto& expected_span_hash = declaration
                ? entry.declaration_span_sha256
                : entry.use_span_sha256;
            const auto expected_span_bytes = declaration
                ? entry.declaration_span_bytes
                : entry.use_span_bytes;
            const auto& expected_context_hash = declaration
                ? entry.declaration_context_sha256
                : entry.use_context_sha256;
            const auto source_path = artifact_root / Utf8ToPath(span.source_path);
            if (span.artifact_id != expected_artifact_id
                || !fs::is_regular_file(source_path)) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::ShaderSourceHashMismatch,
                    entry.evidence_id,
                    std::string{role});
                break;
            }
            const auto source = ReadFile(source_path);
            const auto artifact_sha256 = bindings::Sha256(source);
            const auto artifact_key = std::pair{span.source_path, artifact_sha256};
            const auto [artifact, inserted] = artifact_identity.emplace(
                span.artifact_id,
                artifact_key);
            if ((!inserted && artifact->second != artifact_key)
                || LowerAscii(artifact_sha256) != LowerAscii(expected_artifact_hash)
                || span.raw_span.size() != expected_span_bytes
                || span.span_offset > source.size()
                || span.raw_span.size() > source.size() - span.span_offset) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::ShaderSourceHashMismatch,
                    entry.evidence_id,
                    std::string{role});
                break;
            }
            const auto source_span = std::string_view{source}.substr(
                span.span_offset,
                span.raw_span.size());
            if (source_span != span.raw_span
                || LowerAscii(bindings::Sha256(span.raw_span))
                    != LowerAscii(expected_span_hash)) {
                AddDiagnostic(
                    result,
                    declaration ? WeatherDiagnosticCode::ShaderDeclarationMismatch
                                : WeatherDiagnosticCode::ShaderUseMismatch,
                    entry.evidence_id,
                    std::string{role});
                break;
            }
            constexpr std::size_t context_flank = 32;
            const auto context_begin = span.span_offset > context_flank
                ? span.span_offset - context_flank
                : 0;
            const auto context_end = std::min(
                source.size(),
                span.span_offset + span.raw_span.size() + context_flank);
            const auto context = std::string_view{source}.substr(
                context_begin,
                context_end - context_begin);
            if (LowerAscii(bindings::Sha256(context))
                != LowerAscii(expected_context_hash)) {
                AddDiagnostic(
                    result,
                    declaration ? WeatherDiagnosticCode::ShaderDeclarationMismatch
                                : WeatherDiagnosticCode::ShaderUseMismatch,
                    entry.evidence_id,
                    std::string{role} + "_CONTEXT");
                break;
            }
        }
    }
    if (!result.diagnostics.empty()) {
        result.registry.reset();
    } else {
        result.registry = VerifiedSemanticRegistry(
            registry.entries,
            result.verified_entries,
            result.unresolved_entries);
    }
    return result;
}

WeatherCompileResult CompileWeatherThemeBundles(
    const fs::path& input_root,
    const fs::path& output_root,
    const WeatherThemeConfig& config,
    const VerifiedSemanticRegistry& registry,
    const bindings::DispositionCatalog& catalog,
    const WeatherCompileControls& controls) {
    WeatherCompileResult result;
    if (!detail::PathsAreSafelyDisjoint(input_root, output_root)) {
        AddDiagnostic(result, WeatherDiagnosticCode::UnsafeOutputPath);
        return result;
    }
    if (!config.diagnostics.empty() || config.profiles.empty()) {
        AddDiagnostic(result, WeatherDiagnosticCode::InvalidConfig);
        return result;
    }
    if (registry.entries().empty()) {
        AddDiagnostic(result, WeatherDiagnosticCode::InvalidSemanticRegistry);
        return result;
    }

    std::map<std::string, bindings::BindingDisposition> catalog_by_profile;
    for (const auto& binding : catalog.bindings) {
        catalog_by_profile.emplace(binding.canonical_identity, binding);
    }
    std::set<std::string> profiles_seen;
    std::set<std::string> bundles_seen;
    for (const auto& profile : config.profiles) {
        if (!profiles_seen.insert(profile.profile_id).second
            || !bundles_seen.insert(profile.bundle_id).second
            || profile.bundle_id.empty() || profile.profile_id.empty()
            || !IsSafeRelativePath(profile.preset_directory)
            || !IsSafeRelativePath(profile.overlay_file)
            || !IsSha256(profile.input_bundle_sha256)
            || !IsSha256(profile.source_tree_sha256)
            || profile.expected_weather_records == 0 || profile.expected_cloud_layers == 0
            || !std::isfinite(profile.max_double_tint_budget)
            || profile.max_double_tint_budget < 0.0
            || profile.families.size() != AllWeatherFamilies().size()
            || profile.times.size() != AllWeatherTimes().size()
            || !catalog_by_profile.contains(profile.profile_id)) {
            AddDiagnostic(result, WeatherDiagnosticCode::InvalidConfig, profile.profile_id);
        }
        const auto axis_valid = [](const ThemeAxis& axis) {
            return std::isfinite(axis.exposure_ev) && axis.exposure_ev >= -4.0
                && axis.exposure_ev <= 4.0 && std::isfinite(axis.chroma)
                && axis.chroma >= 0.0 && axis.chroma <= 4.0
                && std::isfinite(axis.blend) && axis.blend >= 0.0
                && axis.blend <= 1.0 && std::isfinite(axis.min_luminance)
                && std::isfinite(axis.max_luminance) && axis.min_luminance >= 0.0
                && axis.max_luminance <= 1.0 && axis.min_luminance <= axis.max_luminance
                && std::ranges::all_of(axis.tint, [](const double value) {
                       return std::isfinite(value) && value > 0.0 && value <= 2.0;
                   });
        };
        const bool component_axes_valid = axis_valid(profile.base)
            && !std::ranges::any_of(profile.families, [&](const auto& entry) {
                   return !axis_valid(entry.second);
               })
            && !std::ranges::any_of(profile.times, [&](const auto& entry) {
                   return !axis_valid(entry.second);
               });
        const auto derived_axes_valid = [&profile]() {
            if (profile.families.size() != AllWeatherFamilies().size()
                || profile.times.size() != AllWeatherTimes().size()) {
                return false;
            }
            for (const auto family : AllWeatherFamilies()) {
                std::array<ThemeAxis, 4> targets;
                for (std::size_t index = 0; index < targets.size(); ++index) {
                    targets[index] = ResolveTarget(profile, family, AllWeatherTimes()[index]);
                    const auto& target = targets[index];
                    if (target.exposure_ev < -4.0 || target.exposure_ev > 4.0
                        || !std::isfinite(target.chroma) || target.chroma < 0.0
                        || target.chroma > 4.0
                        || target.min_luminance > target.max_luminance
                        || target.max_luminance - target.min_luminance
                            + 1e-12 < kCloudSeparation[index]
                        || std::ranges::any_of(target.tint, [](const double value) {
                               return !std::isfinite(value) || value <= 0.0
                                   || value > 2.0;
                           })) {
                        return false;
                    }
                }
                const auto& sunrise = targets[0];
                const auto& day = targets[1];
                const auto& sunset = targets[2];
                const auto& night = targets[3];
                const auto day_lower = std::max({
                    sunrise.min_luminance,
                    day.min_luminance,
                    sunset.min_luminance,
                    night.min_luminance,
                });
                if (day_lower > day.max_luminance
                    || sunrise.max_luminance < night.max_luminance
                    || sunset.max_luminance < night.max_luminance) {
                    return false;
                }
            }
            return true;
        }();
        if (!component_axes_valid || !derived_axes_valid) {
            AddDiagnostic(result, WeatherDiagnosticCode::InvalidConfig, profile.profile_id);
        }
    }
    if (!result.success()) {
        return result;
    }
    for (const auto& entry : registry.entries()) {
        for (const auto& profile : entry.required_profiles) {
            if (!profiles_seen.contains(profile)) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InvalidSemanticRegistry,
                    profile,
                    entry.target_filename,
                    entry.binding_key);
            }
        }
    }
    if (!result.success()) {
        return result;
    }

    auto output_lock = detail::ExclusiveOutputLock::Acquire(output_root);
    if (!output_lock.has_value()) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "OUTPUT_LOCKED");
        return result;
    }
    std::error_code error;
    if (fs::exists(output_root, error)
        && (!fs::is_directory(output_root, error)
            || !detail::HasOwnershipMarker(
                output_root,
                detail::OwnedTreeRole::Output,
                {}))) {
        AddDiagnostic(result, WeatherDiagnosticCode::UnsafeOutputPath, {}, {}, "UNOWNED_OUTPUT");
        return result;
    }
    if (error) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError);
        return result;
    }

    std::string source_tree_before;
    try {
        source_tree_before = improvement::DirectoryTreeHash(input_root);
    } catch (const std::exception&) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SOURCE_HASH");
        return result;
    }
    if (source_tree_before.empty()) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SOURCE_HASH");
        return result;
    }
    const auto snapshot_transaction_id = detail::NewTransactionId();
    const auto created_snapshot = detail::CreateOwnedTree(
        output_root.parent_path(),
        "ewi",
        detail::OwnedTreeRole::Scratch,
        snapshot_transaction_id);
    if (!created_snapshot.has_value()) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_CREATE");
        return result;
    }
    const auto snapshot_owner = *created_snapshot;
    const auto snapshot = snapshot_owner / "p";
    OwnedTreeCleanup snapshot_cleanup{
        snapshot_owner,
        detail::OwnedTreeRole::Scratch,
        snapshot_transaction_id};
    const auto cleanup_snapshot = [&]() { return snapshot_cleanup.Cleanup(); };
    std::string snapshot_tree_hash;
    try {
        if (controls.phase_observer) {
            controls.phase_observer(WeatherCompilePhase::SnapshotCreated, snapshot);
        }
        if (!CopyTree(input_root, snapshot)) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_COPY");
        } else {
            snapshot_tree_hash = improvement::DirectoryTreeHash(snapshot);
            if (snapshot_tree_hash.empty()) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::IoError,
                    {},
                    {},
                    "SNAPSHOT_HASH");
            }
        }
    } catch (const std::exception&) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_COPY");
    }
    if (!result.success()) {
        if (!cleanup_snapshot()) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_CLEANUP");
        }
        return result;
    }
    if (snapshot_tree_hash != source_tree_before) {
        AddDiagnostic(result, WeatherDiagnosticCode::SourceChanged, {}, {}, "SNAPSHOT_HASH");
        if (!cleanup_snapshot()) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_CLEANUP");
        }
        return result;
    }
    const auto inventory = InventoryInputTree(snapshot, config);
    if (!inventory.valid) {
        AddDiagnostic(
            result,
            WeatherDiagnosticCode::InputTreeMismatch,
            {},
            inventory.unexpected_path);
        if (!cleanup_snapshot()) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_CLEANUP");
        }
        return result;
    }
    try {
        if (controls.phase_observer) {
            controls.phase_observer(WeatherCompilePhase::SnapshotVerified, snapshot);
        }
    } catch (const std::exception&) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_OBSERVER");
        if (!cleanup_snapshot()) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_CLEANUP");
        }
        return result;
    }

    const auto transaction_id = detail::NewTransactionId();
    const auto created_stage = detail::CreateOwnedTree(
        output_root.parent_path(),
        "ews",
        detail::OwnedTreeRole::Stage,
        transaction_id);
    if (!created_stage.has_value()) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "STAGE_CREATE");
        if (!cleanup_snapshot()) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "SNAPSHOT_CLEANUP");
        }
        return result;
    }
    const auto stage = *created_stage;
    OwnedTreeCleanup stage_cleanup{
        stage,
        detail::OwnedTreeRole::Stage,
        transaction_id};
    const auto cleanup_stage = [&]() { return stage_cleanup.Cleanup(); };
    const auto cleanup_workspaces = [&]() {
        if (!cleanup_stage()) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "STAGE_CLEANUP");
        }
        if (!cleanup_snapshot()) {
            AddDiagnostic(
                result,
                WeatherDiagnosticCode::IoError,
                {},
                {},
                "SNAPSHOT_CLEANUP");
        }
    };
    try {
        if (!CopyTree(snapshot, stage)) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError);
            throw std::runtime_error("weather copy failed");
        }
        for (const auto& profile : config.profiles) {
            const auto input_bundle = snapshot / "profiles" / Utf8ToPath(profile.bundle_id);
            const auto output_bundle = stage / "profiles" / Utf8ToPath(profile.bundle_id);
            const auto input_preset_root = input_bundle / "preset";
            const auto output_preset_root = output_bundle / "preset";
            const auto input_preset = input_preset_root / Utf8ToPath(profile.preset_directory);
            const auto output_preset = output_preset_root / Utf8ToPath(profile.preset_directory);
            const auto input_overlay = input_bundle / "overlay" / Utf8ToPath(profile.overlay_file);
            if (!fs::is_directory(input_preset) || !fs::is_regular_file(input_overlay)) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::MissingInputBundle,
                    profile.profile_id);
                break;
            }
            const auto overlay_bytes = ReadFile(input_overlay);
            const auto overlay_bindings = OverlaySemanticBindings(overlay_bytes);
            for (const auto& entry : registry.entries()) {
                if (std::ranges::find(
                        entry.required_profiles,
                        profile.profile_id)
                        == entry.required_profiles.end()) {
                    continue;
                }
                const SemanticBindingIdentity identity{
                    entry.target_filename,
                    entry.target_category,
                    entry.binding_key,
                    entry.binding_type,
                };
                if (!overlay_bindings.contains(identity)) {
                    AddDiagnostic(
                        result,
                        WeatherDiagnosticCode::MissingSemanticBinding,
                        profile.profile_id,
                        entry.target_filename,
                        entry.binding_key);
                }
            }
            if (!result.success()) {
                break;
            }
            bindings::DispositionCatalog one_catalog;
            one_catalog.bindings.push_back(catalog_by_profile.at(profile.profile_id));
            const auto source_audit = audit::AuditLegacyPresets(input_preset_root, one_catalog);
            const auto metadata = ReadBundleMetadata(input_bundle / "bundle.csv");
            const auto overlay_sha256 = bindings::Sha256(overlay_bytes);
            const auto preset_tree_sha256 = source_audit.completed()
                    && source_audit.presets.size() == 1
                ? source_audit.presets.front().tree_sha256
                : std::string{};
            const auto expected_overlay_path = "overlay/" + profile.overlay_file;
            const auto expected_preset_path = "preset/" + profile.preset_directory;
            const auto computed_bundle_sha256 = PairedBundleHash(
                profile,
                overlay_sha256,
                preset_tree_sha256);
            if (!metadata.has_value() || metadata->bundle_id != profile.bundle_id
                || metadata->profile_id != profile.profile_id
                || metadata->overlay_path != expected_overlay_path
                || LowerAscii(metadata->overlay_sha256) != LowerAscii(overlay_sha256)
                || metadata->preset_path != expected_preset_path
                || LowerAscii(metadata->preset_tree_sha256)
                    != LowerAscii(preset_tree_sha256)
                || LowerAscii(metadata->bundle_sha256)
                    != LowerAscii(computed_bundle_sha256)
                || LowerAscii(computed_bundle_sha256)
                    != LowerAscii(profile.input_bundle_sha256)) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InputBundleHashMismatch,
                    profile.profile_id);
                break;
            }

            WeatherBundle bundle;
            bundle.bundle_id = profile.bundle_id;
            bundle.profile_id = profile.profile_id;
            const auto overlay_tint_alpha = OverlayTintAlpha(overlay_bytes);
            if (!overlay_tint_alpha.has_value()) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InvalidWeatherValue,
                    profile.profile_id,
                    profile.overlay_file,
                    "TINT_ALPHA");
                break;
            }
            bundle.overlay_tint_alpha = *overlay_tint_alpha;
            bundle.world_tint_strength = WorldTintStrength(profile);
            bundle.double_tint_budget = bundle.overlay_tint_alpha + bundle.world_tint_strength;
            if (bundle.double_tint_budget > profile.max_double_tint_budget + 1e-9) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::DoubleTintBudgetExceeded,
                    profile.profile_id);
                break;
            }

            std::vector<fs::path> weather_files;
            const auto input_weather = input_preset / "Weathers";
            const auto output_weather = output_preset / "Weathers";
            for (const auto& entry : fs::directory_iterator{input_weather}) {
                if (entry.is_regular_file()
                    && LowerAscii(PathToUtf8(entry.path().extension())) == ".ini") {
                    weather_files.push_back(entry.path());
                }
            }
            std::ranges::sort(weather_files, [](const fs::path& left, const fs::path& right) {
                return PathToUtf8(left.filename()) < PathToUtf8(right.filename());
            });
            if (weather_files.size() != profile.expected_weather_records) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::CoverageMismatch,
                    profile.profile_id);
                break;
            }

            std::map<WeatherFamily, std::size_t> family_counts;
            for (const auto family : AllWeatherFamilies()) {
                family_counts.emplace(family, 0);
            }
            if (!source_audit.completed() || source_audit.presets.size() != 1
                || LowerAscii(source_audit.presets.front().tree_sha256)
                    != LowerAscii(profile.source_tree_sha256)) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::InputSourceTreeMismatch,
                    profile.profile_id);
                break;
            }
            for (const auto& source_path : weather_files) {
                const auto relative = source_path.lexically_relative(input_preset);
                const auto output_path = output_preset / relative;
                const auto source_bytes = ReadFile(source_path);
                const auto document = ParseIni(source_bytes);
                const auto classification_value = WeatherClassificationValue(document);
                if (!classification_value.has_value()) {
                    AddDiagnostic(
                        result,
                        WeatherDiagnosticCode::MissingWeatherField,
                        profile.profile_id,
                        PathToUtf8(relative),
                        "Misc.WeatherClassification");
                    break;
                }
                const auto classification = ClassifyWeather(
                    PathToUtf8(source_path.stem()),
                    *classification_value);
                ++family_counts[classification.family];
                const auto transformed = TransformWeather(
                    source_bytes,
                    profile,
                    classification.family);
                if (!transformed.success) {
                    AddDiagnostic(
                        result,
                        transformed.error,
                        profile.profile_id,
                        PathToUtf8(relative),
                        transformed.key);
                    break;
                }
                WriteFile(output_path, transformed.bytes);
                AddCounts(result.counts, transformed.validation);
                ++result.counts.weather_records;
                ++result.counts.transformed_records;
                result.counts.transformed_fields += transformed.fields;
                result.counts.alpha_values_preserved += transformed.alpha_values;
                ++bundle.weather_records;
                bundle.transformed_fields += transformed.fields;
                bundle.alpha_values_preserved += transformed.alpha_values;
                result.provenance.push_back(WeatherProvenance{
                    profile.profile_id,
                    PathToUtf8(relative),
                    classification.family,
                    classification.basis,
                    bindings::Sha256(source_bytes),
                    bindings::Sha256(transformed.bytes),
                    transformed.fields,
                    transformed.alpha_values,
                    transformed.protected_hash,
                    transformed.source_color_hash,
                    transformed.output_color_hash,
                });
            }
            if (!result.success()) {
                break;
            }
            if (std::ranges::any_of(family_counts, [](const auto& entry) {
                    return entry.second == 0;
                })) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::CoverageMismatch,
                    profile.profile_id);
                break;
            }

            const auto generated_audit = audit::AuditLegacyPresets(output_preset_root, one_catalog);
            if (!source_audit.completed() || !generated_audit.completed()
                || generated_audit.presets.size() != 1) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::GeneratedAuditFailed,
                    profile.profile_id);
                break;
            }
            if (source_audit.counts.record_files != generated_audit.counts.record_files) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::IdentityCountChanged,
                    profile.profile_id);
                break;
            }
            bundle.preset_tree_sha256 = generated_audit.presets.front().tree_sha256;
            const auto output_overlay_sha256 = bindings::Sha256File(
                output_bundle / "overlay" / profile.overlay_file);
            bundle.bundle_sha256 = bindings::Sha256(
                std::string{"ELDER_WEATHER_BUNDLE_V1\n"} + bundle.bundle_id + "\n"
                + bundle.profile_id + "\n" + bundle.preset_tree_sha256 + "\n"
                + output_overlay_sha256 + "\n");
            std::string weather_manifest =
                "bundle_id,profile_id,input_bundle_sha256,source_preset_tree_sha256,"
                "output_preset_tree_sha256,overlay_sha256,weather_records,"
                "transformed_fields,alpha_values_preserved,bundle_sha256\n";
            weather_manifest += CsvField(bundle.bundle_id) + ','
                + CsvField(bundle.profile_id) + ','
                + CsvField(profile.input_bundle_sha256) + ','
                + CsvField(profile.source_tree_sha256) + ','
                + CsvField(bundle.preset_tree_sha256) + ','
                + CsvField(output_overlay_sha256) + ','
                + std::to_string(bundle.weather_records) + ','
                + std::to_string(bundle.transformed_fields) + ','
                + std::to_string(bundle.alpha_values_preserved) + ','
                + CsvField(bundle.bundle_sha256) + '\n';
            WriteFile(output_bundle / "weather-bundle.csv", weather_manifest);
            bundle.bundle_bytes = DirectoryBytes(output_bundle);
            result.bundles.push_back(std::move(bundle));
        }
    } catch (const std::exception&) {
        if (result.success()) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError);
        }
    }

    if (!result.success()) {
        cleanup_workspaces();
        return result;
    }
    result.counts.profiles = result.bundles.size();
    result.counts.semantic_verified = registry.verified_entries();
    result.counts.semantic_unresolved = registry.unresolved_entries();
    std::ranges::sort(result.bundles, [](const WeatherBundle& left, const WeatherBundle& right) {
        return left.bundle_id < right.bundle_id;
    });
    std::ranges::sort(
        result.provenance,
        [](const WeatherProvenance& left, const WeatherProvenance& right) {
            return std::tie(left.profile_id, left.relative_path)
                < std::tie(right.profile_id, right.relative_path);
        });
    if (!MatchesExpectations(controls.expectations, result.counts)) {
        AddDiagnostic(result, WeatherDiagnosticCode::ExpectationMismatch);
        cleanup_workspaces();
        return result;
    }
    try {
        WriteArtifacts(stage, result, inventory.manifest);
        if (improvement::DirectoryTreeHash(snapshot) != source_tree_before) {
            AddDiagnostic(result, WeatherDiagnosticCode::SourceChanged);
        }
        if (result.success() && !cleanup_snapshot()) {
            AddDiagnostic(
                result,
                WeatherDiagnosticCode::IoError,
                {},
                {},
                "SNAPSHOT_CLEANUP");
        }
        if (result.success()) {
            const auto publication = detail::PublishOwnedTree(
                stage,
                output_root,
                transaction_id);
            if (!publication.success || !publication.cleanup_complete) {
                AddDiagnostic(
                    result,
                    WeatherDiagnosticCode::IoError,
                    {},
                    {},
                    publication.committed && !publication.cleanup_complete
                        ? "PUBLICATION_CLEANUP_INCOMPLETE"
                        : "PUBLICATION_FAILED");
            }
        }
    } catch (const std::exception&) {
        AddDiagnostic(result, WeatherDiagnosticCode::IoError);
    }
    if (!result.success()) {
        if (!cleanup_stage()) {
            AddDiagnostic(result, WeatherDiagnosticCode::IoError, {}, {}, "STAGE_CLEANUP");
        }
        if (fs::exists(snapshot_owner) && !cleanup_snapshot()) {
            AddDiagnostic(
                result,
                WeatherDiagnosticCode::IoError,
                {},
                {},
                "SNAPSHOT_CLEANUP");
        }
    }
    return result;
}

bool HasDiagnostic(
    const WeatherCompileResult& result,
    const WeatherDiagnosticCode code) noexcept {
    return std::ranges::any_of(result.diagnostics, [code](const WeatherDiagnostic& diagnostic) {
        return diagnostic.code == code;
    });
}

bool HasDiagnostic(
    const SemanticVerificationResult& result,
    const WeatherDiagnosticCode code) noexcept {
    return std::ranges::any_of(result.diagnostics, [code](const WeatherDiagnostic& diagnostic) {
        return diagnostic.code == code;
    });
}

std::string_view ToString(const WeatherFamily family) noexcept {
    switch (family) {
        case WeatherFamily::Clear: return "CLEAR";
        case WeatherFamily::Cloudy: return "CLOUDY";
        case WeatherFamily::Fog: return "FOG";
        case WeatherFamily::Rain: return "RAIN";
        case WeatherFamily::Snow: return "SNOW";
        case WeatherFamily::Storm: return "STORM";
    }
    return "UNKNOWN";
}

std::string_view ToString(const WeatherTime time) noexcept {
    switch (time) {
        case WeatherTime::Sunrise: return "SUNRISE";
        case WeatherTime::Day: return "DAY";
        case WeatherTime::Sunset: return "SUNSET";
        case WeatherTime::Night: return "NIGHT";
    }
    return "UNKNOWN";
}

std::string_view ToString(const SemanticEvidence evidence) noexcept {
    switch (evidence) {
        case SemanticEvidence::VerifiedExternalEvidence:
            return "VERIFIED_EXTERNAL_EVIDENCE";
        case SemanticEvidence::UnresolvedStaleBinding: return "UNRESOLVED_STALE_BINDING";
    }
    return "UNKNOWN";
}

std::string_view ToString(const WeatherDiagnosticCode code) noexcept {
    switch (code) {
        case WeatherDiagnosticCode::InvalidConfig: return "INVALID_CONFIG";
        case WeatherDiagnosticCode::InvalidSemanticRegistry:
            return "INVALID_SEMANTIC_REGISTRY";
        case WeatherDiagnosticCode::UnsafeOutputPath: return "UNSAFE_OUTPUT_PATH";
        case WeatherDiagnosticCode::MissingInputBundle: return "MISSING_INPUT_BUNDLE";
        case WeatherDiagnosticCode::InputBundleHashMismatch:
            return "INPUT_BUNDLE_HASH_MISMATCH";
        case WeatherDiagnosticCode::InputSourceTreeMismatch:
            return "INPUT_SOURCE_TREE_MISMATCH";
        case WeatherDiagnosticCode::InputTreeMismatch: return "INPUT_TREE_MISMATCH";
        case WeatherDiagnosticCode::CoverageMismatch: return "COVERAGE_MISMATCH";
        case WeatherDiagnosticCode::MissingWeatherField: return "MISSING_WEATHER_FIELD";
        case WeatherDiagnosticCode::DuplicateWeatherField: return "DUPLICATE_WEATHER_FIELD";
        case WeatherDiagnosticCode::InvalidWeatherValue: return "INVALID_WEATHER_VALUE";
        case WeatherDiagnosticCode::InvariantViolation: return "INVARIANT_VIOLATION";
        case WeatherDiagnosticCode::DoubleTintBudgetExceeded:
            return "DOUBLE_TINT_BUDGET_EXCEEDED";
        case WeatherDiagnosticCode::MissingSemanticBinding:
            return "MISSING_SEMANTIC_BINDING";
        case WeatherDiagnosticCode::ShaderSourceHashMismatch:
            return "SHADER_SOURCE_HASH_MISMATCH";
        case WeatherDiagnosticCode::ShaderDeclarationMismatch:
            return "SHADER_DECLARATION_MISMATCH";
        case WeatherDiagnosticCode::ShaderUseMismatch: return "SHADER_USE_MISMATCH";
        case WeatherDiagnosticCode::GeneratedAuditFailed: return "GENERATED_AUDIT_FAILED";
        case WeatherDiagnosticCode::IdentityCountChanged: return "IDENTITY_COUNT_CHANGED";
        case WeatherDiagnosticCode::SourceChanged: return "SOURCE_CHANGED";
        case WeatherDiagnosticCode::ExpectationMismatch: return "EXPECTATION_MISMATCH";
        case WeatherDiagnosticCode::IoError: return "IO_ERROR";
    }
    return "UNKNOWN";
}

WeatherThemeConfig LoadWeatherThemeConfig(const fs::path& path) {
    WeatherThemeConfig config;
    constexpr std::array<std::string_view, 20> expected_header{
        "record_type",
        "bundle_id",
        "profile_id",
        "preset_directory",
        "overlay_file",
        "input_bundle_sha256",
        "source_tree_sha256",
        "expected_weather_records",
        "expected_cloud_layers",
        "max_double_tint_budget",
        "scope",
        "exposure_ev",
        "chroma",
        "tint_r",
        "tint_g",
        "tint_b",
        "blend",
        "min_luminance",
        "max_luminance",
        "rationale",
    };
    const auto invalid = [&config](
                             const std::string& profile = {},
                             const std::string& key = {}) {
        config.diagnostics.push_back(
            {WeatherDiagnosticCode::InvalidConfig, profile, {}, key});
    };
    const auto parse_family = [](const std::string_view value)
        -> std::optional<WeatherFamily> {
        for (const auto family : AllWeatherFamilies()) {
            if (value == ToString(family)) {
                return family;
            }
        }
        return std::nullopt;
    };
    const auto parse_time = [](const std::string_view value)
        -> std::optional<WeatherTime> {
        for (const auto time : AllWeatherTimes()) {
            if (value == ToString(time)) {
                return time;
            }
        }
        return std::nullopt;
    };
    const auto parse_axis = [](const std::vector<std::string>& fields)
        -> std::optional<ThemeAxis> {
        const auto exposure = ParseDouble(fields[11]);
        const auto chroma = ParseDouble(fields[12]);
        const auto tint_red = ParseDouble(fields[13]);
        const auto tint_green = ParseDouble(fields[14]);
        const auto tint_blue = ParseDouble(fields[15]);
        const auto blend = ParseDouble(fields[16]);
        const auto minimum = ParseDouble(fields[17]);
        const auto maximum = ParseDouble(fields[18]);
        if (!exposure.has_value() || !chroma.has_value() || !tint_red.has_value()
            || !tint_green.has_value() || !tint_blue.has_value()
            || !blend.has_value() || !minimum.has_value() || !maximum.has_value()
            || *exposure < -4.0 || *exposure > 4.0 || *chroma < 0.0
            || *chroma > 4.0 || *tint_red <= 0.0 || *tint_red > 2.0
            || *tint_green <= 0.0 || *tint_green > 2.0 || *tint_blue <= 0.0
            || *tint_blue > 2.0 || *blend < 0.0 || *blend > 1.0
            || *minimum < 0.0 || *minimum > 1.0 || *maximum < 0.0
            || *maximum > 1.0 || *minimum > *maximum || fields[19].empty()) {
            return std::nullopt;
        }
        return ThemeAxis{
            *exposure,
            *chroma,
            {*tint_red, *tint_green, *tint_blue},
            *blend,
            *minimum,
            *maximum,
            fields[19],
        };
    };

    try {
        std::ifstream input{path, std::ios::binary};
        std::string line;
        if (!input || !std::getline(input, line)) {
            invalid({}, "HEADER");
            return config;
        }
        bool valid = false;
        const auto header = ParseCsvRow(line, valid);
        if (!valid || header.size() != expected_header.size()
            || !std::ranges::equal(header, expected_header)) {
            invalid({}, "HEADER");
            return config;
        }

        std::map<std::string, std::size_t> profile_indices;
        std::size_t line_number = 1;
        while (std::getline(input, line)) {
            ++line_number;
            if (Trim(line).empty()) {
                continue;
            }
            const auto fields = ParseCsvRow(line, valid);
            const auto key = "LINE_" + std::to_string(line_number);
            if (!valid || fields.size() != expected_header.size()) {
                invalid({}, key);
                continue;
            }
            const auto weather_records = ParseCount(fields[7]);
            const auto cloud_layers = ParseCount(fields[8]);
            const auto tint_budget = ParseDouble(fields[9]);
            const auto axis = parse_axis(fields);
            if (fields[0].empty() || fields[1].empty() || fields[2].empty()
                || !IsSafeRelativePath(fields[1])
                || !IsSafeRelativePath(fields[3]) || !IsSafeRelativePath(fields[4])
                || !IsSha256(fields[5]) || !IsSha256(fields[6])
                || !weather_records.has_value() || *weather_records == 0
                || !cloud_layers.has_value() || *cloud_layers == 0
                || !tint_budget.has_value() || *tint_budget < 0.0
                || *tint_budget > 4.0 || !axis.has_value()) {
                invalid(fields[2], key);
                continue;
            }

            if (fields[0] == "PROFILE") {
                if (fields[10] != "BASE" || profile_indices.contains(fields[2])) {
                    invalid(fields[2], key);
                    continue;
                }
                WeatherProfileTheme profile;
                profile.bundle_id = fields[1];
                profile.profile_id = fields[2];
                profile.preset_directory = fields[3];
                profile.overlay_file = fields[4];
                profile.input_bundle_sha256 = fields[5];
                profile.source_tree_sha256 = fields[6];
                profile.expected_weather_records = *weather_records;
                profile.expected_cloud_layers = *cloud_layers;
                profile.max_double_tint_budget = *tint_budget;
                profile.base = *axis;
                profile_indices.emplace(profile.profile_id, config.profiles.size());
                config.profiles.push_back(std::move(profile));
                continue;
            }

            const auto found = profile_indices.find(fields[2]);
            if (found == profile_indices.end()) {
                invalid(fields[2], key);
                continue;
            }
            auto& profile = config.profiles[found->second];
            if (profile.bundle_id != fields[1]
                || profile.preset_directory != fields[3]
                || profile.overlay_file != fields[4]
                || LowerAscii(profile.input_bundle_sha256) != LowerAscii(fields[5])
                || LowerAscii(profile.source_tree_sha256) != LowerAscii(fields[6])
                || profile.expected_weather_records != *weather_records
                || profile.expected_cloud_layers != *cloud_layers
                || profile.max_double_tint_budget != *tint_budget) {
                invalid(fields[2], key);
                continue;
            }
            if (fields[0] == "FAMILY") {
                const auto family = parse_family(fields[10]);
                if (!family.has_value() || !profile.families.emplace(*family, *axis).second) {
                    invalid(fields[2], key);
                }
            } else if (fields[0] == "TIME") {
                const auto time = parse_time(fields[10]);
                if (!time.has_value() || !profile.times.emplace(*time, *axis).second) {
                    invalid(fields[2], key);
                }
            } else {
                invalid(fields[2], key);
            }
        }
        if (!input.eof()) {
            invalid({}, "READ");
        }
    } catch (const std::exception&) {
        invalid({}, "READ");
    }
    if (config.profiles.empty()) {
        invalid({}, "NO_PROFILES");
    }
    for (const auto& profile : config.profiles) {
        if (profile.families.size() != AllWeatherFamilies().size()
            || profile.times.size() != AllWeatherTimes().size()) {
            invalid(profile.profile_id, "INCOMPLETE_AXES");
        }
    }
    return config;
}

ShaderSemanticRegistry LoadShaderSemanticRegistry(const fs::path& path) {
    ShaderSemanticRegistry registry;
    constexpr std::array<std::string_view, 19> expected_header{
        "target_filename",
        "target_category",
        "binding_key",
        "binding_type",
        "evidence_id",
        "declaration_artifact_id",
        "declaration_artifact_sha256",
        "declaration_span_sha256",
        "declaration_span_bytes",
        "declaration_context_sha256",
        "use_artifact_id",
        "use_artifact_sha256",
        "use_span_sha256",
        "use_span_bytes",
        "use_context_sha256",
        "semantic_paraphrase",
        "evidence",
        "uncertainty",
        "required_profiles",
    };
    const auto invalid = [&registry](const std::string& key = {}) {
        registry.diagnostics.push_back(
            {WeatherDiagnosticCode::InvalidSemanticRegistry, {}, {}, key});
    };
    try {
        std::ifstream input{path, std::ios::binary};
        std::string line;
        if (!input || !std::getline(input, line)) {
            invalid("HEADER");
            return registry;
        }
        bool valid = false;
        const auto header = ParseCsvRow(line, valid);
        if (!valid || header.size() != expected_header.size()
            || !std::ranges::equal(header, expected_header)) {
            invalid("HEADER");
            return registry;
        }
        std::set<std::tuple<std::string, std::string, std::string, std::string>> seen;
        std::size_t line_number = 1;
        while (std::getline(input, line)) {
            ++line_number;
            if (Trim(line).empty()) {
                continue;
            }
            const auto fields = ParseCsvRow(line, valid);
            const auto line_key = "LINE_" + std::to_string(line_number);
            if (!valid || fields.size() != expected_header.size()) {
                invalid(line_key);
                continue;
            }
            std::optional<SemanticEvidence> evidence;
            if (fields[16] == "VERIFIED_EXTERNAL_EVIDENCE") {
                evidence = SemanticEvidence::VerifiedExternalEvidence;
            } else if (fields[16] == "UNRESOLVED_STALE_BINDING") {
                evidence = SemanticEvidence::UnresolvedStaleBinding;
            }
            const auto identity = std::tuple{fields[0], fields[1], fields[2], fields[3]};
            const bool common_valid = !fields[0].empty() && !fields[1].empty()
                && !fields[2].empty() && IsBindingType(fields[3])
                && IsOpaqueId(fields[4]) && !fields[15].empty()
                && evidence.has_value() && seen.insert(identity).second;
            const auto declaration_bytes = ParseCount(fields[8]);
            const auto use_bytes = ParseCount(fields[13]);
            const auto required_profiles = ParseRequiredProfiles(fields[18]);
            const bool verified_valid = evidence.has_value()
                && *evidence == SemanticEvidence::VerifiedExternalEvidence
                && IsOpaqueId(fields[5]) && IsSha256(fields[6])
                && IsSha256(fields[7]) && declaration_bytes.has_value()
                && *declaration_bytes > 0 && IsSha256(fields[9])
                && IsOpaqueId(fields[10]) && IsSha256(fields[11])
                && IsSha256(fields[12]) && use_bytes.has_value() && *use_bytes > 0
                && IsSha256(fields[14]);
            const bool unresolved_valid = evidence.has_value()
                && *evidence == SemanticEvidence::UnresolvedStaleBinding
                && !fields[17].empty()
                && std::ranges::all_of(
                    fields.begin() + 5,
                    fields.begin() + 15,
                    [](const std::string& value) { return value.empty(); });
            if (!common_valid || !required_profiles.has_value()
                || (!verified_valid && !unresolved_valid)) {
                invalid(line_key);
                continue;
            }
            registry.entries.push_back(ShaderSemanticEntry{
                fields[0],
                fields[1],
                fields[2],
                fields[3],
                fields[4],
                fields[5],
                fields[6],
                fields[7],
                declaration_bytes.value_or(0),
                fields[9],
                fields[10],
                fields[11],
                fields[12],
                use_bytes.value_or(0),
                fields[14],
                fields[15],
                *evidence,
                fields[17],
                *required_profiles,
            });
        }
        if (!input.eof()) {
            invalid("READ");
        }
    } catch (const std::exception&) {
        invalid("READ");
    }
    if (registry.entries.empty()) {
        invalid("NO_ENTRIES");
    }
    return registry;
}

}  // namespace elder::weather
