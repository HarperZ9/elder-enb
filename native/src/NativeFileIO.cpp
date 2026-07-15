#include "elder/shaders/NativeFileIO.hpp"

#ifdef _WIN32
#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#endif

#include <algorithm>
#include <fstream>
#include <limits>
#include <sstream>
#include <string>
#include <system_error>

namespace elder::shaders::native_io {

std::filesystem::path NormalizePath(const std::filesystem::path& input) {
  auto normalized = input.is_absolute()
      ? input.lexically_normal()
      : std::filesystem::absolute(input).lexically_normal();
#ifdef _WIN32
  std::wstring value = normalized.native();
  if (value.starts_with(L"\\\\?\\")) {
    return std::filesystem::path{std::move(value)};
  }
  if (value.starts_with(L"\\\\")) {
    value = L"\\\\?\\UNC\\" + value.substr(2U);
  } else {
    value = L"\\\\?\\" + value;
  }
  return std::filesystem::path{std::move(value)};
#else
  return normalized;
#endif
}

bool ReadBinaryFile(
    const std::filesystem::path& path,
    std::string& output,
    std::string& detail) noexcept {
  output.clear();
  detail.clear();
  try {
    const auto native_path = NormalizePath(path);
#ifdef _WIN32
    HANDLE file = CreateFileW(
        native_path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
        nullptr);
    if (file == INVALID_HANDLE_VALUE) {
      detail = "Win32 " + std::to_string(GetLastError());
      return false;
    }
    LARGE_INTEGER size{};
    if (GetFileSizeEx(file, &size) == 0) {
      detail = "could not determine the input file size (Win32 "
          + std::to_string(GetLastError()) + ')';
      CloseHandle(file);
      return false;
    }
    if (size.QuadPart < 0
        || static_cast<unsigned long long>(size.QuadPart)
            > static_cast<unsigned long long>(output.max_size())) {
      detail = "input file size is not representable";
      CloseHandle(file);
      return false;
    }
    std::string bytes(static_cast<std::size_t>(size.QuadPart), '\0');
    std::size_t offset = 0U;
    while (offset < bytes.size()) {
      const DWORD request = static_cast<DWORD>(std::min<std::size_t>(
          bytes.size() - offset,
          static_cast<std::size_t>(std::numeric_limits<DWORD>::max())));
      DWORD read{};
      if (ReadFile(file, bytes.data() + offset, request, &read, nullptr) == 0
          || read != request) {
        detail = "could not read the complete file (Win32 "
            + std::to_string(GetLastError()) + ')';
        CloseHandle(file);
        return false;
      }
      offset += read;
    }
    if (CloseHandle(file) == 0) {
      detail = "could not close the input file (Win32 "
          + std::to_string(GetLastError()) + ')';
      return false;
    }
    output = std::move(bytes);
    return true;
#else
    std::ifstream stream(native_path, std::ios::binary);
    if (!stream) {
      detail = "could not open the input file";
      return false;
    }
    std::ostringstream bytes;
    bytes << stream.rdbuf();
    if (!stream.good() && !stream.eof()) {
      detail = "could not read the complete input file";
      return false;
    }
    output = bytes.str();
    return true;
#endif
  } catch (const std::exception& error) {
    detail = std::string{"native file read exception: "} + error.what();
    return false;
  } catch (...) {
    detail = "native file read exception";
    return false;
  }
}

}  // namespace elder::shaders::native_io
