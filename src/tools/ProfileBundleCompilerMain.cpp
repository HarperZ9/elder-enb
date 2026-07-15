#include "elder/bindings/LegacyKreateBindings.hpp"
#include "elder/improvement/ProfileBundleCompiler.hpp"

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
using elder::bindings::LoadDispositionCatalog;
using elder::improvement::CompileImprovedBundles;
using elder::improvement::DirectoryTreeHash;
using elder::improvement::LoadImprovementManifest;
using elder::improvement::ToString;

struct Options {
    fs::path overlay_root;
    fs::path preset_root;
    fs::path catalog;
    fs::path improvement_manifest;
    fs::path output_root;
    std::optional<std::size_t> expected_profiles;
    std::optional<std::size_t> expected_repairs;
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
        } else if (name == "--output-root") {
            options.output_root = value;
        } else if (name == "--expect-profiles") {
            options.expected_profiles = ParseCount(value);
            if (!options.expected_profiles.has_value()) {
                return false;
            }
        } else if (name == "--expect-repairs") {
            options.expected_repairs = ParseCount(value);
            if (!options.expected_repairs.has_value()) {
                return false;
            }
        } else {
            return false;
        }
    }
    return !options.overlay_root.empty() && !options.preset_root.empty()
        && !options.catalog.empty() && !options.improvement_manifest.empty()
        && !options.output_root.empty();
}

void PrintUsage() {
    std::cerr
        << "usage: elder_profile_bundle_compiler --overlay-root PATH "
           "--preset-root PATH --catalog FILE --improvement-manifest FILE "
           "--output-root PATH [--expect-profiles N] [--expect-repairs N]\n";
}

}  // namespace

int main(const int argument_count, char* arguments[]) {
    Options options;
    if (!ParseArguments(argument_count, arguments, options)) {
        PrintUsage();
        return 2;
    }

    const auto catalog = LoadDispositionCatalog(options.catalog);
    const auto manifest = LoadImprovementManifest(options.improvement_manifest);
    if (!catalog.diagnostics.empty() || !manifest.diagnostics.empty()) {
        std::cerr << "INVALID_MANIFEST\n";
        return 2;
    }

    const auto result = CompileImprovedBundles(
        options.overlay_root,
        options.preset_root,
        options.output_root,
        manifest,
        catalog);
    for (const auto& diagnostic : result.diagnostics) {
        std::cerr << ToString(diagnostic.code) << ' ' << diagnostic.profile_id << ' '
                  << diagnostic.relative_path << ' ' << diagnostic.section << ' '
                  << diagnostic.key << '\n';
    }
    if (!result.success()) {
        return 3;
    }
    if ((options.expected_profiles.has_value()
         && result.counts.profiles != *options.expected_profiles)
        || (options.expected_repairs.has_value()
            && result.counts.repairs != *options.expected_repairs)) {
        std::cerr << "EXPECTATION_MISMATCH\n";
        return 4;
    }

    std::cout << "profiles=" << result.counts.profiles
              << " copied_files=" << result.counts.copied_files
              << " repairs=" << result.counts.repairs
              << " overlay_changes=" << result.counts.overlay_changes
              << " kreate_changes=" << result.counts.kreate_changes
              << " export_name_debt=" << result.counts.export_name_debt
              << " record_files=" << result.counts.record_files
              << " output_tree_sha256=" << DirectoryTreeHash(options.output_root) << '\n';
    return 0;
}
