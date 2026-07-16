#include "elder/runtime/PulsePublication.hpp"

#include <cmath>

namespace elder::runtime {
namespace {

using enbcore::runtime::FramePulsePayload;
using enbcore::runtime::FramePulseResult;
using enbcore::runtime::FramePulseStatus;
using enbcore::runtime::InactiveFramePulsePayload;
using enbcore::runtime::kFramePulseFrameWrapModulus;
using enbcore::runtime::kFramePulseMaximumDeltaSeconds;
using enbcore::runtime::kFramePulseMaximumDimension;
using enbcore::runtime::kFramePulseMinimumDimension;

[[nodiscard]] PulseParameterWrite Inactive(
    const PulsePublicationDiagnostic diagnostic) noexcept
{
  return PulseParameterWrite{
      kElderFramePulseParameterKey,
      InactiveFramePulsePayload(),
      PulsePublicationDecision::publish_inactive,
      diagnostic,
  };
}

[[nodiscard]] bool IntegerExact(const float value) noexcept
{
  return std::nearbyint(value) == value;
}

[[nodiscard]] bool DimensionValid(const float value) noexcept
{
  return std::isfinite(value) && IntegerExact(value)
      && value >= static_cast<float>(kFramePulseMinimumDimension)
      && value <= static_cast<float>(kFramePulseMaximumDimension);
}

[[nodiscard]] bool LivePayloadValid(const FramePulsePayload& payload) noexcept
{
  if (!std::isfinite(payload.frame) || !IntegerExact(payload.frame)) {
    return false;
  }
  if (payload.frame < 1.0F
      || payload.frame > static_cast<float>(kFramePulseFrameWrapModulus)) {
    return false;
  }
  if (!std::isfinite(payload.delta_seconds) || payload.delta_seconds <= 0.0F
      || payload.delta_seconds > kFramePulseMaximumDeltaSeconds) {
    return false;
  }
  return DimensionValid(payload.width) && DimensionValid(payload.height);
}

}  // namespace

PulseParameterWrite PlanPulseParameterWrite(const FramePulseResult& result,
                                            const FramePulsePayload& payload) noexcept
{
  if (result.status != FramePulseStatus::Published) {
    return Inactive(PulsePublicationDiagnostic::pulse_not_published);
  }

  if (!LivePayloadValid(payload)) {
    return Inactive(PulsePublicationDiagnostic::live_payload_invalid);
  }

  return PulseParameterWrite{
      kElderFramePulseParameterKey,
      payload,
      PulsePublicationDecision::publish_live,
      PulsePublicationDiagnostic::none,
  };
}

}  // namespace elder::runtime
