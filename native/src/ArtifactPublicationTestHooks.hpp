#pragma once

#include "elder/shaders/ArtifactPublication.hpp"

#include <cstddef>
#include <limits>
#include <span>

namespace elder::shaders::testing {

inline constexpr std::size_t no_publication_fault =
    std::numeric_limits<std::size_t>::max();

struct ArtifactPublicationFaults {
  std::size_t fail_stage_write_at{no_publication_fault};
  std::size_t fail_stage_cleanup_at{no_publication_fault};
  std::size_t fail_backup_cleanup_at{no_publication_fault};
};

[[nodiscard]] ArtifactPublicationResult PublishArtifactSetForTesting(
    std::span<const ArtifactPayload> artifacts,
    const ArtifactPublicationFaults& faults) noexcept;

}  // namespace elder::shaders::testing
