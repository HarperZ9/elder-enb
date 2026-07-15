#include "elder/audit/LegacyPresetAudit.hpp"
#include "elder/bindings/LegacyKreateBindings.hpp"

#include <charconv>
#include <cstddef>
#include <filesystem>
#include <iostream>
#include <optional>
#include <string>
#include <string_view>
#include <system_error>

namespace {

namespace fs = std::filesystem;
using elder::audit::AuditDiagnostic;
using elder::audit::AuditDiagnosticClass;
using elder::audit::AuditDiagnosticCode;
using elder::audit::AuditExitCode;
using elder::audit::AuditLegacyPresets;
using elder::audit::AuditOutputPathsAreSafe;
using elder::audit::AuditResult;
using elder::audit::ToString;
using elder::audit::WriteAuditManifest;
using elder::audit::WriteAuditReport;
using elder::bindings::LoadDispositionCatalog;

struct Options {
    fs::path preset_root;
    fs::path catalog;
    fs::path manifest;
    fs::path report;
    std::optional<std::size_t> expected_presets;
    std::optional<std::size_t> expected_ini_files;
    std::optional<std::string> required_preset;
    bool fail_on_findings{false};
};

[[nodiscard]] std::optional<std::size_t> ParseCount(const std::string_view value) {
    std::size_t count = 0;
    const auto* begin = value.data();
    const auto* end = begin + value.size();
    const auto conversion = std::from_chars(begin, end, count);
    if (conversion.ec != std::errc{} || conversion.ptr != end) {
        return std::nullopt;
    }
    return count;
}

[[nodiscard]] bool ParseArguments(
    const int argument_count,
    char* arguments[],
    Options& options) {
    for (int index = 1; index < argument_count; ++index) {
        const std::string_view name{arguments[index]};
        if (name == "--fail-on-findings") {
            options.fail_on_findings = true;
            continue;
        }
        if (index + 1 >= argument_count) {
            return false;
        }
        const std::string value{arguments[++index]};
        if (name == "--preset-root") {
            options.preset_root = value;
        } else if (name == "--catalog") {
            options.catalog = value;
        } else if (name == "--manifest") {
            options.manifest = value;
        } else if (name == "--report") {
            options.report = value;
        } else if (name == "--expect-presets") {
            options.expected_presets = ParseCount(value);
            if (!options.expected_presets.has_value()) {
                return false;
            }
        } else if (name == "--expect-ini-files") {
            options.expected_ini_files = ParseCount(value);
            if (!options.expected_ini_files.has_value()) {
                return false;
            }
        } else if (name == "--require-preset") {
            options.required_preset = value;
        } else {
            return false;
        }
    }
    return !options.preset_root.empty() && !options.catalog.empty()
        && !options.manifest.empty() && !options.report.empty();
}

void AddFatal(
    AuditResult& result,
    const AuditDiagnosticCode code,
    const std::string& preset_id = {}) {
    result.diagnostics.push_back(AuditDiagnostic{
        AuditDiagnosticClass::Fatal,
        code,
        preset_id,
        {},
        {},
        0,
    });
    ++result.counts.fatal_errors;
}

void PrintUsage() {
    std::cerr
        << "usage: elder_preset_auditor --preset-root PATH --catalog FILE "
           "--manifest FILE --report FILE [--expect-presets N] "
           "[--expect-ini-files N] [--require-preset NAME] [--fail-on-findings]\n";
}

}  // namespace

int main(const int argument_count, char* arguments[]) {
    Options options;
    if (!ParseArguments(argument_count, arguments, options)) {
        PrintUsage();
        return 2;
    }
    if (!AuditOutputPathsAreSafe(
            options.preset_root,
            options.manifest,
            options.report)) {
        std::cerr << ToString(AuditDiagnosticCode::UnsafeOutputPath) << '\n';
        return 2;
    }

    const auto catalog = LoadDispositionCatalog(options.catalog);
    auto result = AuditLegacyPresets(options.preset_root, catalog);
    if (!catalog.diagnostics.empty()) {
        AddFatal(result, AuditDiagnosticCode::InvalidCatalog);
    }
    if (options.expected_presets.has_value()
        && *options.expected_presets != result.counts.catalog_presets) {
        AddFatal(result, AuditDiagnosticCode::ExpectationMismatch);
    }
    if (options.expected_ini_files.has_value()
        && *options.expected_ini_files != result.counts.ini_files) {
        AddFatal(result, AuditDiagnosticCode::ExpectationMismatch);
    }
    if (options.required_preset.has_value()) {
        const auto found = std::ranges::any_of(
            result.presets,
            [&options](const elder::audit::AuditedPreset& preset) {
                return preset.preset_id == *options.required_preset;
            });
        if (!found) {
            AddFatal(
                result,
                AuditDiagnosticCode::ExpectationMismatch,
                *options.required_preset);
        }
    }

    if (!result.completed()) {
        std::error_code ignored;
        fs::remove(options.manifest, ignored);
    }
    if (!WriteAuditReport(options.report, result)) {
        std::cerr << ToString(AuditDiagnosticCode::IoError) << '\n';
        return 3;
    }
    if (result.completed() && !WriteAuditManifest(options.manifest, result)) {
        std::cerr << ToString(AuditDiagnosticCode::IoError) << '\n';
        return 3;
    }

    std::cout << "presets=" << result.counts.catalog_presets
              << " ini_files=" << result.counts.ini_files
              << " record_files=" << result.counts.record_files
              << " findings=" << result.counts.findings
              << " fatal_errors=" << result.counts.fatal_errors << '\n';
    for (const auto& diagnostic : result.diagnostics) {
        std::cerr << ToString(diagnostic.classification) << ' '
                  << ToString(diagnostic.code) << ' '
                  << diagnostic.preset_id << ' ' << diagnostic.category << ' '
                  << diagnostic.relative_path << ' ' << diagnostic.line << '\n';
    }
    return AuditExitCode(result, options.fail_on_findings);
}
