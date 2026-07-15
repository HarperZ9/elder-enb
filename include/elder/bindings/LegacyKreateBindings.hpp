#pragma once

#include "elder/profiles/TransactionalProfile.hpp"

#include <cstddef>
#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace elder::bindings {

inline constexpr std::string_view kKreateOverlayGroup = "10 - KreatE Presets";

enum class BindingDiagnosticCode {
    InvalidCatalog,
    DuplicateCatalogEntry,
    AmbiguousAlias,
    UnknownIdentity,
    InvalidOverlayMetadata,
    InvalidPresetMetadata,
    MissingSelectedOverlay,
    MissingRetiredOverlay,
    MissingPreset,
    SelectedHashChanged,
    RetiredHashChanged,
    PresetHashChanged,
    UnaccountedOverlay,
    UnboundOverlay,
    DivergentDuplicateWithoutDisposition,
    OrphanPreset,
    UnsafeOutputPath,
    ExpectationMismatch,
    IoError,
};

struct BindingDiagnostic {
    BindingDiagnosticCode code;
    std::string identity;
    std::string entry;

    bool operator==(const BindingDiagnostic&) const = default;
};

struct OverlayMetadata {
    std::string filename;
    std::string ui_name;
    std::string ui_groups;
    int ui_ordering;
    std::string sha256;
};

struct PresetMetadata {
    std::string directory_name;
    std::map<std::string, std::string> identity_metadata;
    std::string sha256;
};

struct BindingDisposition {
    std::string canonical_identity;
    std::string selected_overlay_file;
    std::string selected_overlay_sha256;
    std::string preset_directory;
    std::string preset_info_sha256;
};

struct RetiredDisposition {
    std::string canonical_identity;
    std::string overlay_file;
    std::string overlay_sha256;
};

struct AliasDisposition {
    std::string alias;
    std::string canonical_identity;
};

struct DispositionCatalog {
    std::vector<BindingDisposition> bindings;
    std::vector<RetiredDisposition> retired;
    std::vector<AliasDisposition> aliases;
    std::vector<BindingDiagnostic> diagnostics;
};

struct CompiledBinding {
    std::string canonical_identity;
    std::string overlay_id;
    std::string overlay_sha256;
    std::string preset_id;
    std::string preset_info_sha256;
    std::vector<std::string> aliases;
    std::vector<std::string> retired_overlay_ids;
};

struct CompileCounts {
    std::size_t discovered_overlays{0};
    std::size_t compiled_bindings{0};
    std::size_t retired_overlays{0};
    std::size_t aliases{0};
    std::size_t unresolved_entries{0};
    std::size_t ambiguous_aliases{0};
    std::size_t orphan_presets{0};
    std::size_t unbound_overlays{0};
};

struct CompileResult {
    CompileCounts counts;
    std::vector<CompiledBinding> bindings;
    std::vector<BindingDiagnostic> diagnostics;

    [[nodiscard]] bool success() const noexcept;
};

[[nodiscard]] std::string Sha256(std::string_view bytes);
[[nodiscard]] std::string Sha256File(const std::filesystem::path& path);
[[nodiscard]] OverlayMetadata ReadOverlayMetadata(const std::filesystem::path& path);
[[nodiscard]] PresetMetadata ReadPresetMetadata(const std::filesystem::path& directory);
[[nodiscard]] DispositionCatalog LoadDispositionCatalog(const std::filesystem::path& path);
[[nodiscard]] CompileResult CompileBindings(
    const std::filesystem::path& overlay_root,
    const std::filesystem::path& preset_root,
    const DispositionCatalog& catalog);
[[nodiscard]] bool HasDiagnostic(
    const CompileResult& result,
    BindingDiagnosticCode code) noexcept;
[[nodiscard]] bool WriteManifest(
    const std::filesystem::path& path,
    const CompileResult& result);
[[nodiscard]] bool WriteReport(
    const std::filesystem::path& path,
    const CompileResult& result);
[[nodiscard]] bool OutputPathsAreSafe(
    const std::filesystem::path& overlay_root,
    const std::filesystem::path& preset_root,
    const std::filesystem::path& manifest_path,
    const std::filesystem::path& report_path);
[[nodiscard]] std::optional<profiles::ProfilePackage> MakeProfilePackage(
    const CompileResult& result,
    std::string_view identity,
    std::vector<profiles::ProfileOperation> operations);
[[nodiscard]] std::string_view ToString(BindingDiagnosticCode code) noexcept;

}  // namespace elder::bindings
