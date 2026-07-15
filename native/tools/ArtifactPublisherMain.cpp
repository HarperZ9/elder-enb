#include "elder/shaders/ArtifactPublication.hpp"
#include "elder/shaders/NativeFileIO.hpp"

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
  if (argument_count < 3 || (argument_count % 2) == 0) {
    std::cerr << "usage: elder_native_artifact_publisher "
                 "<source> <destination> [<source> <destination> ...]\n";
    return 2;
  }
  std::vector<elder::shaders::ArtifactPayload> artifacts;
  artifacts.reserve(static_cast<std::size_t>((argument_count - 1) / 2));
  for (int index = 1; index < argument_count; index += 2) {
    elder::shaders::ArtifactPayload artifact;
    artifact.destination = arguments[index + 1];
    std::string detail;
    if (!elder::shaders::native_io::ReadBinaryFile(
            arguments[index], artifact.bytes, detail)) {
      std::cerr << "could not read staged artifact at argument " << index
                << ": " << detail << '\n';
      return 1;
    }
    artifacts.push_back(std::move(artifact));
  }
  const auto result = elder::shaders::PublishArtifactSet(artifacts);
  if (!result.ok()) {
    std::cerr << "artifact transaction failed at output "
              << result.artifact_index << ": " << result.detail << '\n';
    return 1;
  }
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
