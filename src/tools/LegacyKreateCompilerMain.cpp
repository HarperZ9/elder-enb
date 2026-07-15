#include "elder/bindings/LegacyKreateBindings.hpp"

#include <algorithm>
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
using elder::bindings::BindingDiagnostic;
using elder::bindings::BindingDiagnosticCode;
using elder::bindings::CompileBindings;
using elder::bindings::CompileResult;
using elder::bindings::LoadDispositionCatalog;
using elder::bindings::OutputPathsAreSafe;
using elder::bindings::ToString;
using elder::bindings::WriteManifest;
using elder::bindings::WriteReport;

struct Options {
    fs::path overlay_root;
    fs::path preset_root;
    fs::path catalog;
    fs::path manifest;
    fs::path report;
    std::optional<std::size_t> expected_overlays;
    std::optional<std::size_t> expected_bindings;
    std::optional<std::size_t> expected_retired;
    std::optional<std::size_t> expected_aliases;
    std::optional<std::string> required_identity;
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
    for (int index = 1; index < argument_count; index += 2) {
        if (index + 1 >= argument_count) {
            return false;
        }
        const std::string_view name{arguments[index]};
        const std::string value{arguments[index + 1]};
        if (name == "--overlay-root") {
            options.overlay_root = value;
        } else if (name == "--preset-root") {
            options.preset_root = value;
        } else if (name == "--catalog") {
            options.catalog = value;
        } else if (name == "--manifest") {
            options.manifest = value;
        } else if (name == "--report") {
            options.report = value;
        } else if (name == "--require-identity") {
            options.required_identity = value;
        } else if (name == "--expect-overlays") {
            options.expected_overlays = ParseCount(value);
            if (!options.expected_overlays.has_value()) {
                return false;
            }
        } else if (name == "--expect-bindings") {
            options.expected_bindings = ParseCount(value);
            if (!options.expected_bindings.has_value()) {
                return false;
            }
        } else if (name == "--expect-retired") {
            options.expected_retired = ParseCount(value);
            if (!options.expected_retired.has_value()) {
                return false;
            }
        } else if (name == "--expect-aliases") {
            options.expected_aliases = ParseCount(value);
            if (!options.expected_aliases.has_value()) {
                return false;
            }
        } else {
            return false;
        }
    }
    return !options.overlay_root.empty() && !options.preset_root.empty()
        && !options.catalog.empty() && !options.manifest.empty() && !options.report.empty();
}

void AddExpectationFailure(
    CompileResult& result,
    const std::string& identity,
    const std::string& entry) {
    result.diagnostics.push_back(BindingDiagnostic{
        BindingDiagnosticCode::ExpectationMismatch,
        identity,
        entry,
    });
}

void CheckExpected(
    CompileResult& result,
    const std::optional<std::size_t> expected,
    const std::size_t actual,
    const std::string& label) {
    if (expected.has_value() && *expected != actual) {
        AddExpectationFailure(
            result,
            label,
            "expected=" + std::to_string(*expected) + ",actual=" + std::to_string(actual));
    }
}

void PrintUsage() {
    std::cerr
        << "usage: elder_binding_compiler --overlay-root PATH --preset-root PATH "
           "--catalog FILE --manifest FILE --report FILE "
           "[--expect-overlays N] [--expect-bindings N] [--expect-retired N] "
           "[--expect-aliases N] [--require-identity NAME]\n";
}

}  // namespace

int main(const int argument_count, char* arguments[]) {
    Options options;
    if (!ParseArguments(argument_count, arguments, options)) {
        PrintUsage();
        return 2;
    }

    if (!OutputPathsAreSafe(
            options.overlay_root,
            options.preset_root,
            options.manifest,
            options.report)) {
        std::cerr << ToString(BindingDiagnosticCode::UnsafeOutputPath)
                  << " outputs must be distinct and outside input roots\n";
        return 2;
    }

    auto catalog = LoadDispositionCatalog(options.catalog);
    auto result = CompileBindings(options.overlay_root, options.preset_root, catalog);

    CheckExpected(
        result,
        options.expected_overlays,
        result.counts.discovered_overlays,
        "overlays");
    CheckExpected(
        result,
        options.expected_bindings,
        result.counts.compiled_bindings,
        "bindings");
    CheckExpected(
        result,
        options.expected_retired,
        result.counts.retired_overlays,
        "retired");
    CheckExpected(result, options.expected_aliases, result.counts.aliases, "aliases");

    if (options.required_identity.has_value()) {
        const auto found = std::ranges::any_of(
            result.bindings,
            [&options](const elder::bindings::CompiledBinding& binding) {
                return binding.canonical_identity == *options.required_identity;
            });
        if (!found) {
            AddExpectationFailure(result, *options.required_identity, "required identity missing");
        }
    }

    if (!result.success()) {
        std::error_code ignored;
        fs::remove(options.manifest, ignored);
    }

    if (!WriteReport(options.report, result)) {
        std::cerr << "failed to write deterministic report\n";
        return 3;
    }
    if (result.success() && !WriteManifest(options.manifest, result)) {
        result.diagnostics.push_back(BindingDiagnostic{
            BindingDiagnosticCode::IoError,
            {},
            "manifest output",
        });
        (void)WriteReport(options.report, result);
        std::cerr << "failed to write deterministic manifest\n";
        return 3;
    }

    std::cout << "overlays=" << result.counts.discovered_overlays
              << " bindings=" << result.counts.compiled_bindings
              << " retired=" << result.counts.retired_overlays
              << " aliases=" << result.counts.aliases
              << " unresolved=" << result.counts.unresolved_entries
              << " ambiguous=" << result.counts.ambiguous_aliases
              << " orphans=" << result.counts.orphan_presets
              << " unbound=" << result.counts.unbound_overlays << '\n';

    for (const auto& diagnostic : result.diagnostics) {
        std::cerr << ToString(diagnostic.code) << ' ' << diagnostic.identity
                  << ' ' << diagnostic.entry << '\n';
    }
    return result.success() ? 0 : 1;
}
