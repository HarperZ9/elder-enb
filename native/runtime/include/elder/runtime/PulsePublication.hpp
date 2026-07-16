#pragma once

#include <enbcore/runtime/FramePulse.hpp>

#include <cstdint>
#include <string_view>

namespace elder::runtime {

// Elder's publication policy for the neutral frame pulse. The core decides
// whether a pulse exists; Elder decides what its ENB parameter write looks
// like. The policy is fail-closed twice over: a pulse that was not published
// becomes the inactive payload regardless of the caller's bytes, and a
// "published" pulse whose payload violates the core contract is treated as a
// breach and also becomes the inactive payload, with its own diagnostic.

inline constexpr std::string_view kElderFramePulseParameterKey =
    "Elder Runtime | Frame Pulse";

enum class PulsePublicationDecision : std::uint32_t {
  publish_live = 0U,
  publish_inactive = 1U,
};

enum class PulsePublicationDiagnostic : std::uint32_t {
  none = 0U,
  pulse_not_published = 100U,
  live_payload_invalid = 110U,
};

struct PulseParameterWrite {
  std::string_view parameter_key;
  enbcore::runtime::FramePulsePayload payload;
  PulsePublicationDecision decision;
  PulsePublicationDiagnostic diagnostic;
};

[[nodiscard]] PulseParameterWrite PlanPulseParameterWrite(
    const enbcore::runtime::FramePulseResult& result,
    const enbcore::runtime::FramePulsePayload& payload) noexcept;

}  // namespace elder::runtime
