#include "elder/profiles/TransactionalProfile.hpp"

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <iostream>
#include <limits>
#include <map>
#include <optional>
#include <source_location>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace {

using elder::profiles::ActiveProfileIdentity;
using elder::profiles::DiagnosticCode;
using elder::profiles::OperationKind;
using elder::profiles::ProfileOperation;
using elder::profiles::ProfilePackage;
using elder::profiles::ProfileReport;
using elder::profiles::ProfileResult;
using elder::profiles::ToString;
using elder::profiles::TransactionalProfile;
using elder::profiles::ValueMap;

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

[[nodiscard]] bool HasDiagnostic(const ProfileReport& report, const DiagnosticCode code) {
    for (const auto& diagnostic : report.diagnostics) {
        if (diagnostic.code == code) {
            return true;
        }
    }
    return false;
}

struct Snapshot {
    ValueMap values;
    std::optional<ActiveProfileIdentity> active_identity;
    std::uint64_t generation;
};

[[nodiscard]] Snapshot Capture(const TransactionalProfile& engine) {
    return Snapshot{engine.values(), engine.active_identity(), engine.generation()};
}

void CheckUnchanged(const TransactionalProfile& engine, const Snapshot& before) {
    CHECK(engine.values() == before.values);
    CHECK(engine.active_identity() == before.active_identity);
    CHECK(engine.generation() == before.generation);
}

[[nodiscard]] ProfilePackage ValidPackage() {
    return ProfilePackage{
        .overlay_id = "elder.overlay.cinematic",
        .preset_id = "elder.preset.twilight",
        .operations = {
            ProfileOperation{"exposure", OperationKind::Set, 4.0},
            ProfileOperation{"saturation", OperationKind::Add, 0.5},
            ProfileOperation{"gamma", OperationKind::Multiply, 2.0},
        },
    };
}

void CheckRejectedAndUnchanged(
    TransactionalProfile& engine,
    const ProfilePackage& package,
    const DiagnosticCode expected_code) {
    const auto before = Capture(engine);
    const auto report = engine.Apply(package);

    CHECK(report.result == ProfileResult::Rejected);
    CHECK(!report.committed());
    CHECK(report.generation_before == before.generation);
    CHECK(report.generation_after == before.generation);
    CHECK(!report.diagnostics.empty());
    CHECK(HasDiagnostic(report, expected_code));
    CheckUnchanged(engine, before);
}

void ApplyCommitsBoundPackageAtomically() {
    TransactionalProfile engine{{
        {"exposure", 1.0},
        {"gamma", 3.0},
        {"saturation", 2.0},
    }};

    const auto package = ValidPackage();
    const auto report = engine.Apply(package);

    CHECK(report.result == ProfileResult::Applied);
    CHECK(report.committed());
    CHECK(report.generation_before == 0);
    CHECK(report.generation_after == 1);
    CHECK(report.diagnostics.size() == 1);
    CHECK(report.diagnostics.front().code == DiagnosticCode::ProfileApplied);
    CHECK(engine.values().at("exposure") == 4.0);
    CHECK(engine.values().at("saturation") == 2.5);
    CHECK(engine.values().at("gamma") == 6.0);
    CHECK(engine.generation() == 1);
    CHECK(engine.active_identity().has_value());
    CHECK(engine.active_identity()->overlay_id == package.overlay_id);
    CHECK(engine.active_identity()->preset_id == package.preset_id);
}

void ApplyStagesEachPackageFromImmutableBaseline() {
    TransactionalProfile engine{{{"exposure", 10.0}}};
    const ProfilePackage additive{
        "overlay.add",
        "preset.add",
        {ProfileOperation{"exposure", OperationKind::Add, 5.0}},
    };
    const ProfilePackage multiplier{
        "overlay.multiply",
        "preset.multiply",
        {ProfileOperation{"exposure", OperationKind::Multiply, 2.0}},
    };

    CHECK(engine.Apply(additive).result == ProfileResult::Applied);
    CHECK(engine.values().at("exposure") == 15.0);
    CHECK(engine.Apply(multiplier).result == ProfileResult::Applied);
    CHECK(engine.values().at("exposure") == 20.0);
    CHECK(engine.generation() == 2);
}

void ExactReselectionIsAnExplicitIdempotentNoOp() {
    TransactionalProfile engine{{{"exposure", 10.0}}};
    const ProfilePackage package{
        "overlay.add",
        "preset.add",
        {ProfileOperation{"exposure", OperationKind::Add, 5.0}},
    };

    CHECK(engine.Apply(package).result == ProfileResult::Applied);
    const auto before = Capture(engine);
    const auto report = engine.Apply(package);

    CHECK(report.result == ProfileResult::AlreadyActive);
    CHECK(!report.committed());
    CHECK(report.generation_before == 1);
    CHECK(report.generation_after == 1);
    CHECK(report.diagnostics.size() == 1);
    CHECK(report.diagnostics.front().code == DiagnosticCode::ProfileAlreadyActive);
    CheckUnchanged(engine, before);
    CHECK(engine.values().at("exposure") == 15.0);
}

void ChangedPackageWithSameIdentityCommitsFromBaseline() {
    TransactionalProfile engine{{{"exposure", 10.0}}};
    ProfilePackage package{
        "overlay.add",
        "preset.add",
        {ProfileOperation{"exposure", OperationKind::Add, 5.0}},
    };

    CHECK(engine.Apply(package).result == ProfileResult::Applied);
    package.operations.front().operand = 7.0;
    const auto report = engine.Apply(package);

    CHECK(report.result == ProfileResult::Applied);
    CHECK(report.generation_before == 1);
    CHECK(report.generation_after == 2);
    CHECK(engine.generation() == 2);
    CHECK(engine.values().at("exposure") == 17.0);
}

void RejectsEmptyOverlayId() {
    TransactionalProfile engine{{{"exposure", 1.0}, {"gamma", 3.0}, {"saturation", 2.0}}};
    auto package = ValidPackage();
    package.overlay_id.clear();
    CheckRejectedAndUnchanged(engine, package, DiagnosticCode::EmptyOverlayId);
}

void RejectsEmptyPresetId() {
    TransactionalProfile engine{{{"exposure", 1.0}, {"gamma", 3.0}, {"saturation", 2.0}}};
    auto package = ValidPackage();
    package.preset_id.clear();
    CheckRejectedAndUnchanged(engine, package, DiagnosticCode::EmptyPresetId);
}

void RejectsEmptyOperations() {
    TransactionalProfile engine{{{"exposure", 1.0}, {"gamma", 3.0}, {"saturation", 2.0}}};
    auto package = ValidPackage();
    package.operations.clear();
    CheckRejectedAndUnchanged(engine, package, DiagnosticCode::EmptyOperations);
}

void RejectsUnknownTargetKey() {
    TransactionalProfile engine{{{"exposure", 1.0}, {"gamma", 3.0}, {"saturation", 2.0}}};
    auto package = ValidPackage();
    package.operations.front().target_key = "missing";
    CheckRejectedAndUnchanged(engine, package, DiagnosticCode::UnknownTargetKey);
}

void RejectsDuplicateTargetKey() {
    TransactionalProfile engine{{{"exposure", 1.0}, {"gamma", 3.0}, {"saturation", 2.0}}};
    auto package = ValidPackage();
    package.operations.at(1).target_key = package.operations.front().target_key;
    CheckRejectedAndUnchanged(engine, package, DiagnosticCode::DuplicateTargetKey);
}

void RejectsNonFiniteOperands() {
    TransactionalProfile engine{{{"exposure", 1.0}, {"gamma", 3.0}, {"saturation", 2.0}}};

    auto nan_package = ValidPackage();
    nan_package.operations.front().operand = std::numeric_limits<double>::quiet_NaN();
    CheckRejectedAndUnchanged(engine, nan_package, DiagnosticCode::NonFiniteValue);

    auto infinity_package = ValidPackage();
    infinity_package.operations.front().operand = std::numeric_limits<double>::infinity();
    CheckRejectedAndUnchanged(engine, infinity_package, DiagnosticCode::NonFiniteValue);
}

void RejectsInvalidMultiplyOperands() {
    TransactionalProfile engine{{{"exposure", 1.0}, {"gamma", 3.0}, {"saturation", 2.0}}};

    auto zero_package = ValidPackage();
    zero_package.operations.back().operand = 0.0;
    CheckRejectedAndUnchanged(engine, zero_package, DiagnosticCode::InvalidMultiplyOperand);

    auto negative_package = ValidPackage();
    negative_package.operations.back().operand = -1.0;
    CheckRejectedAndUnchanged(engine, negative_package, DiagnosticCode::InvalidMultiplyOperand);
}

void RejectsNonFiniteStagedResult() {
    TransactionalProfile engine{{{"exposure", std::numeric_limits<double>::max()}}};
    const ProfilePackage package{
        "overlay.overflow",
        "preset.overflow",
        {ProfileOperation{"exposure", OperationKind::Multiply, 2.0}},
    };

    CheckRejectedAndUnchanged(engine, package, DiagnosticCode::NonFiniteValue);
}

void ReportsAllErrorsBeforeMutationAndPreservesActiveState() {
    TransactionalProfile engine{{{"exposure", 10.0}, {"gamma", 2.0}}};
    const ProfilePackage active{
        "overlay.active",
        "preset.active",
        {ProfileOperation{"exposure", OperationKind::Add, 5.0}},
    };
    CHECK(engine.Apply(active).result == ProfileResult::Applied);
    const auto before = Capture(engine);

    const ProfilePackage malformed{
        "",
        "",
        {
            ProfileOperation{"exposure", OperationKind::Set, 20.0},
            ProfileOperation{"exposure", OperationKind::Add, 1.0},
            ProfileOperation{"missing", OperationKind::Set, std::numeric_limits<double>::quiet_NaN()},
        },
    };
    const auto report = engine.Apply(malformed);

    CHECK(report.result == ProfileResult::Rejected);
    CHECK(HasDiagnostic(report, DiagnosticCode::EmptyOverlayId));
    CHECK(HasDiagnostic(report, DiagnosticCode::EmptyPresetId));
    CHECK(HasDiagnostic(report, DiagnosticCode::DuplicateTargetKey));
    CHECK(HasDiagnostic(report, DiagnosticCode::UnknownTargetKey));
    CHECK(HasDiagnostic(report, DiagnosticCode::NonFiniteValue));
    CHECK(report.diagnostics.size() == 5);
    CheckUnchanged(engine, before);
}

void RemoveActiveRestoresBaselineAtomically() {
    const ValueMap baseline{{"exposure", 10.0}, {"gamma", 2.0}};
    TransactionalProfile engine{baseline};
    const ProfilePackage package{
        "overlay.active",
        "preset.active",
        {ProfileOperation{"exposure", OperationKind::Add, 5.0}},
    };
    CHECK(engine.Apply(package).result == ProfileResult::Applied);

    const auto report = engine.RemoveActive();

    CHECK(report.result == ProfileResult::Removed);
    CHECK(report.committed());
    CHECK(report.generation_before == 1);
    CHECK(report.generation_after == 2);
    CHECK(report.diagnostics.size() == 1);
    CHECK(report.diagnostics.front().code == DiagnosticCode::ProfileRemoved);
    CHECK(engine.values() == baseline);
    CHECK(!engine.active_identity().has_value());
    CHECK(engine.generation() == 2);
}

void RemoveWithoutActiveIsAnExplicitNoOp() {
    TransactionalProfile engine{{{"exposure", 10.0}}};
    const auto before = Capture(engine);

    const auto report = engine.RemoveActive();

    CHECK(report.result == ProfileResult::NoActiveProfile);
    CHECK(!report.committed());
    CHECK(report.generation_before == 0);
    CHECK(report.generation_after == 0);
    CHECK(report.diagnostics.size() == 1);
    CHECK(report.diagnostics.front().code == DiagnosticCode::NoActiveProfile);
    CheckUnchanged(engine, before);
}

void DiagnosticAndResultCodesAreStable() {
    CHECK(ToString(DiagnosticCode::ProfileApplied) == "PROFILE_APPLIED");
    CHECK(ToString(DiagnosticCode::ProfileAlreadyActive) == "PROFILE_ALREADY_ACTIVE");
    CHECK(ToString(DiagnosticCode::ProfileRemoved) == "PROFILE_REMOVED");
    CHECK(ToString(DiagnosticCode::NoActiveProfile) == "NO_ACTIVE_PROFILE");
    CHECK(ToString(DiagnosticCode::EmptyOverlayId) == "EMPTY_OVERLAY_ID");
    CHECK(ToString(DiagnosticCode::EmptyPresetId) == "EMPTY_PRESET_ID");
    CHECK(ToString(DiagnosticCode::EmptyOperations) == "EMPTY_OPERATIONS");
    CHECK(ToString(DiagnosticCode::UnknownTargetKey) == "UNKNOWN_TARGET_KEY");
    CHECK(ToString(DiagnosticCode::DuplicateTargetKey) == "DUPLICATE_TARGET_KEY");
    CHECK(ToString(DiagnosticCode::NonFiniteValue) == "NON_FINITE_VALUE");
    CHECK(ToString(DiagnosticCode::InvalidMultiplyOperand) == "INVALID_MULTIPLY_OPERAND");
    CHECK(ToString(ProfileResult::Applied) == "APPLIED");
    CHECK(ToString(ProfileResult::Rejected) == "REJECTED");
    CHECK(ToString(ProfileResult::AlreadyActive) == "ALREADY_ACTIVE");
    CHECK(ToString(ProfileResult::Removed) == "REMOVED");
    CHECK(ToString(ProfileResult::NoActiveProfile) == "NO_ACTIVE_PROFILE");
}

struct TestCase {
    std::string_view name;
    void (*run)();
};

}  // namespace

int main() {
    const std::vector<TestCase> tests{
        {"apply commits bound package atomically", ApplyCommitsBoundPackageAtomically},
        {"apply stages each package from immutable baseline", ApplyStagesEachPackageFromImmutableBaseline},
        {"exact reselection is an explicit idempotent no-op", ExactReselectionIsAnExplicitIdempotentNoOp},
        {"changed package with same identity commits from baseline", ChangedPackageWithSameIdentityCommitsFromBaseline},
        {"rejects empty overlay id", RejectsEmptyOverlayId},
        {"rejects empty preset id", RejectsEmptyPresetId},
        {"rejects empty operations", RejectsEmptyOperations},
        {"rejects unknown target key", RejectsUnknownTargetKey},
        {"rejects duplicate target key", RejectsDuplicateTargetKey},
        {"rejects non-finite operands", RejectsNonFiniteOperands},
        {"rejects invalid multiply operands", RejectsInvalidMultiplyOperands},
        {"rejects non-finite staged result", RejectsNonFiniteStagedResult},
        {"reports all errors before mutation and preserves active state", ReportsAllErrorsBeforeMutationAndPreservesActiveState},
        {"remove active restores baseline atomically", RemoveActiveRestoresBaselineAtomically},
        {"remove without active is an explicit no-op", RemoveWithoutActiveIsAnExplicitNoOp},
        {"diagnostic and result codes are stable", DiagnosticAndResultCodesAreStable},
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

    std::cout << passed << "/" << tests.size() << " behavioral tests passed\n";
    return passed == tests.size() ? 0 : 1;
}
