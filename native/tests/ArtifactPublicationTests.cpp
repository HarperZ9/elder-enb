#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include "elder/shaders/ArtifactPublication.hpp"
#include "ArtifactPublicationTestHooks.hpp"

#include <algorithm>
#include <cstdint>
#include <cwctype>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace {

using elder::shaders::ArtifactPayload;
using elder::shaders::ArtifactPublicationDiagnostic;
using elder::shaders::PublishArtifactSet;
using elder::shaders::testing::ArtifactPublicationFaults;
using elder::shaders::testing::PublishArtifactSetForTesting;

struct TestContext {
  std::size_t assertions{};
  std::vector<std::string> failures;

  void Expect(const bool condition, std::string message) {
    ++assertions;
    if (!condition) failures.push_back(std::move(message));
  }
};

[[nodiscard]] std::string ReadAll(const std::filesystem::path& path) {
  std::filesystem::path native_path = std::filesystem::absolute(path).lexically_normal();
  std::wstring extended = native_path.native();
  if (!extended.starts_with(L"\\\\?\\")) {
    if (extended.starts_with(L"\\\\")) {
      extended = L"\\\\?\\UNC\\" + extended.substr(2U);
    } else {
      extended = L"\\\\?\\" + extended;
    }
  }
  std::ifstream stream(std::filesystem::path{extended}, std::ios::binary);
  std::ostringstream bytes;
  bytes << stream.rdbuf();
  return bytes.str();
}

void WriteFixture(const std::filesystem::path& path, const std::string& bytes) {
  auto parent = std::filesystem::absolute(path.parent_path()).lexically_normal();
  std::wstring extended_parent = parent.native();
  if (!extended_parent.starts_with(L"\\\\?\\")) {
    if (extended_parent.starts_with(L"\\\\")) {
      extended_parent = L"\\\\?\\UNC\\" + extended_parent.substr(2U);
    } else {
      extended_parent = L"\\\\?\\" + extended_parent;
    }
  }
  std::error_code error;
  std::filesystem::create_directories(
      std::filesystem::path{extended_parent}, error);
  if (error) throw std::runtime_error("could not create publication fixture directory");

  auto native_path = std::filesystem::absolute(path).lexically_normal();
  std::wstring extended = native_path.native();
  if (!extended.starts_with(L"\\\\?\\")) {
    if (extended.starts_with(L"\\\\")) {
      extended = L"\\\\?\\UNC\\" + extended.substr(2U);
    } else {
      extended = L"\\\\?\\" + extended;
    }
  }
  std::ofstream stream(
      std::filesystem::path{extended}, std::ios::binary | std::ios::trunc);
  stream.write(bytes.data(), static_cast<std::streamsize>(bytes.size()));
  if (!stream) throw std::runtime_error("could not write publication fixture");
}

[[nodiscard]] std::filesystem::path ExtendedPath(
    const std::filesystem::path& path) {
  auto absolute = std::filesystem::absolute(path).lexically_normal();
  std::wstring extended = absolute.native();
  if (!extended.starts_with(L"\\\\?\\")) {
    if (extended.starts_with(L"\\\\")) {
      extended = L"\\\\?\\UNC\\" + extended.substr(2U);
    } else {
      extended = L"\\\\?\\" + extended;
    }
  }
  return std::filesystem::path{std::move(extended)};
}

[[nodiscard]] std::filesystem::path PublicationLockPath(
    const std::filesystem::path& destination) {
  std::wstring key = ExtendedPath(destination).native();
  std::transform(key.begin(), key.end(), key.begin(), [](const wchar_t value) {
    return static_cast<wchar_t>(std::towlower(value));
  });
  std::uint64_t hash = 14695981039346656037ULL;
  for (const wchar_t character : key) {
    const auto code = static_cast<std::uint32_t>(character);
    for (unsigned int shift = 0U; shift < 32U; shift += 8U) {
      hash ^= static_cast<std::uint8_t>((code >> shift) & 0xffU);
      hash *= 1099511628211ULL;
    }
  }
  std::ostringstream filename;
  filename << ".elder-owned-" << std::hex << std::setfill('0')
           << std::setw(16) << hash << ".lock";
  return destination.parent_path() / filename.str();
}

[[nodiscard]] bool HasOwnedDebris(const std::filesystem::path& directory) {
  for (const auto& entry : std::filesystem::directory_iterator(directory)) {
    if (entry.path().filename().string().find(".elder-owned-")
        != std::string::npos) {
      return true;
    }
  }
  return false;
}

[[nodiscard]] std::vector<ArtifactPayload> FourPayloads(
    const std::filesystem::path& directory,
    const std::string_view prefix) {
  return {
      {directory / "parameters.fxh", std::string{prefix} + "-hlsl"},
      {directory / "defaults.hpp", std::string{prefix} + "-cpp"},
      {directory / "manifest.json", std::string{prefix} + "-manifest"},
      {directory / "default.profile", std::string{prefix} + "-profile"},
  };
}

void SuccessfulSetIsAllOrNothingAndOwned(TestContext& context,
                                          const std::filesystem::path& root) {
  const auto directory = root / "success";
  auto payloads = FourPayloads(directory, "new");
  for (const auto& payload : payloads) {
    WriteFixture(payload.destination, "old");
  }
  const auto foreign = directory / "parameters.fxh.elder-owned-foreign.stage";
  WriteFixture(foreign, "foreign-owned-marker");
  const auto result = PublishArtifactSet(payloads);
  context.Expect(result.ok(), "four-output transaction was rejected: "
                                      + result.detail);
  for (const auto& payload : payloads) {
    context.Expect(ReadAll(payload.destination) == payload.bytes,
                   "published artifact bytes changed: "
                       + payload.destination.filename().string());
  }
  context.Expect(ReadAll(foreign) == "foreign-owned-marker",
                 "transaction removed a staging path it did not own");
  std::filesystem::remove(foreign);
  context.Expect(!HasOwnedDebris(directory),
                 "successful transaction left owned staging debris");
}

void LockedDestinationRollsBackEveryOutput(
    TestContext& context,
    const std::filesystem::path& root) {
  const auto directory = root / "rollback";
  auto payloads = FourPayloads(directory, "new");
  for (std::size_t index = 0U; index < payloads.size(); ++index) {
    WriteFixture(payloads[index].destination, "old-" + std::to_string(index));
  }
  HANDLE locked = CreateFileW(
      payloads[1].destination.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
      OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (locked == INVALID_HANDLE_VALUE) {
    throw std::runtime_error("could not lock rollback fixture");
  }
  const auto result = PublishArtifactSet(payloads);
  CloseHandle(locked);
  context.Expect(
      result.diagnostic == ArtifactPublicationDiagnostic::backup_failed,
      "locked destination returned the wrong transaction diagnostic");
  for (std::size_t index = 0U; index < payloads.size(); ++index) {
    context.Expect(ReadAll(payloads[index].destination)
                       == "old-" + std::to_string(index),
                   "failed transaction did not restore output "
                       + std::to_string(index));
  }
  context.Expect(!HasOwnedDebris(directory),
                 "failed transaction left owned staging debris");
}

void DuplicateDestinationsFailBeforeMutation(
    TestContext& context,
    const std::filesystem::path& root) {
  const auto directory = root / "duplicate";
  const auto destination = directory / "same.bin";
  WriteFixture(destination, "original");
  const std::vector<ArtifactPayload> payloads{
      {destination, std::string{"first\0binary", 12U}},
      {destination, "second"},
  };
  const auto result = PublishArtifactSet(payloads);
  context.Expect(
      result.diagnostic == ArtifactPublicationDiagnostic::duplicate_destination,
      "duplicate destination was not rejected");
  context.Expect(ReadAll(destination) == "original",
                 "duplicate rejection mutated its destination");
  context.Expect(!HasOwnedDebris(directory),
                 "duplicate rejection left owned staging debris");
}

void LongPathsPublishAndReplaceAsOneSet(
    TestContext& context,
    const std::filesystem::path& root) {
  auto directory = root / "long-path";
  for (int index = 0; index < 7; ++index) {
    directory /= "elder-native-release-publication-segment-0123456789";
  }
  context.Expect(
      std::filesystem::absolute(directory).native().size() > 260U,
      "long-path regression fixture did not cross MAX_PATH");

  auto payloads = FourPayloads(directory, "long-new");
  for (std::size_t index = 0U; index < payloads.size(); ++index) {
    WriteFixture(payloads[index].destination,
                 "long-old-" + std::to_string(index));
  }
  const auto result = PublishArtifactSet(payloads);
  context.Expect(result.ok(), "long-path artifact set was rejected: "
                                  + result.detail);
  for (const auto& payload : payloads) {
    context.Expect(
        ReadAll(payload.destination) == payload.bytes,
        "long-path artifact replacement changed bytes: "
            + payload.destination.filename().string());
  }

  std::error_code error;
  const auto extended_directory = ExtendedPath(directory);
  for (const auto& entry :
       std::filesystem::directory_iterator(extended_directory, error)) {
    context.Expect(
        entry.path().filename().wstring().find(L".elder-owned-")
            == std::wstring::npos,
        "long-path transaction left owned staging debris");
  }
  context.Expect(!error, "could not inspect long-path publication directory");
}

void ForeignLockCollisionIsPreserved(
    TestContext& context,
    const std::filesystem::path& root) {
  const auto directory = root / "foreign-lock";
  auto payloads = FourPayloads(directory, "new");
  WriteFixture(payloads.front().destination, "original");
  const auto foreign_lock = PublicationLockPath(payloads.front().destination);
  WriteFixture(foreign_lock, "foreign-lock-owner");

  const auto result = PublishArtifactSet(payloads);
  context.Expect(
      result.diagnostic == ArtifactPublicationDiagnostic::lock_failed,
      "foreign publication lock did not reject a colliding transaction");
  context.Expect(result.artifact_index == 0U,
                 "lock collision reported the wrong artifact index");
  context.Expect(ReadAll(payloads.front().destination) == "original",
                 "lock collision mutated an existing destination");
  context.Expect(ReadAll(foreign_lock) == "foreign-lock-owner",
                 "transaction removed a lock it did not own");

  std::error_code error;
  std::filesystem::remove(ExtendedPath(foreign_lock), error);
  context.Expect(!error, "could not remove foreign-lock test fixture");
  context.Expect(!HasOwnedDebris(directory),
                 "lock collision left transaction-owned debris");
}

void FailedEarlyStageCleanupIsNeverReportedAsOrdinaryStageFailure(
    TestContext& context,
    const std::filesystem::path& root) {
  const auto directory = root / "stage-cleanup-incomplete";
  auto payloads = FourPayloads(directory, "new");
  ArtifactPublicationFaults faults;
  faults.fail_stage_write_at = 1U;
  faults.fail_stage_cleanup_at = 0U;

  const auto result = PublishArtifactSetForTesting(payloads, faults);
  context.Expect(
      result.diagnostic
          == ArtifactPublicationDiagnostic::stage_cleanup_incomplete,
      "failed early stage cleanup was not reported distinctly");
  context.Expect(!result.ok(),
                 "failed early stage cleanup was silently successful");
  context.Expect(result.artifact_index == 0U,
                 "failed stage cleanup reported the wrong artifact index");
  context.Expect(result.detail.find("cleanup incomplete") != std::string::npos,
                 "failed stage cleanup omitted its cleanup state");
  context.Expect(HasOwnedDebris(directory),
                 "stage cleanup fault injection did not retain owned debris");
  for (const auto& payload : payloads) {
    context.Expect(ReadAll(payload.destination).empty(),
                   "failed staging unexpectedly published an output");
  }
}

void FailedPostCommitBackupCleanupIsNeverReportedAsSuccess(
    TestContext& context,
    const std::filesystem::path& root) {
  const auto directory = root / "backup-cleanup-incomplete";
  auto payloads = FourPayloads(directory, "replacement");
  for (std::size_t index = 0U; index < payloads.size(); ++index) {
    WriteFixture(payloads[index].destination,
                 "original-" + std::to_string(index));
  }
  ArtifactPublicationFaults faults;
  faults.fail_backup_cleanup_at = 2U;

  const auto result = PublishArtifactSetForTesting(payloads, faults);
  context.Expect(
      result.diagnostic
          == ArtifactPublicationDiagnostic::backup_cleanup_incomplete,
      "failed post-commit backup cleanup was not reported distinctly");
  context.Expect(!result.ok(),
                 "failed post-commit backup cleanup was silently successful");
  context.Expect(result.artifact_index == 2U,
                 "failed backup cleanup reported the wrong artifact index");
  context.Expect(result.detail.find("outputs were committed")
                     != std::string::npos,
                 "backup cleanup failure did not expose commit state");
  for (const auto& payload : payloads) {
    context.Expect(ReadAll(payload.destination) == payload.bytes,
                   "backup cleanup failure changed a committed output");
  }
  context.Expect(HasOwnedDebris(directory),
                 "backup cleanup fault injection did not retain owned debris");
}

}  // namespace

int main() {
  TestContext context;
  const auto root = std::filesystem::temp_directory_path()
      / ("elder-native-publication-" + std::to_string(GetCurrentProcessId()));
  std::error_code error;
  std::filesystem::remove_all(ExtendedPath(root), error);
  try {
    SuccessfulSetIsAllOrNothingAndOwned(context, root);
    LockedDestinationRollsBackEveryOutput(context, root);
    DuplicateDestinationsFailBeforeMutation(context, root);
    LongPathsPublishAndReplaceAsOneSet(context, root);
    ForeignLockCollisionIsPreserved(context, root);
    FailedEarlyStageCleanupIsNeverReportedAsOrdinaryStageFailure(context, root);
    FailedPostCommitBackupCleanupIsNeverReportedAsSuccess(context, root);
  } catch (const std::exception& exception) {
    context.Expect(false, std::string{"publication test exception: "}
                              + exception.what());
  }
  error.clear();
  std::filesystem::remove_all(ExtendedPath(root), error);
  context.Expect(!error, "could not remove publication test fixtures");
  if (!context.failures.empty()) {
    for (const auto& failure : context.failures) {
      std::cerr << "[FAIL] " << failure << '\n';
    }
    std::cerr << context.failures.size() << " failures across "
              << context.assertions << " assertions\n";
    return 1;
  }
  std::cout << "Elder artifact publication cases passed: "
            << context.assertions << " assertions\n";
  return 0;
}
