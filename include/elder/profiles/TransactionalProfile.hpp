#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace elder::profiles {

using ValueMap = std::map<std::string, double>;

enum class OperationKind {
    Set,
    Add,
    Multiply,
};

struct ProfileOperation {
    std::string target_key;
    OperationKind kind;
    double operand;

    bool operator==(const ProfileOperation&) const = default;
};

struct ProfilePackage {
    std::string overlay_id;
    std::string preset_id;
    std::vector<ProfileOperation> operations;

    bool operator==(const ProfilePackage&) const = default;
};

struct ActiveProfileIdentity {
    std::string overlay_id;
    std::string preset_id;

    bool operator==(const ActiveProfileIdentity&) const = default;
};

enum class ProfileResult {
    Applied,
    Rejected,
    AlreadyActive,
    Removed,
    NoActiveProfile,
};

enum class DiagnosticCode {
    ProfileApplied,
    ProfileAlreadyActive,
    ProfileRemoved,
    NoActiveProfile,
    EmptyOverlayId,
    EmptyPresetId,
    EmptyOperations,
    UnknownTargetKey,
    DuplicateTargetKey,
    NonFiniteValue,
    InvalidMultiplyOperand,
};

struct Diagnostic {
    DiagnosticCode code;
    std::optional<std::size_t> operation_index;
    std::string target_key;

    bool operator==(const Diagnostic&) const = default;
};

struct ProfileReport {
    ProfileResult result;
    std::uint64_t generation_before;
    std::uint64_t generation_after;
    std::vector<Diagnostic> diagnostics;

    [[nodiscard]] bool committed() const noexcept;
};

[[nodiscard]] std::string_view ToString(DiagnosticCode code) noexcept;
[[nodiscard]] std::string_view ToString(ProfileResult result) noexcept;

class TransactionalProfile final {
public:
    explicit TransactionalProfile(ValueMap baseline);

    [[nodiscard]] ProfileReport Apply(const ProfilePackage& package);
    [[nodiscard]] ProfileReport RemoveActive();

    [[nodiscard]] const ValueMap& values() const noexcept;
    [[nodiscard]] std::optional<ActiveProfileIdentity> active_identity() const;
    [[nodiscard]] std::uint64_t generation() const noexcept;

private:
    const ValueMap baseline_;
    ValueMap values_;
    std::optional<ProfilePackage> active_package_;
    std::uint64_t generation_{0};
};

}  // namespace elder::profiles
