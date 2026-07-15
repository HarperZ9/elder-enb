#pragma once

#include <cstddef>
#include <filesystem>
#include <span>
#include <string>

namespace elder::shaders {

struct ArtifactPayload {
  std::filesystem::path destination;
  std::string bytes;
};

enum class ArtifactPublicationDiagnostic {
  none = 0,
  empty_set,
  invalid_destination,
  duplicate_destination,
  create_directory_failed,
  lock_failed,
  stage_create_failed,
  stage_write_failed,
  stage_cleanup_incomplete,
  backup_failed,
  publish_failed,
  backup_cleanup_incomplete,
  rollback_failed,
  exception,
};

struct ArtifactPublicationResult {
  ArtifactPublicationDiagnostic diagnostic{ArtifactPublicationDiagnostic::none};
  std::size_t artifact_index{};
  std::string detail;

  [[nodiscard]] bool ok() const noexcept {
    return diagnostic == ArtifactPublicationDiagnostic::none;
  }
};

[[nodiscard]] ArtifactPublicationResult PublishArtifactSet(
    std::span<const ArtifactPayload> artifacts) noexcept;

}  // namespace elder::shaders
