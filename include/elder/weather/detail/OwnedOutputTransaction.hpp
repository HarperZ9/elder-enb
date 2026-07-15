#pragma once

#include <cstdint>
#include <filesystem>
#include <functional>
#include <optional>
#include <string>
#include <string_view>
#include <system_error>

namespace elder::weather::detail {

enum class OwnedTreeRole {
    Stage,
    Output,
    Backup,
    Scratch,
};

struct PublicationResult {
    bool success{false};
    bool committed{false};
    bool rolled_back{false};
    bool cleanup_complete{false};
};

using RenameOperation = std::function<bool(
    const std::filesystem::path&,
    const std::filesystem::path&,
    std::error_code&)>;
using RemoveOperation = std::function<bool(
    const std::filesystem::path&,
    OwnedTreeRole,
    std::string_view)>;

[[nodiscard]] bool PathsAreSafelyDisjoint(
    const std::filesystem::path& input,
    const std::filesystem::path& output);
[[nodiscard]] std::string NewTransactionId();
[[nodiscard]] std::optional<std::filesystem::path> CreateOwnedTree(
    const std::filesystem::path& parent,
    std::string_view prefix,
    OwnedTreeRole role,
    std::string_view transaction_id);
[[nodiscard]] bool WriteOwnershipMarker(
    const std::filesystem::path& root,
    OwnedTreeRole role,
    std::string_view transaction_id);
[[nodiscard]] bool HasOwnershipMarker(
    const std::filesystem::path& root,
    OwnedTreeRole role,
    std::string_view transaction_id);
[[nodiscard]] bool RemoveOwnedTree(
    const std::filesystem::path& root,
    OwnedTreeRole role,
    std::string_view transaction_id);
[[nodiscard]] std::filesystem::path OutputLockPath(
    const std::filesystem::path& output);

class ExclusiveOutputLock {
public:
    ExclusiveOutputLock(const ExclusiveOutputLock&) = delete;
    ExclusiveOutputLock& operator=(const ExclusiveOutputLock&) = delete;
    ExclusiveOutputLock(ExclusiveOutputLock&& other) noexcept;
    ExclusiveOutputLock& operator=(ExclusiveOutputLock&& other) noexcept;
    ~ExclusiveOutputLock();

    [[nodiscard]] static std::optional<ExclusiveOutputLock> Acquire(
        const std::filesystem::path& output);
    [[nodiscard]] const std::filesystem::path& path() const noexcept;

private:
    ExclusiveOutputLock(std::intptr_t native_handle, std::filesystem::path path);
    void Close() noexcept;

    std::intptr_t native_handle_{-1};
    std::filesystem::path path_;
};

[[nodiscard]] PublicationResult PublishOwnedTree(
    const std::filesystem::path& stage,
    const std::filesystem::path& output,
    std::string_view transaction_id,
    RenameOperation rename = {},
    RemoveOperation remove = {});

}  // namespace elder::weather::detail
