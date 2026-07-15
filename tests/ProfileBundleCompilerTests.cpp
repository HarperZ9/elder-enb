#include "elder/audit/LegacyPresetAudit.hpp"
#include "elder/bindings/LegacyKreateBindings.hpp"
#include "elder/improvement/ProfileBundleCompiler.hpp"

#include <atomic>
#include <chrono>
#include <cstddef>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <source_location>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

namespace {

namespace fs = std::filesystem;
using elder::audit::AuditLegacyPresets;
using elder::audit::HasDiagnostic;
using elder::bindings::BindingDisposition;
using elder::bindings::DispositionCatalog;
using elder::bindings::Sha256File;
using elder::improvement::BundleDiagnosticCode;
using elder::improvement::CompileImprovedBundles;
using elder::improvement::DirectoryTreeHash;
using elder::improvement::ImprovementManifest;
using elder::improvement::LoadImprovementManifest;
using elder::improvement::ProfileSpec;
using elder::improvement::RuleLayer;
using elder::improvement::RuleOperation;
using elder::improvement::SemanticType;
using elder::improvement::ToString;
using elder::improvement::TransformRule;

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
        throw std::runtime_error("cannot write synthetic bundle fixture");
    }
    output.write(bytes.data(), static_cast<std::streamsize>(bytes.size()));
}

[[nodiscard]] std::string ReadBytes(const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("cannot read synthetic bundle fixture");
    }
    return std::string{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{},
    };
}

[[nodiscard]] std::string Csv(const std::string_view value) {
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

struct SyntheticFixture {
    fs::path root;
    fs::path overlays;
    fs::path presets;
    fs::path outputs;
    DispositionCatalog catalog;

    SyntheticFixture() {
        static std::atomic<unsigned long long> sequence{0};
        const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
        root = fs::temp_directory_path()
            / ("elder-bundle-test-" + std::to_string(stamp) + "-"
               + std::to_string(sequence.fetch_add(1)));
        overlays = root / "overlays";
        presets = root / "presets";
        outputs = root / "outputs";
        fs::create_directories(overlays);
        fs::create_directories(presets);
    }

    SyntheticFixture(const SyntheticFixture&) = delete;
    SyntheticFixture& operator=(const SyntheticFixture&) = delete;

    ~SyntheticFixture() {
        std::error_code ignored;
        fs::remove_all(root, ignored);
    }

    void Populate(const std::string_view fused_tint = "0.5, 0.5, 0.5, 0[DepthOfField]") {
        WriteBytes(
            overlays / "Alpha.ini",
            "[OVERLAYINFO]\n"
            "UIName = STYLE - Alpha\n"
            "UIGroups = 10 - KreatE Presets\n"
            "UIOrdering = 1\n"
            "[OVERLAYPARAM1]\n"
            "Category = ENBEFFECT.FX\n"
            "Name = CG.HDR.|- Day - Exposure (in EVs)\n"
            "Operation = \"+ 0.0\"\n");
        WriteBytes(
            presets / "Alpha" / "PresetInfo.ini",
            "Optional=true\n"
            "ConfigVersion=1.3.0\n"
            "PresetVersion=1.0.0\n"
            "Author=\"synthetic\"\n"
            "Description=\"\"\n");
        WriteBytes(
            presets / "Alpha" / "ImageSpaces" / "Exterior.ini",
            std::string{"ID=0x1\nOptional=true\nBrightness=1\nTint="}
                + std::string{fused_tint}
                + "\nStrength=0\nDistance=0\nRange=0\n");
        WriteBytes(
            presets / "Alpha" / "Weathers" / "Clear.ini",
            "ID=0x2\n"
            "Optional=true\n"
            "[Colors]\n"
            "SkyUpperDay=0.4, 0.6, 0.8\n"
            "SkyUpperNight=0.02, 0.03, 0.04\n"
            "[Fog]\n"
            "NightMax=0.95\n");
        WriteBytes(presets / "Alpha" / "opaque.asset", "opaque-copy-sentinel");

        catalog.bindings.push_back(BindingDisposition{
            "Alpha",
            "Alpha.ini",
            Sha256File(overlays / "Alpha.ini"),
            "Alpha",
            Sha256File(presets / "Alpha" / "PresetInfo.ini"),
        });
    }

    [[nodiscard]] std::string PresetTreeHash() const {
        const auto audit = AuditLegacyPresets(presets, catalog);
        CHECK(audit.completed());
        CHECK(audit.presets.size() == 1);
        return audit.presets.front().tree_sha256;
    }

    [[nodiscard]] ImprovementManifest Manifest(
        const std::size_t expected_repairs = 1) const {
        ImprovementManifest manifest;
        manifest.profiles.push_back(ProfileSpec{
            "elder.alpha.first-pass",
            "Alpha",
            "Alpha.ini",
            Sha256File(overlays / "Alpha.ini"),
            "Alpha",
            PresetTreeHash(),
            expected_repairs,
            "synthetic_direction",
        });
        manifest.rules.push_back(TransformRule{
            "Alpha",
            RuleLayer::Overlay,
            "Alpha.ini",
            Sha256File(overlays / "Alpha.ini"),
            "OVERLAYPARAM1",
            "Operation",
            SemanticType::OverlayOperation,
            "\"+ 0.0\"",
            RuleOperation::Set,
            "\"+ 0.04\"",
            -1.0,
            1.0,
            "restrained_exposure",
        });
        manifest.rules.push_back(TransformRule{
            "Alpha",
            RuleLayer::Kreate,
            "ImageSpaces/Exterior.ini",
            Sha256File(presets / "Alpha" / "ImageSpaces" / "Exterior.ini"),
            "",
            "Brightness",
            SemanticType::Scalar,
            "1",
            RuleOperation::Set,
            "1.02",
            0.0,
            2.0,
            "exterior_readability",
        });
        manifest.rules.push_back(TransformRule{
            "Alpha",
            RuleLayer::Kreate,
            "Weathers/Clear.ini",
            Sha256File(presets / "Alpha" / "Weathers" / "Clear.ini"),
            "Colors",
            "SkyUpperDay",
            SemanticType::Vector3,
            "0.4, 0.6, 0.8",
            RuleOperation::ScaleRgb,
            "1.05, 1, 0.95",
            0.0,
            1.0,
            "day_color_separation",
        });
        return manifest;
    }

    void ReplaceOverlay(const std::string_view bytes) {
        WriteBytes(overlays / "Alpha.ini", bytes);
        catalog.bindings.front().selected_overlay_sha256 =
            Sha256File(overlays / "Alpha.ini");
    }
};

[[nodiscard]] std::string ManifestCsv(
    const SyntheticFixture& fixture,
    const ImprovementManifest& manifest) {
    std::string csv =
        "record_type,bundle_id,profile_id,overlay_file,overlay_sha256,preset_directory,"
        "preset_tree_sha256,expected_repairs,art_direction,layer,relative_path,file_sha256,"
        "section,key,semantic_type,guard_value,operation,operand,min_value,max_value,rationale\n";
    for (const auto& profile : manifest.profiles) {
        csv += Csv("PROFILE") + ',' + Csv(profile.bundle_id) + ',' + Csv(profile.profile_id)
            + ',' + Csv(profile.overlay_file) + ',' + Csv(profile.overlay_sha256) + ','
            + Csv(profile.preset_directory) + ',' + Csv(profile.preset_tree_sha256) + ','
            + Csv(std::to_string(profile.expected_repairs)) + ',' + Csv(profile.art_direction)
            + ",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\",\"\"\n";
    }
    for (const auto& rule : manifest.rules) {
        csv += Csv("RULE") + ",\"\"," + Csv(rule.profile_id)
            + ",\"\",\"\",\"\",\"\",\"\",\"\"," + Csv(ToString(rule.layer))
            + ',' + Csv(rule.relative_path) + ',' + Csv(rule.file_sha256) + ','
            + Csv(rule.section) + ',' + Csv(rule.key) + ',' + Csv(ToString(rule.semantic_type))
            + ',' + Csv(rule.guard_value) + ',' + Csv(ToString(rule.operation)) + ','
            + Csv(rule.operand) + ',' + Csv(std::to_string(rule.min_value)) + ','
            + Csv(std::to_string(rule.max_value)) + ',' + Csv(rule.rationale) + '\n';
    }
    (void)fixture;
    return csv;
}

void ManifestLoaderPreservesGuardedRules() {
    SyntheticFixture fixture;
    fixture.Populate();
    const auto expected = fixture.Manifest();
    const auto path = fixture.root / "manifest.csv";
    WriteBytes(path, ManifestCsv(fixture, expected));

    const auto loaded = LoadImprovementManifest(path);
    CHECK(loaded.diagnostics.empty());
    CHECK(loaded.profiles == expected.profiles);
    CHECK(loaded.rules == expected.rules);
}

void ExactFusedTintIsRepairedAndBundleIsPaired() {
    SyntheticFixture fixture;
    fixture.Populate();
    const auto source_overlay_hash = Sha256File(fixture.overlays / "Alpha.ini");
    const auto source_preset_hash = fixture.PresetTreeHash();

    const auto result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "run",
        fixture.Manifest(),
        fixture.catalog);

    CHECK(result.success());
    CHECK(result.counts.profiles == 1);
    CHECK(result.counts.repairs == 1);
    CHECK(result.counts.overlay_changes == 1);
    CHECK(result.counts.kreate_changes == 2);
    CHECK(result.counts.record_files == 2);
    CHECK(result.bundles.size() == 1);
    CHECK(result.bundles.front().bundle_id == "elder.alpha.first-pass");
    CHECK(result.bundles.front().profile_id == "Alpha");
    CHECK(result.bundles.front().overlay_file == "Alpha.ini");
    CHECK(result.bundles.front().preset_directory == "Alpha");
    CHECK(result.bundles.front().bundle_sha256.size() == 64);
    CHECK(result.bundles.front().bundle_bytes > 0);

    const auto bundle_root = fixture.outputs / "run" / "profiles" / "elder.alpha.first-pass";
    const auto repaired = ReadBytes(bundle_root / "preset" / "Alpha" / "ImageSpaces" / "Exterior.ini");
    CHECK(repaired.find("Tint=0.5, 0.5, 0.5, 0\n[DepthOfField]\n") != std::string::npos);
    CHECK(repaired.find("Brightness=1.02") != std::string::npos);
    CHECK(ReadBytes(bundle_root / "preset" / "Alpha" / "opaque.asset")
          == "opaque-copy-sentinel");
    CHECK(ReadBytes(bundle_root / "bundle.csv").find("Alpha.ini") != std::string::npos);
    CHECK(ReadBytes(bundle_root / "bundle.csv").find("preset/Alpha") != std::string::npos);
    CHECK(Sha256File(fixture.overlays / "Alpha.ini") == source_overlay_hash);
    CHECK(fixture.PresetTreeHash() == source_preset_hash);
}

void GeneratedPresetReauditsWithoutInvalidNumericTokens() {
    SyntheticFixture fixture;
    fixture.Populate();
    const auto result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "run",
        fixture.Manifest(),
        fixture.catalog);
    CHECK(result.success());

    DispositionCatalog generated_catalog;
    generated_catalog.bindings.push_back(fixture.catalog.bindings.front());
    const auto audit = AuditLegacyPresets(
        fixture.outputs / "run" / "profiles" / "elder.alpha.first-pass" / "preset",
        generated_catalog);
    CHECK(audit.completed());
    CHECK(!HasDiagnostic(audit, elder::audit::AuditDiagnosticCode::InvalidNumericToken));
    CHECK(audit.counts.record_files == 2);
}

void NearMatchRepairIsRejectedWithoutPublishedOutput() {
    SyntheticFixture fixture;
    fixture.Populate("0.5, 0.5, 0.5[DepthOfField]");
    const auto result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "rejected",
        fixture.Manifest(),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(elder::improvement::HasDiagnostic(
        result,
        BundleDiagnosticCode::AmbiguousFusedDepthOfField));
    CHECK(!fs::exists(fixture.outputs / "rejected"));
}

void RepairCountMismatchFailsClosed() {
    SyntheticFixture fixture;
    fixture.Populate();
    const auto result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "rejected",
        fixture.Manifest(2),
        fixture.catalog);
    CHECK(!result.success());
    CHECK(elder::improvement::HasDiagnostic(result, BundleDiagnosticCode::RepairCountMismatch));
    CHECK(!fs::exists(fixture.outputs / "rejected"));
}

void SourceHashAndValueGuardsFailClosed() {
    SyntheticFixture fixture;
    fixture.Populate();
    auto bad_hash = fixture.Manifest();
    bad_hash.rules.front().file_sha256 = std::string(64, '0');
    const auto hash_result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "bad-hash",
        bad_hash,
        fixture.catalog);
    CHECK(!hash_result.success());
    CHECK(elder::improvement::HasDiagnostic(hash_result, BundleDiagnosticCode::SourceHashMismatch));

    auto bad_value = fixture.Manifest();
    bad_value.rules.back().guard_value = "0.1, 0.2, 0.3";
    const auto value_result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "bad-value",
        bad_value,
        fixture.catalog);
    CHECK(!value_result.success());
    CHECK(elder::improvement::HasDiagnostic(value_result, BundleDiagnosticCode::GuardValueMismatch));
}

void OverlaySchemaCannotBeExtendedOrDuplicated() {
    SyntheticFixture fixture;
    fixture.Populate();
    auto unsupported = fixture.Manifest();
    unsupported.rules.front().key = "Unsupported";
    const auto missing_result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "missing",
        unsupported,
        fixture.catalog);
    CHECK(!missing_result.success());
    CHECK(elder::improvement::HasDiagnostic(
        missing_result,
        BundleDiagnosticCode::UnsupportedOverlayBinding));

    auto duplicate = fixture.Manifest();
    duplicate.rules.push_back(duplicate.rules.front());
    const auto duplicate_result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "duplicate",
        duplicate,
        fixture.catalog);
    CHECK(!duplicate_result.success());
    CHECK(elder::improvement::HasDiagnostic(duplicate_result, BundleDiagnosticCode::DuplicateRule));
}

void NonFiniteOrOutOfBoundsResultsAreRejected() {
    SyntheticFixture fixture;
    fixture.Populate();
    auto non_finite = fixture.Manifest();
    non_finite.rules[1].operand = "nan";
    const auto non_finite_result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "non-finite",
        non_finite,
        fixture.catalog);
    CHECK(!non_finite_result.success());
    CHECK(elder::improvement::HasDiagnostic(non_finite_result, BundleDiagnosticCode::InvalidTransform));

    auto out_of_bounds = fixture.Manifest();
    out_of_bounds.rules[1].operand = "3";
    const auto bounds_result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "bounds",
        out_of_bounds,
        fixture.catalog);
    CHECK(!bounds_result.success());
    CHECK(elder::improvement::HasDiagnostic(bounds_result, BundleDiagnosticCode::ValueOutOfBounds));
}

void CompleteOutputsAreByteDeterministic() {
    SyntheticFixture fixture;
    fixture.Populate();
    const auto first = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "a",
        fixture.Manifest(),
        fixture.catalog);
    const auto second = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "b",
        fixture.Manifest(),
        fixture.catalog);
    CHECK(first.success());
    CHECK(second.success());
    CHECK(first.bundles == second.bundles);
    CHECK(first.provenance == second.provenance);
    CHECK(DirectoryTreeHash(fixture.outputs / "a") == DirectoryTreeHash(fixture.outputs / "b"));
}

void Utf8ProfileNamesRemainPaired() {
    SyntheticFixture fixture;
    fixture.Populate();
    auto manifest = fixture.Manifest();
    constexpr std::u8string_view utf8_name = u8"Jötunheimar";
    const std::string profile{
        reinterpret_cast<const char*>(utf8_name.data()),
        utf8_name.size(),
    };
    const fs::path native_name{std::u8string{utf8_name}};
    fs::rename(fixture.presets / "Alpha", fixture.presets / native_name);
    fixture.catalog.bindings.front().canonical_identity = profile;
    fixture.catalog.bindings.front().preset_directory = profile;
    fixture.catalog.bindings.front().preset_info_sha256 =
        Sha256File(fixture.presets / native_name / "PresetInfo.ini");
    manifest.profiles.front().profile_id = profile;
    manifest.profiles.front().preset_directory = profile;
    manifest.profiles.front().preset_tree_sha256 = fixture.PresetTreeHash();
    for (auto& rule : manifest.rules) {
        rule.profile_id = profile;
        if (rule.layer == RuleLayer::Kreate) {
            rule.file_sha256 = Sha256File(
                fixture.presets / native_name / fs::path{std::u8string{
                    reinterpret_cast<const char8_t*>(rule.relative_path.data()),
                    reinterpret_cast<const char8_t*>(rule.relative_path.data())
                        + rule.relative_path.size()}});
        }
    }

    const auto result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "utf8",
        manifest,
        fixture.catalog);
    CHECK(result.success());
    CHECK(result.bundles.front().profile_id == profile);
    CHECK(fs::exists(
        fixture.outputs / "utf8" / "profiles" / "elder.alpha.first-pass"
        / "preset" / native_name / "PresetInfo.ini"));
}

void StableDiagnosticCodesArePublished() {
    CHECK(ToString(BundleDiagnosticCode::InvalidManifest) == "INVALID_MANIFEST");
    CHECK(ToString(BundleDiagnosticCode::SourceHashMismatch) == "SOURCE_HASH_MISMATCH");
    CHECK(ToString(BundleDiagnosticCode::GuardValueMismatch) == "GUARD_VALUE_MISMATCH");
    CHECK(ToString(BundleDiagnosticCode::AmbiguousFusedDepthOfField)
          == "AMBIGUOUS_FUSED_DEPTH_OF_FIELD");
    CHECK(ToString(BundleDiagnosticCode::RepairCountMismatch) == "REPAIR_COUNT_MISMATCH");
    CHECK(ToString(BundleDiagnosticCode::UnsupportedOverlayKey) == "UNSUPPORTED_OVERLAY_KEY");
    CHECK(ToString(BundleDiagnosticCode::GeneratedAuditFailed) == "GENERATED_AUDIT_FAILED");
    CHECK(ToString(BundleDiagnosticCode::MissingOverlayBindingField)
          == "MISSING_OVERLAY_BINDING_FIELD");
    CHECK(ToString(BundleDiagnosticCode::AmbiguousOverlayBindingField)
          == "AMBIGUOUS_OVERLAY_BINDING_FIELD");
    CHECK(ToString(BundleDiagnosticCode::UnsupportedOverlayBinding)
          == "UNSUPPORTED_OVERLAY_BINDING");
}

void OverlayRulesPublishResolvedBindingProvenance() {
    SyntheticFixture fixture;
    fixture.Populate();
    const auto result = CompileImprovedBundles(
        fixture.overlays,
        fixture.presets,
        fixture.outputs / "resolved-binding",
        fixture.Manifest(),
        fixture.catalog);
    CHECK(result.success());
    const auto binding = std::ranges::find_if(
        result.provenance,
        [](const elder::improvement::ProvenanceEntry& entry) {
            return entry.layer == "OVERLAY";
        });
    CHECK(binding != result.provenance.end());
    CHECK(binding->target_filename == "ENBEFFECT.FX");
    CHECK(binding->target_category == "CG.HDR.");
    CHECK(binding->target_key == "- Day - Exposure (in EVs)");
    CHECK(binding->target_type == "ADD_SCALAR");
    CHECK(binding->rationale_basis == "INTENDED_OUTCOME");
}

void OverlayBindingResolutionFailsClosed() {
    SyntheticFixture missing;
    missing.Populate();
    missing.ReplaceOverlay(
        "[OVERLAYINFO]\n"
        "UIName = STYLE - Alpha\n"
        "UIGroups = 10 - KreatE Presets\n"
        "UIOrdering = 1\n"
        "[OVERLAYPARAM1]\n"
        "Name = CG.HDR.|- Day - Exposure (in EVs)\n"
        "Operation = \"+ 0.0\"\n");
    const auto missing_result = CompileImprovedBundles(
        missing.overlays,
        missing.presets,
        missing.outputs / "missing-binding",
        missing.Manifest(),
        missing.catalog);
    CHECK(!missing_result.success());
    CHECK(elder::improvement::HasDiagnostic(
        missing_result,
        BundleDiagnosticCode::MissingOverlayBindingField));

    SyntheticFixture ambiguous;
    ambiguous.Populate();
    ambiguous.ReplaceOverlay(
        "[OVERLAYINFO]\n"
        "UIName = STYLE - Alpha\n"
        "UIGroups = 10 - KreatE Presets\n"
        "UIOrdering = 1\n"
        "[OVERLAYPARAM1]\n"
        "Category = ENBEFFECT.FX\n"
        "Name = CG.HDR.|- Day - Exposure (in EVs)\n"
        "Name = CG.HDR.|- Day - Alternate\n"
        "Operation = \"+ 0.0\"\n");
    const auto ambiguous_result = CompileImprovedBundles(
        ambiguous.overlays,
        ambiguous.presets,
        ambiguous.outputs / "ambiguous-binding",
        ambiguous.Manifest(),
        ambiguous.catalog);
    CHECK(!ambiguous_result.success());
    CHECK(elder::improvement::HasDiagnostic(
        ambiguous_result,
        BundleDiagnosticCode::AmbiguousOverlayBindingField));

    SyntheticFixture unsupported;
    unsupported.Populate();
    unsupported.ReplaceOverlay(
        "[OVERLAYINFO]\n"
        "UIName = STYLE - Alpha\n"
        "UIGroups = 10 - KreatE Presets\n"
        "UIOrdering = 1\n"
        "[OVERLAYPARAM1]\n"
        "Category = not a shader target\n"
        "Name = CG.HDR.|- Day - Exposure (in EVs)\n"
        "Operation = \"+ 0.0\"\n");
    const auto unsupported_result = CompileImprovedBundles(
        unsupported.overlays,
        unsupported.presets,
        unsupported.outputs / "unsupported-binding",
        unsupported.Manifest(),
        unsupported.catalog);
    CHECK(!unsupported_result.success());
    CHECK(elder::improvement::HasDiagnostic(
        unsupported_result,
        BundleDiagnosticCode::UnsupportedOverlayBinding));
}

struct TestCase {
    std::string_view name;
    void (*run)();
};

}  // namespace

int main() {
    const std::vector<TestCase> tests{
        {"manifest loader preserves guarded rules", ManifestLoaderPreservesGuardedRules},
        {"exact fused Tint is repaired and bundle is paired", ExactFusedTintIsRepairedAndBundleIsPaired},
        {"generated preset reaudits without invalid numeric tokens", GeneratedPresetReauditsWithoutInvalidNumericTokens},
        {"near-match repair is rejected without published output", NearMatchRepairIsRejectedWithoutPublishedOutput},
        {"repair count mismatch fails closed", RepairCountMismatchFailsClosed},
        {"source hash and value guards fail closed", SourceHashAndValueGuardsFailClosed},
        {"overlay schema cannot be extended or duplicated", OverlaySchemaCannotBeExtendedOrDuplicated},
        {"non-finite or out-of-bounds results are rejected", NonFiniteOrOutOfBoundsResultsAreRejected},
        {"complete outputs are byte deterministic", CompleteOutputsAreByteDeterministic},
        {"UTF-8 profile names remain paired", Utf8ProfileNamesRemainPaired},
        {"stable diagnostic codes are published", StableDiagnosticCodesArePublished},
        {"overlay rules publish resolved binding provenance",
         OverlayRulesPublishResolvedBindingProvenance},
        {"overlay binding resolution fails closed", OverlayBindingResolutionFailsClosed},
    };

    std::size_t passed = 0;
    for (const auto& test : tests) {
        try {
            test.run();
            ++passed;
            std::cout << "PASS: " << test.name << '\n';
        } catch (const std::exception& error) {
            std::cerr << "FAIL: " << test.name << "\n  " << error.what() << '\n';
        } catch (...) {
            std::cerr << "FAIL: " << test.name << "\n  unknown exception\n";
        }
    }
    std::cout << passed << "/" << tests.size() << " bundle tests passed\n";
    return passed == tests.size() ? 0 : 1;
}
