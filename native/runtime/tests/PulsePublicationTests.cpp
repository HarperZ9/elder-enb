#include "elder/runtime/PulsePublication.hpp"

#include <bit>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <limits>
#include <string_view>

namespace {

int failures = 0;

void expect(const bool condition, const char* expression, const char* file, const int line)
{
  if (condition) {
    return;
  }

  std::cerr << file << ':' << line << ": expectation failed: " << expression << '\n';
  ++failures;
}

#define EXPECT(expression) expect((expression), #expression, __FILE__, __LINE__)

using elder::runtime::kElderFramePulseParameterKey;
using elder::runtime::PlanPulseParameterWrite;
using elder::runtime::PulsePublicationDecision;
using elder::runtime::PulsePublicationDiagnostic;
using enbcore::runtime::FramePulseDiagnostic;
using enbcore::runtime::FramePulsePayload;
using enbcore::runtime::FramePulseResult;
using enbcore::runtime::FramePulseStatus;
using enbcore::runtime::InactiveFramePulsePayload;

[[nodiscard]] bool same_payload_bits(const FramePulsePayload& lhs, const FramePulsePayload& rhs)
{
  return std::bit_cast<std::uint32_t>(lhs.frame) == std::bit_cast<std::uint32_t>(rhs.frame)
      && std::bit_cast<std::uint32_t>(lhs.delta_seconds)
          == std::bit_cast<std::uint32_t>(rhs.delta_seconds)
      && std::bit_cast<std::uint32_t>(lhs.width) == std::bit_cast<std::uint32_t>(rhs.width)
      && std::bit_cast<std::uint32_t>(lhs.height) == std::bit_cast<std::uint32_t>(rhs.height);
}

[[nodiscard]] FramePulsePayload live_payload()
{
  FramePulsePayload payload{};
  payload.frame = 240.0F;
  payload.delta_seconds = 1.0F / 60.0F;
  payload.width = 2560.0F;
  payload.height = 1440.0F;
  return payload;
}

void stable_codes_are_explicit()
{
  EXPECT(static_cast<std::uint32_t>(PulsePublicationDecision::publish_live) == 0U);
  EXPECT(static_cast<std::uint32_t>(PulsePublicationDecision::publish_inactive) == 1U);
  EXPECT(static_cast<std::uint32_t>(PulsePublicationDiagnostic::none) == 0U);
  EXPECT(static_cast<std::uint32_t>(PulsePublicationDiagnostic::pulse_not_published) == 100U);
  EXPECT(static_cast<std::uint32_t>(PulsePublicationDiagnostic::live_payload_invalid) == 110U);
}

void parameter_key_is_stable()
{
  EXPECT(kElderFramePulseParameterKey == std::string_view{"Elder Runtime | Frame Pulse"});
}

void published_pulse_plans_a_live_write_with_exact_bytes()
{
  const FramePulseResult result{FramePulseStatus::Published, FramePulseDiagnostic::None};
  const FramePulsePayload payload = live_payload();

  const auto write = PlanPulseParameterWrite(result, payload);

  EXPECT(write.decision == PulsePublicationDecision::publish_live);
  EXPECT(write.diagnostic == PulsePublicationDiagnostic::none);
  EXPECT(write.parameter_key == kElderFramePulseParameterKey);
  EXPECT(same_payload_bits(write.payload, payload));
}

void withheld_pulse_forces_the_inactive_payload()
{
  const FramePulseResult result{
      FramePulseStatus::Withheld, FramePulseDiagnostic::RenderInfoUnavailable};
  // A stale live payload must not leak through a withheld pulse.
  const FramePulsePayload stale = live_payload();

  const auto write = PlanPulseParameterWrite(result, stale);

  EXPECT(write.decision == PulsePublicationDecision::publish_inactive);
  EXPECT(write.diagnostic == PulsePublicationDiagnostic::pulse_not_published);
  EXPECT(same_payload_bits(write.payload, InactiveFramePulsePayload()));
}

void rejected_pulse_forces_the_inactive_payload()
{
  const FramePulseResult result{
      FramePulseStatus::Rejected, FramePulseDiagnostic::DeltaSecondsNonFinite};
  const FramePulsePayload stale = live_payload();

  const auto write = PlanPulseParameterWrite(result, stale);

  EXPECT(write.decision == PulsePublicationDecision::publish_inactive);
  EXPECT(write.diagnostic == PulsePublicationDiagnostic::pulse_not_published);
  EXPECT(same_payload_bits(write.payload, InactiveFramePulsePayload()));
}

void published_pulse_with_invalid_payload_fails_closed()
{
  const FramePulseResult result{FramePulseStatus::Published, FramePulseDiagnostic::None};

  FramePulsePayload zero_frame = live_payload();
  zero_frame.frame = 0.0F;
  const auto zero_write = PlanPulseParameterWrite(result, zero_frame);
  EXPECT(zero_write.decision == PulsePublicationDecision::publish_inactive);
  EXPECT(zero_write.diagnostic == PulsePublicationDiagnostic::live_payload_invalid);
  EXPECT(same_payload_bits(zero_write.payload, InactiveFramePulsePayload()));

  FramePulsePayload nan_delta = live_payload();
  nan_delta.delta_seconds = std::numeric_limits<float>::quiet_NaN();
  const auto nan_write = PlanPulseParameterWrite(result, nan_delta);
  EXPECT(nan_write.decision == PulsePublicationDecision::publish_inactive);
  EXPECT(nan_write.diagnostic == PulsePublicationDiagnostic::live_payload_invalid);

  FramePulsePayload fractional_frame = live_payload();
  fractional_frame.frame = 240.5F;
  const auto fractional_write = PlanPulseParameterWrite(result, fractional_frame);
  EXPECT(fractional_write.decision == PulsePublicationDecision::publish_inactive);
  EXPECT(fractional_write.diagnostic == PulsePublicationDiagnostic::live_payload_invalid);

  FramePulsePayload oversized = live_payload();
  oversized.width = 65536.0F;
  const auto oversized_write = PlanPulseParameterWrite(result, oversized);
  EXPECT(oversized_write.decision == PulsePublicationDecision::publish_inactive);
  EXPECT(oversized_write.diagnostic == PulsePublicationDiagnostic::live_payload_invalid);
}

}  // namespace

int main()
{
  stable_codes_are_explicit();
  parameter_key_is_stable();
  published_pulse_plans_a_live_write_with_exact_bytes();
  withheld_pulse_forces_the_inactive_payload();
  rejected_pulse_forces_the_inactive_payload();
  published_pulse_with_invalid_payload_fails_closed();

  if (failures != 0) {
    std::cerr << failures << " assertion(s) failed\n";
    return 1;
  }

  std::cout << "Elder runtime pulse-publication tests passed\n";
  return 0;
}
