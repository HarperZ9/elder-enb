#pragma once

#include "elder/bindings/LegacyKreateBindings.hpp"

#include <cstddef>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

namespace elder::improvement {

enum class BundleDiagnosticCode {
    InvalidManifest,
    UnsafeOutputPath,
    MissingProfileBinding,
    DuplicateProfile,
    DuplicateBundle,
    DuplicateRule,
    MissingSource,
    SourceHashMismatch,
    SourceTreeHashMismatch,
    AmbiguousFusedDepthOfField,
    RepairCountMismatch,
    MissingGuardedKey,
    DuplicateGuardedKey,
    GuardValueMismatch,
    InvalidTransform,
    ValueOutOfBounds,
    UnsupportedOverlayKey,
    MissingOverlayBindingField,
    AmbiguousOverlayBindingField,
    UnsupportedOverlayBinding,
    GeneratedAuditFailed,
    IdentityCountChanged,
    PairingMismatch,
    SourceChanged,
    IoError,
};

enum class RuleLayer {
    Overlay,
    Kreate,
};

enum class SemanticType {
    Scalar,
    Vector3,
    Vector4,
    OverlayOperation,
};

enum class RuleOperation {
    Set,
    Scale,
    ScaleRgb,
};

struct BundleDiagnostic {
    BundleDiagnosticCode code;
    std::string profile_id;
    std::string relative_path;
    std::string section;
    std::string key;

    bool operator==(const BundleDiagnostic&) const = default;
};

struct ProfileSpec {
    std::string bundle_id;
    std::string profile_id;
    std::string overlay_file;
    std::string overlay_sha256;
    std::string preset_directory;
    std::string preset_tree_sha256;
    std::size_t expected_repairs{0};
    std::string art_direction;

    bool operator==(const ProfileSpec&) const = default;
};

struct TransformRule {
    std::string profile_id;
    RuleLayer layer;
    std::string relative_path;
    std::string file_sha256;
    std::string section;
    std::string key;
    SemanticType semantic_type;
    std::string guard_value;
    RuleOperation operation;
    std::string operand;
    double min_value{0.0};
    double max_value{0.0};
    std::string rationale;

    bool operator==(const TransformRule&) const = default;
};

struct ImprovementManifest {
    std::vector<ProfileSpec> profiles;
    std::vector<TransformRule> rules;
    std::vector<BundleDiagnostic> diagnostics;
};

struct ProvenanceEntry {
    std::string profile_id;
    std::string layer;
    std::string relative_path;
    std::string source_sha256;
    std::string section;
    std::string key;
    std::string semantic_type;
    std::string guard_value;
    std::string operation;
    std::string operand;
    std::string output_value;
    std::string rationale;
    std::string target_filename;
    std::string target_category;
    std::string target_key;
    std::string target_type;
    std::string rationale_basis;

    bool operator==(const ProvenanceEntry&) const = default;
};

struct CompiledBundle {
    std::string bundle_id;
    std::string profile_id;
    std::string overlay_file;
    std::string preset_directory;
    std::size_t repairs{0};
    std::size_t overlay_changes{0};
    std::size_t kreate_changes{0};
    std::size_t export_name_debt{0};
    std::size_t record_files{0};
    std::string overlay_sha256;
    std::string preset_tree_sha256;
    std::string bundle_sha256;
    std::uintmax_t bundle_bytes{0};

    bool operator==(const CompiledBundle&) const = default;
};

struct BundleCompileCounts {
    std::size_t profiles{0};
    std::size_t copied_files{0};
    std::size_t repairs{0};
    std::size_t overlay_changes{0};
    std::size_t kreate_changes{0};
    std::size_t export_name_debt{0};
    std::size_t record_files{0};
};

struct BundleCompileResult {
    BundleCompileCounts counts;
    std::vector<CompiledBundle> bundles;
    std::vector<ProvenanceEntry> provenance;
    std::vector<BundleDiagnostic> diagnostics;

    [[nodiscard]] bool success() const noexcept;
};

[[nodiscard]] ImprovementManifest LoadImprovementManifest(
    const std::filesystem::path& path);
[[nodiscard]] BundleCompileResult CompileImprovedBundles(
    const std::filesystem::path& overlay_root,
    const std::filesystem::path& preset_root,
    const std::filesystem::path& output_root,
    const ImprovementManifest& manifest,
    const bindings::DispositionCatalog& catalog);
[[nodiscard]] bool HasDiagnostic(
    const BundleCompileResult& result,
    BundleDiagnosticCode code) noexcept;
[[nodiscard]] std::string DirectoryTreeHash(const std::filesystem::path& root);
[[nodiscard]] std::string_view ToString(BundleDiagnosticCode code) noexcept;
[[nodiscard]] std::string_view ToString(RuleLayer layer) noexcept;
[[nodiscard]] std::string_view ToString(SemanticType type) noexcept;
[[nodiscard]] std::string_view ToString(RuleOperation operation) noexcept;

}  // namespace elder::improvement
