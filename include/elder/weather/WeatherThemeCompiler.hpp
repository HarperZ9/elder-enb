#pragma once

#include "elder/bindings/LegacyKreateBindings.hpp"

#include <array>
#include <cstddef>
#include <filesystem>
#include <functional>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace elder::weather {

enum class WeatherFamily {
    Clear,
    Cloudy,
    Fog,
    Rain,
    Snow,
    Storm,
};

enum class WeatherTime {
    Sunrise,
    Day,
    Sunset,
    Night,
};

enum class SemanticEvidence {
    VerifiedExternalEvidence,
    UnresolvedStaleBinding,
};

enum class WeatherDiagnosticCode {
    InvalidConfig,
    InvalidSemanticRegistry,
    UnsafeOutputPath,
    MissingInputBundle,
    InputBundleHashMismatch,
    InputSourceTreeMismatch,
    InputTreeMismatch,
    CoverageMismatch,
    MissingWeatherField,
    DuplicateWeatherField,
    InvalidWeatherValue,
    InvariantViolation,
    DoubleTintBudgetExceeded,
    MissingSemanticBinding,
    ShaderSourceHashMismatch,
    ShaderDeclarationMismatch,
    ShaderUseMismatch,
    GeneratedAuditFailed,
    IdentityCountChanged,
    SourceChanged,
    ExpectationMismatch,
    IoError,
};

struct ThemeAxis {
    double exposure_ev{0.0};
    double chroma{1.0};
    std::array<double, 3> tint{1.0, 1.0, 1.0};
    double blend{1.0};
    double min_luminance{0.0};
    double max_luminance{1.0};
    std::string rationale;

    bool operator==(const ThemeAxis&) const = default;
};

struct WeatherProfileTheme {
    std::string bundle_id;
    std::string profile_id;
    std::string preset_directory;
    std::string overlay_file;
    std::string input_bundle_sha256;
    std::string source_tree_sha256;
    std::size_t expected_weather_records{0};
    std::size_t expected_cloud_layers{0};
    double max_double_tint_budget{0.0};
    ThemeAxis base;
    std::map<WeatherFamily, ThemeAxis> families;
    std::map<WeatherTime, ThemeAxis> times;

    bool operator==(const WeatherProfileTheme&) const = default;
};

struct WeatherDiagnostic {
    WeatherDiagnosticCode code;
    std::string profile_id;
    std::string relative_path;
    std::string key;

    bool operator==(const WeatherDiagnostic&) const = default;
};

struct WeatherThemeConfig {
    std::vector<WeatherProfileTheme> profiles;
    std::vector<WeatherDiagnostic> diagnostics;
};

struct ShaderSemanticEntry {
    std::string target_filename;
    std::string target_category;
    std::string binding_key;
    std::string binding_type;
    std::string evidence_id;
    std::string declaration_artifact_id;
    std::string declaration_artifact_sha256;
    std::string declaration_span_sha256;
    std::size_t declaration_span_bytes{0};
    std::string declaration_context_sha256;
    std::string use_artifact_id;
    std::string use_artifact_sha256;
    std::string use_span_sha256;
    std::size_t use_span_bytes{0};
    std::string use_context_sha256;
    std::string semantic_paraphrase;
    SemanticEvidence evidence{SemanticEvidence::VerifiedExternalEvidence};
    std::string uncertainty;
    std::vector<std::string> required_profiles;

    bool operator==(const ShaderSemanticEntry&) const = default;
};

struct ShaderSemanticRegistry {
    std::vector<ShaderSemanticEntry> entries;
    std::vector<WeatherDiagnostic> diagnostics;
};

struct SemanticVerificationResult;

class VerifiedSemanticRegistry {
public:
    VerifiedSemanticRegistry(const VerifiedSemanticRegistry&) = default;
    VerifiedSemanticRegistry& operator=(const VerifiedSemanticRegistry&) = default;
    VerifiedSemanticRegistry(VerifiedSemanticRegistry&&) noexcept = default;
    VerifiedSemanticRegistry& operator=(VerifiedSemanticRegistry&&) noexcept = default;

    [[nodiscard]] const std::vector<ShaderSemanticEntry>& entries() const noexcept;
    [[nodiscard]] std::size_t verified_entries() const noexcept;
    [[nodiscard]] std::size_t unresolved_entries() const noexcept;

private:
    VerifiedSemanticRegistry(
        std::vector<ShaderSemanticEntry> entries,
        std::size_t verified_entries,
        std::size_t unresolved_entries);

    std::vector<ShaderSemanticEntry> entries_;
    std::size_t verified_entries_{0};
    std::size_t unresolved_entries_{0};

    friend SemanticVerificationResult VerifyShaderSemanticRegistry(
        const ShaderSemanticRegistry& registry);
    friend SemanticVerificationResult VerifyShaderSemanticRegistry(
        const ShaderSemanticRegistry& registry,
        const std::filesystem::path& artifact_root,
        const std::filesystem::path& protected_sidecar);
};

struct SemanticVerificationResult {
    std::size_t verified_entries{0};
    std::size_t unresolved_entries{0};
    std::vector<WeatherDiagnostic> diagnostics;
    std::optional<VerifiedSemanticRegistry> registry;

    [[nodiscard]] bool success() const noexcept;
};

struct WeatherClassification {
    WeatherFamily family{WeatherFamily::Cloudy};
    std::string basis;

    bool operator==(const WeatherClassification&) const = default;
};

struct WeatherProvenance {
    std::string profile_id;
    std::string relative_path;
    WeatherFamily family{WeatherFamily::Cloudy};
    std::string family_basis;
    std::string source_sha256;
    std::string output_sha256;
    std::size_t transformed_fields{0};
    std::size_t alpha_values_preserved{0};
    std::string protected_values_sha256;
    std::string source_colors_sha256;
    std::string output_colors_sha256;

    bool operator==(const WeatherProvenance&) const = default;
};

struct WeatherBundle {
    std::string bundle_id;
    std::string profile_id;
    std::size_t weather_records{0};
    std::size_t transformed_fields{0};
    std::size_t alpha_values_preserved{0};
    double overlay_tint_alpha{0.0};
    double world_tint_strength{0.0};
    double double_tint_budget{0.0};
    std::string preset_tree_sha256;
    std::string bundle_sha256;
    std::uintmax_t bundle_bytes{0};

    bool operator==(const WeatherBundle&) const = default;
};

struct WeatherCompileCounts {
    std::size_t profiles{0};
    std::size_t weather_records{0};
    std::size_t transformed_records{0};
    std::size_t transformed_fields{0};
    std::size_t alpha_values_preserved{0};
    std::size_t alpha_preservation_violations{0};
    std::size_t protected_value_changes{0};
    std::size_t non_finite_values{0};
    std::size_t range_violations{0};
    std::size_t temporal_sequences{0};
    std::size_t temporal_order_violations{0};
    std::size_t fog_horizon_checks{0};
    std::size_t fog_horizon_violations{0};
    std::size_t cloud_sky_separation_checks{0};
    std::size_t cloud_sky_separation_violations{0};
    std::size_t unreadable_night_violations{0};
    std::size_t snow_clip_violations{0};
    std::size_t semantic_verified{0};
    std::size_t semantic_unresolved{0};
};

struct WeatherCompileResult {
    WeatherCompileCounts counts;
    std::vector<WeatherBundle> bundles;
    std::vector<WeatherProvenance> provenance;
    std::vector<WeatherDiagnostic> diagnostics;

    [[nodiscard]] bool success() const noexcept;
};

struct WeatherCompileExpectations {
    std::optional<std::size_t> profiles;
    std::optional<std::size_t> weather_records;
    std::optional<std::size_t> transformed_fields;
    std::optional<std::size_t> semantic_verified;
    std::optional<std::size_t> semantic_unresolved;
};

enum class WeatherCompilePhase {
    SnapshotCreated,
    SnapshotVerified,
};

struct WeatherCompileControls {
    WeatherCompileExpectations expectations;
    std::function<void(WeatherCompilePhase, const std::filesystem::path&)>
        phase_observer;
};

[[nodiscard]] constexpr std::array<WeatherFamily, 6> AllWeatherFamilies() noexcept {
    return {
        WeatherFamily::Clear,
        WeatherFamily::Cloudy,
        WeatherFamily::Fog,
        WeatherFamily::Rain,
        WeatherFamily::Snow,
        WeatherFamily::Storm,
    };
}

[[nodiscard]] constexpr std::array<WeatherTime, 4> AllWeatherTimes() noexcept {
    return {
        WeatherTime::Sunrise,
        WeatherTime::Day,
        WeatherTime::Sunset,
        WeatherTime::Night,
    };
}

[[nodiscard]] WeatherClassification ClassifyWeather(
    std::string_view record_identity,
    int classification);
[[nodiscard]] WeatherThemeConfig LoadWeatherThemeConfig(
    const std::filesystem::path& path);
[[nodiscard]] ShaderSemanticRegistry LoadShaderSemanticRegistry(
    const std::filesystem::path& path);
[[nodiscard]] SemanticVerificationResult VerifyShaderSemanticRegistry(
    const ShaderSemanticRegistry& registry);
[[nodiscard]] SemanticVerificationResult VerifyShaderSemanticRegistry(
    const ShaderSemanticRegistry& registry,
    const std::filesystem::path& artifact_root,
    const std::filesystem::path& protected_sidecar);
[[nodiscard]] WeatherCompileResult CompileWeatherThemeBundles(
    const std::filesystem::path& input_root,
    const std::filesystem::path& output_root,
    const WeatherThemeConfig& config,
    const VerifiedSemanticRegistry& registry,
    const bindings::DispositionCatalog& catalog,
    const WeatherCompileControls& controls = {});
[[nodiscard]] bool HasDiagnostic(
    const WeatherCompileResult& result,
    WeatherDiagnosticCode code) noexcept;
[[nodiscard]] bool HasDiagnostic(
    const SemanticVerificationResult& result,
    WeatherDiagnosticCode code) noexcept;
[[nodiscard]] std::string_view ToString(WeatherFamily family) noexcept;
[[nodiscard]] std::string_view ToString(WeatherTime time) noexcept;
[[nodiscard]] std::string_view ToString(SemanticEvidence evidence) noexcept;
[[nodiscard]] std::string_view ToString(WeatherDiagnosticCode code) noexcept;

}  // namespace elder::weather
