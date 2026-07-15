#include "elder/profiles/TransactionalProfile.hpp"

#include <cmath>
#include <set>
#include <type_traits>
#include <utility>

namespace elder::profiles {
namespace {

[[nodiscard]] Diagnostic MakeDiagnostic(
    const DiagnosticCode code,
    const std::optional<std::size_t> operation_index = std::nullopt,
    std::string target_key = {}) {
    return Diagnostic{code, operation_index, std::move(target_key)};
}

[[nodiscard]] std::vector<Diagnostic> Validate(
    const ProfilePackage& package,
    const ValueMap& baseline) {
    std::vector<Diagnostic> diagnostics;

    if (package.overlay_id.empty()) {
        diagnostics.push_back(MakeDiagnostic(DiagnosticCode::EmptyOverlayId));
    }
    if (package.preset_id.empty()) {
        diagnostics.push_back(MakeDiagnostic(DiagnosticCode::EmptyPresetId));
    }
    if (package.operations.empty()) {
        diagnostics.push_back(MakeDiagnostic(DiagnosticCode::EmptyOperations));
    }

    std::set<std::string> seen_targets;
    for (std::size_t index = 0; index < package.operations.size(); ++index) {
        const auto& operation = package.operations[index];

        if (!baseline.contains(operation.target_key)) {
            diagnostics.push_back(MakeDiagnostic(
                DiagnosticCode::UnknownTargetKey,
                index,
                operation.target_key));
        }

        if (!seen_targets.insert(operation.target_key).second) {
            diagnostics.push_back(MakeDiagnostic(
                DiagnosticCode::DuplicateTargetKey,
                index,
                operation.target_key));
        }

        if (!std::isfinite(operation.operand)) {
            diagnostics.push_back(MakeDiagnostic(
                DiagnosticCode::NonFiniteValue,
                index,
                operation.target_key));
        } else if (operation.kind == OperationKind::Multiply && operation.operand <= 0.0) {
            diagnostics.push_back(MakeDiagnostic(
                DiagnosticCode::InvalidMultiplyOperand,
                index,
                operation.target_key));
        }
    }

    return diagnostics;
}

[[nodiscard]] ProfileReport SingleDiagnosticReport(
    const ProfileResult result,
    const std::uint64_t generation_before,
    const std::uint64_t generation_after,
    const DiagnosticCode diagnostic) {
    return ProfileReport{
        result,
        generation_before,
        generation_after,
        {MakeDiagnostic(diagnostic)},
    };
}

}  // namespace

bool ProfileReport::committed() const noexcept {
    return result == ProfileResult::Applied || result == ProfileResult::Removed;
}

std::string_view ToString(const DiagnosticCode code) noexcept {
    switch (code) {
    case DiagnosticCode::ProfileApplied:
        return "PROFILE_APPLIED";
    case DiagnosticCode::ProfileAlreadyActive:
        return "PROFILE_ALREADY_ACTIVE";
    case DiagnosticCode::ProfileRemoved:
        return "PROFILE_REMOVED";
    case DiagnosticCode::NoActiveProfile:
        return "NO_ACTIVE_PROFILE";
    case DiagnosticCode::EmptyOverlayId:
        return "EMPTY_OVERLAY_ID";
    case DiagnosticCode::EmptyPresetId:
        return "EMPTY_PRESET_ID";
    case DiagnosticCode::EmptyOperations:
        return "EMPTY_OPERATIONS";
    case DiagnosticCode::UnknownTargetKey:
        return "UNKNOWN_TARGET_KEY";
    case DiagnosticCode::DuplicateTargetKey:
        return "DUPLICATE_TARGET_KEY";
    case DiagnosticCode::NonFiniteValue:
        return "NON_FINITE_VALUE";
    case DiagnosticCode::InvalidMultiplyOperand:
        return "INVALID_MULTIPLY_OPERAND";
    }

    return "UNKNOWN_DIAGNOSTIC_CODE";
}

std::string_view ToString(const ProfileResult result) noexcept {
    switch (result) {
    case ProfileResult::Applied:
        return "APPLIED";
    case ProfileResult::Rejected:
        return "REJECTED";
    case ProfileResult::AlreadyActive:
        return "ALREADY_ACTIVE";
    case ProfileResult::Removed:
        return "REMOVED";
    case ProfileResult::NoActiveProfile:
        return "NO_ACTIVE_PROFILE";
    }

    return "UNKNOWN_PROFILE_RESULT";
}

TransactionalProfile::TransactionalProfile(ValueMap baseline)
    : baseline_(std::move(baseline)), values_(baseline_) {}

ProfileReport TransactionalProfile::Apply(const ProfilePackage& package) {
    auto diagnostics = Validate(package, baseline_);
    if (!diagnostics.empty()) {
        return ProfileReport{
            ProfileResult::Rejected,
            generation_,
            generation_,
            std::move(diagnostics),
        };
    }

    if (active_package_.has_value() && *active_package_ == package) {
        return SingleDiagnosticReport(
            ProfileResult::AlreadyActive,
            generation_,
            generation_,
            DiagnosticCode::ProfileAlreadyActive);
    }

    auto staged_values = baseline_;
    for (std::size_t index = 0; index < package.operations.size(); ++index) {
        const auto& operation = package.operations[index];
        auto& value = staged_values.at(operation.target_key);

        switch (operation.kind) {
        case OperationKind::Set:
            value = operation.operand;
            break;
        case OperationKind::Add:
            value += operation.operand;
            break;
        case OperationKind::Multiply:
            value *= operation.operand;
            break;
        }

        if (!std::isfinite(value)) {
            return ProfileReport{
                ProfileResult::Rejected,
                generation_,
                generation_,
                {MakeDiagnostic(DiagnosticCode::NonFiniteValue, index, operation.target_key)},
            };
        }
    }

    std::optional<ProfilePackage> staged_active{package};
    static_assert(std::is_nothrow_swappable_v<ValueMap>);
    static_assert(std::is_nothrow_swappable_v<std::optional<ProfilePackage>>);

    auto report = SingleDiagnosticReport(
        ProfileResult::Applied,
        generation_,
        generation_ + 1,
        DiagnosticCode::ProfileApplied);

    values_.swap(staged_values);
    active_package_.swap(staged_active);
    ++generation_;
    return report;
}

ProfileReport TransactionalProfile::RemoveActive() {
    if (!active_package_.has_value()) {
        return SingleDiagnosticReport(
            ProfileResult::NoActiveProfile,
            generation_,
            generation_,
            DiagnosticCode::NoActiveProfile);
    }

    auto staged_values = baseline_;
    auto report = SingleDiagnosticReport(
        ProfileResult::Removed,
        generation_,
        generation_ + 1,
        DiagnosticCode::ProfileRemoved);

    values_.swap(staged_values);
    active_package_.reset();
    ++generation_;
    return report;
}

const ValueMap& TransactionalProfile::values() const noexcept {
    return values_;
}

std::optional<ActiveProfileIdentity> TransactionalProfile::active_identity() const {
    if (!active_package_.has_value()) {
        return std::nullopt;
    }

    return ActiveProfileIdentity{
        active_package_->overlay_id,
        active_package_->preset_id,
    };
}

std::uint64_t TransactionalProfile::generation() const noexcept {
    return generation_;
}

}  // namespace elder::profiles
