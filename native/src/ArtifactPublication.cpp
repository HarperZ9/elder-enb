#include "elder/shaders/ArtifactPublication.hpp"
#include "elder/shaders/NativeFileIO.hpp"

#include "ArtifactPublicationTestHooks.hpp"

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cwctype>
#include <iomanip>
#include <limits>
#include <set>
#include <sstream>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

namespace elder::shaders {
namespace {

struct ArtifactState {
  const ArtifactPayload* payload{};
  std::filesystem::path destination;
  std::filesystem::path stage;
  std::filesystem::path backup;
  std::filesystem::path lock;
  std::wstring key;
  bool staged{};
  bool backed_up{};
  bool published{};
};

class OwnedLock final {
 public:
  OwnedLock() = default;
  OwnedLock(const OwnedLock&) = delete;
  OwnedLock& operator=(const OwnedLock&) = delete;

  OwnedLock(OwnedLock&& other) noexcept : handle_(other.handle_) {
    other.handle_ = INVALID_HANDLE_VALUE;
  }

  OwnedLock& operator=(OwnedLock&& other) noexcept {
    if (this != &other) {
      Release();
      handle_ = other.handle_;
      other.handle_ = INVALID_HANDLE_VALUE;
    }
    return *this;
  }

  ~OwnedLock() { Release(); }

  [[nodiscard]] bool Acquire(
      const std::filesystem::path& path,
      std::string& detail) noexcept {
    handle_ = CreateFileW(
        path.c_str(), GENERIC_READ | DELETE, 0U, nullptr, CREATE_NEW,
        FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_TEMPORARY
            | FILE_FLAG_DELETE_ON_CLOSE,
        nullptr);
    if (handle_ != INVALID_HANDLE_VALUE) return true;
    detail = "could not acquire owned artifact lock (Win32 "
        + std::to_string(GetLastError()) + ')';
    return false;
  }

 private:
  void Release() noexcept {
    if (handle_ != INVALID_HANDLE_VALUE) {
      CloseHandle(handle_);
      handle_ = INVALID_HANDLE_VALUE;
    }
  }

  HANDLE handle_{INVALID_HANDLE_VALUE};
};

[[nodiscard]] ArtifactPublicationResult Failure(
    const ArtifactPublicationDiagnostic diagnostic,
    const std::size_t index,
    std::string detail) {
  return {diagnostic, index, std::move(detail)};
}

[[nodiscard]] std::wstring DestinationKey(
    const std::filesystem::path& destination) {
  std::wstring key = native_io::NormalizePath(destination).native();
  std::transform(key.begin(), key.end(), key.begin(), [](const wchar_t value) {
    return static_cast<wchar_t>(std::towlower(value));
  });
  return key;
}

[[nodiscard]] std::uint64_t StablePathHash(const std::wstring_view value) {
  std::uint64_t hash = 14695981039346656037ULL;
  for (const wchar_t character : value) {
    const auto code = static_cast<std::uint32_t>(character);
    for (unsigned int shift = 0U; shift < 32U; shift += 8U) {
      hash ^= static_cast<std::uint8_t>((code >> shift) & 0xffU);
      hash *= 1099511628211ULL;
    }
  }
  return hash;
}

[[nodiscard]] std::string LockName(const std::wstring_view key) {
  std::ostringstream name;
  name << ".elder-owned-" << std::hex << std::setfill('0')
       << std::setw(16) << StablePathHash(key) << ".lock";
  return name.str();
}

[[nodiscard]] std::string TransactionToken() {
  static std::atomic<std::uint64_t> sequence{};
  const auto tick = static_cast<std::uint64_t>(
      std::chrono::steady_clock::now().time_since_epoch().count());
  std::ostringstream token;
  token << GetCurrentProcessId() << '-' << tick << '-'
        << sequence.fetch_add(1U, std::memory_order_relaxed);
  return token.str();
}

[[nodiscard]] bool WriteExclusive(
    const std::filesystem::path& path,
    const std::string& bytes,
    bool& owned,
    ArtifactPublicationDiagnostic& diagnostic,
    std::string& detail,
    const bool inject_write_failure) {
  HANDLE file = CreateFileW(
      path.c_str(), GENERIC_WRITE, 0U, nullptr, CREATE_NEW,
      FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_WRITE_THROUGH, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    diagnostic = ArtifactPublicationDiagnostic::stage_create_failed;
    detail = "could not exclusively create owned staging file (Win32 "
        + std::to_string(GetLastError()) + ')';
    return false;
  }
  owned = true;
  if (inject_write_failure) {
    CloseHandle(file);
    diagnostic = ArtifactPublicationDiagnostic::stage_write_failed;
    detail = "injected staging write failure";
    return false;
  }
  std::size_t offset = 0U;
  bool succeeded = true;
  while (offset < bytes.size()) {
    const auto remaining = bytes.size() - offset;
    const DWORD chunk = static_cast<DWORD>(std::min<std::size_t>(
        remaining, std::numeric_limits<DWORD>::max()));
    DWORD written{};
    if (WriteFile(file, bytes.data() + offset, chunk, &written, nullptr) == 0
        || written != chunk) {
      diagnostic = ArtifactPublicationDiagnostic::stage_write_failed;
      detail = "could not write owned staging file (Win32 "
          + std::to_string(GetLastError()) + ')';
      succeeded = false;
      break;
    }
    offset += written;
  }
  if (succeeded && FlushFileBuffers(file) == 0) {
    diagnostic = ArtifactPublicationDiagnostic::stage_write_failed;
    detail = "could not flush owned staging file (Win32 "
        + std::to_string(GetLastError()) + ')';
    succeeded = false;
  }
  if (CloseHandle(file) == 0 && succeeded) {
    diagnostic = ArtifactPublicationDiagnostic::stage_write_failed;
    detail = "could not close owned staging file (Win32 "
        + std::to_string(GetLastError()) + ')';
    succeeded = false;
  }
  return succeeded;
}

[[nodiscard]] bool RemoveOwned(
    const std::filesystem::path& path) noexcept {
  if (DeleteFileW(path.c_str()) != 0) return true;
  const DWORD error = GetLastError();
  return error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND;
}

[[nodiscard]] bool MoveOwned(
    const std::filesystem::path& source,
    const std::filesystem::path& destination,
    std::string& detail) noexcept {
  if (MoveFileExW(
          source.c_str(), destination.c_str(), MOVEFILE_WRITE_THROUGH) != 0) {
    return true;
  }
  detail = "Win32 " + std::to_string(GetLastError());
  return false;
}

enum class PathInspection { missing, regular, invalid, error };

[[nodiscard]] PathInspection InspectDestination(
    const std::filesystem::path& path,
    std::string& detail) noexcept {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES) {
    const DWORD error = GetLastError();
    if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
      return PathInspection::missing;
    }
    detail = "Win32 " + std::to_string(error);
    return PathInspection::error;
  }
  if ((attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT))
      != 0U) {
    return PathInspection::invalid;
  }
  return PathInspection::regular;
}

[[nodiscard]] bool CreateDirectories(
    const std::filesystem::path& extended_parent,
    std::string& detail) {
  std::error_code error;
  std::filesystem::create_directories(extended_parent, error);
  if (!error) return true;
  detail = error.message();
  return false;
}

[[nodiscard]] bool ShouldInject(
    const testing::ArtifactPublicationFaults* const faults,
    const std::size_t configured,
    const std::size_t index) noexcept {
  return faults != nullptr && configured == index;
}

[[nodiscard]] bool RemoveStage(
    ArtifactState& state,
    const std::size_t index,
    const testing::ArtifactPublicationFaults* const faults) noexcept {
  if (ShouldInject(faults, faults == nullptr
                               ? testing::no_publication_fault
                               : faults->fail_stage_cleanup_at,
                   index)) {
    return false;
  }
  return RemoveOwned(state.stage);
}

[[nodiscard]] bool RollBack(
    std::vector<ArtifactState>& states,
    const testing::ArtifactPublicationFaults* const faults) noexcept {
  bool success = true;
  for (auto iterator = states.rbegin(); iterator != states.rend(); ++iterator) {
    if (iterator->published) {
      if (!RemoveOwned(iterator->destination)) success = false;
      iterator->published = false;
    }
  }
  for (auto iterator = states.rbegin(); iterator != states.rend(); ++iterator) {
    if (iterator->backed_up) {
      std::string ignored;
      if (!MoveOwned(iterator->backup, iterator->destination, ignored)) {
        success = false;
      } else {
        iterator->backed_up = false;
      }
    }
  }
  for (std::size_t index = 0U; index < states.size(); ++index) {
    auto& state = states[index];
    if (state.staged) {
      if (!RemoveStage(state, index, faults)) {
        success = false;
      } else {
        state.staged = false;
      }
    }
  }
  return success;
}

[[nodiscard]] ArtifactPublicationResult PublishArtifactSetImpl(
    const std::span<const ArtifactPayload> artifacts,
    const testing::ArtifactPublicationFaults* const faults) noexcept {
  try {
    if (artifacts.empty()) {
      return Failure(
          ArtifactPublicationDiagnostic::empty_set, 0U,
          "artifact transaction is empty");
    }
    std::set<std::wstring> destinations;
    std::vector<ArtifactState> states;
    states.reserve(artifacts.size());
    for (std::size_t index = 0U; index < artifacts.size(); ++index) {
      if (artifacts[index].destination.empty()
          || artifacts[index].destination.filename().empty()) {
        return Failure(
            ArtifactPublicationDiagnostic::invalid_destination, index,
            "artifact destination is empty or has no filename");
      }
      std::wstring key = DestinationKey(artifacts[index].destination);
      if (!destinations.emplace(key).second) {
        return Failure(
            ArtifactPublicationDiagnostic::duplicate_destination, index,
            "artifact destinations must be unique");
      }
      const auto destination = native_io::NormalizePath(
          artifacts[index].destination);
      std::string detail;
      const auto inspection = InspectDestination(destination, detail);
      if (inspection == PathInspection::error) {
        return Failure(
            ArtifactPublicationDiagnostic::invalid_destination, index,
            "could not inspect artifact destination: " + detail);
      }
      if (inspection == PathInspection::invalid) {
        return Failure(
            ArtifactPublicationDiagnostic::invalid_destination, index,
            "artifact destination exists but is not a regular file");
      }

      const auto parent = destination.parent_path();
      states.push_back({
          &artifacts[index], destination, {}, {}, {}, std::move(key)});
      states.back().lock = parent / LockName(states.back().key);
    }

    const std::string token = TransactionToken();
    for (std::size_t index = 0U; index < artifacts.size(); ++index) {
      auto& state = states[index];
      const auto parent = state.destination.parent_path();
      std::string detail;
      if (!CreateDirectories(parent, detail)) {
        return Failure(
            ArtifactPublicationDiagnostic::create_directory_failed, index,
            "could not create artifact directory: " + detail);
      }
      const std::string owned_base = ".elder-owned-" + token + '-'
          + std::to_string(index);
      state.stage = parent / (owned_base + ".stage");
      state.backup = parent / (owned_base + ".backup");
    }

    std::vector<std::size_t> lock_order(states.size());
    for (std::size_t index = 0U; index < states.size(); ++index) {
      lock_order[index] = index;
    }
    std::sort(
        lock_order.begin(), lock_order.end(), [&](const auto left,
                                                  const auto right) {
          return states[left].key < states[right].key;
        });
    std::vector<OwnedLock> locks;
    locks.reserve(states.size());
    for (const std::size_t index : lock_order) {
      OwnedLock lock;
      std::string detail;
      if (!lock.Acquire(states[index].lock, detail)) {
        return Failure(
            ArtifactPublicationDiagnostic::lock_failed, index,
            std::move(detail));
      }
      locks.push_back(std::move(lock));
    }

    for (std::size_t index = 0U; index < states.size(); ++index) {
      ArtifactPublicationDiagnostic diagnostic{};
      std::string detail;
      const bool inject_write_failure = faults != nullptr
          && faults->fail_stage_write_at == index;
      if (!WriteExclusive(
              states[index].stage, states[index].payload->bytes,
              states[index].staged, diagnostic, detail,
              inject_write_failure)) {
        std::size_t cleanup_failure = testing::no_publication_fault;
        for (std::size_t cleanup_index = 0U;
             cleanup_index < states.size(); ++cleanup_index) {
          auto& state = states[cleanup_index];
          if (!state.staged) continue;
          if (RemoveStage(state, cleanup_index, faults)) {
            state.staged = false;
          } else if (cleanup_failure == testing::no_publication_fault) {
            cleanup_failure = cleanup_index;
          }
        }
        if (cleanup_failure != testing::no_publication_fault) {
          return Failure(
              ArtifactPublicationDiagnostic::stage_cleanup_incomplete,
              cleanup_failure,
              "staging failed at output " + std::to_string(index)
                  + "; owned stage cleanup incomplete");
        }
        return Failure(diagnostic, index, std::move(detail));
      }
    }

    for (std::size_t index = 0U; index < states.size(); ++index) {
      auto& state = states[index];
      std::string inspection_detail;
      const auto inspection =
          InspectDestination(state.destination, inspection_detail);
      if (inspection == PathInspection::error
          || inspection == PathInspection::invalid) {
        const std::string failure_detail =
            inspection == PathInspection::invalid
                ? "destination became non-regular before backup"
                : "could not inspect destination before backup: "
                    + inspection_detail;
        const bool rolled_back = RollBack(states, faults);
        return Failure(
            rolled_back ? ArtifactPublicationDiagnostic::backup_failed
                        : ArtifactPublicationDiagnostic::rollback_failed,
            index, failure_detail);
      }
      if (inspection == PathInspection::regular) {
        std::string move_detail;
        if (!MoveOwned(state.destination, state.backup, move_detail)) {
          const std::string failure_detail =
              "could not back up existing artifact: " + move_detail;
          const bool rolled_back = RollBack(states, faults);
          return Failure(
              rolled_back ? ArtifactPublicationDiagnostic::backup_failed
                          : ArtifactPublicationDiagnostic::rollback_failed,
              index, failure_detail);
        }
        state.backed_up = true;
      }
    }

    for (std::size_t index = 0U; index < states.size(); ++index) {
      auto& state = states[index];
      std::string move_detail;
      if (!MoveOwned(state.stage, state.destination, move_detail)) {
        const std::string detail =
            "could not publish staged artifact: " + move_detail;
        const bool rolled_back = RollBack(states, faults);
        return Failure(
            rolled_back ? ArtifactPublicationDiagnostic::publish_failed
                        : ArtifactPublicationDiagnostic::rollback_failed,
            index, detail);
      }
      state.staged = false;
      state.published = true;
    }

    std::size_t cleanup_failure = testing::no_publication_fault;
    for (std::size_t index = 0U; index < states.size(); ++index) {
      auto& state = states[index];
      if (!state.backed_up) continue;
      const bool removed = faults != nullptr
              && faults->fail_backup_cleanup_at == index
          ? false
          : RemoveOwned(state.backup);
      if (removed) {
        state.backed_up = false;
      } else if (cleanup_failure == testing::no_publication_fault) {
        cleanup_failure = index;
      }
    }
    if (cleanup_failure != testing::no_publication_fault) {
      return Failure(
          ArtifactPublicationDiagnostic::backup_cleanup_incomplete,
          cleanup_failure,
          "outputs were committed, but owned backup cleanup incomplete");
    }
    return {};
  } catch (const std::exception& error) {
    return Failure(
        ArtifactPublicationDiagnostic::exception, 0U,
        std::string{"artifact transaction exception: "} + error.what());
  } catch (...) {
    return Failure(
        ArtifactPublicationDiagnostic::exception, 0U,
        "artifact transaction exception");
  }
}

}  // namespace

ArtifactPublicationResult PublishArtifactSet(
    const std::span<const ArtifactPayload> artifacts) noexcept {
  return PublishArtifactSetImpl(artifacts, nullptr);
}

namespace testing {

ArtifactPublicationResult PublishArtifactSetForTesting(
    const std::span<const ArtifactPayload> artifacts,
    const ArtifactPublicationFaults& faults) noexcept {
  return PublishArtifactSetImpl(artifacts, &faults);
}

}  // namespace testing

}  // namespace elder::shaders
