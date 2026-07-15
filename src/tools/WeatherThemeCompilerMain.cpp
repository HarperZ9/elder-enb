#include "elder/bindings/LegacyKreateBindings.hpp"
#include "elder/improvement/ProfileBundleCompiler.hpp"
#include "elder/weather/WeatherThemeCompiler.hpp"
#include "elder/weather/detail/OwnedOutputTransaction.hpp"

#include <charconv>
#include <cstddef>
#include <filesystem>
#include <iostream>
#include <map>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>

namespace {

namespace fs = std::filesystem;

struct Options {
    fs::path overlay_root;
    fs::path preset_root;
    fs::path catalog;
    fs::path improvement_manifest;
    fs::path theme_config;
    fs::path semantic_registry;
    fs::path shader_root;
    fs::path semantic_evidence_sidecar;
    fs::path output_root;
    std::optional<std::size_t> expected_profiles;
    std::optional<std::size_t> expected_weather_records;
    std::optional<std::size_t> expected_fields;
    std::optional<std::size_t> expected_semantic_verified;
    std::optional<std::size_t> expected_semantic_unresolved;
};

[[nodiscard]] std::optional<std::size_t> ParseCount(const std::string_view value) {
    std::size_t count = 0;
    const auto conversion = std::from_chars(
        value.data(),
        value.data() + value.size(),
        count);
    if (conversion.ec != std::errc{}
        || conversion.ptr != value.data() + value.size()) {
        return std::nullopt;
    }
    return count;
}

[[nodiscard]] bool ParseExpected(
    const std::string_view value,
    std::optional<std::size_t>& target) {
    target = ParseCount(value);
    return target.has_value();
}

[[nodiscard]] bool ParseArguments(
    const int argument_count,
    char* arguments[],
    Options& options) {
    for (int index = 1; index < argument_count; ++index) {
        if (index + 1 >= argument_count) {
            return false;
        }
        const std::string_view name{arguments[index]};
        const std::string value{arguments[++index]};
        if (name == "--overlay-root") {
            options.overlay_root = value;
        } else if (name == "--preset-root") {
            options.preset_root = value;
        } else if (name == "--catalog") {
            options.catalog = value;
        } else if (name == "--improvement-manifest") {
            options.improvement_manifest = value;
        } else if (name == "--theme-config") {
            options.theme_config = value;
        } else if (name == "--semantic-registry") {
            options.semantic_registry = value;
        } else if (name == "--shader-root") {
            options.shader_root = value;
        } else if (name == "--semantic-evidence-sidecar") {
            options.semantic_evidence_sidecar = value;
        } else if (name == "--output-root") {
            options.output_root = value;
        } else if (name == "--expect-profiles") {
            if (!ParseExpected(value, options.expected_profiles)) {
                return false;
            }
        } else if (name == "--expect-weather-records") {
            if (!ParseExpected(value, options.expected_weather_records)) {
                return false;
            }
        } else if (name == "--expect-fields") {
            if (!ParseExpected(value, options.expected_fields)) {
                return false;
            }
        } else if (name == "--expect-semantic-verified") {
            if (!ParseExpected(value, options.expected_semantic_verified)) {
                return false;
            }
        } else if (name == "--expect-semantic-unresolved") {
            if (!ParseExpected(value, options.expected_semantic_unresolved)) {
                return false;
            }
        } else {
            return false;
        }
    }
    return !options.overlay_root.empty() && !options.preset_root.empty()
        && !options.catalog.empty() && !options.improvement_manifest.empty()
        && !options.theme_config.empty() && !options.semantic_registry.empty()
        && !options.output_root.empty()
        && (options.shader_root.empty() == options.semantic_evidence_sidecar.empty());
}

void PrintUsage() {
    std::cerr
        << "usage: elder_weather_theme_compiler --overlay-root PATH "
           "--preset-root PATH --catalog FILE --improvement-manifest FILE "
           "--theme-config FILE --semantic-registry FILE "
           "[--shader-root PATH --semantic-evidence-sidecar FILE] "
           "--output-root PATH [--expect-profiles N] "
           "[--expect-weather-records N] [--expect-fields N] "
           "[--expect-semantic-verified N] [--expect-semantic-unresolved N]\n";
}

[[nodiscard]] bool Matches(
    const std::optional<std::size_t>& expected,
    const std::size_t actual) {
    return !expected.has_value() || *expected == actual;
}

}  // namespace

int main(const int argument_count, char* arguments[]) {
    Options options;
    if (!ParseArguments(argument_count, arguments, options)) {
        PrintUsage();
        return 2;
    }

    const auto catalog = elder::bindings::LoadDispositionCatalog(options.catalog);
    const auto manifest = elder::improvement::LoadImprovementManifest(
        options.improvement_manifest);
    const auto themes = elder::weather::LoadWeatherThemeConfig(options.theme_config);
    const auto registry = elder::weather::LoadShaderSemanticRegistry(
        options.semantic_registry);
    if (!catalog.diagnostics.empty() || !manifest.diagnostics.empty()
        || !themes.diagnostics.empty() || !registry.diagnostics.empty()) {
        std::cerr << "INVALID_MANIFEST\n";
        return 2;
    }

    const auto semantic = options.shader_root.empty()
        ? elder::weather::VerifyShaderSemanticRegistry(registry)
        : elder::weather::VerifyShaderSemanticRegistry(
              registry,
              options.shader_root,
              options.semantic_evidence_sidecar);
    for (const auto& diagnostic : semantic.diagnostics) {
        std::cerr << elder::weather::ToString(diagnostic.code) << ' '
                  << diagnostic.relative_path << ' ' << diagnostic.key << '\n';
    }
    if (!semantic.success()) {
        return 3;
    }
    if (!Matches(options.expected_semantic_verified, semantic.verified_entries)
        || !Matches(options.expected_semantic_unresolved, semantic.unresolved_entries)) {
        std::cerr << "EXPECTATION_MISMATCH\n";
        return 6;
    }
    if (options.shader_root.empty()) {
        if (options.expected_profiles.has_value()
            || options.expected_weather_records.has_value()
            || options.expected_fields.has_value()) {
            std::cerr << "EXPECTATION_REQUIRES_PROTECTED_EVIDENCE\n";
            return 6;
        }
        std::cout << "mode=structural-only semantic_verified="
                  << semantic.verified_entries << " semantic_unresolved="
                  << semantic.unresolved_entries << " output=not-published\n";
        return 0;
    }
    if (!semantic.registry.has_value()) {
        std::cerr << "SEMANTIC_CAPABILITY_REQUIRED\n";
        return 3;
    }

    std::error_code scratch_parent_error;
    const auto scratch_parent = fs::temp_directory_path(scratch_parent_error);
    if (scratch_parent_error) {
        std::cerr << "SCRATCH_CREATE_FAILED\n";
        return 4;
    }
    const auto scratch_transaction = elder::weather::detail::NewTransactionId();
    const auto scratch = elder::weather::detail::CreateOwnedTree(
        scratch_parent,
        "ewf",
        elder::weather::detail::OwnedTreeRole::Scratch,
        scratch_transaction);
    if (!scratch.has_value()) {
        std::cerr << "SCRATCH_CREATE_FAILED\n";
        return 4;
    }
    const auto scratch_owner = *scratch;
    const auto base_root = scratch_owner / "p";
    const auto cleanup_scratch = [&]() {
        std::error_code error;
        if (!fs::exists(scratch_owner, error)) {
            return !error;
        }
        if (error) {
            return false;
        }
        return elder::weather::detail::RemoveOwnedTree(
            scratch_owner,
            elder::weather::detail::OwnedTreeRole::Scratch,
            scratch_transaction);
    };
    const auto first_pass = elder::improvement::CompileImprovedBundles(
        options.overlay_root,
        options.preset_root,
        base_root,
        manifest,
        catalog);
    if (!first_pass.success()) {
        for (const auto& diagnostic : first_pass.diagnostics) {
            std::cerr << elder::improvement::ToString(diagnostic.code) << ' '
                      << diagnostic.profile_id << ' ' << diagnostic.relative_path << ' '
                      << diagnostic.section << ' ' << diagnostic.key << '\n';
        }
        if (!cleanup_scratch()) {
            std::cerr << "SCRATCH_CLEANUP_FAILED\n";
        }
        return 4;
    }

    elder::weather::WeatherCompileControls controls;
    controls.expectations.profiles = options.expected_profiles;
    controls.expectations.weather_records = options.expected_weather_records;
    controls.expectations.transformed_fields = options.expected_fields;
    controls.expectations.semantic_verified = options.expected_semantic_verified;
    controls.expectations.semantic_unresolved = options.expected_semantic_unresolved;
    controls.phase_observer = [&](const elder::weather::WeatherCompilePhase phase,
                                  const fs::path&) {
        if (phase == elder::weather::WeatherCompilePhase::SnapshotVerified
            && !cleanup_scratch()) {
            throw std::runtime_error("scratch cleanup failed");
        }
    };
    const auto result = elder::weather::CompileWeatherThemeBundles(
        base_root,
        options.output_root,
        themes,
        *semantic.registry,
        catalog,
        controls);
    std::error_code scratch_error;
    const bool scratch_exists = fs::exists(scratch_owner, scratch_error);
    if (scratch_error || (scratch_exists && !cleanup_scratch())) {
        std::cerr << "SCRATCH_CLEANUP_FAILED\n";
        return 5;
    }
    for (const auto& diagnostic : result.diagnostics) {
        std::cerr << elder::weather::ToString(diagnostic.code) << ' '
                  << diagnostic.profile_id << ' ' << diagnostic.relative_path << ' '
                  << diagnostic.key << '\n';
    }
    if (!result.success()) {
        return 5;
    }

    std::map<elder::weather::WeatherFamily, std::size_t> family_counts;
    for (const auto family : elder::weather::AllWeatherFamilies()) {
        family_counts.emplace(family, 0);
    }
    for (const auto& record : result.provenance) {
        ++family_counts[record.family];
    }

    std::cout
        << "profiles=" << result.counts.profiles
        << " weather_records=" << result.counts.weather_records
        << " transformed_fields=" << result.counts.transformed_fields
        << " alpha_values_preserved=" << result.counts.alpha_values_preserved
        << " alpha_preservation_violations="
        << result.counts.alpha_preservation_violations
        << " protected_value_changes=" << result.counts.protected_value_changes
        << " temporal_sequences=" << result.counts.temporal_sequences
        << " temporal_violations=" << result.counts.temporal_order_violations
        << " fog_horizon_checks=" << result.counts.fog_horizon_checks
        << " fog_horizon_violations=" << result.counts.fog_horizon_violations
        << " cloud_separation_checks=" << result.counts.cloud_sky_separation_checks
        << " cloud_separation_violations="
        << result.counts.cloud_sky_separation_violations
        << " unreadable_nights=" << result.counts.unreadable_night_violations
        << " snow_clip_violations=" << result.counts.snow_clip_violations
        << " semantic_verified=" << semantic.verified_entries
        << " semantic_unresolved=" << semantic.unresolved_entries;
    for (const auto family : elder::weather::AllWeatherFamilies()) {
        std::cout << ' ' << elder::weather::ToString(family) << '='
                  << family_counts.at(family);
    }
    std::cout << " output_tree_sha256="
              << elder::improvement::DirectoryTreeHash(options.output_root) << '\n';
    return 0;
}
