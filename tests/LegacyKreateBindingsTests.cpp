#include "elder/bindings/LegacyKreateBindings.hpp"
#include "elder/profiles/TransactionalProfile.hpp"

#include <atomic>
#include <chrono>
#include <cstddef>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <optional>
#include <source_location>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <utility>
#include <vector>

namespace {

namespace fs = std::filesystem;
using elder::bindings::AliasDisposition;
using elder::bindings::BindingDiagnosticCode;
using elder::bindings::BindingDisposition;
using elder::bindings::CompileBindings;
using elder::bindings::CompileResult;
using elder::bindings::DispositionCatalog;
using elder::bindings::HasDiagnostic;
using elder::bindings::LoadDispositionCatalog;
using elder::bindings::MakeProfilePackage;
using elder::bindings::OutputPathsAreSafe;
using elder::bindings::ReadOverlayMetadata;
using elder::bindings::ReadPresetMetadata;
using elder::bindings::RetiredDisposition;
using elder::bindings::Sha256;
using elder::bindings::Sha256File;
using elder::bindings::ToString;
using elder::bindings::WriteManifest;
using elder::bindings::WriteReport;
using elder::profiles::OperationKind;
using elder::profiles::ProfileOperation;
using elder::profiles::ProfileResult;
using elder::profiles::TransactionalProfile;

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

void WriteText(const fs::path& path, const std::string_view text) {
    fs::create_directories(path.parent_path());
    std::ofstream output{path, std::ios::binary | std::ios::trunc};
    if (!output) {
        throw std::runtime_error("cannot write synthetic fixture: " + path.string());
    }
    output.write(text.data(), static_cast<std::streamsize>(text.size()));
}

[[nodiscard]] std::string ReadText(const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("cannot read synthetic fixture: " + path.string());
    }
    return std::string{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{},
    };
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

struct SyntheticFixture {
    fs::path root;
    fs::path overlays;
    fs::path presets;
    fs::path outputs;

    SyntheticFixture() {
        static std::atomic<unsigned long long> sequence{0};
        const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
        root = fs::temp_directory_path()
            / ("elder-kreate-test-" + std::to_string(stamp) + "-"
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

    void AddOverlay(
        const std::string& filename,
        const std::string& identity,
        const int ordering,
        const std::string& sentinel) const {
        WriteText(
            overlays / filename,
            "[OVERLAYINFO]\n"
            "UIName = STYLE - " + identity + "\n"
            "UIGroups = 10 - KreatE Presets\n"
            "UIOrdering = " + std::to_string(ordering) + "\n"
            "[SYNTHETIC OPERATIONS]\n"
            "BodySentinel = " + sentinel + "\n");
    }

    void AddPreset(const std::string& directory, const std::string& marker = "complete") const {
        WriteText(
            presets / directory / "PresetInfo.ini",
            "Optional = true\n"
            "ConfigVersion = 1.3.0\n"
            "PresetVersion = 1.0.0\n"
            "Author = \"synthetic\"\n"
            "Description = \"" + marker + "\"\n");
    }

    [[nodiscard]] DispositionCatalog AccountedCatalog() const {
        DispositionCatalog catalog;
        catalog.bindings = {
            BindingDisposition{
                "Alpha",
                "002. STYLE - Alpha.ini",
                Sha256File(overlays / "002. STYLE - Alpha.ini"),
                "Alpha",
                Sha256File(presets / "Alpha" / "PresetInfo.ini"),
            },
            BindingDisposition{
                "Beta",
                "003. STYLE - Beta.ini",
                Sha256File(overlays / "003. STYLE - Beta.ini"),
                "Beta",
                Sha256File(presets / "Beta" / "PresetInfo.ini"),
            },
        };
        catalog.retired = {
            RetiredDisposition{
                "Alpha",
                "001. STYLE - Alpha.ini",
                Sha256File(overlays / "001. STYLE - Alpha.ini"),
            },
        };
        catalog.aliases = {AliasDisposition{"Alias Alpha", "Alpha"}};
        return catalog;
    }

    [[nodiscard]] DispositionCatalog Populate() const {
        AddOverlay("001. STYLE - Alpha.ini", "Alpha", 1, "retired-opaque-body");
        AddOverlay("002. STYLE - Alpha.ini", "Alpha", 2, "selected-opaque-body");
        AddOverlay("003. STYLE - Beta.ini", "Beta", 3, "beta-opaque-body");
        AddPreset("Alpha");
        AddPreset("Beta");
        return AccountedCatalog();
    }
};

void WriteCatalogCsv(
    const fs::path& path,
    const DispositionCatalog& catalog,
    const std::vector<std::string>& extra_rows = {}) {
    std::string csv =
        "record_type,canonical_identity,overlay_file,overlay_sha256,preset_directory,"
        "preset_info_sha256,alias\n";
    for (const auto& binding : catalog.bindings) {
        csv += CsvField("BINDING") + ',' + CsvField(binding.canonical_identity) + ','
            + CsvField(binding.selected_overlay_file) + ','
            + CsvField(binding.selected_overlay_sha256) + ','
            + CsvField(binding.preset_directory) + ','
            + CsvField(binding.preset_info_sha256) + ',' + CsvField("") + '\n';
    }
    for (const auto& retired : catalog.retired) {
        csv += CsvField("RETIRED") + ',' + CsvField(retired.canonical_identity) + ','
            + CsvField(retired.overlay_file) + ',' + CsvField(retired.overlay_sha256)
            + ',' + CsvField("") + ',' + CsvField("") + ',' + CsvField("") + '\n';
    }
    for (const auto& alias : catalog.aliases) {
        csv += CsvField("ALIAS") + ',' + CsvField(alias.canonical_identity) + ','
            + CsvField("") + ',' + CsvField("") + ',' + CsvField("") + ','
            + CsvField("") + ',' + CsvField(alias.alias) + '\n';
    }
    for (const auto& row : extra_rows) {
        csv += row + '\n';
    }
    WriteText(path, csv);
}

[[nodiscard]] CompileResult CompileFixture(
    const SyntheticFixture& fixture,
    const DispositionCatalog& catalog,
    const std::vector<std::string>& extra_rows = {}) {
    const auto catalog_path = fixture.root / "catalog.csv";
    WriteCatalogCsv(catalog_path, catalog, extra_rows);
    const auto loaded = LoadDispositionCatalog(catalog_path);
    return CompileBindings(fixture.overlays, fixture.presets, loaded);
}

void Sha256MatchesKnownVector() {
    CHECK(Sha256("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
}

void MetadataReadersExposeOnlyWhitelistedFields() {
    SyntheticFixture fixture;
    fixture.AddOverlay("001. STYLE - Alpha.ini", "Alpha", 7, "must-never-emit");
    fixture.AddPreset("Alpha", "metadata-only");

    const auto overlay = ReadOverlayMetadata(fixture.overlays / "001. STYLE - Alpha.ini");
    const auto preset = ReadPresetMetadata(fixture.presets / "Alpha");

    CHECK(overlay.filename == "001. STYLE - Alpha.ini");
    CHECK(overlay.ui_name == "STYLE - Alpha");
    CHECK(overlay.ui_groups == "10 - KreatE Presets");
    CHECK(overlay.ui_ordering == 7);
    CHECK(overlay.sha256.size() == 64);
    CHECK(preset.directory_name == "Alpha");
    CHECK(preset.identity_metadata.size() == 5);
    CHECK(preset.identity_metadata.contains("Author"));
    CHECK(preset.identity_metadata.contains("Description"));
    CHECK(!preset.identity_metadata.contains("BodySentinel"));
}

void AccountedCatalogCompilesAndBindsProfilePackage() {
    SyntheticFixture fixture;
    const auto catalog = fixture.Populate();
    const auto result = CompileFixture(fixture, catalog);

    CHECK(result.success());
    CHECK(result.diagnostics.empty());
    CHECK(result.counts.discovered_overlays == 3);
    CHECK(result.counts.compiled_bindings == 2);
    CHECK(result.counts.retired_overlays == 1);
    CHECK(result.counts.aliases == 1);
    CHECK(result.counts.unresolved_entries == 0);
    CHECK(result.counts.ambiguous_aliases == 0);
    CHECK(result.counts.orphan_presets == 0);
    CHECK(result.counts.unbound_overlays == 0);

    const std::vector<ProfileOperation> operations{
        ProfileOperation{"tone", OperationKind::Add, 2.0},
    };
    const auto package = MakeProfilePackage(result, "Alias Alpha", operations);
    CHECK(package.has_value());
    CHECK(package->overlay_id == "002. STYLE - Alpha.ini");
    CHECK(package->preset_id == "Alpha");

    TransactionalProfile engine{{{"tone", 1.0}}};
    CHECK(engine.Apply(*package).result == ProfileResult::Applied);
    CHECK(engine.values().at("tone") == 3.0);
}

void WritersAreDeterministicAndExcludeBodies() {
    SyntheticFixture fixture;
    const auto result = CompileFixture(fixture, fixture.Populate());
    CHECK(result.success());

    const auto manifest_a = fixture.outputs / "a" / "manifest.csv";
    const auto report_a = fixture.outputs / "a" / "report.txt";
    const auto manifest_b = fixture.outputs / "b" / "manifest.csv";
    const auto report_b = fixture.outputs / "b" / "report.txt";
    CHECK(WriteManifest(manifest_a, result));
    CHECK(WriteReport(report_a, result));
    CHECK(WriteManifest(manifest_b, result));
    CHECK(WriteReport(report_b, result));

    const auto manifest = ReadText(manifest_a);
    CHECK(manifest == ReadText(manifest_b));
    CHECK(ReadText(report_a) == ReadText(report_b));
    CHECK(manifest.find("selected-opaque-body") == std::string::npos);
    CHECK(manifest.find("retired-opaque-body") == std::string::npos);
    CHECK(manifest.find("beta-opaque-body") == std::string::npos);
}

void OutputPathsInsideInputRootsAreRejected() {
    SyntheticFixture fixture;
    const auto safe_manifest = fixture.outputs / "manifest.csv";
    const auto safe_report = fixture.outputs / "report.txt";
    CHECK(OutputPathsAreSafe(
        fixture.overlays,
        fixture.presets,
        safe_manifest,
        safe_report));
    CHECK(!OutputPathsAreSafe(
        fixture.overlays,
        fixture.presets,
        fixture.overlays / "forbidden-manifest.csv",
        safe_report));
    CHECK(!OutputPathsAreSafe(
        fixture.overlays,
        fixture.presets,
        safe_manifest,
        fixture.presets / "forbidden-report.txt"));
    CHECK(!OutputPathsAreSafe(
        fixture.overlays,
        fixture.presets,
        safe_manifest,
        safe_manifest));
}

void ChangedSelectedHashFailsClosed() {
    SyntheticFixture fixture;
    auto catalog = fixture.Populate();
    catalog.bindings.front().selected_overlay_sha256 = std::string(64, '0');
    const auto result = CompileFixture(fixture, catalog);
    CHECK(!result.success());
    CHECK(result.bindings.empty());
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::SelectedHashChanged));
}

void ChangedRetiredAndPresetHashesFailClosed() {
    SyntheticFixture fixture;
    auto catalog = fixture.Populate();
    catalog.retired.front().overlay_sha256 = std::string(64, '1');
    catalog.bindings.back().preset_info_sha256 = std::string(64, '2');
    const auto result = CompileFixture(fixture, catalog);
    CHECK(!result.success());
    CHECK(result.bindings.empty());
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::RetiredHashChanged));
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::PresetHashChanged));
}

void MissingSelectedRetiredAndPresetEntriesFailClosed() {
    SyntheticFixture fixture;
    auto catalog = fixture.Populate();
    catalog.bindings.front().selected_overlay_file = "missing-selected.ini";
    catalog.bindings.back().preset_directory = "missing-preset";
    catalog.retired.front().overlay_file = "missing-retired.ini";
    const auto result = CompileFixture(fixture, catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::MissingSelectedOverlay));
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::MissingRetiredOverlay));
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::MissingPreset));
}

void DuplicateCatalogEntriesAndAmbiguousAliasesFailClosed() {
    SyntheticFixture fixture;
    auto catalog = fixture.Populate();
    catalog.bindings.push_back(catalog.bindings.front());
    catalog.aliases.push_back(AliasDisposition{"Alias Alpha", "Beta"});
    const auto result = CompileFixture(fixture, catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::DuplicateCatalogEntry));
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::AmbiguousAlias));
}

void UnknownOverlayIsUnresolvedUnaccountedAndUnbound() {
    SyntheticFixture fixture;
    const auto catalog = fixture.Populate();
    fixture.AddOverlay("004. STYLE - Unknown.ini", "Unknown", 4, "unknown-opaque-body");
    const auto result = CompileFixture(fixture, catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::UnknownIdentity));
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::UnaccountedOverlay));
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::UnboundOverlay));
    CHECK(result.counts.unresolved_entries == 1);
    CHECK(result.counts.unbound_overlays == 1);
}

void DivergentDuplicateRequiresReviewedRetirement() {
    SyntheticFixture fixture;
    auto catalog = fixture.Populate();
    catalog.retired.clear();
    const auto result = CompileFixture(fixture, catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::DivergentDuplicateWithoutDisposition));
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::UnaccountedOverlay));
}

void OrphanPresetFailsClosed() {
    SyntheticFixture fixture;
    const auto catalog = fixture.Populate();
    fixture.AddPreset("Orphan");
    const auto result = CompileFixture(fixture, catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::OrphanPreset));
    CHECK(result.counts.orphan_presets == 1);
}

void InvalidOverlayAndPresetMetadataFailClosed() {
    SyntheticFixture fixture;
    auto catalog = fixture.Populate();
    WriteText(
        fixture.overlays / catalog.bindings.back().selected_overlay_file,
        "[OVERLAYINFO]\nUIName = STYLE - Beta\nUIGroups = 10 - KreatE Presets\n");
    WriteText(
        fixture.presets / "Alpha" / "PresetInfo.ini",
        "Optional = true\nConfigVersion = 1.3.0\n");
    catalog.bindings.back().selected_overlay_sha256 =
        Sha256File(fixture.overlays / catalog.bindings.back().selected_overlay_file);
    catalog.bindings.front().preset_info_sha256 =
        Sha256File(fixture.presets / "Alpha" / "PresetInfo.ini");
    const auto result = CompileFixture(fixture, catalog);
    CHECK(!result.success());
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::InvalidOverlayMetadata));
    CHECK(HasDiagnostic(result, BindingDiagnosticCode::InvalidPresetMetadata));
}

void StableDiagnosticCodesArePublished() {
    CHECK(ToString(BindingDiagnosticCode::InvalidCatalog) == "INVALID_CATALOG");
    CHECK(ToString(BindingDiagnosticCode::DuplicateCatalogEntry) == "DUPLICATE_CATALOG_ENTRY");
    CHECK(ToString(BindingDiagnosticCode::AmbiguousAlias) == "AMBIGUOUS_ALIAS");
    CHECK(ToString(BindingDiagnosticCode::UnknownIdentity) == "UNKNOWN_IDENTITY");
    CHECK(ToString(BindingDiagnosticCode::MissingSelectedOverlay) == "MISSING_SELECTED_OVERLAY");
    CHECK(ToString(BindingDiagnosticCode::MissingRetiredOverlay) == "MISSING_RETIRED_OVERLAY");
    CHECK(ToString(BindingDiagnosticCode::MissingPreset) == "MISSING_PRESET");
    CHECK(ToString(BindingDiagnosticCode::SelectedHashChanged) == "SELECTED_HASH_CHANGED");
    CHECK(ToString(BindingDiagnosticCode::RetiredHashChanged) == "RETIRED_HASH_CHANGED");
    CHECK(ToString(BindingDiagnosticCode::PresetHashChanged) == "PRESET_HASH_CHANGED");
    CHECK(ToString(BindingDiagnosticCode::UnaccountedOverlay) == "UNACCOUNTED_OVERLAY");
    CHECK(ToString(BindingDiagnosticCode::UnboundOverlay) == "UNBOUND_OVERLAY");
    CHECK(ToString(BindingDiagnosticCode::DivergentDuplicateWithoutDisposition)
          == "DIVERGENT_DUPLICATE_WITHOUT_DISPOSITION");
    CHECK(ToString(BindingDiagnosticCode::OrphanPreset) == "ORPHAN_PRESET");
}

struct TestCase {
    std::string_view name;
    void (*run)();
};

}  // namespace

int main() {
    const std::vector<TestCase> tests{
        {"SHA-256 matches the known vector", Sha256MatchesKnownVector},
        {"metadata readers expose only whitelisted fields", MetadataReadersExposeOnlyWhitelistedFields},
        {"accounted catalog compiles and binds a profile package", AccountedCatalogCompilesAndBindsProfilePackage},
        {"writers are deterministic and exclude bodies", WritersAreDeterministicAndExcludeBodies},
        {"output paths inside input roots are rejected", OutputPathsInsideInputRootsAreRejected},
        {"changed selected hash fails closed", ChangedSelectedHashFailsClosed},
        {"changed retired and preset hashes fail closed", ChangedRetiredAndPresetHashesFailClosed},
        {"missing selected retired and preset entries fail closed", MissingSelectedRetiredAndPresetEntriesFailClosed},
        {"duplicate catalog entries and ambiguous aliases fail closed", DuplicateCatalogEntriesAndAmbiguousAliasesFailClosed},
        {"unknown overlay is unresolved unaccounted and unbound", UnknownOverlayIsUnresolvedUnaccountedAndUnbound},
        {"divergent duplicate requires reviewed retirement", DivergentDuplicateRequiresReviewedRetirement},
        {"orphan preset fails closed", OrphanPresetFailsClosed},
        {"invalid overlay and preset metadata fail closed", InvalidOverlayAndPresetMetadataFailClosed},
        {"stable diagnostic codes are published", StableDiagnosticCodesArePublished},
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

    std::cout << passed << "/" << tests.size() << " binding tests passed\n";
    return passed == tests.size() ? 0 : 1;
}
