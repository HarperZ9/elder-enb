#pragma once

#include <elder/runtime/PulsePublication.hpp>

#include <enbcore/enb/SdkContract.hpp>
#include <enbcore/runtime/FramePulse.hpp>

#include <array>
#include <cstdint>

namespace elder::runtime {

// The frame driver: everything the ENB callback does, minus the callback.
//
// The callback itself runs on the render thread inside a live frame, so the
// parts that can be wrong are kept out of it and made testable here. Building
// the sample, deciding the write, and encoding the sixteen bytes are pure
// functions over plain structs. PluginMain supplies the clock and the host.

// Elder's target shaders. ENB addresses a parameter by shader file and symbol,
// so a value must be written once per file that reads it. Uppercase matches
// what the SDK expects.
inline constexpr std::array<const char*, 3> kElderTargetShaders{
    "ENBEFFECT.FX",
    "ENBEFFECTPREPASS.FX",
    "ENBEFFECTPOSTPASS.FX",
};

// The HLSL symbol declared in ElderRuntimeParameters.fxh. The pipe-separated
// key in PulsePublication.hpp is the UIName ENB shows a user; this is what the
// SDK write addresses.
inline constexpr const char* kElderFramePulseSymbol = "ElderRuntimeFramePulse";

// A frame's timing, measured by the caller. Separated from the sample so the
// clock stays in PluginMain and the policy here stays testable.
struct FrameTiming {
    float delta_seconds;
    bool has_previous_frame;
};

// Builds the sample the core validates. A first frame has no previous
// timestamp, so its delta is not measured and the sample is marked
// unavailable: the core then withholds, and the runtime publishes inactive.
// That is the correct first frame, not a defect to paper over.
[[nodiscard]] enbcore::runtime::FramePulseSample BuildSample(
    const enbcore::enb::RenderInfo* render_info,
    const FrameTiming& timing) noexcept;

// Encodes a payload as the sixteen-byte COLOR4 the SDK carries. Always writes
// all four floats and always reports size 16, including for the inactive
// payload, so a stale live value is overwritten rather than left behind.
[[nodiscard]] enbcore::enb::Parameter EncodePulseParameter(
    const enbcore::runtime::FramePulsePayload& payload) noexcept;

// One frame, resolved. Advances the counter through the core, applies Elder's
// publication policy, and returns the bytes to write plus the reason.
struct FrameOutcome {
    enbcore::enb::Parameter parameter;
    PulsePublicationDecision decision;
    PulsePublicationDiagnostic diagnostic;
    enbcore::runtime::FramePulseStatus pulse_status;
};

[[nodiscard]] FrameOutcome DriveFrame(
    enbcore::runtime::FramePulseState& state,
    const enbcore::enb::RenderInfo* render_info,
    const FrameTiming& timing) noexcept;

}  // namespace elder::runtime
