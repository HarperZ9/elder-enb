#include "elder/weather/detail/OwnedOutputTransaction.hpp"

#include "elder/bindings/LegacyKreateBindings.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <fstream>
#include <iterator>
#include <ranges>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#else
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#endif

namespace elder::weather::detail {
namespace {

namespace fs = std::filesystem;

constexpr std::string_view kMarkerName = ".elder-weather-owner";
constexpr std::string_view kMarkerVersion = "ELDER_WEATHER_OWNED_V2";

#ifdef _WIN32
[[nodiscard]] fs::path LongPathSafe(const fs::path& path) {
    if (path.empty()) {
        return path;
    }
    std::error_code error;
    const auto absolute = path.is_absolute() ? path : fs::absolute(path, error);
    if (error) {
        return path;
    }
    const auto normalized = absolute.lexically_normal();
    const auto& native = normalized.native();
    constexpr std::wstring_view extended_prefix{L"\\\\?\\"};
    constexpr std::wstring_view unc_prefix{L"\\\\"};
    if (native.starts_with(extended_prefix)) {
        return normalized;
    }
    if (native.starts_with(unc_prefix)) {
        return fs::path{
            std::wstring{L"\\\\?\\UNC\\"} + native.substr(unc_prefix.size())};
    }
    return fs::path{std::wstring{extended_prefix} + native};
}
#else
[[nodiscard]] fs::path LongPathSafe(const fs::path& path) {
    return path;
}
#endif

[[nodiscard]] std::string RoleName(const OwnedTreeRole role) {
    switch (role) {
        case OwnedTreeRole::Stage: return "stage";
        case OwnedTreeRole::Output: return "output";
        case OwnedTreeRole::Backup: return "backup";
        case OwnedTreeRole::Scratch: return "scratch";
    }
    return {};
}

[[nodiscard]] std::string MarkerBytes(
    const OwnedTreeRole role,
    const std::string_view transaction_id) {
    std::string bytes = std::string{kMarkerVersion} + "\nrole=" + RoleName(role) + "\n";
    if (role != OwnedTreeRole::Output) {
        bytes += "transaction=" + std::string{transaction_id} + "\n";
    }
    return bytes;
}

[[nodiscard]] std::optional<std::string> ReadFile(const fs::path& path) {
    std::ifstream input{LongPathSafe(path), std::ios::binary};
    if (!input) {
        return std::nullopt;
    }
    return std::string{
        std::istreambuf_iterator<char>{input},
        std::istreambuf_iterator<char>{}};
}

[[nodiscard]] bool IsRootPath(const fs::path& path) {
    return path.empty() || path == path.root_path();
}

#ifdef _WIN32
[[nodiscard]] bool IsReparsePoint(const fs::path& path) {
    const auto attributes = GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES
        && (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
}

[[nodiscard]] bool HasReparseComponent(const fs::path& path) {
    std::error_code error;
    const auto absolute = LongPathSafe(path).lexically_normal();
    if (error) {
        return true;
    }
    auto current = absolute.root_path();
    for (const auto& component : absolute.relative_path()) {
        current /= component;
        const auto attributes = GetFileAttributesW(current.c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES) {
            break;
        }
        if ((attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
            return true;
        }
    }
    return false;
}

[[nodiscard]] std::optional<fs::path> FinalPath(const fs::path& path) {
    std::error_code error;
    auto existing = LongPathSafe(path).lexically_normal();
    if (error) {
        return std::nullopt;
    }
    std::vector<fs::path> tail;
    while (!fs::exists(existing, error)) {
        if (error || IsRootPath(existing)) {
            return std::nullopt;
        }
        tail.push_back(existing.filename());
        existing = existing.parent_path();
    }
    if (HasReparseComponent(existing)) {
        return std::nullopt;
    }
    const HANDLE handle = CreateFileW(
        existing.c_str(),
        0,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        nullptr,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS,
        nullptr);
    if (handle == INVALID_HANDLE_VALUE) {
        return std::nullopt;
    }
    const DWORD required = GetFinalPathNameByHandleW(
        handle,
        nullptr,
        0,
        FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    if (required == 0) {
        CloseHandle(handle);
        return std::nullopt;
    }
    std::wstring value(required, L'\0');
    const DWORD written = GetFinalPathNameByHandleW(
        handle,
        value.data(),
        required,
        FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    CloseHandle(handle);
    if (written == 0 || written >= required) {
        return std::nullopt;
    }
    value.resize(written);
    fs::path resolved{value};
    for (auto iterator = tail.rbegin(); iterator != tail.rend(); ++iterator) {
        resolved /= *iterator;
    }
    return resolved.lexically_normal();
}

[[nodiscard]] bool EqualComponent(const fs::path& left, const fs::path& right) {
    const auto& lhs = left.native();
    const auto& rhs = right.native();
    return CompareStringOrdinal(
               lhs.data(),
               static_cast<int>(lhs.size()),
               rhs.data(),
               static_cast<int>(rhs.size()),
               TRUE)
        == CSTR_EQUAL;
}

[[nodiscard]] std::wstring LowerInvariant(std::wstring value) {
    if (value.empty()) {
        return value;
    }
    const int required = LCMapStringEx(
        LOCALE_NAME_INVARIANT,
        LCMAP_LOWERCASE,
        value.data(),
        static_cast<int>(value.size()),
        nullptr,
        0,
        nullptr,
        nullptr,
        0);
    if (required <= 0) {
        return value;
    }
    std::wstring lowered(static_cast<std::size_t>(required), L'\0');
    const int written = LCMapStringEx(
        LOCALE_NAME_INVARIANT,
        LCMAP_LOWERCASE,
        value.data(),
        static_cast<int>(value.size()),
        lowered.data(),
        required,
        nullptr,
        nullptr,
        0);
    if (written != required) {
        return value;
    }
    return lowered;
}
#else
[[nodiscard]] bool HasReparseComponent(const fs::path& path) {
    std::error_code error;
    auto current = fs::absolute(path, error).root_path();
    if (error) {
        return true;
    }
    for (const auto& component : fs::absolute(path).relative_path()) {
        current /= component;
        if (!fs::exists(current, error)) {
            break;
        }
        if (error || fs::is_symlink(fs::symlink_status(current, error)) || error) {
            return true;
        }
    }
    return false;
}

[[nodiscard]] std::optional<fs::path> FinalPath(const fs::path& path) {
    std::error_code error;
    const auto resolved = fs::weakly_canonical(path, error);
    if (error || HasReparseComponent(path)) {
        return std::nullopt;
    }
    return resolved;
}

[[nodiscard]] bool EqualComponent(const fs::path& left, const fs::path& right) {
    return left == right;
}
#endif

[[nodiscard]] bool IsComponentPrefix(const fs::path& prefix, const fs::path& path) {
    auto prefix_iterator = prefix.begin();
    auto path_iterator = path.begin();
    while (prefix_iterator != prefix.end()) {
        if (path_iterator == path.end()
            || !EqualComponent(*prefix_iterator, *path_iterator)) {
            return false;
        }
        ++prefix_iterator;
        ++path_iterator;
    }
    return true;
}

[[nodiscard]] bool SameFileIdentity(const fs::path& left, const fs::path& right) {
    std::error_code error;
    if (!fs::exists(left, error) || error || !fs::exists(right, error) || error) {
        return false;
    }
#ifdef _WIN32
    const auto open = [](const fs::path& path) {
        return CreateFileW(
            LongPathSafe(path).c_str(),
            0,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            nullptr,
            OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS,
            nullptr);
    };
    const HANDLE left_handle = open(left);
    const HANDLE right_handle = open(right);
    if (left_handle == INVALID_HANDLE_VALUE || right_handle == INVALID_HANDLE_VALUE) {
        if (left_handle != INVALID_HANDLE_VALUE) {
            CloseHandle(left_handle);
        }
        if (right_handle != INVALID_HANDLE_VALUE) {
            CloseHandle(right_handle);
        }
        return false;
    }
    BY_HANDLE_FILE_INFORMATION left_info{};
    BY_HANDLE_FILE_INFORMATION right_info{};
    const bool loaded = GetFileInformationByHandle(left_handle, &left_info) != 0
        && GetFileInformationByHandle(right_handle, &right_info) != 0;
    CloseHandle(left_handle);
    CloseHandle(right_handle);
    return loaded && left_info.dwVolumeSerialNumber == right_info.dwVolumeSerialNumber
        && left_info.nFileIndexHigh == right_info.nFileIndexHigh
        && left_info.nFileIndexLow == right_info.nFileIndexLow;
#else
    return fs::equivalent(left, right, error) && !error;
#endif
}

[[nodiscard]] std::string ComparablePathBytes(const fs::path& path) {
    const auto resolved = FinalPath(path).value_or(path.lexically_normal());
#ifdef _WIN32
    const auto lowered = LowerInvariant(resolved.native());
    const int required = WideCharToMultiByte(
        CP_UTF8,
        WC_ERR_INVALID_CHARS,
        lowered.data(),
        static_cast<int>(lowered.size()),
        nullptr,
        0,
        nullptr,
        nullptr);
    if (required <= 0) {
        return {};
    }
    std::string bytes(static_cast<std::size_t>(required), '\0');
    const int written = WideCharToMultiByte(
        CP_UTF8,
        WC_ERR_INVALID_CHARS,
        lowered.data(),
        static_cast<int>(lowered.size()),
        bytes.data(),
        required,
        nullptr,
        nullptr);
    return written == required ? bytes : std::string{};
#else
    return resolved.generic_string();
#endif
}

[[nodiscard]] bool DefaultRename(
    const fs::path& source,
    const fs::path& target,
    std::error_code& error) {
    fs::rename(LongPathSafe(source), LongPathSafe(target), error);
    return !error;
}

}  // namespace

bool PathsAreSafelyDisjoint(const fs::path& input, const fs::path& output) {
    std::error_code error;
    if (input.empty() || output.empty() || !fs::is_directory(input, error) || error
        || IsRootPath(output.lexically_normal()) || HasReparseComponent(input)
        || HasReparseComponent(output)) {
        return false;
    }
    const auto resolved_input = FinalPath(input);
    const auto resolved_output = FinalPath(output);
    if (!resolved_input.has_value() || !resolved_output.has_value()
        || IsRootPath(*resolved_output)
        || IsComponentPrefix(*resolved_input, *resolved_output)
        || IsComponentPrefix(*resolved_output, *resolved_input)
        || SameFileIdentity(input, output)) {
        return false;
    }
    return true;
}

std::string NewTransactionId() {
    static std::atomic<unsigned long long> sequence{0};
    const auto ticks = std::chrono::steady_clock::now().time_since_epoch().count();
#ifdef _WIN32
    const auto process = static_cast<unsigned long long>(GetCurrentProcessId());
#else
    const auto process = static_cast<unsigned long long>(getpid());
#endif
    return std::to_string(process) + '-' + std::to_string(ticks) + '-'
        + std::to_string(sequence.fetch_add(1));
}

std::optional<fs::path> CreateOwnedTree(
    const fs::path& parent,
    const std::string_view prefix,
    const OwnedTreeRole role,
    const std::string_view transaction_id) {
    if (prefix.empty() || prefix.size() > 8 || transaction_id.empty()
        || !std::ranges::all_of(prefix, [](const unsigned char character) {
               return (character >= 'a' && character <= 'z')
                   || (character >= '0' && character <= '9') || character == '-';
           })) {
        return std::nullopt;
    }
    std::error_code error;
    const auto safe_parent = LongPathSafe(parent);
    fs::create_directories(safe_parent, error);
    if (error || HasReparseComponent(safe_parent)) {
        return std::nullopt;
    }
    const auto alias = bindings::Sha256(
        std::string{prefix} + ':' + std::string{transaction_id}).substr(0, 4);
    for (std::size_t attempt = 0; attempt < 16; ++attempt) {
        constexpr std::string_view attempt_digits{"0123456789abcdef"};
        const std::string candidate_name = "." + std::string{prefix.back()}
            + alias + attempt_digits[attempt];
        const auto candidate = parent
            / candidate_name;
        const auto safe_candidate = LongPathSafe(candidate);
        error.clear();
        if (!fs::create_directory(safe_candidate, error) || error) {
            continue;
        }
        if (WriteOwnershipMarker(candidate, role, transaction_id)) {
            return candidate;
        }
        fs::remove(safe_candidate, error);
        return std::nullopt;
    }
    return std::nullopt;
}

bool WriteOwnershipMarker(
    const fs::path& root,
    const OwnedTreeRole role,
    const std::string_view transaction_id) {
    const auto safe_root = LongPathSafe(root);
    if (!fs::is_directory(safe_root)
        || (role != OwnedTreeRole::Output && transaction_id.empty())) {
        return false;
    }
    std::ofstream output{
        safe_root / kMarkerName,
        std::ios::binary | std::ios::trunc};
    const auto bytes = MarkerBytes(role, transaction_id);
    output.write(bytes.data(), static_cast<std::streamsize>(bytes.size()));
    return static_cast<bool>(output);
}

bool HasOwnershipMarker(
    const fs::path& root,
    const OwnedTreeRole role,
    const std::string_view transaction_id) {
    const auto bytes = ReadFile(root / kMarkerName);
    return bytes.has_value() && *bytes == MarkerBytes(role, transaction_id);
}

bool RemoveOwnedTree(
    const fs::path& root,
    const OwnedTreeRole role,
    const std::string_view transaction_id) {
    if (!HasOwnershipMarker(root, role, transaction_id) || HasReparseComponent(root)) {
        return false;
    }
    std::error_code error;
    const auto safe_root = LongPathSafe(root);
    fs::remove_all(safe_root, error);
    return !error && !fs::exists(safe_root, error) && !error;
}

fs::path OutputLockPath(const fs::path& output) {
    const auto comparable = ComparablePathBytes(output);
    const auto digest = bindings::Sha256(comparable);
    return output.parent_path() / (".elder-weather-lock-" + digest.substr(0, 24) + ".lck");
}

ExclusiveOutputLock::ExclusiveOutputLock(
    const std::intptr_t native_handle,
    fs::path path)
    : native_handle_(native_handle), path_(std::move(path)) {}

ExclusiveOutputLock::ExclusiveOutputLock(ExclusiveOutputLock&& other) noexcept
    : native_handle_(other.native_handle_), path_(std::move(other.path_)) {
    other.native_handle_ = -1;
}

ExclusiveOutputLock& ExclusiveOutputLock::operator=(ExclusiveOutputLock&& other) noexcept {
    if (this != &other) {
        Close();
        native_handle_ = other.native_handle_;
        path_ = std::move(other.path_);
        other.native_handle_ = -1;
    }
    return *this;
}

ExclusiveOutputLock::~ExclusiveOutputLock() {
    Close();
}

std::optional<ExclusiveOutputLock> ExclusiveOutputLock::Acquire(const fs::path& output) {
    const auto lock_path = OutputLockPath(output);
    std::error_code error;
    fs::create_directories(lock_path.parent_path(), error);
    if (error || HasReparseComponent(lock_path.parent_path())) {
        return std::nullopt;
    }
#ifdef _WIN32
    const HANDLE handle = CreateFileW(
        LongPathSafe(lock_path).c_str(),
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        nullptr);
    if (handle == INVALID_HANDLE_VALUE) {
        return std::nullopt;
    }
    return ExclusiveOutputLock{reinterpret_cast<std::intptr_t>(handle), lock_path};
#else
    const int descriptor = open(lock_path.c_str(), O_CREAT | O_RDWR, 0600);
    if (descriptor < 0 || flock(descriptor, LOCK_EX | LOCK_NB) != 0) {
        if (descriptor >= 0) {
            close(descriptor);
        }
        return std::nullopt;
    }
    return ExclusiveOutputLock{descriptor, lock_path};
#endif
}

const fs::path& ExclusiveOutputLock::path() const noexcept {
    return path_;
}

void ExclusiveOutputLock::Close() noexcept {
    if (native_handle_ == -1) {
        return;
    }
#ifdef _WIN32
    CloseHandle(reinterpret_cast<HANDLE>(native_handle_));
#else
    flock(static_cast<int>(native_handle_), LOCK_UN);
    close(static_cast<int>(native_handle_));
#endif
    native_handle_ = -1;
}

PublicationResult PublishOwnedTree(
    const fs::path& stage,
    const fs::path& output,
    const std::string_view transaction_id,
    RenameOperation rename,
    RemoveOperation remove) {
    PublicationResult result;
    if (!HasOwnershipMarker(stage, OwnedTreeRole::Stage, transaction_id)
        || HasReparseComponent(stage) || HasReparseComponent(output)) {
        return result;
    }
    std::error_code error;
    const bool had_output = fs::exists(output, error) && !error;
    if (error || (had_output
                  && !HasOwnershipMarker(output, OwnedTreeRole::Output, {}))) {
        return result;
    }
    if (!rename) {
        rename = DefaultRename;
    }
    if (!remove) {
        remove = RemoveOwnedTree;
    }
    const auto backup_alias = bindings::Sha256(
        std::string{"backup:"} + std::string{transaction_id}).substr(0, 6);
    const auto backup = output.parent_path() / (".b" + backup_alias);
    if (fs::exists(backup, error) || error) {
        return result;
    }

    if (had_output) {
        error.clear();
        if (!rename(output, backup, error) || error
            || !WriteOwnershipMarker(
                backup,
                OwnedTreeRole::Backup,
                transaction_id)) {
            if (fs::exists(backup, error) && !fs::exists(output, error)) {
                error.clear();
                if (rename(backup, output, error) && !error) {
                    static_cast<void>(
                        WriteOwnershipMarker(output, OwnedTreeRole::Output, {}));
                    result.rolled_back = true;
                }
            }
            return result;
        }
    }

    error.clear();
    if (!rename(stage, output, error) || error
        || !WriteOwnershipMarker(output, OwnedTreeRole::Output, {})) {
        if (fs::exists(output, error) && !fs::exists(stage, error)) {
            error.clear();
            static_cast<void>(rename(output, stage, error));
        }
        if (had_output && fs::exists(backup, error) && !fs::exists(output, error)) {
            error.clear();
            if (rename(backup, output, error) && !error) {
                static_cast<void>(
                    WriteOwnershipMarker(output, OwnedTreeRole::Output, {}));
                result.rolled_back = true;
            }
        } else if (!had_output) {
            result.rolled_back = fs::exists(stage, error) && !error;
        }
        return result;
    }

    result.committed = true;
    if (!had_output) {
        result.cleanup_complete = true;
        result.success = true;
        return result;
    }

    result.cleanup_complete = remove(
        backup,
        OwnedTreeRole::Backup,
        transaction_id);
    if (!result.cleanup_complete) {
        if (!HasOwnershipMarker(backup, OwnedTreeRole::Backup, transaction_id)
            || !HasOwnershipMarker(output, OwnedTreeRole::Output, {})) {
            return result;
        }
        error.clear();
        if (!rename(output, stage, error) || error) {
            return result;
        }
        result.committed = false;
        error.clear();
        if (rename(backup, output, error) && !error
            && WriteOwnershipMarker(output, OwnedTreeRole::Output, {})) {
            result.rolled_back = true;
            static_cast<void>(
                WriteOwnershipMarker(stage, OwnedTreeRole::Stage, transaction_id));
            return result;
        }

        if (fs::exists(output, error) && !error) {
            error.clear();
            static_cast<void>(rename(output, backup, error));
        }
        error.clear();
        if (rename(stage, output, error) && !error
            && (HasOwnershipMarker(output, OwnedTreeRole::Output, {})
                || WriteOwnershipMarker(output, OwnedTreeRole::Output, {}))) {
            result.committed = true;
        }
        return result;
    }
    result.success = true;
    return result;
}

}  // namespace elder::weather::detail
