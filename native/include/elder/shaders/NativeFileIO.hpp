#pragma once

#include <filesystem>
#include <string>

namespace elder::shaders::native_io {

// Returns an absolute, lexically normalized path suitable for direct native
// filesystem calls. On Windows this includes the extended-length prefix for
// both local and UNC paths.
[[nodiscard]] std::filesystem::path NormalizePath(
    const std::filesystem::path& input);

[[nodiscard]] bool ReadBinaryFile(
    const std::filesystem::path& path,
    std::string& output,
    std::string& detail) noexcept;

}  // namespace elder::shaders::native_io
