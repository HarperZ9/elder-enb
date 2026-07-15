#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <algorithm>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace {

struct TestContext {
  std::size_t assertions{};
  std::vector<std::string> failures;

  void Expect(const bool condition, std::string message) {
    ++assertions;
    if (!condition) failures.push_back(std::move(message));
  }
};

[[nodiscard]] std::filesystem::path ExtendedPath(
    const std::filesystem::path& input) {
  auto absolute = std::filesystem::absolute(input).lexically_normal();
  std::wstring value = absolute.native();
  if (value.starts_with(L"\\\\?\\")) return absolute;
  if (value.starts_with(L"\\\\")) {
    value = L"\\\\?\\UNC\\" + value.substr(2U);
  } else {
    value = L"\\\\?\\" + value;
  }
  return std::filesystem::path{std::move(value)};
}

void WriteBinary(const std::filesystem::path& path,
                 const std::string_view bytes) {
  std::error_code error;
  std::filesystem::create_directories(ExtendedPath(path.parent_path()), error);
  if (error) throw std::runtime_error("could not create CLI fixture directory");
  const auto native = ExtendedPath(path);
  HANDLE file = CreateFileW(
      native.c_str(), GENERIC_WRITE, 0U, nullptr, CREATE_ALWAYS,
      FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    throw std::runtime_error("could not create CLI fixture");
  }
  DWORD written{};
  const bool ok = bytes.size() <= static_cast<std::size_t>(MAXDWORD)
      && WriteFile(file, bytes.data(), static_cast<DWORD>(bytes.size()),
                   &written, nullptr) != 0
      && written == bytes.size();
  CloseHandle(file);
  if (!ok) throw std::runtime_error("could not write CLI fixture");
}

[[nodiscard]] std::string ReadBinary(const std::filesystem::path& path) {
  const auto native = ExtendedPath(path);
  HANDLE file = CreateFileW(
      native.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) return {};
  LARGE_INTEGER size{};
  if (GetFileSizeEx(file, &size) == 0 || size.QuadPart < 0
      || size.QuadPart > MAXDWORD) {
    CloseHandle(file);
    return {};
  }
  std::string bytes(static_cast<std::size_t>(size.QuadPart), '\0');
  DWORD read{};
  const bool ok = bytes.empty()
      || (ReadFile(file, bytes.data(), static_cast<DWORD>(bytes.size()),
                   &read, nullptr) != 0
          && read == bytes.size());
  CloseHandle(file);
  return ok ? bytes : std::string{};
}

[[nodiscard]] std::wstring QuoteArgument(const std::wstring_view argument) {
  if (argument.find_first_of(L" \t\"") == std::wstring_view::npos) {
    return std::wstring{argument};
  }
  std::wstring quoted{L"\""};
  std::size_t slashes{};
  for (const wchar_t character : argument) {
    if (character == L'\\') {
      ++slashes;
      continue;
    }
    if (character == L'\"') {
      quoted.append(slashes * 2U + 1U, L'\\');
      quoted.push_back(L'\"');
      slashes = 0U;
      continue;
    }
    quoted.append(slashes, L'\\');
    slashes = 0U;
    quoted.push_back(character);
  }
  quoted.append(slashes * 2U, L'\\');
  quoted.push_back(L'\"');
  return quoted;
}

[[nodiscard]] DWORD RunTool(
    const std::filesystem::path& executable,
    const std::vector<std::filesystem::path>& arguments) {
  const auto application = ExtendedPath(executable).native();
  std::wstring command = QuoteArgument(application);
  for (const auto& argument : arguments) {
    command.push_back(L' ');
    command += QuoteArgument(argument.native());
  }
  std::vector<wchar_t> writable(command.begin(), command.end());
  writable.push_back(L'\0');
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (CreateProcessW(
          application.c_str(), writable.data(), nullptr, nullptr, FALSE, 0U,
          nullptr, nullptr, &startup, &process) == 0) {
    return MAXDWORD;
  }
  WaitForSingleObject(process.hProcess, INFINITE);
  DWORD exit_code{MAXDWORD};
  GetExitCodeProcess(process.hProcess, &exit_code);
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return exit_code;
}

[[nodiscard]] std::filesystem::path LongDirectory(
    const std::filesystem::path& root,
    const std::wstring_view leaf) {
  auto directory = root / leaf;
  while (std::filesystem::absolute(directory).native().size() <= 300U) {
    directory /= L"elder-native-cli-source-destination-segment-0123456789";
  }
  return directory;
}

void PublisherAcceptsLongAndUnicodePaths(
    TestContext& context,
    const std::filesystem::path& publisher,
    const std::filesystem::path& root) {
  const auto long_directory = LongDirectory(root, L"publisher-long");
  const auto long_source = long_directory / L"source.bin";
  const auto long_destination = long_directory / L"destination.bin";
  WriteBinary(long_source, "publisher-long-payload");
  context.Expect(
      std::filesystem::absolute(long_source).native().size() > 260U,
      "publisher source fixture did not cross MAX_PATH");
  context.Expect(
      RunTool(publisher, {long_source, long_destination}) == 0U,
      "artifact publisher rejected a source and destination beyond MAX_PATH");
  context.Expect(ReadBinary(long_destination) == "publisher-long-payload",
                 "artifact publisher changed the long-path payload");

  const auto unicode_directory = root / L"publisher-\u5929\u5019-\u8272\u5f69-\u0394";
  const auto unicode_source = unicode_directory / L"\u5165\u529b-\u03b4.bin";
  const auto unicode_destination = unicode_directory / L"\u51fa\u529b-\u03bb.bin";
  WriteBinary(unicode_source, "publisher-unicode-payload");
  context.Expect(
      RunTool(publisher, {unicode_source, unicode_destination}) == 0U,
      "artifact publisher rejected Unicode source and destination paths");
  context.Expect(ReadBinary(unicode_destination) == "publisher-unicode-payload",
                 "artifact publisher changed the Unicode-path payload");
}

void SchemaCompilerAcceptsLongAndUnicodePaths(
    TestContext& context,
    const std::filesystem::path& compiler,
    const std::filesystem::path& production_schema,
    const std::filesystem::path& root) {
  const std::string schema_bytes = ReadBinary(production_schema);
  context.Expect(!schema_bytes.empty(), "production schema fixture is empty");

  const auto long_directory = LongDirectory(root, L"compiler-long");
  const auto long_source = long_directory / L"schema.csv";
  WriteBinary(long_source, schema_bytes);
  const std::vector<std::filesystem::path> long_outputs{
      long_directory / L"parameters.fxh",
      long_directory / L"defaults.hpp",
      long_directory / L"manifest.json",
      long_directory / L"default.profile",
  };
  std::vector<std::filesystem::path> long_arguments{long_source};
  long_arguments.insert(
      long_arguments.end(), long_outputs.begin(), long_outputs.end());
  context.Expect(
      RunTool(compiler, long_arguments) == 0U,
      "schema compiler rejected a source and destinations beyond MAX_PATH");
  for (const auto& output : long_outputs) {
    context.Expect(!ReadBinary(output).empty(),
                   "schema compiler omitted a long-path output");
  }

  const auto unicode_directory = root / L"compiler-\u5929\u5019-\u8272\u5f69-\u0394";
  const auto unicode_source = unicode_directory / L"\u5165\u529b-schema.csv";
  WriteBinary(unicode_source, schema_bytes);
  const std::vector<std::filesystem::path> unicode_outputs{
      unicode_directory / L"\u51fa\u529b-parameters.fxh",
      unicode_directory / L"\u51fa\u529b-defaults.hpp",
      unicode_directory / L"\u51fa\u529b-manifest.json",
      unicode_directory / L"\u51fa\u529b-default.profile",
  };
  std::vector<std::filesystem::path> unicode_arguments{unicode_source};
  unicode_arguments.insert(
      unicode_arguments.end(), unicode_outputs.begin(), unicode_outputs.end());
  context.Expect(
      RunTool(compiler, unicode_arguments) == 0U,
      "schema compiler rejected Unicode source and destination paths");
  for (const auto& output : unicode_outputs) {
    context.Expect(!ReadBinary(output).empty(),
                   "schema compiler omitted a Unicode-path output");
  }
}

}  // namespace

int main(const int argument_count, const char* const* arguments) {
  if (argument_count != 4) {
    std::cerr << "usage: NativeToolCliTests <publisher> <compiler> <schema>\n";
    return 2;
  }
  TestContext context;
  const auto root = std::filesystem::temp_directory_path()
      / (L"elder-native-cli-" + std::to_wstring(GetCurrentProcessId()));
  std::error_code error;
  std::filesystem::remove_all(ExtendedPath(root), error);
  try {
    PublisherAcceptsLongAndUnicodePaths(context, arguments[1], root);
    SchemaCompilerAcceptsLongAndUnicodePaths(
        context, arguments[2], arguments[3], root);
  } catch (const std::exception& exception) {
    context.Expect(false, std::string{"CLI test exception: "} + exception.what());
  }
  error.clear();
  std::filesystem::remove_all(ExtendedPath(root), error);
  context.Expect(!error, "could not remove CLI regression fixtures");
  if (!context.failures.empty()) {
    for (const auto& failure : context.failures) {
      std::cerr << "[FAIL] " << failure << '\n';
    }
    std::cerr << context.failures.size() << " failures across "
              << context.assertions << " assertions\n";
    return 1;
  }
  std::cout << "Elder native CLI path cases passed: "
            << context.assertions << " assertions\n";
  return 0;
}
