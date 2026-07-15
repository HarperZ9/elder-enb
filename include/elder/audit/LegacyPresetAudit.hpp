#pragma once

#include "elder/bindings/LegacyKreateBindings.hpp"

#include <cstddef>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

namespace elder::audit {

enum class AuditDiagnosticClass {
    Finding,
    Fatal,
};

enum class AuditDiagnosticCode {
    IoError,
    InvalidUtf8,
    MalformedIniLine,
    MalformedSection,
    DuplicateSection,
    DuplicateKey,
    MissingIdentity,
    MultipleIdentity,
    MalformedLegacyId,
    MalformedSymbol,
    MissingOptional,
    InvalidOptional,
    NonFiniteNumeric,
    InvalidNumericToken,
    InvalidQuotedValue,
    DuplicateRecordIdentity,
    SuspiciousDuplicateFilename,
    MissingPresetInfo,
    DuplicateCatalogPreset,
    MissingPresetDirectory,
    InvalidCatalog,
    UnsafeOutputPath,
    ExpectationMismatch,
};

enum class IdentityKind {
    None,
    LegacyId,
    Symbol,
};

struct AuditDiagnostic {
    AuditDiagnosticClass classification;
    AuditDiagnosticCode code;
    std::string preset_id;
    std::string category;
    std::string relative_path;
    std::size_t line{0};

    bool operator==(const AuditDiagnostic&) const = default;
};

struct AuditedFile {
    std::string preset_id;
    std::string category;
    std::string relative_path;
    IdentityKind identity_kind{IdentityKind::None};
    std::string relative_identity;
    std::string sha256;

    bool operator==(const AuditedFile&) const = default;
};

struct AuditedPreset {
    std::string preset_id;
    std::size_t ini_files{0};
    std::size_t record_files{0};
    std::size_t findings{0};
    std::size_t fatal_errors{0};
    std::string tree_sha256;

    bool operator==(const AuditedPreset&) const = default;
};

struct AuditCounts {
    std::size_t catalog_presets{0};
    std::size_t ini_files{0};
    std::size_t record_files{0};
    std::size_t findings{0};
    std::size_t fatal_errors{0};
};

struct AuditResult {
    AuditCounts counts;
    std::vector<AuditedPreset> presets;
    std::vector<AuditedFile> files;
    std::vector<AuditDiagnostic> diagnostics;

    [[nodiscard]] bool completed() const noexcept;
    [[nodiscard]] bool clean() const noexcept;
};

[[nodiscard]] AuditResult AuditLegacyPresets(
    const std::filesystem::path& preset_root,
    const bindings::DispositionCatalog& catalog);
[[nodiscard]] bool HasDiagnostic(
    const AuditResult& result,
    AuditDiagnosticCode code) noexcept;
[[nodiscard]] std::size_t CountDiagnostics(
    const AuditResult& result,
    AuditDiagnosticCode code) noexcept;
[[nodiscard]] std::size_t CountDiagnostics(
    const AuditResult& result,
    AuditDiagnosticClass classification) noexcept;
[[nodiscard]] bool WriteAuditManifest(
    const std::filesystem::path& path,
    const AuditResult& result);
[[nodiscard]] bool WriteAuditReport(
    const std::filesystem::path& path,
    const AuditResult& result);
[[nodiscard]] bool AuditOutputPathsAreSafe(
    const std::filesystem::path& preset_root,
    const std::filesystem::path& manifest_path,
    const std::filesystem::path& report_path);
[[nodiscard]] int AuditExitCode(
    const AuditResult& result,
    bool fail_on_findings) noexcept;
[[nodiscard]] std::string_view ToString(AuditDiagnosticCode code) noexcept;
[[nodiscard]] std::string_view ToString(AuditDiagnosticClass classification) noexcept;
[[nodiscard]] std::string_view ToString(IdentityKind kind) noexcept;

}  // namespace elder::audit
