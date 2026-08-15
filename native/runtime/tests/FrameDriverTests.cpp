#include "elder/runtime/FrameDriver.hpp"

#include <bit>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <limits>

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

using elder::runtime::BuildSample;
using elder::runtime::DriveFrame;
using elder::runtime::EncodePulseParameter;
using elder::runtime::FrameTiming;
using elder::runtime::kElderFramePulseSymbol;
using elder::runtime::kElderTargetShaders;
using elder::runtime::PulsePublicationDecision;
using elder::runtime::PulsePublicationDiagnostic;
using enbcore::enb::ParameterKind;
using enbcore::enb::RenderInfo;
using enbcore::runtime::FramePulsePayload;
using enbcore::runtime::FramePulseState;
using enbcore::runtime::FramePulseStatus;

[[nodiscard]] RenderInfo MakeRenderInfo(const std::uint32_t width,
                                        const std::uint32_t height)
{
  RenderInfo info{};
  info.screen_size_x = width;
  info.screen_size_y = height;
  return info;
}

[[nodiscard]] FramePulsePayload DecodeParameter(const enbcore::enb::Parameter& parameter)
{
  float values[4]{};
  std::memcpy(values, parameter.data.data(), sizeof(values));
  return FramePulsePayload{values[0], values[1], values[2], values[3]};
}

// The first frame has no measured delta, so it must publish inactive rather
// than guess one. Publishing a fabricated first delta would put a live pulse in
// front of shaders before anything real had been measured.
void FirstFrameIsInactive()
{
  FramePulseState state{};
  const RenderInfo info = MakeRenderInfo(1920U, 1080U);

  const auto outcome = DriveFrame(state, &info, FrameTiming{0.0F, false});

  EXPECT(outcome.decision == PulsePublicationDecision::publish_inactive);
  EXPECT(outcome.pulse_status != FramePulseStatus::Published);
  EXPECT(state.published_frames == 0U);

  const FramePulsePayload payload = DecodeParameter(outcome.parameter);
  EXPECT(payload.frame == 0.0F);
  EXPECT(payload.delta_seconds == 0.0F);
}

// A normal frame publishes live and advances the counter exactly once.
void SteadyFramePublishesLive()
{
  FramePulseState state{};
  const RenderInfo info = MakeRenderInfo(2560U, 1440U);

  const auto first = DriveFrame(state, &info, FrameTiming{1.0F / 60.0F, true});
  EXPECT(first.decision == PulsePublicationDecision::publish_live);
  EXPECT(first.diagnostic == PulsePublicationDiagnostic::none);
  EXPECT(state.published_frames == 1U);

  const FramePulsePayload payload = DecodeParameter(first.parameter);
  EXPECT(payload.frame == 1.0F);
  EXPECT(payload.width == 2560.0F);
  EXPECT(payload.height == 1440.0F);

  const auto second = DriveFrame(state, &info, FrameTiming{1.0F / 60.0F, true});
  EXPECT(second.decision == PulsePublicationDecision::publish_live);
  EXPECT(DecodeParameter(second.parameter).frame == 2.0F);
  EXPECT(state.published_frames == 2U);
}

// A missing render info is the ENB host not being ready. The counter must not
// advance, and the write must be the inactive payload rather than skipped, so a
// previously live value cannot linger in front of shaders.
void MissingRenderInfoPublishesInactiveWithoutAdvancing()
{
  FramePulseState state{};
  const RenderInfo info = MakeRenderInfo(1920U, 1080U);

  EXPECT(DriveFrame(state, &info, FrameTiming{1.0F / 60.0F, true}).decision
         == PulsePublicationDecision::publish_live);
  EXPECT(state.published_frames == 1U);

  const auto lost = DriveFrame(state, nullptr, FrameTiming{1.0F / 60.0F, true});
  EXPECT(lost.decision == PulsePublicationDecision::publish_inactive);
  EXPECT(state.published_frames == 1U);
  EXPECT(DecodeParameter(lost.parameter).frame == 0.0F);
}

// A stalled or absurd frame time is rejected by the core rather than published.
// A debugger break or a loading screen can produce these.
void OutOfRangeDeltaIsRejected()
{
  FramePulseState state{};
  const RenderInfo info = MakeRenderInfo(1920U, 1080U);

  for (const float delta : {0.0F,
                            -1.0F,
                            1000.0F,
                            std::numeric_limits<float>::quiet_NaN(),
                            std::numeric_limits<float>::infinity()}) {
    const auto outcome = DriveFrame(state, &info, FrameTiming{delta, true});
    EXPECT(outcome.decision == PulsePublicationDecision::publish_inactive);
    EXPECT(DecodeParameter(outcome.parameter).frame == 0.0F);
  }
  EXPECT(state.published_frames == 0U);
}

// The encoding must fill the SDK parameter exactly: sixteen bytes, COLOR4, in
// the order the shader header documents.
void EncodingMatchesTheShaderContract()
{
  const FramePulsePayload payload{7.0F, 0.016F, 1920.0F, 1080.0F};
  const auto parameter = EncodePulseParameter(payload);

  EXPECT(parameter.type == ParameterKind::Color4);
  EXPECT(parameter.size == 16U);

  const FramePulsePayload decoded = DecodeParameter(parameter);
  EXPECT(std::bit_cast<std::uint32_t>(decoded.frame)
         == std::bit_cast<std::uint32_t>(payload.frame));
  EXPECT(std::bit_cast<std::uint32_t>(decoded.delta_seconds)
         == std::bit_cast<std::uint32_t>(payload.delta_seconds));
  EXPECT(std::bit_cast<std::uint32_t>(decoded.width)
         == std::bit_cast<std::uint32_t>(payload.width));
  EXPECT(std::bit_cast<std::uint32_t>(decoded.height)
         == std::bit_cast<std::uint32_t>(payload.height));
}

// The inactive payload is written, not skipped. This is the contract that stops
// a stale live pulse being visible after the bridge goes away.
void InactivePayloadIsStillAFullWrite()
{
  const auto parameter =
      EncodePulseParameter(enbcore::runtime::InactiveFramePulsePayload());
  EXPECT(parameter.size == 16U);
  EXPECT(parameter.type == ParameterKind::Color4);
  for (const std::uint8_t byte : parameter.data) {
    EXPECT(byte == 0U);
  }
}

// A first frame is only ever unavailable because of the missing previous
// timestamp, never because the dimensions were wrong.
void BuildSampleWithoutPreviousFrameIsUnavailable()
{
  const RenderInfo info = MakeRenderInfo(1920U, 1080U);
  const auto sample = BuildSample(&info, FrameTiming{0.016F, false});
  EXPECT(!sample.render_info_available);

  const auto ready = BuildSample(&info, FrameTiming{0.016F, true});
  EXPECT(ready.render_info_available);
  EXPECT(ready.output_width == 1920U);
  EXPECT(ready.output_height == 1080U);
}

// The write targets are the shader files that read the symbol, and the symbol
// is the HLSL identifier rather than the pipe-separated UIName.
void TargetsAreAddressable()
{
  EXPECT(kElderTargetShaders.size() == 3U);
  for (const char* shader : kElderTargetShaders) {
    EXPECT(shader != nullptr);
    EXPECT(shader[0] != '\0');
  }
  EXPECT(std::strcmp(kElderFramePulseSymbol, "ElderRuntimeFramePulse") == 0);
}

}  // namespace

int main()
{
  FirstFrameIsInactive();
  SteadyFramePublishesLive();
  MissingRenderInfoPublishesInactiveWithoutAdvancing();
  OutOfRangeDeltaIsRejected();
  EncodingMatchesTheShaderContract();
  InactivePayloadIsStillAFullWrite();
  BuildSampleWithoutPreviousFrameIsUnavailable();
  TargetsAreAddressable();

  if (failures != 0) {
    std::cerr << failures << " frame-driver expectation(s) failed\n";
    return 1;
  }
  std::cout << "PASS: Elder frame driver\n";
  return 0;
}
