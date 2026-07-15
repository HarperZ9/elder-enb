#include "elder/audit/LegacyPresetAudit.hpp"
#include "elder/bindings/LegacyKreateBindings.hpp"
#include "elder/improvement/ProfileBundleCompiler.hpp"
#include "elder/weather/WeatherThemeCompiler.hpp"
#include "elder/weather/detail/OwnedOutputTransaction.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <map>
#include <source_location>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#endif

namespace {

namespace fs = std::filesystem;
using elder::bindings::BindingDisposition;
using elder::bindings::DispositionCatalog;
using elder::bindings::Sha256;
using elder::bindings::Sha256File;
using namespace elder::weather;

class AssertionFailure final : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

void Check(
    const bool condition,
    const std::string_view expression,
    const std::source_location location = std::source_location::current()) {
    if (!condition) {
        throw AssertionFailure(
            std::string{location.file_name()} + ":" + std::to_string(location.line())
            + ": check failed: " + std::string{expression});
    }
}

#define CHECK(expression) Check(static_cast<bool>(expression), #expression)

void WriteBytes(const fs::path& path, const std::string_view bytes) {
    fs::create_directories(path.parent_path());
    std::ofstream output{path, std::ios::binary | std::ios::trunc};
    if (!output) {
        throw std::runtime_error("cannot write weather fixture");
    }
    output.write(bytes.data(), static_cast<std::streamsize>(bytes.size()));
}

[[nodiscard]] std::string ReadBytes(const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("cannot read weather fixture");
    }
    return {std::istreambuf_iterator<char>{input}, std::istreambuf_iterator<char>{}};
}

[[nodiscard]] std::string Csv(const std::string_view value) {
    std::string output{"\""};
    for (const char character : value) {
        output += character == '"' ? "\"\"" : std::string(1, character);
    }
    output += '"';
    return output;
}

[[nodiscard]] ThemeAxis Axis(
    const double exposure,
    const double chroma,
    const std::array<double, 3> tint,
    const double blend,
    const double minimum,
    const double maximum) {
    return ThemeAxis{exposure, chroma, tint, blend, minimum, maximum};
}

[[nodiscard]] std::string WeatherBytes(const int classification, const bool complete = true) {
    constexpr std::array<std::string_view, 4> times{"Sunrise", "Day", "Sunset", "Night"};
    std::string bytes =
        "ID = 0x123\n"
        "Optional = true\n"
        "[DirAmbient]\n"
        "Enable = true\n";
    for (const std::string_view base : {"Top", "Middle", "Bottom"}) {
        for (const auto time : times) {
            bytes += std::string{base} + std::string{time}
                + (time == "Night" ? " = 0.02, 0.03, 0.05\n"
                                    : " = 0.35, 0.45, 0.60\n");
        }
    }
    bytes += "[Clouds]\n";
    for (int layer = 0; layer < 2; ++layer) {
        bytes += "Layer" + std::to_string(layer) + "Enabled = true\n";
        bytes += "Layer" + std::to_string(layer) + "Texture = cloud.dds\n";
        for (const auto time : times) {
            bytes += "Layer" + std::to_string(layer) + "Color" + std::string{time}
                + (time == "Night" ? " = 0.02, 0.03, 0.05, 0.73\n"
                                    : " = 0.55, 0.62, 0.70, 1.25\n");
        }
    }
    bytes += "[Fog]\nDayNear = 100\nDayFar = 10000\nNightNear = 100\nNightFar = 9000\n";
    bytes += "[Colors]\n";
    const std::vector<std::string_view> bases{
        "SkyUpper", "SkyLower", "Horizon", "FogNear", "FogFar", "Sunlight",
        "Ambient", "CloudLodDiffuse", "CloudLodAmbient"};
    for (const auto base : bases) {
        for (const auto time : times) {
            if (!complete && base == "SkyUpper" && time == "Sunrise") {
                continue;
            }
            std::string value = time == "Night"
                ? "0.015, 0.025, 0.045"
                : (base == "CloudLodDiffuse" ? "0.54, 0.61, 0.69" : "0.32, 0.46, 0.64");
            bytes += std::string{base} + std::string{time} + " = " + value + "\n";
        }
    }
    for (const auto time : times) {
        bytes += "EffectLighting" + std::string{time} + " = 0.8, 0.7, 0.6\n";
        bytes += "WaterMultiplier" + std::string{time} + " = 0.2, 0.3, 0.4\n";
    }
    bytes += "[Precipitation]\nID = 0xDEADBEEF\nBeginFadeIn = 100\nEndFadeOut = 400\n";
    bytes += "[Misc]\nWeatherClassification = " + std::to_string(classification)
        + "\nVolumetricLightingIDDay = 0xBEEF\nImageSpaceIDDay = 0xCAFE\n";
    return bytes;
}

struct Fixture {
    fs::path root;
    fs::path input;
    fs::path output;
    fs::path shader_root;
    WeatherThemeConfig config;
    ShaderSemanticRegistry registry;
    DispositionCatalog catalog;

    Fixture() {
        static std::atomic<unsigned long long> sequence{0};
        root = fs::temp_directory_path()
            / ("elder-weather-test-"
               + std::to_string(std::chrono::steady_clock::now().time_since_epoch().count())
               + "-" + std::to_string(sequence.fetch_add(1)));
        input = root / "input";
        output = root / "output";
        shader_root = root / "shaders";
    }

    ~Fixture() {
        std::error_code ignored;
        fs::remove_all(root, ignored);
    }

    void RefreshBundleMetadata(const std::size_t index = 0) {
        auto& profile = config.profiles.at(index);
        auto& binding = catalog.bindings.at(index);
        const auto profile_root = input / "profiles" / profile.bundle_id;
        const auto overlay_path = profile_root / "overlay" / profile.overlay_file;
        DispositionCatalog one_catalog;
        one_catalog.bindings.push_back(binding);
        one_catalog.bindings.front().selected_overlay_sha256 = Sha256File(overlay_path);
        const auto audit = elder::audit::AuditLegacyPresets(
            profile_root / "preset",
            one_catalog);
        if (!audit.completed() || audit.presets.size() != 1) {
            throw std::runtime_error("cannot refresh synthetic bundle guard");
        }
        binding.selected_overlay_sha256 = Sha256File(overlay_path);
        binding.preset_info_sha256 = Sha256File(
            profile_root / "preset" / profile.preset_directory / "PresetInfo.ini");
        profile.source_tree_sha256 = audit.presets.front().tree_sha256;
        const auto overlay_sha256 = Sha256File(overlay_path);
        const auto bundle_sha256 = Sha256(
            std::string{"ELDER_PAIRED_BUNDLE_V1\n"}
            + profile.bundle_id + "\n" + profile.profile_id + "\n"
            + profile.overlay_file + "\n" + overlay_sha256 + "\n"
            + profile.preset_directory + "\n" + profile.source_tree_sha256 + "\n");
        profile.input_bundle_sha256 = bundle_sha256;
        WriteBytes(
            profile_root / "bundle.csv",
            "bundle_id,profile_id,overlay_path,overlay_sha256,preset_path,"
            "preset_tree_sha256,bundle_sha256\n"
            + profile.bundle_id + ',' + profile.profile_id + ",overlay/"
            + profile.overlay_file + ',' + overlay_sha256 + ",preset/"
            + profile.preset_directory + ',' + profile.source_tree_sha256 + ','
            + bundle_sha256 + "\n");
    }

    [[nodiscard]] fs::path WriteSemanticSidecar() const {
        const auto source = ReadBytes(shader_root / "enbeffect.fx");
        const std::string declaration = "float4 Day_CGTint";
        const std::string use = "use(Day_CGTint)";
        const auto declaration_offset = source.find(declaration);
        const auto use_offset = source.find(use);
        if (declaration_offset == std::string::npos || use_offset == std::string::npos) {
            throw std::runtime_error("cannot locate synthetic semantic spans");
        }
        const auto sidecar = root / "protected-semantic-evidence.csv";
        WriteBytes(
            sidecar,
            "evidence_id,role,artifact_id,source_path,span_offset,raw_span\n"
            + Csv("elder-semantic-evidence-001") + ',' + Csv("declaration") + ','
            + Csv("artifact-01") + ',' + Csv("enbeffect.fx") + ','
            + Csv(std::to_string(declaration_offset)) + ',' + Csv(declaration) + "\n"
            + Csv("elder-semantic-evidence-001") + ',' + Csv("use") + ','
            + Csv("artifact-01") + ',' + Csv("enbeffect.fx") + ','
            + Csv(std::to_string(use_offset)) + ',' + Csv(use) + "\n");
        return sidecar;
    }

    void Populate(const bool complete = true) {
        WriteBytes(input / "bundle-index.csv", "synthetic bundle index\n");
        WriteBytes(input / "provenance.csv", "synthetic provenance\n");
        WriteBytes(input / "report.txt", "synthetic report\n");
        const auto profile_root = input / "profiles" / "elder.alpha.weather";
        WriteBytes(
            profile_root / "overlay" / "Alpha.ini",
            "[OVERLAYINFO]\nUIName = STYLE - Alpha\n"
            "[OVERLAYPARAM1]\nCategory = ENBEFFECT.FX\n"
            "Name = CG.HDR.|- Day - Tint\nOperation = \"= 0.52, 0.50, 0.48, 0.08\"\n");
        WriteBytes(
            profile_root / "preset" / "Alpha" / "PresetInfo.ini",
            "Optional=true\nConfigVersion=1.3.0\nPresetVersion=1.0.0\n"
            "Author=synthetic\nDescription=\n");
        const std::array<std::pair<std::string_view, int>, 6> weathers{{
            {"ClearWeather.ini", 1},
            {"CloudyWeather.ini", 2},
            {"DenseFog.ini", 2},
            {"RainWeather.ini", 3},
            {"SnowWeather.ini", 4},
            {"ThunderStorm.ini", 3},
        }};
        for (const auto& [name, classification] : weathers) {
            WriteBytes(
                profile_root / "preset" / "Alpha" / "Weathers" / name,
                WeatherBytes(classification, complete));
        }
        WeatherProfileTheme profile;
        profile.bundle_id = "elder.alpha.weather";
        profile.profile_id = "Alpha";
        profile.preset_directory = "Alpha";
        profile.overlay_file = "Alpha.ini";
        profile.input_bundle_sha256 = std::string(64, 'a');
        profile.source_tree_sha256 = std::string(64, 'b');
        profile.expected_weather_records = 6;
        profile.expected_cloud_layers = 2;
        profile.max_double_tint_budget = 0.35;
        profile.base = Axis(0.0, 1.0, {1.0, 1.0, 1.0}, 0.40, 0.0, 0.98);
        for (const auto family : AllWeatherFamilies()) {
            profile.families.emplace(
                family,
                Axis(-0.01 * static_cast<int>(family), 0.98, {0.99, 1.0, 1.01}, 1.0, 0.0, 0.98));
        }
        profile.times.emplace(
            WeatherTime::Sunrise,
            Axis(-0.08, 1.02, {1.04, 1.0, 0.94}, 1.0, 0.07, 0.90));
        profile.times.emplace(
            WeatherTime::Day,
            Axis(0.0, 1.0, {1.0, 1.0, 1.0}, 1.0, 0.10, 0.96));
        profile.times.emplace(
            WeatherTime::Sunset,
            Axis(-0.10, 1.03, {1.05, 1.0, 0.92}, 1.0, 0.06, 0.90));
        profile.times.emplace(
            WeatherTime::Night,
            Axis(-0.10, 0.90, {0.94, 1.0, 1.08}, 1.0, 0.015, 0.35));
        config.profiles.push_back(profile);

        const std::string shader_source = "float4 Day_CGTint;\nuse(Day_CGTint);\n";
        const std::string declaration_span = "float4 Day_CGTint";
        const std::string use_span = "use(Day_CGTint)";
        WriteBytes(shader_root / "enbeffect.fx", shader_source);
        registry.entries.push_back(ShaderSemanticEntry{
            "ENBEFFECT.FX",
            "CG.HDR.",
            "- Day - Tint",
            "SET_VECTOR4",
            "elder-semantic-evidence-001",
            "artifact-01",
            Sha256(shader_source),
            Sha256(declaration_span),
            declaration_span.size(),
            Sha256(shader_source),
            "artifact-01",
            Sha256(shader_source),
            Sha256(use_span),
            use_span.size(),
            Sha256(shader_source),
            "The day tint control enters the project color response.",
            SemanticEvidence::VerifiedExternalEvidence,
            {},
            {"Alpha"},
        });
        catalog.bindings.push_back(BindingDisposition{
            "Alpha",
            "Alpha.ini",
            Sha256File(profile_root / "overlay" / "Alpha.ini"),
            "Alpha",
            Sha256File(profile_root / "preset" / "Alpha" / "PresetInfo.ini"),
        });
        const auto source_audit = elder::audit::AuditLegacyPresets(
            profile_root / "preset",
            catalog);
        if (!source_audit.completed() || source_audit.presets.size() != 1) {
            throw std::runtime_error("cannot establish synthetic source guard");
        }
        RefreshBundleMetadata();
    }

    void AddSecondProfile(const bool contains_required_binding) {
        const auto source = input / "profiles" / "elder.alpha.weather" / "preset"
            / "Alpha";
        const auto destination = input / "profiles" / "elder.beta.weather" / "preset"
            / "Beta";
        std::error_code error;
        fs::create_directories(destination.parent_path(), error);
        if (error) {
            throw std::runtime_error("cannot create second synthetic profile root");
        }
        fs::copy(
            source,
            destination,
            fs::copy_options::recursive,
            error);
        if (error) {
            throw std::runtime_error("cannot copy second synthetic profile");
        }
        const auto overlay = contains_required_binding
            ? "[OVERLAYINFO]\nUIName = STYLE - Beta\n"
              "[OVERLAYPARAM1]\nCategory = ENBEFFECT.FX\n"
              "Name = CG.HDR.|- Day - Tint\n"
              "Operation = \"= 0.50, 0.50, 0.50, 0.04\"\n"
            : "[OVERLAYINFO]\nUIName = STYLE - Beta\n"
              "[OVERLAYPARAM1]\nCategory = ENBEFFECT.FX\n"
              "Name = CG.HDR.|- Split Tint\n"
              "Operation = \"= 0.50, 0.50, 0.50, 0.04\"\n";
        WriteBytes(
            input / "profiles" / "elder.beta.weather" / "overlay" / "Beta.ini",
            overlay);

        auto profile = config.profiles.front();
        profile.bundle_id = "elder.beta.weather";
        profile.profile_id = "Beta";
        profile.preset_directory = "Beta";
        profile.overlay_file = "Beta.ini";
        config.profiles.push_back(profile);

        auto binding = catalog.bindings.front();
        binding.canonical_identity = "Beta";
        binding.selected_overlay_file = "Beta.ini";
        binding.preset_directory = "Beta";
        catalog.bindings.push_back(binding);
        RefreshBundleMetadata(1);
    }
};

[[nodiscard]] VerifiedSemanticRegistry Verified(const Fixture& fixture) {
    const auto verification = VerifyShaderSemanticRegistry(
        fixture.registry,
        fixture.shader_root,
        fixture.WriteSemanticSidecar());
    if (!verification.success() || !verification.registry.has_value()) {
        throw std::runtime_error("cannot establish synthetic semantic capability");
    }
    return *verification.registry;
}

void FamilyClassificationUsesRecordEvidenceAndIdentityOverrides() {
    CHECK(ClassifyWeather("SunnyClear", 1).family == WeatherFamily::Clear);
    CHECK(ClassifyWeather("OrdinaryClouds", 2).family == WeatherFamily::Cloudy);
    CHECK(ClassifyWeather("DenseFog", 2).family == WeatherFamily::Fog);
    CHECK(ClassifyWeather("SteadyRain", 3).family == WeatherFamily::Rain);
    CHECK(ClassifyWeather("MountainSnow", 4).family == WeatherFamily::Snow);
    CHECK(ClassifyWeather("SnowThunderStorm", 4).family == WeatherFamily::Storm);
}

void CompleteCoveragePreservesAlphaAndProtectedFields() {
    Fixture fixture;
    fixture.Populate();
    const auto before = ReadBytes(
        fixture.input / "profiles" / "elder.alpha.weather" / "preset" / "Alpha"
        / "Weathers" / "ClearWeather.ini");
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(result.success());
    CHECK(result.counts.weather_records == 6);
    CHECK(result.counts.transformed_records == 6);
    CHECK(result.counts.transformed_fields == 336);
    CHECK(result.counts.alpha_values_preserved == 48);
    CHECK(result.counts.alpha_preservation_violations == 0);
    CHECK(result.counts.protected_value_changes == 0);
    CHECK(result.counts.cloud_sky_separation_checks == 48);
    CHECK(result.provenance.front().relative_path.starts_with("Weathers/"));
    CHECK(!result.provenance.front().relative_path.starts_with("Weathers/Weathers/"));
    CHECK(fs::is_regular_file(
        fixture.output / "profiles" / "elder.alpha.weather" / "preset" / "Alpha"
        / result.provenance.front().relative_path));
    const auto after = ReadBytes(
        fixture.output / "profiles" / "elder.alpha.weather" / "preset" / "Alpha"
        / "Weathers" / "ClearWeather.ini");
    CHECK(after != before);
    CHECK(after.contains(", 1.25"));
    CHECK(after.contains("EffectLightingDay = 0.8, 0.7, 0.6"));
    CHECK(after.contains("WaterMultiplierDay = 0.2, 0.3, 0.4"));
    CHECK(after.contains("ID = 0xDEADBEEF"));
    CHECK(after.contains("VolumetricLightingIDDay = 0xBEEF"));
    CHECK(after.contains("ImageSpaceIDDay = 0xCAFE"));
    const auto bundle_manifest = ReadBytes(
        fixture.output / "profiles" / "elder.alpha.weather" / "weather-bundle.csv");
    CHECK(bundle_manifest.contains("input_bundle_sha256"));
    CHECK(bundle_manifest.contains("output_preset_tree_sha256"));
    CHECK(bundle_manifest.contains(result.bundles.front().bundle_sha256));
}

void ProductionBundleContentAndTrailingRowsFailClosed() {
    {
        Fixture fixture;
        fixture.Populate();
        const auto overlay = fixture.input / "profiles" / "elder.alpha.weather"
            / "overlay" / "Alpha.ini";
        WriteBytes(overlay, ReadBytes(overlay) + "; tampered after bundle creation\n");
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InputBundleHashMismatch));
        CHECK(!fs::exists(fixture.output));
    }
    {
        Fixture fixture;
        fixture.Populate();
        const auto manifest = fixture.input / "profiles" / "elder.alpha.weather"
            / "bundle.csv";
        WriteBytes(manifest, ReadBytes(manifest) + "unexpected,trailing,row\n");
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InputBundleHashMismatch));
        CHECK(!fs::exists(fixture.output));
    }
}

void UnownedOutputAndFixedStagingSentinelsAreNeverDeleted() {
    {
        Fixture fixture;
        fixture.Populate();
        WriteBytes(fixture.output / "sentinel.bin", "unowned-output");
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(ReadBytes(fixture.output / "sentinel.bin") == "unowned-output");
    }
    {
        Fixture fixture;
        fixture.Populate();
        const auto stale = fixture.root / ".output.weather-staging";
        WriteBytes(stale / "sentinel.bin", "unowned-stale-tree");
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(result.success());
        CHECK(ReadBytes(stale / "sentinel.bin") == "unowned-stale-tree");
    }
}

void OwnedOutputCanBeReplacedDeterministically() {
    Fixture fixture;
    fixture.Populate();
    const auto first = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(first.success());
    const auto first_hash = elder::improvement::DirectoryTreeHash(fixture.output);
    const auto marker = fixture.output / ".elder-weather-owner";
    CHECK(ReadBytes(marker) == "ELDER_WEATHER_OWNED_V2\nrole=output\n");
    const auto second = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(second.success());
    CHECK(elder::improvement::DirectoryTreeHash(fixture.output) == first_hash);
    for (const auto& entry : fs::directory_iterator{fixture.root}) {
        const auto name = entry.path().filename().string();
        CHECK(!name.starts_with(".s"));
        CHECK(!name.starts_with(".b"));
    }
}

void RootAncestorDescendantAndEqualOutputsAreRejected() {
    const auto verify_rejected = [](const auto& select_output) {
        Fixture fixture;
        fixture.Populate();
        const auto before = elder::improvement::DirectoryTreeHash(fixture.input);
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            select_output(fixture),
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::UnsafeOutputPath));
        CHECK(elder::improvement::DirectoryTreeHash(fixture.input) == before);
    };
    verify_rejected([](const Fixture& fixture) { return fixture.input; });
    verify_rejected([](const Fixture& fixture) { return fixture.root; });
    verify_rejected([](const Fixture& fixture) { return fixture.input / "descendant"; });
    verify_rejected([](const Fixture& fixture) { return fixture.root.root_path(); });
}

void ReparseAliasedOutputIsRejectedWhenPlatformCanCreateIt() {
    Fixture fixture;
    fixture.Populate();
    const auto alias = fixture.root / "reparse-output";
    std::error_code error;
    fs::create_directory_symlink(fixture.input, alias, error);
    if (error) {
        return;
    }
    const auto before = elder::improvement::DirectoryTreeHash(fixture.input);
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        alias,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::UnsafeOutputPath));
    CHECK(elder::improvement::DirectoryTreeHash(fixture.input) == before);
}

void UnicodeOutputAndExclusiveLockAreSupported() {
    Fixture fixture;
    fixture.Populate();
    const auto output = fixture.root / fs::path{u8"weather-ö-雪"};
    const auto first = CompileWeatherThemeBundles(
        fixture.input,
        output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(first.success());
    CHECK(ReadBytes(output / ".elder-weather-owner")
          == "ELDER_WEATHER_OWNED_V2\nrole=output\n");

    std::vector<fs::path> locks;
    for (const auto& entry : fs::directory_iterator{fixture.root}) {
        const auto native_name = entry.path().filename().generic_u8string();
        const std::string name{
            reinterpret_cast<const char*>(native_name.data()),
            native_name.size(),
        };
        if (name.starts_with(".elder-weather-lock-") && name.ends_with(".lck")) {
            locks.push_back(entry.path());
        }
    }
    CHECK(locks.size() == 1);
#ifdef _WIN32
    const HANDLE held = CreateFileW(
        locks.front().c_str(),
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        nullptr);
    CHECK(held != INVALID_HANDLE_VALUE);
    const auto before = elder::improvement::DirectoryTreeHash(output);
    const auto blocked = CompileWeatherThemeBundles(
        fixture.input,
        output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!blocked.success());
    CHECK(elder::improvement::DirectoryTreeHash(output) == before);
    CHECK(CloseHandle(held) != 0);
#endif
}

void RenameFailureRollsOwnedOutputBack() {
    Fixture fixture;
    const auto stage = fixture.root / "owned-stage";
    const auto output = fixture.root / "owned-output";
    WriteBytes(stage / "new.bin", "new-output");
    WriteBytes(output / "old.bin", "old-output");
    CHECK(elder::weather::detail::WriteOwnershipMarker(
        stage,
        elder::weather::detail::OwnedTreeRole::Stage,
        "rollback-test"));
    CHECK(elder::weather::detail::WriteOwnershipMarker(
        output,
        elder::weather::detail::OwnedTreeRole::Output,
        {}));
    std::size_t rename_calls = 0;
    const auto rename = [&rename_calls](
                            const fs::path& source,
                            const fs::path& target,
                            std::error_code& error) {
        ++rename_calls;
        if (rename_calls == 2) {
            error = std::make_error_code(std::errc::permission_denied);
            return false;
        }
        fs::rename(source, target, error);
        return !error;
    };
    const auto published = elder::weather::detail::PublishOwnedTree(
        stage,
        output,
        "rollback-test",
        rename);
    CHECK(!published.success);
    CHECK(published.rolled_back);
    CHECK(ReadBytes(output / "old.bin") == "old-output");
    CHECK(ReadBytes(stage / "new.bin") == "new-output");
}

void CleanupFailureRollsBackBeforeReportingFailure() {
    Fixture fixture;
    const auto stage = fixture.root / "owned-stage";
    const auto output = fixture.root / "owned-output";
    WriteBytes(stage / "new.bin", "new-output");
    WriteBytes(output / "old.bin", "old-output");
    CHECK(elder::weather::detail::WriteOwnershipMarker(
        stage,
        elder::weather::detail::OwnedTreeRole::Stage,
        "cleanup-rollback-test"));
    CHECK(elder::weather::detail::WriteOwnershipMarker(
        output,
        elder::weather::detail::OwnedTreeRole::Output,
        {}));
    const auto fail_cleanup = [](
                                  const fs::path&,
                                  const elder::weather::detail::OwnedTreeRole,
                                  const std::string_view) {
        return false;
    };
    const auto published = elder::weather::detail::PublishOwnedTree(
        stage,
        output,
        "cleanup-rollback-test",
        {},
        fail_cleanup);
    CHECK(!published.success);
    CHECK(!published.committed);
    CHECK(published.rolled_back);
    CHECK(!published.cleanup_complete);
    CHECK(ReadBytes(output / "old.bin") == "old-output");
    CHECK(ReadBytes(stage / "new.bin") == "new-output");
    CHECK(elder::weather::detail::HasOwnershipMarker(
        stage,
        elder::weather::detail::OwnedTreeRole::Stage,
        "cleanup-rollback-test"));
}

void RollbackImpossibleCleanupFailureNeverReportsSuccess() {
    Fixture fixture;
    const auto stage = fixture.root / "owned-stage";
    const auto output = fixture.root / "owned-output";
    WriteBytes(stage / "new.bin", "new-output");
    WriteBytes(output / "old.bin", "old-output");
    CHECK(elder::weather::detail::WriteOwnershipMarker(
        stage,
        elder::weather::detail::OwnedTreeRole::Stage,
        "cleanup-hard-failure-test"));
    CHECK(elder::weather::detail::WriteOwnershipMarker(
        output,
        elder::weather::detail::OwnedTreeRole::Output,
        {}));
    std::size_t rename_calls = 0;
    const auto fail_rollback_rename = [&rename_calls](
                                          const fs::path& source,
                                          const fs::path& target,
                                          std::error_code& error) {
        ++rename_calls;
        if (rename_calls == 3) {
            error = std::make_error_code(std::errc::permission_denied);
            return false;
        }
        fs::rename(source, target, error);
        return !error;
    };
    const auto fail_cleanup = [](
                                  const fs::path&,
                                  const elder::weather::detail::OwnedTreeRole,
                                  const std::string_view) {
        return false;
    };
    const auto published = elder::weather::detail::PublishOwnedTree(
        stage,
        output,
        "cleanup-hard-failure-test",
        fail_rollback_rename,
        fail_cleanup);
    CHECK(!published.success);
    CHECK(published.committed);
    CHECK(!published.rolled_back);
    CHECK(!published.cleanup_complete);
    CHECK(ReadBytes(output / "new.bin") == "new-output");
    CHECK(!fs::exists(stage));
    CHECK(std::ranges::count_if(
              fs::directory_iterator{fixture.root},
              [](const fs::directory_entry& entry) {
                  return entry.path().filename().string().starts_with(".b");
              })
          == 1);
}

void ScratchCleanupNeverMintsAReplacementOwnershipMarker() {
    Fixture fixture;
    const auto transaction = elder::weather::detail::NewTransactionId();
    const auto scratch = elder::weather::detail::CreateOwnedTree(
        fixture.root,
        "ewf",
        elder::weather::detail::OwnedTreeRole::Scratch,
        transaction);
    CHECK(scratch.has_value());
    WriteBytes(*scratch / "p" / "sentinel.bin", "owned payload");
    WriteBytes(*scratch / ".elder-weather-owner", "tampered marker\n");
    CHECK(!elder::weather::detail::RemoveOwnedTree(
        *scratch,
        elder::weather::detail::OwnedTreeRole::Scratch,
        transaction));
    CHECK(ReadBytes(*scratch / "p" / "sentinel.bin") == "owned payload");

    const auto source_root = fs::path{ELDER_TEST_SOURCE_DIR};
    const auto main_source = ReadBytes(
        source_root / "src" / "tools" / "WeatherThemeCompilerMain.cpp");
    CHECK(main_source.contains("scratch_owner / \"p\""));
    CHECK(!main_source.contains("WriteOwnershipMarker("));
    CHECK(!main_source.contains("ExclusiveOutputLock::Acquire"));
}

void OwnedTemporaryNamesPreserveDeepPathHeadroom() {
    Fixture fixture;
    const std::string transaction(180, 'a');
    const auto tree = elder::weather::detail::CreateOwnedTree(
        fixture.root,
        "ewf",
        elder::weather::detail::OwnedTreeRole::Scratch,
        transaction);
    CHECK(tree.has_value());
    CHECK(tree->filename().native().size() <= 24);
    CHECK(elder::weather::detail::HasOwnershipMarker(
        *tree,
        elder::weather::detail::OwnedTreeRole::Scratch,
        transaction));
    CHECK(elder::weather::detail::RemoveOwnedTree(
        *tree,
        elder::weather::detail::OwnedTreeRole::Scratch,
        transaction));
}

void FullLegacyAndWeatherCompositionSupportsLongestCorpusPath() {
    Fixture fixture;
    fixture.Populate();

    const fs::path weather_relative_root = fs::path{"profiles"}
        / "elder.alpha.weather" / "preset" / "Alpha" / "Weathers";
    std::string long_stem{"x"};
    while ((weather_relative_root / (long_stem + ".ini")).generic_string().size()
           < 143) {
        long_stem += 'x';
    }
    const auto longest_relative = weather_relative_root / (long_stem + ".ini");
    CHECK(longest_relative.generic_string().size() == 143);
    WriteBytes(fixture.input / longest_relative, WeatherBytes(2));
    fixture.config.profiles.front().expected_weather_records = 7;
    fixture.RefreshBundleMetadata();

    const auto short_output_length = (fixture.root / "out").native().size();
    CHECK(short_output_length + 1 < 107);
    const auto long_parent = fixture.root
        / std::string(107 - short_output_length - 1, 'd');
    fs::create_directories(long_parent);
    const auto output = long_parent / "out";
    CHECK(output.native().size() == 107);

    const auto transaction = elder::weather::detail::NewTransactionId();
    const auto scratch = elder::weather::detail::CreateOwnedTree(
        fixture.root,
        "ewf",
        elder::weather::detail::OwnedTreeRole::Scratch,
        transaction);
    CHECK(scratch.has_value());
    const auto legacy_stage = *scratch / ".p.staging";
    std::error_code error;
    fs::copy(
        fixture.input,
        legacy_stage,
        fs::copy_options::recursive,
        error);
    CHECK(!error);
    CHECK(fs::is_regular_file(legacy_stage / longest_relative));
    const auto legacy_payload = *scratch / "p";
    fs::rename(legacy_stage, legacy_payload, error);
    CHECK(!error);

    bool outer_scratch_cleaned = false;
    WeatherCompileControls controls;
    controls.phase_observer = [&](const WeatherCompilePhase phase, const fs::path&) {
        if (phase == WeatherCompilePhase::SnapshotVerified) {
            outer_scratch_cleaned = elder::weather::detail::RemoveOwnedTree(
                *scratch,
                elder::weather::detail::OwnedTreeRole::Scratch,
                transaction);
            if (!outer_scratch_cleaned) {
                throw std::runtime_error("cannot clean composed legacy scratch");
            }
        }
    };
    const auto result = CompileWeatherThemeBundles(
        legacy_payload,
        output,
        fixture.config,
        Verified(fixture),
        fixture.catalog,
        controls);
    CHECK(result.success());
    CHECK(result.counts.weather_records == 7);
    CHECK(outer_scratch_cleaned);
    CHECK(!fs::exists(*scratch));
    CHECK(fs::is_regular_file(output / longest_relative));
    const auto first_hash = elder::improvement::DirectoryTreeHash(output);
    const auto replacement = CompileWeatherThemeBundles(
        fixture.input,
        output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(replacement.success());
    CHECK(elder::improvement::DirectoryTreeHash(output) == first_hash);
    for (const auto& entry : fs::directory_iterator{long_parent}) {
        const auto name = entry.path().filename().string();
        CHECK(!name.starts_with(".b"));
        CHECK(!name.starts_with(".i"));
        CHECK(!name.starts_with(".s"));
    }
}

void SnapshotCopyExceptionIsDiagnosedAndCleaned() {
    Fixture fixture;
    fixture.Populate();
    WeatherCompileControls controls;
    controls.phase_observer = [](const WeatherCompilePhase phase, const fs::path& snapshot) {
        if (phase == WeatherCompilePhase::SnapshotCreated) {
            fs::create_directories(snapshot / "bundle-index.csv");
        }
    };
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog,
        controls);
    CHECK(!result.success());
    CHECK(std::ranges::any_of(result.diagnostics, [](const WeatherDiagnostic& diagnostic) {
        return diagnostic.code == WeatherDiagnosticCode::IoError
            && diagnostic.key == "SNAPSHOT_COPY";
    }));
    CHECK(!fs::exists(fixture.output));
    for (const auto& entry : fs::directory_iterator{fixture.root}) {
        CHECK(!entry.path().filename().string().starts_with(".i"));
    }
}

void SourceHashExceptionIsDiagnosedWithoutCreatingWorkspaces() {
#ifdef _WIN32
    Fixture fixture;
    fixture.Populate();
    const auto source = fixture.input / "bundle-index.csv";
    const HANDLE held = CreateFileW(
        source.c_str(),
        GENERIC_READ,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        nullptr);
    CHECK(held != INVALID_HANDLE_VALUE);
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(std::ranges::any_of(result.diagnostics, [](const WeatherDiagnostic& diagnostic) {
        return diagnostic.code == WeatherDiagnosticCode::IoError
            && diagnostic.key == "SOURCE_HASH";
    }));
    CHECK(!fs::exists(fixture.output));
    for (const auto& entry : fs::directory_iterator{fixture.root}) {
        CHECK(!entry.path().filename().string().starts_with(".i"));
        CHECK(!entry.path().filename().string().starts_with(".s"));
    }
    CHECK(CloseHandle(held) != 0);
#endif
}

void CaseAliasedInputOutputIsRejectedWithoutSourceMutation() {
#ifdef _WIN32
    Fixture fixture;
    fixture.Populate();
    const auto source_guard = elder::improvement::DirectoryTreeHash(fixture.input);
    const auto alias = fixture.input.parent_path() / "INPUT";
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        alias,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::UnsafeOutputPath));
    CHECK(elder::improvement::DirectoryTreeHash(fixture.input) == source_guard);
#endif
}

void ExactTargetSetPreservesLookalikes() {
    Fixture fixture;
    fixture.Populate();
    const auto weather = fixture.input / "profiles" / "elder.alpha.weather" / "preset"
        / "Alpha" / "Weathers" / "ClearWeather.ini";
    auto bytes = ReadBytes(weather);
    const auto marker = bytes.find("[Precipitation]");
    CHECK(marker != std::string::npos);
    bytes.insert(marker, "SkyUpperLookalikeDay = opaque-project-value\n");
    WriteBytes(weather, bytes);
    fixture.RefreshBundleMetadata();
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(result.success());
    const auto generated = ReadBytes(
        fixture.output / "profiles" / "elder.alpha.weather" / "preset" / "Alpha"
        / "Weathers" / "ClearWeather.ini");
    CHECK(generated.contains("SkyUpperLookalikeDay = opaque-project-value"));
}

void EveryAuthoredCloudLayerReceivesAlphaAwareContrastValidation() {
    Fixture fixture;
    fixture.Populate();
    const auto weather = fixture.input / "profiles" / "elder.alpha.weather" / "preset"
        / "Alpha" / "Weathers" / "ClearWeather.ini";
    auto bytes = ReadBytes(weather);
    const std::string old_value = "Layer0ColorDay = 0.55, 0.62, 0.70, 1.25";
    const auto found = bytes.find(old_value);
    CHECK(found != std::string::npos);
    bytes.replace(found, old_value.size(), "Layer0ColorDay = 0.05, 0.06, 0.07, 1.25");
    WriteBytes(weather, bytes);
    fixture.RefreshBundleMetadata();
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(result.success());
    CHECK(result.counts.cloud_sky_separation_checks == 48);
    const auto generated = ReadBytes(
        fixture.output / "profiles" / "elder.alpha.weather" / "preset" / "Alpha"
        / "Weathers" / "ClearWeather.ini");
    CHECK(generated.find("Layer0ColorDay = 0.05, 0.06, 0.07, 1.25")
          == std::string::npos);
}

void InvalidAuthoredCloudAlphaFailsClosed() {
    Fixture fixture;
    fixture.Populate();
    const auto weather = fixture.input / "profiles" / "elder.alpha.weather" / "preset"
        / "Alpha" / "Weathers" / "ClearWeather.ini";
    auto bytes = ReadBytes(weather);
    const auto found = bytes.find(", 1.25");
    CHECK(found != std::string::npos);
    bytes.replace(found, 6, ", -0.1");
    WriteBytes(weather, bytes);
    fixture.RefreshBundleMetadata();
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InvalidWeatherValue));
    CHECK(!fs::exists(fixture.output));
}

void TintBudgetParsingIsOrderIndependentAndComposesAllTints() {
    {
        Fixture fixture;
        fixture.Populate();
        const auto overlay = fixture.input / "profiles" / "elder.alpha.weather"
            / "overlay" / "Alpha.ini";
        WriteBytes(
            overlay,
            "[OVERLAYINFO]\nUIName = STYLE - Alpha\n"
            "[OVERLAYPARAM1]\nCategory = ENBEFFECT.FX\n"
            "Operation = \"= 0.52, 0.50, 0.48, 0.08\"\n"
            "Name = CG.HDR.|- Day - Tint\n");
        fixture.RefreshBundleMetadata();
        fixture.config.profiles.front().max_double_tint_budget = 0.05;
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::DoubleTintBudgetExceeded));
    }
    {
        Fixture fixture;
        fixture.Populate();
        const auto overlay = fixture.input / "profiles" / "elder.alpha.weather"
            / "overlay" / "Alpha.ini";
        WriteBytes(
            overlay,
            "[OVERLAYPARAM1]\nCategory = ENBEFFECT.FX\n"
            "Name = CG.HDR.|- Day - Tint\n"
            "Operation = \"= 0.52, 0.50, 0.48, 0.04\"\n"
            "[OVERLAYPARAM2]\nCategory = ENBEFFECT.FX\n"
            "Name = CG.LDR.|- Day - Tint\n"
            "Operation = \"= 0.48, 0.50, 0.54, 0.04\"\n");
        fixture.RefreshBundleMetadata();
        fixture.config.profiles.front().max_double_tint_budget = 0.10;
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::DoubleTintBudgetExceeded));
    }
    {
        Fixture fixture;
        fixture.Populate();
        const auto overlay = fixture.input / "profiles" / "elder.alpha.weather"
            / "overlay" / "Alpha.ini";
        WriteBytes(
            overlay,
            "[OVERLAYPARAM1]\nCategory = ENBEFFECT.FX\n"
            "Name = CG.HDR.|- Day - Tint\n"
            "Operation = \"= 0.52, 0.50, 0.48, 0.06\"\n"
            "[OVERLAYPARAM2]\nCategory = ENBEFFECT.FX\n"
            "Name = CG.HDR.|- Night - Tint\n"
            "Operation = \"= 0.48, 0.50, 0.54, 0.06\"\n");
        fixture.RefreshBundleMetadata();
        fixture.config.profiles.front().max_double_tint_budget = 0.11;
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(result.success());
    }
}

void InvalidOverlayTintAlphaFailsClosed() {
    Fixture fixture;
    fixture.Populate();
    const auto overlay = fixture.input / "profiles" / "elder.alpha.weather"
        / "overlay" / "Alpha.ini";
    auto bytes = ReadBytes(overlay);
    const auto found = bytes.find("0.08");
    CHECK(found != std::string::npos);
    bytes.replace(found, 4, "-0.1");
    WriteBytes(overlay, bytes);
    fixture.RefreshBundleMetadata();
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InvalidWeatherValue));
    CHECK(!fs::exists(fixture.output));
}

void TrackedSemanticRegistryDoesNotLeakRecoveredSourceDetails() {
    const fs::path source_root{ELDER_TEST_SOURCE_DIR};
    const auto bytes = ReadBytes(source_root / "config" / "shader-semantic-registry.csv");
    for (const std::string_view forbidden : {
             "Core_FX/",
             "UI_Headers/",
             "UIAdapt_",
             "UIDay_",
             "SEPARATE_VAR",
             "TOD7(",
             "ExtSep7(",
             "DNI_SEPARATION",
             "p.Intensity",
             "OUT.",
         }) {
        CHECK(!bytes.contains(forbidden));
    }
}

void SemanticVerificationProducesAnOpaqueCompileCapability() {
    static_assert(!std::is_default_constructible_v<VerifiedSemanticRegistry>);
    Fixture fixture;
    fixture.Populate();
    const auto structural = VerifyShaderSemanticRegistry(fixture.registry);
    CHECK(structural.success());
    CHECK(!structural.registry.has_value());
    const auto verification = VerifyShaderSemanticRegistry(
        fixture.registry,
        fixture.shader_root,
        fixture.WriteSemanticSidecar());
    CHECK(verification.success());
    CHECK(verification.registry.has_value());
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        *verification.registry,
        fixture.catalog);
    CHECK(result.success());
}

void ProtectedSemanticSidecarRejectsSpanAndCountTampering() {
    {
        Fixture fixture;
        fixture.Populate();
        const auto sidecar = fixture.WriteSemanticSidecar();
        auto bytes = ReadBytes(sidecar);
        const auto span = bytes.find("float4 Day_CGTint");
        CHECK(span != std::string::npos);
        bytes.replace(span, 1, "x");
        WriteBytes(sidecar, bytes);
        const auto result = VerifyShaderSemanticRegistry(
            fixture.registry,
            fixture.shader_root,
            sidecar);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::ShaderDeclarationMismatch));
        CHECK(!result.registry.has_value());
    }
    {
        Fixture fixture;
        fixture.Populate();
        const auto sidecar = fixture.WriteSemanticSidecar();
        auto bytes = ReadBytes(sidecar);
        const auto header_end = bytes.find('\n');
        const auto declaration_end = bytes.find('\n', header_end + 1);
        CHECK(header_end != std::string::npos);
        CHECK(declaration_end != std::string::npos);
        bytes.resize(declaration_end + 1);
        WriteBytes(sidecar, bytes);
        const auto result = VerifyShaderSemanticRegistry(
            fixture.registry,
            fixture.shader_root,
            sidecar);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InvalidSemanticRegistry));
        CHECK(!result.registry.has_value());
    }
    {
        Fixture fixture;
        fixture.Populate();
        const auto sidecar = fixture.WriteSemanticSidecar();
        auto bytes = ReadBytes(sidecar);
        bytes += Csv("elder-semantic-evidence-999") + ',' + Csv("use") + ','
            + Csv("artifact-99") + ',' + Csv("enbeffect.fx") + ",0,"
            + Csv("unexpected") + "\n";
        WriteBytes(sidecar, bytes);
        const auto result = VerifyShaderSemanticRegistry(
            fixture.registry,
            fixture.shader_root,
            sidecar);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InvalidSemanticRegistry));
        CHECK(!result.registry.has_value());
    }
}

void TemporalSpatialAndRangeValidatorsAreZeroViolation() {
    Fixture fixture;
    fixture.Populate();
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(result.success());
    CHECK(result.counts.non_finite_values == 0);
    CHECK(result.counts.range_violations == 0);
    CHECK(result.counts.temporal_order_violations == 0);
    CHECK(result.counts.fog_horizon_violations == 0);
    CHECK(result.counts.cloud_sky_separation_violations == 0);
    CHECK(result.counts.unreadable_night_violations == 0);
    CHECK(result.counts.snow_clip_violations == 0);
}

void MissingTargetFieldFailsClosedWithoutPublication() {
    Fixture fixture;
    fixture.Populate(false);
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::MissingWeatherField));
    CHECK(!fs::exists(fixture.output));
}

void CrossLayerDoubleTintBudgetFailsClosed() {
    Fixture fixture;
    fixture.Populate();
    fixture.config.profiles.front().max_double_tint_budget = 0.05;
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::DoubleTintBudgetExceeded));
}

void ResolvedThemeAxesFailClosedBeforeFilesystemMutation() {
    Fixture fixture;
    fixture.Populate();
    fixture.config.profiles.front().base.min_luminance = 0.90;
    fixture.config.profiles.front().families.at(WeatherFamily::Clear).max_luminance = 0.80;
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InvalidConfig));
    CHECK(!fs::exists(fixture.output));
}

void DerivedTemporalIntervalsAndCloudHeadroomFailClosed() {
    {
        Fixture fixture;
        fixture.Populate();
        fixture.config.profiles.front().times.at(WeatherTime::Day).max_luminance = 0.20;
        auto& night = fixture.config.profiles.front().times.at(WeatherTime::Night);
        night.min_luminance = 0.30;
        night.max_luminance = 0.35;
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InvalidConfig));
        CHECK(!fs::exists(fixture.output));
    }
    {
        Fixture fixture;
        fixture.Populate();
        auto& day = fixture.config.profiles.front().times.at(WeatherTime::Day);
        day.min_luminance = 0.10;
        day.max_luminance = 0.12;
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InvalidConfig));
        CHECK(!fs::exists(fixture.output));
    }
}

void ProfileSourceTreeGuardFailsClosed() {
    Fixture fixture;
    fixture.Populate();
    fixture.config.profiles.front().source_tree_sha256 = std::string(64, 'c');
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InputSourceTreeMismatch));
    CHECK(!fs::exists(fixture.output));
}

void SemanticRegistryVerifiesHashDeclarationAndUse() {
    Fixture fixture;
    fixture.Populate();
    const auto structural = VerifyShaderSemanticRegistry(fixture.registry);
    CHECK(structural.success());
    CHECK(!structural.registry.has_value());
    const auto sidecar = fixture.WriteSemanticSidecar();
    const auto verified = VerifyShaderSemanticRegistry(
        fixture.registry,
        fixture.shader_root,
        sidecar);
    CHECK(verified.success());
    CHECK(verified.verified_entries == 1);
    CHECK(verified.unresolved_entries == 0);

    WriteBytes(fixture.shader_root / "enbeffect.fx", "float changed;\n");
    const auto changed = VerifyShaderSemanticRegistry(
        fixture.registry,
        fixture.shader_root,
        sidecar);
    CHECK(!changed.success());
    CHECK(HasDiagnostic(changed, WeatherDiagnosticCode::ShaderSourceHashMismatch));

    WriteBytes(fixture.shader_root / "enbeffect.fx", "float4 Day_CGTint;\nuse(Day_CGTint);\n");
    fixture.registry.entries.front().declaration_context_sha256 = std::string(64, 'c');
    const auto context_mismatch = VerifyShaderSemanticRegistry(
        fixture.registry,
        fixture.shader_root,
        sidecar);
    CHECK(!context_mismatch.success());
    CHECK(HasDiagnostic(
        context_mismatch,
        WeatherDiagnosticCode::ShaderDeclarationMismatch));
}

void ExpectationsAreCheckedBeforeAbsentOrExistingOutputPublication() {
    {
        Fixture fixture;
        fixture.Populate();
        WeatherCompileControls controls;
        controls.expectations.profiles = 2;
        const auto mismatch = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog,
            controls);
        CHECK(!mismatch.success());
        CHECK(HasDiagnostic(mismatch, WeatherDiagnosticCode::ExpectationMismatch));
        CHECK(!fs::exists(fixture.output));
    }
    {
        Fixture fixture;
        fixture.Populate();
        const auto published = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(published.success());
        const auto before = elder::improvement::DirectoryTreeHash(fixture.output);
        WeatherCompileControls controls;
        controls.expectations.transformed_fields = published.counts.transformed_fields + 1;
        const auto mismatch = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog,
            controls);
        CHECK(!mismatch.success());
        CHECK(HasDiagnostic(mismatch, WeatherDiagnosticCode::ExpectationMismatch));
        CHECK(elder::improvement::DirectoryTreeHash(fixture.output) == before);
    }
}

void ExactBundleSetAndFullTreeAllowlistRejectExtraPayload() {
    {
        Fixture fixture;
        fixture.Populate();
        WriteBytes(
            fixture.input / "profiles" / "elder.unlisted.weather" / "payload.bin",
            "unlisted bundle");
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InputTreeMismatch));
        CHECK(!fs::exists(fixture.output));
    }
    {
        Fixture fixture;
        fixture.Populate();
        WriteBytes(
            fixture.input / "profiles" / "elder.alpha.weather" / "extra.bin",
            "unlisted payload");
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(!result.success());
        CHECK(HasDiagnostic(result, WeatherDiagnosticCode::InputTreeMismatch));
        CHECK(!fs::exists(fixture.output));
    }
    {
        Fixture fixture;
        fixture.Populate();
        const auto result = CompileWeatherThemeBundles(
            fixture.input,
            fixture.output,
            fixture.config,
            Verified(fixture),
            fixture.catalog);
        CHECK(result.success());
        const auto manifest = ReadBytes(fixture.output / "input-tree-manifest.csv");
        CHECK(manifest.starts_with("relative_path,file_bytes,file_sha256\n"));
        CHECK(manifest.contains("profiles/elder.alpha.weather/bundle.csv"));
        CHECK(manifest.contains("profiles/elder.alpha.weather/overlay/Alpha.ini"));
        CHECK(!manifest.contains(fixture.root.string()));
    }
}

void RequiredSemanticTuplesAreEnforcedPerProfile() {
    Fixture fixture;
    fixture.Populate();
    fixture.AddSecondProfile(false);
    fixture.registry.entries.front().required_profiles = {"Alpha", "Beta"};
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::MissingSemanticBinding));
    CHECK(std::ranges::any_of(
        result.diagnostics,
        [](const WeatherDiagnostic& diagnostic) {
            return diagnostic.code == WeatherDiagnosticCode::MissingSemanticBinding
                && diagnostic.profile_id == "Beta";
        }));
    CHECK(!fs::exists(fixture.output));
}

void OwnedSnapshotIsTheOnlyValidationAndTransformSource() {
    Fixture fixture;
    fixture.Populate();
    const auto source_weather = fixture.input / "profiles" / "elder.alpha.weather"
        / "preset" / "Alpha" / "Weathers" / "ClearWeather.ini";
    const auto original = ReadBytes(source_weather);
    auto changed = original;
    const auto target = changed.find("0.32, 0.46, 0.64");
    CHECK(target != std::string::npos);
    changed.replace(target, std::string_view{"0.32, 0.46, 0.64"}.size(), "0.10, 0.20, 0.30");

    WeatherCompileControls controls;
    controls.phase_observer = [&](
                                  const WeatherCompilePhase phase,
                                  const fs::path&) {
        if (phase == WeatherCompilePhase::SnapshotVerified) {
            WriteBytes(source_weather, changed);
        }
    };
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog,
        controls);
    CHECK(result.success());
    CHECK(ReadBytes(source_weather) == changed);

    Fixture reference;
    reference.Populate();
    const auto reference_result = CompileWeatherThemeBundles(
        reference.input,
        reference.output,
        reference.config,
        Verified(reference),
        reference.catalog);
    CHECK(reference_result.success());
    CHECK(ReadBytes(
              fixture.output / "profiles" / "elder.alpha.weather" / "preset"
              / "Alpha" / "Weathers" / "ClearWeather.ini")
          == ReadBytes(
              reference.output / "profiles" / "elder.alpha.weather" / "preset"
              / "Alpha" / "Weathers" / "ClearWeather.ini"));
}

void SnapshotMutationIsDetectedBeforePublication() {
    Fixture fixture;
    fixture.Populate();
    WeatherCompileControls controls;
    controls.phase_observer = [](const WeatherCompilePhase phase, const fs::path& snapshot) {
        if (phase == WeatherCompilePhase::SnapshotVerified) {
            WriteBytes(snapshot / "report.txt", "mutated snapshot\n");
        }
    };
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog,
        controls);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::SourceChanged));
    CHECK(!fs::exists(fixture.output));
}

void SemanticRegistryMustResolveAgainstCompiledOverlayBindings() {
    Fixture fixture;
    fixture.Populate();
    fixture.registry.entries.front().binding_key = "- Missing Tint";
    const auto result = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output,
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, WeatherDiagnosticCode::MissingSemanticBinding));
    CHECK(!fs::exists(fixture.output));
}

void SemanticCoverageRetainsExplicitResidualUncertainty() {
    Fixture fixture;
    fixture.Populate();
    auto unresolved = fixture.registry.entries.front();
    unresolved.evidence_id = "elder-semantic-evidence-002";
    unresolved.binding_key = "- Intensity";
    unresolved.declaration_artifact_id.clear();
    unresolved.declaration_artifact_sha256.clear();
    unresolved.declaration_span_sha256.clear();
    unresolved.declaration_span_bytes = 0;
    unresolved.declaration_context_sha256.clear();
    unresolved.use_artifact_id.clear();
    unresolved.use_artifact_sha256.clear();
    unresolved.use_span_sha256.clear();
    unresolved.use_span_bytes = 0;
    unresolved.use_context_sha256.clear();
    unresolved.evidence = SemanticEvidence::UnresolvedStaleBinding;
    unresolved.semantic_paraphrase = "No source-backed meaning is assigned.";
    unresolved.uncertainty = "No independently verified scalar binding exists.";
    fixture.registry.entries.push_back(unresolved);
    const auto verified = VerifyShaderSemanticRegistry(fixture.registry);
    CHECK(verified.success());
    CHECK(verified.verified_entries == 1);
    CHECK(verified.unresolved_entries == 1);
}

void IndependentOutputsAreByteDeterministic() {
    Fixture fixture;
    fixture.Populate();
    const auto first = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output / "a",
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    const auto second = CompileWeatherThemeBundles(
        fixture.input,
        fixture.output / "b",
        fixture.config,
        Verified(fixture),
        fixture.catalog);
    CHECK(first.success());
    CHECK(second.success());
    CHECK(first.bundles == second.bundles);
    CHECK(first.provenance == second.provenance);
    CHECK(elder::improvement::DirectoryTreeHash(fixture.output / "a")
          == elder::improvement::DirectoryTreeHash(fixture.output / "b"));
}

void StableDiagnosticCodesArePublished() {
    CHECK(ToString(WeatherDiagnosticCode::MissingWeatherField) == "MISSING_WEATHER_FIELD");
    CHECK(ToString(WeatherDiagnosticCode::CoverageMismatch) == "COVERAGE_MISMATCH");
    CHECK(ToString(WeatherDiagnosticCode::InvariantViolation) == "INVARIANT_VIOLATION");
    CHECK(ToString(WeatherDiagnosticCode::DoubleTintBudgetExceeded)
          == "DOUBLE_TINT_BUDGET_EXCEEDED");
    CHECK(ToString(WeatherDiagnosticCode::ShaderSourceHashMismatch)
          == "SHADER_SOURCE_HASH_MISMATCH");
    CHECK(ToString(WeatherDiagnosticCode::InputSourceTreeMismatch)
          == "INPUT_SOURCE_TREE_MISMATCH");
    CHECK(ToString(WeatherDiagnosticCode::InputTreeMismatch) == "INPUT_TREE_MISMATCH");
    CHECK(ToString(WeatherDiagnosticCode::ExpectationMismatch) == "EXPECTATION_MISMATCH");
}

void TrackedThemeConfigLoadsCompleteProfileFamilyAndTimeAxes() {
    Fixture fixture;
    const auto config_path = fixture.root / "weather-themes.csv";
    std::string bytes =
        "record_type,bundle_id,profile_id,preset_directory,overlay_file,"
        "input_bundle_sha256,source_tree_sha256,expected_weather_records,"
        "expected_cloud_layers,max_double_tint_budget,scope,exposure_ev,chroma,"
        "tint_r,tint_g,tint_b,blend,min_luminance,max_luminance,rationale\n";
    const auto append_axis = [&bytes](
                                 const std::string_view type,
                                 const std::string_view scope,
                                 const std::string_view rationale) {
        bytes += std::string{type}
            + ",elder.alpha.weather,Alpha,Alpha,Alpha.ini,"
              "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,"
              "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,"
              "6,2,0.35," + std::string{scope}
            + ",0.0,1.0,1.0,1.0,1.0,0.4,0.01,0.96," + std::string{rationale}
            + "\n";
    };
    append_axis("PROFILE", "BASE", "profile intent");
    for (const auto family : AllWeatherFamilies()) {
        append_axis("FAMILY", ToString(family), "family intent");
    }
    for (const auto time : AllWeatherTimes()) {
        append_axis("TIME", ToString(time), "time intent");
    }
    WriteBytes(config_path, bytes);

    const auto config = LoadWeatherThemeConfig(config_path);
    CHECK(config.diagnostics.empty());
    CHECK(config.profiles.size() == 1);
    CHECK(config.profiles.front().families.size() == 6);
    CHECK(config.profiles.front().times.size() == 4);
    CHECK(config.profiles.front().base.rationale == "profile intent");
    CHECK(config.profiles.front().families.at(WeatherFamily::Storm).rationale
          == "family intent");
    CHECK(config.profiles.front().times.at(WeatherTime::Night).rationale
          == "time intent");
}

void TrackedRegistriesFailClosedOnIncompleteOrMalformedRows() {
    Fixture fixture;
    const auto theme_path = fixture.root / "incomplete-theme.csv";
    WriteBytes(
        theme_path,
        "record_type,bundle_id,profile_id,preset_directory,overlay_file,"
        "input_bundle_sha256,source_tree_sha256,expected_weather_records,"
        "expected_cloud_layers,max_double_tint_budget,scope,exposure_ev,chroma,"
        "tint_r,tint_g,tint_b,blend,min_luminance,max_luminance,rationale\n"
        "PROFILE,elder.alpha.weather,Alpha,Alpha,Alpha.ini,"
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,"
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,"
        "6,2,0.35,BASE,0,1,1,1,1,0.4,0.01,0.96,intent\n");
    const auto incomplete = LoadWeatherThemeConfig(theme_path);
    CHECK(!incomplete.diagnostics.empty());
    CHECK(incomplete.diagnostics.front().code == WeatherDiagnosticCode::InvalidConfig);

    const auto registry_path = fixture.root / "semantic-registry.csv";
    WriteBytes(
        registry_path,
        "target_filename,target_category,binding_key,binding_type,evidence_id,"
        "declaration_artifact_id,declaration_artifact_sha256,"
        "declaration_span_sha256,declaration_span_bytes,"
        "declaration_context_sha256,use_artifact_id,use_artifact_sha256,"
        "use_span_sha256,use_span_bytes,use_context_sha256,semantic_paraphrase,"
        "evidence,uncertainty,required_profiles\n"
        "ENBEFFECT.FX,CG.HDR.,- Day - Tint,SET_VECTOR4,"
        "elder-semantic-evidence-001,artifact-01,not-a-hash,"
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,17,"
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,"
        "artifact-01,aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,"
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,16,"
        "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,"
        "Day tint enters project color response,VERIFIED_EXTERNAL_EVIDENCE,,Alpha\n");
    const auto malformed = LoadShaderSemanticRegistry(registry_path);
    CHECK(!malformed.diagnostics.empty());
    CHECK(malformed.diagnostics.front().code
          == WeatherDiagnosticCode::InvalidSemanticRegistry);
}

void TrackedSemanticRegistryLoadsVerifiedAndExplicitlyUnresolvedEvidence() {
    Fixture fixture;
    const auto registry_path = fixture.root / "semantic-registry.csv";
    WriteBytes(
        registry_path,
        "target_filename,target_category,binding_key,binding_type,evidence_id,"
        "declaration_artifact_id,declaration_artifact_sha256,"
        "declaration_span_sha256,declaration_span_bytes,"
        "declaration_context_sha256,use_artifact_id,use_artifact_sha256,"
        "use_span_sha256,use_span_bytes,use_context_sha256,semantic_paraphrase,"
        "evidence,uncertainty,required_profiles\n"
        "ENBEFFECT.FX,CG.HDR.,- Day - Tint,SET_VECTOR4,"
        "elder-semantic-evidence-001,artifact-01,"
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,"
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,17,"
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc,"
        "artifact-01,aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,"
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd,16,"
        "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee,"
        "Day tint enters project color response,VERIFIED_EXTERNAL_EVIDENCE,,Alpha\n"
        "ENBEFFECTPOSTPASS.FX,Vignette.,- Intensity,ADD_SCALAR,"
        "elder-semantic-evidence-002,,,,,,,,,,,"
        "No source-backed meaning is assigned,UNRESOLVED_STALE_BINDING,"
        "No independently verified scalar binding exists,Alpha\n");

    const auto registry = LoadShaderSemanticRegistry(registry_path);
    CHECK(registry.diagnostics.empty());
    CHECK(registry.entries.size() == 2);
    CHECK(registry.entries.front().semantic_paraphrase
          == "Day tint enters project color response");
    CHECK(registry.entries.front().use_span_bytes == 16);
    CHECK(registry.entries.back().evidence == SemanticEvidence::UnresolvedStaleBinding);
    CHECK(!registry.entries.back().uncertainty.empty());
    CHECK(registry.entries.front().required_profiles == std::vector<std::string>{"Alpha"});
}

void RepositoryWeatherAndSemanticRegistriesAreComplete() {
    const fs::path source_root{ELDER_TEST_SOURCE_DIR};
    const auto config = LoadWeatherThemeConfig(
        source_root / "config" / "five-profile-weather-themes.csv");
    const auto registry = LoadShaderSemanticRegistry(
        source_root / "config" / "shader-semantic-registry.csv");
    CHECK(config.diagnostics.empty());
    CHECK(config.profiles.size() == 5);
    std::size_t family_axes = 0;
    std::size_t time_axes = 0;
    for (const auto& profile : config.profiles) {
        family_axes += profile.families.size();
        time_axes += profile.times.size();
    }
    CHECK(family_axes == 30);
    CHECK(time_axes == 20);
    CHECK(registry.diagnostics.empty());
    CHECK(registry.entries.size() == 16);
    CHECK(std::ranges::count_if(registry.entries, [](const ShaderSemanticEntry& entry) {
              return entry.evidence == SemanticEvidence::VerifiedExternalEvidence;
          }) == 15);
    CHECK(std::ranges::count_if(registry.entries, [](const ShaderSemanticEntry& entry) {
              return entry.evidence == SemanticEvidence::UnresolvedStaleBinding;
          }) == 1);
}

struct TestCase {
    std::string_view name;
    void (*run)();
};

}  // namespace

int main() {
    const std::vector<TestCase> tests{
        {"family classification uses record evidence and identity overrides",
         FamilyClassificationUsesRecordEvidenceAndIdentityOverrides},
        {"complete coverage preserves alpha and protected fields",
         CompleteCoveragePreservesAlphaAndProtectedFields},
        {"temporal spatial and range validators are zero violation",
         TemporalSpatialAndRangeValidatorsAreZeroViolation},
        {"missing target field fails closed without publication",
         MissingTargetFieldFailsClosedWithoutPublication},
        {"cross-layer double-tint budget fails closed", CrossLayerDoubleTintBudgetFailsClosed},
        {"resolved theme axes fail closed before filesystem mutation",
         ResolvedThemeAxesFailClosedBeforeFilesystemMutation},
        {"derived temporal intervals and cloud headroom fail closed",
         DerivedTemporalIntervalsAndCloudHeadroomFailClosed},
        {"profile source tree guard fails closed", ProfileSourceTreeGuardFailsClosed},
        {"production bundle content and trailing rows fail closed",
         ProductionBundleContentAndTrailingRowsFailClosed},
        {"unowned output and fixed staging sentinels are never deleted",
         UnownedOutputAndFixedStagingSentinelsAreNeverDeleted},
        {"owned output can be replaced deterministically",
         OwnedOutputCanBeReplacedDeterministically},
        {"root ancestor descendant and equal outputs are rejected",
         RootAncestorDescendantAndEqualOutputsAreRejected},
        {"reparse-aliased output is rejected when platform can create it",
         ReparseAliasedOutputIsRejectedWhenPlatformCanCreateIt},
        {"Unicode output and exclusive lock are supported",
         UnicodeOutputAndExclusiveLockAreSupported},
        {"rename failure rolls owned output back", RenameFailureRollsOwnedOutputBack},
        {"cleanup failure rolls back before reporting failure",
         CleanupFailureRollsBackBeforeReportingFailure},
        {"rollback-impossible cleanup failure never reports success",
         RollbackImpossibleCleanupFailureNeverReportsSuccess},
        {"scratch cleanup never mints a replacement ownership marker",
         ScratchCleanupNeverMintsAReplacementOwnershipMarker},
        {"owned temporary names preserve deep path headroom",
         OwnedTemporaryNamesPreserveDeepPathHeadroom},
        {"full legacy and weather composition supports longest corpus path",
         FullLegacyAndWeatherCompositionSupportsLongestCorpusPath},
        {"snapshot copy exception is diagnosed and cleaned",
         SnapshotCopyExceptionIsDiagnosedAndCleaned},
        {"source hash exception is diagnosed without creating workspaces",
         SourceHashExceptionIsDiagnosedWithoutCreatingWorkspaces},
        {"case-aliased input output is rejected without source mutation",
         CaseAliasedInputOutputIsRejectedWithoutSourceMutation},
        {"exact target set preserves lookalikes", ExactTargetSetPreservesLookalikes},
        {"every authored cloud layer receives alpha-aware contrast validation",
         EveryAuthoredCloudLayerReceivesAlphaAwareContrastValidation},
        {"invalid authored cloud alpha fails closed", InvalidAuthoredCloudAlphaFailsClosed},
        {"tint budget parsing is order independent and composes all tints",
         TintBudgetParsingIsOrderIndependentAndComposesAllTints},
        {"invalid overlay tint alpha fails closed", InvalidOverlayTintAlphaFailsClosed},
        {"semantic registry verifies hash declaration and use",
         SemanticRegistryVerifiesHashDeclarationAndUse},
        {"expectations are checked before absent or existing output publication",
         ExpectationsAreCheckedBeforeAbsentOrExistingOutputPublication},
        {"exact bundle set and full tree allowlist reject extra payload",
         ExactBundleSetAndFullTreeAllowlistRejectExtraPayload},
        {"required semantic tuples are enforced per profile",
         RequiredSemanticTuplesAreEnforcedPerProfile},
        {"owned snapshot is the only validation and transform source",
         OwnedSnapshotIsTheOnlyValidationAndTransformSource},
        {"snapshot mutation is detected before publication",
         SnapshotMutationIsDetectedBeforePublication},
        {"semantic registry must resolve against compiled overlay bindings",
         SemanticRegistryMustResolveAgainstCompiledOverlayBindings},
        {"semantic coverage retains explicit residual uncertainty",
         SemanticCoverageRetainsExplicitResidualUncertainty},
        {"independent outputs are byte deterministic", IndependentOutputsAreByteDeterministic},
        {"stable diagnostic codes are published", StableDiagnosticCodesArePublished},
        {"tracked theme config loads complete profile family and time axes",
         TrackedThemeConfigLoadsCompleteProfileFamilyAndTimeAxes},
        {"tracked registries fail closed on incomplete or malformed rows",
         TrackedRegistriesFailClosedOnIncompleteOrMalformedRows},
        {"tracked semantic registry loads verified and explicitly unresolved evidence",
         TrackedSemanticRegistryLoadsVerifiedAndExplicitlyUnresolvedEvidence},
        {"repository weather and semantic registries are complete",
         RepositoryWeatherAndSemanticRegistriesAreComplete},
        {"tracked semantic registry does not leak recovered source details",
         TrackedSemanticRegistryDoesNotLeakRecoveredSourceDetails},
        {"semantic verification produces an opaque compile capability",
         SemanticVerificationProducesAnOpaqueCompileCapability},
        {"protected semantic sidecar rejects span and count tampering",
         ProtectedSemanticSidecarRejectsSpanAndCountTampering},
    };
    std::size_t passed = 0;
    for (const auto& test : tests) {
        try {
            test.run();
            ++passed;
            std::cout << "PASS: " << test.name << '\n';
        } catch (const std::exception& error) {
            std::cerr << "FAIL: " << test.name << "\n  " << error.what() << '\n';
        }
    }
    std::cout << passed << '/' << tests.size() << " weather tests passed\n";
    return passed == tests.size() ? 0 : 1;
}
