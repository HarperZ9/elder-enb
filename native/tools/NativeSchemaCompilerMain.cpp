#include "elder/shaders/ArtifactPublication.hpp"
#include "elder/shaders/NativeFileIO.hpp"
#include "elder/shaders/ParameterSchema.hpp"

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#ifdef _WIN32
using NativeArgumentCharacter = wchar_t;
#else
using NativeArgumentCharacter = char;
#endif

namespace {

int Run(
    const int argument_count,
    const NativeArgumentCharacter* const* arguments) {
  if (argument_count != 6) {
    std::cerr << "usage: elder_native_schema_compiler <schema.csv> "
                 "<parameters.fxh> <defaults.hpp> <manifest.json> "
                 "<default.profile>\n";
    return 2;
  }

  std::string schema_source;
  std::string read_detail;
  if (!elder::shaders::native_io::ReadBinaryFile(
          arguments[1], schema_source, read_detail)) {
    std::cerr << "could not read native parameter schema: "
              << read_detail << '\n';
    return 1;
  }
  elder::shaders::NativeParameterSchema schema;
  const auto parsed = elder::shaders::ParseNativeParameterSchema(
      schema_source, schema);
  if (!parsed.ok()) {
    std::cerr << "schema rejected at line " << parsed.line << ": "
              << parsed.detail << '\n';
    return 1;
  }
  elder::shaders::NativeArtifacts artifacts;
  const auto compiled = elder::shaders::CompileNativeParameterArtifacts(
      schema, artifacts);
  if (!compiled.ok()) {
    std::cerr << "schema compilation failed at line " << compiled.line << ": "
              << compiled.detail << '\n';
    return 1;
  }

  const std::vector<elder::shaders::ArtifactPayload> outputs = {
      {arguments[2], std::move(artifacts.hlsl_ui)},
      {arguments[3], std::move(artifacts.cpp_defaults)},
      {arguments[4], std::move(artifacts.manifest_json)},
      {arguments[5], std::move(artifacts.default_profile)},
  };
  const auto published = elder::shaders::PublishArtifactSet(outputs);
  if (!published.ok()) {
    std::cerr << "generated artifact transaction failed at output "
              << published.artifact_index << ": " << published.detail << '\n';
    return 1;
  }
  std::cout << "generated Elder native parameter ABI "
            << schema.abi_sha256 << '\n';
  return 0;
}

}  // namespace

#ifdef _WIN32
int wmain(const int argument_count, wchar_t** arguments) {
  return Run(argument_count, arguments);
}
#else
int main(const int argument_count, char** arguments) {
  return Run(argument_count, arguments);
}
#endif
