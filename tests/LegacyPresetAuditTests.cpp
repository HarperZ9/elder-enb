#include "elder/audit/LegacyPresetAudit.hpp"
#include "elder/bindings/LegacyKreateBindings.hpp"

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
using elder::audit::AuditDiagnosticClass;
using elder::audit::AuditDiagnosticCode;
using elder::audit::AuditExitCode;
using elder::audit::AuditLegacyPresets;
using elder::audit::AuditOutputPathsAreSafe;
using elder::audit::AuditResult;
using elder::audit::CountDiagnostics;
using elder::audit::HasDiagnostic;
using elder::audit::IdentityKind;
using elder::audit::ToString;
using elder::audit::WriteAuditManifest;
using elder::audit::WriteAuditReport;
using elder::bindings::BindingDisposition;
using elder::bindings::DispositionCatalog;
using elder::bindings::Sha256File;

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
        throw std::runtime_error("cannot write synthetic fixture");
    }
    output.write(bytes.data(), static_cast<std::streamsize>(bytes.size()));
}

[[nodiscard]] std::string ReadBytes(const fs::path& path) {
    std::ifstream input{path, std::ios::binary};
    if (!input) {
        throw std::runtime_error("cannot read synthetic fixture");
    }
    return std::string{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{},
    };
}

struct SyntheticFixture {
    fs::path root;
    fs::path presets;
    fs::path outputs;
    DispositionCatalog catalog;

    SyntheticFixture() {
        static std::atomic<unsigned long long> sequence{0};
        const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
        root = fs::temp_directory_path()
            / ("elder-preset-audit-test-" + std::to_string(stamp) + "-"
               + std::to_string(sequence.fetch_add(1)));
        presets = root / "presets";
        outputs = root / "outputs";
        fs::create_directories(presets);
    }

    SyntheticFixture(const SyntheticFixture&) = delete;
    SyntheticFixture& operator=(const SyntheticFixture&) = delete;

    ~SyntheticFixture() {
        std::error_code ignored;
        fs::remove_all(root, ignored);
    }

    void AddPreset(const std::string& preset) {
        const auto info = presets / preset / "PresetInfo.ini";
        WriteBytes(
            info,
            "Optional = true\n"
            "ConfigVersion = 1.3.0\n"
            "PresetVersion = 1.0.0\n"
            "Author = \"synthetic\"\n"
            "Description = \"\"\n");
        catalog.bindings.push_back(BindingDisposition{
            preset,
            preset + ".overlay.ini",
            std::string(64, '0'),
            preset,
            Sha256File(info),
        });
    }

    void AddRecord(
        const std::string& preset,
        const std::string& category,
        const std::string& filename,
        const std::string_view body) const {
        WriteBytes(presets / preset / category / filename, body);
    }
};

[[nodiscard]] const elder::audit::AuditedFile& FindFile(
    const AuditResult& result,
    const std::string_view relative_path) {
    for (const auto& file : result.files) {
        if (file.relative_path == relative_path) {
            return file;
        }
    }
    throw AssertionFailure("audited file not found");
}

void ValidLegacyAndSymbolRecordsAreAudited() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "Legacy.ini",
        "ID = 0x10A235\n"
        "Optional = true\n"
        "Scalar = -1.25e+2\n"
        "Vector = 0, 0.25, -3.5\n"
        "Texture = \"textures\\\\elder\\\\cloud.dds\"\n"
        "[Sky]\n"
        "Enabled = false\n");
    fixture.AddRecord(
        "Alpha",
        "ImageSpaces",
        "Modern.ini",
        "Symbol = Elder.ImageSpace.Modern\n"
        "Optional = false\n"
        "Tint = 1, 0.5, 0, 1\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);

    CHECK(result.completed());
    CHECK(result.clean());
    CHECK(result.counts.catalog_presets == 1);
    CHECK(result.counts.ini_files == 3);
    CHECK(result.counts.record_files == 2);
    CHECK(result.counts.findings == 0);
    CHECK(result.counts.fatal_errors == 0);
    CHECK(result.presets.size() == 1);
    CHECK(result.presets.front().preset_id == "Alpha");
    CHECK(result.presets.front().tree_sha256.size() == 64);
    CHECK(FindFile(result, "ImageSpaces/Modern.ini").category == "ImageSpaces");
    CHECK(FindFile(result, "ImageSpaces/Modern.ini").identity_kind == IdentityKind::Symbol);
    CHECK(FindFile(result, "ImageSpaces/Modern.ini").relative_identity
          == "Elder.ImageSpace.Modern");
    CHECK(FindFile(result, "Weathers/Legacy.ini").identity_kind == IdentityKind::LegacyId);
    CHECK(FindFile(result, "Weathers/Legacy.ini").relative_identity == "0x10a235");
    CHECK(FindFile(result, "PresetInfo.ini").category == "PresetMetadata");
    CHECK(FindFile(result, "PresetInfo.ini").identity_kind == IdentityKind::None);
}

void HashesAndOrderingAreDeterministicAndContentSensitive() {
    SyntheticFixture fixture;
    fixture.AddPreset("Zulu");
    fixture.AddPreset("Alpha");
    fixture.AddRecord("Zulu", "Weathers", "B.ini", "ID=0x2\nOptional=true\nValue=2\n");
    fixture.AddRecord("Alpha", "Weathers", "A.ini", "ID=0x1\nOptional=true\nValue=1\n");

    const auto first = AuditLegacyPresets(fixture.presets, fixture.catalog);
    const auto second = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(first.completed());
    CHECK(first.presets == second.presets);
    CHECK(first.files == second.files);
    CHECK(first.presets.front().preset_id == "Alpha");
    CHECK(first.files.front().preset_id == "Alpha");
    const auto original_tree = first.presets.front().tree_sha256;

    fixture.AddRecord("Alpha", "Weathers", "A.ini", "ID=0x1\nOptional=true\nValue=3\n");
    const auto changed = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(changed.presets.front().tree_sha256 != original_tree);
    CHECK(FindFile(changed, "Weathers/A.ini").sha256
          != FindFile(first, "Weathers/A.ini").sha256);
}

void InvalidUtf8AndMalformedIniAreFatalParseFaults() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "InvalidUtf8.ini",
        std::string{"ID=0x1\nOptional=true\nName="} + static_cast<char>(0xFF) + "\n");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "MalformedLine.ini",
        "ID=0x2\nOptional=true\nthis is not a key/value\n");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "MalformedSection.ini",
        "ID=0x3\nOptional=true\n[Unclosed\nValue=1\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(!result.completed());
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::InvalidUtf8));
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::MalformedIniLine));
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::MalformedSection));
    CHECK(CountDiagnostics(result, AuditDiagnosticClass::Fatal) == 3);
}

void DuplicateSectionsAndKeysAreActionableFindings() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "DuplicateSyntax.ini",
        "ID=0x1\n"
        "Optional=true\n"
        "optional=false\n"
        "[Sky]\n"
        "Value=1\n"
        "value=2\n"
        "[sky]\n"
        "Other=3\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(!result.clean());
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::DuplicateKey));
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::DuplicateSection));
    CHECK(CountDiagnostics(result, AuditDiagnosticClass::Finding) == 3);
}

void IdentityFaultsAreSeparatedByDiagnostic() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord("Alpha", "Weathers", "Missing.ini", "Optional=true\nValue=1\n");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "Multiple.ini",
        "ID=0x1\nSymbol=Elder.Multiple\nOptional=true\nValue=1\n");
    fixture.AddRecord("Alpha", "Weathers", "BadId.ini", "ID=0xXYZ\nOptional=true\nValue=1\n");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "BadSymbol.ini",
        "Symbol=not a symbol\nOptional=true\nValue=1\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::MissingIdentity));
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::MultipleIdentity));
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::MalformedLegacyId));
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::MalformedSymbol));
}

void OptionalMustExistOnceAndBeBoolean() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord("Alpha", "Weathers", "Missing.ini", "ID=0x1\nValue=1\n");
    fixture.AddRecord("Alpha", "Weathers", "Invalid.ini", "ID=0x2\nOptional=yes\nValue=1\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::MissingOptional));
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::InvalidOptional));
}

void NumericTokensDistinguishMalformedAndNonFiniteValues() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "Numbers.ini",
        "ID=0x1\n"
        "Optional=true\n"
        "Malformed=1.0, nope, 2.0\n"
        "NotFinite=0, nan, +infinity\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(CountDiagnostics(result, AuditDiagnosticCode::InvalidNumericToken) == 1);
    CHECK(CountDiagnostics(result, AuditDiagnosticCode::NonFiniteNumeric) == 1);
}

void QuotedStringsAndPathsRequireClosedValidEscapes() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "Strings.ini",
        "ID=0x1\n"
        "Optional=true\n"
        "Good=\"textures\\\\elder\\\\sky.dds\"\n"
        "Escaped=\"elder\\\"sky\"\n"
        "Bad=\"unterminated\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(CountDiagnostics(result, AuditDiagnosticCode::InvalidQuotedValue) == 1);
}

void DuplicateIdentitiesAreScopedToPresetAndCategory() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddPreset("Beta");
    fixture.AddRecord("Alpha", "Weathers", "One.ini", "ID=0x1\nOptional=true\nValue=1\n");
    fixture.AddRecord("Alpha", "Weathers", "Two.ini", "ID=0x1\nOptional=true\nValue=2\n");
    fixture.AddRecord("Alpha", "ImageSpaces", "One.ini", "ID=0x1\nOptional=true\nValue=3\n");
    fixture.AddRecord("Beta", "Weathers", "One.ini", "ID=0x1\nOptional=true\nValue=4\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(CountDiagnostics(result, AuditDiagnosticCode::DuplicateRecordIdentity) == 1);
}

void DuplicateNamedFilesAreReportedWithoutRejectingAudit() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord(
        "Alpha",
        "ImageSpaces",
        "InteriorDUPLICATE001.ini",
        "ID=0x1\nOptional=true\nValue=1\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(CountDiagnostics(result, AuditDiagnosticCode::SuspiciousDuplicateFilename) == 1);
}

void OnlyCatalogBoundPresetDirectoriesAreAudited() {
    SyntheticFixture fixture;
    fixture.AddPreset("Bound");
    fixture.AddRecord("Bound", "Weathers", "Bound.ini", "ID=0x1\nOptional=true\nValue=1\n");
    WriteBytes(
        fixture.presets / "Unbound" / "Weathers" / "Broken.ini",
        "not valid ini\n");

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(result.clean());
    CHECK(result.counts.catalog_presets == 1);
    CHECK(result.counts.ini_files == 2);
}

void Utf8CatalogNamesResolveNativeWindowsPaths() {
    SyntheticFixture fixture;
    constexpr std::u8string_view utf8_name = u8"Jötunheimar";
    const std::string catalog_name{
        reinterpret_cast<const char*>(utf8_name.data()),
        utf8_name.size(),
    };
    const fs::path native_name{std::u8string{utf8_name}};
    const auto info = fixture.presets / native_name / "PresetInfo.ini";
    WriteBytes(
        info,
        "Optional=true\n"
        "ConfigVersion=1.3.0\n"
        "PresetVersion=1.0.0\n"
        "Author=\"synthetic\"\n"
        "Description=\"\"\n");
    WriteBytes(
        fixture.presets / native_name / "Weathers" / "Nordic.ini",
        "ID=0x1\nOptional=true\nValue=1\n");
    fixture.catalog.bindings.push_back(BindingDisposition{
        catalog_name,
        "nordic.overlay.ini",
        std::string(64, '0'),
        catalog_name,
        Sha256File(info),
    });

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());
    CHECK(result.counts.catalog_presets == 1);
    CHECK(result.counts.ini_files == 2);
    CHECK(result.presets.front().preset_id == catalog_name);
}

void MissingOrDuplicateCatalogTargetsAreFatal() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.catalog.bindings.push_back(fixture.catalog.bindings.front());
    fixture.catalog.bindings.push_back(BindingDisposition{
        "Missing",
        "missing.overlay.ini",
        std::string(64, '0'),
        "Missing",
        std::string(64, '0'),
    });

    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(!result.completed());
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::DuplicateCatalogPreset));
    CHECK(HasDiagnostic(result, AuditDiagnosticCode::MissingPresetDirectory));
}

void WritersAreDeterministicAndNeverEmitBodies() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "Record.ini",
        "ID=0x1\nOptional=true\nSecretBodySentinel=123.456\n");
    const auto result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(result.completed());

    const auto manifest_a = fixture.outputs / "a" / "manifest.csv";
    const auto report_a = fixture.outputs / "a" / "report.txt";
    const auto manifest_b = fixture.outputs / "b" / "manifest.csv";
    const auto report_b = fixture.outputs / "b" / "report.txt";
    CHECK(WriteAuditManifest(manifest_a, result));
    CHECK(WriteAuditReport(report_a, result));
    CHECK(WriteAuditManifest(manifest_b, result));
    CHECK(WriteAuditReport(report_b, result));
    CHECK(ReadBytes(manifest_a) == ReadBytes(manifest_b));
    CHECK(ReadBytes(report_a) == ReadBytes(report_b));
    CHECK(ReadBytes(manifest_a).find("SecretBodySentinel") == std::string::npos);
    CHECK(ReadBytes(report_a).find("SecretBodySentinel") == std::string::npos);
    CHECK(ReadBytes(manifest_a).find("123.456") == std::string::npos);
}

void OutputPathsMustBeDistinctAndOutsideTheSource() {
    SyntheticFixture fixture;
    const auto manifest = fixture.outputs / "manifest.csv";
    const auto report = fixture.outputs / "report.txt";
    CHECK(AuditOutputPathsAreSafe(fixture.presets, manifest, report));
    CHECK(!AuditOutputPathsAreSafe(
        fixture.presets,
        fixture.presets / "forbidden.csv",
        report));
    CHECK(!AuditOutputPathsAreSafe(
        fixture.presets,
        manifest,
        fixture.presets / "forbidden.txt"));
    CHECK(!AuditOutputPathsAreSafe(fixture.presets, manifest, manifest));
}

void DefaultCompletionAndFailOnFindingsHaveExplicitExitCodes() {
    SyntheticFixture fixture;
    fixture.AddPreset("Alpha");
    fixture.AddRecord(
        "Alpha",
        "Weathers",
        "RecordDUPLICATE001.ini",
        "ID=0x1\nOptional=true\nValue=1\n");
    const auto finding_result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(AuditExitCode(finding_result, false) == 0);
    CHECK(AuditExitCode(finding_result, true) == 1);

    fs::remove_all(fixture.presets / "Alpha");
    const auto fatal_result = AuditLegacyPresets(fixture.presets, fixture.catalog);
    CHECK(AuditExitCode(fatal_result, false) == 1);
}

void StableDiagnosticCodesArePublished() {
    CHECK(ToString(AuditDiagnosticCode::IoError) == "IO_ERROR");
    CHECK(ToString(AuditDiagnosticCode::InvalidUtf8) == "INVALID_UTF8");
    CHECK(ToString(AuditDiagnosticCode::MalformedIniLine) == "MALFORMED_INI_LINE");
    CHECK(ToString(AuditDiagnosticCode::MalformedSection) == "MALFORMED_SECTION");
    CHECK(ToString(AuditDiagnosticCode::DuplicateSection) == "DUPLICATE_SECTION");
    CHECK(ToString(AuditDiagnosticCode::DuplicateKey) == "DUPLICATE_KEY");
    CHECK(ToString(AuditDiagnosticCode::MissingIdentity) == "MISSING_IDENTITY");
    CHECK(ToString(AuditDiagnosticCode::MultipleIdentity) == "MULTIPLE_IDENTITY");
    CHECK(ToString(AuditDiagnosticCode::MalformedLegacyId) == "MALFORMED_LEGACY_ID");
    CHECK(ToString(AuditDiagnosticCode::MalformedSymbol) == "MALFORMED_SYMBOL");
    CHECK(ToString(AuditDiagnosticCode::MissingOptional) == "MISSING_OPTIONAL");
    CHECK(ToString(AuditDiagnosticCode::InvalidOptional) == "INVALID_OPTIONAL");
    CHECK(ToString(AuditDiagnosticCode::NonFiniteNumeric) == "NON_FINITE_NUMERIC");
    CHECK(ToString(AuditDiagnosticCode::InvalidNumericToken) == "INVALID_NUMERIC_TOKEN");
    CHECK(ToString(AuditDiagnosticCode::InvalidQuotedValue) == "INVALID_QUOTED_VALUE");
    CHECK(ToString(AuditDiagnosticCode::DuplicateRecordIdentity)
          == "DUPLICATE_RECORD_IDENTITY");
    CHECK(ToString(AuditDiagnosticCode::SuspiciousDuplicateFilename)
          == "SUSPICIOUS_DUPLICATE_FILENAME");
}

struct TestCase {
    std::string_view name;
    void (*run)();
};

}  // namespace

int main() {
    const std::vector<TestCase> tests{
        {"valid legacy and symbol records are audited", ValidLegacyAndSymbolRecordsAreAudited},
        {"hashes and ordering are deterministic and content sensitive", HashesAndOrderingAreDeterministicAndContentSensitive},
        {"invalid UTF-8 and malformed INI are fatal parse faults", InvalidUtf8AndMalformedIniAreFatalParseFaults},
        {"duplicate sections and keys are actionable findings", DuplicateSectionsAndKeysAreActionableFindings},
        {"identity faults are separated by diagnostic", IdentityFaultsAreSeparatedByDiagnostic},
        {"Optional must exist once and be boolean", OptionalMustExistOnceAndBeBoolean},
        {"numeric tokens distinguish malformed and non-finite values", NumericTokensDistinguishMalformedAndNonFiniteValues},
        {"quoted strings and paths require closed valid escapes", QuotedStringsAndPathsRequireClosedValidEscapes},
        {"duplicate identities are scoped to preset and category", DuplicateIdentitiesAreScopedToPresetAndCategory},
        {"duplicate-named files are reported without rejecting audit", DuplicateNamedFilesAreReportedWithoutRejectingAudit},
        {"only catalog-bound preset directories are audited", OnlyCatalogBoundPresetDirectoriesAreAudited},
        {"UTF-8 catalog names resolve native Windows paths", Utf8CatalogNamesResolveNativeWindowsPaths},
        {"missing or duplicate catalog targets are fatal", MissingOrDuplicateCatalogTargetsAreFatal},
        {"writers are deterministic and never emit bodies", WritersAreDeterministicAndNeverEmitBodies},
        {"output paths must be distinct and outside the source", OutputPathsMustBeDistinctAndOutsideTheSource},
        {"default completion and fail-on-findings have explicit exit codes", DefaultCompletionAndFailOnFindingsHaveExplicitExitCodes},
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

    std::cout << passed << "/" << tests.size() << " preset audit tests passed\n";
    return passed == tests.size() ? 0 : 1;
}
