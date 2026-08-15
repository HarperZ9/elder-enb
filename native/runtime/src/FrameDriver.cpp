#include "elder/runtime/FrameDriver.hpp"

#include <cstring>

namespace elder::runtime {
namespace {

using enbcore::enb::Parameter;
using enbcore::enb::ParameterKind;
using enbcore::enb::RenderInfo;
using enbcore::runtime::FramePulsePayload;
using enbcore::runtime::FramePulseResult;
using enbcore::runtime::FramePulseSample;
using enbcore::runtime::FramePulseState;
using enbcore::runtime::InactiveFramePulsePayload;
using enbcore::runtime::PublishFramePulse;

}  // namespace

FramePulseSample BuildSample(const RenderInfo* const render_info,
                             const FrameTiming& timing) noexcept
{
    FramePulseSample sample{};
    sample.delta_seconds = timing.delta_seconds;
    sample.output_width = 0U;
    sample.output_height = 0U;
    sample.render_info_available = false;

    if (render_info == nullptr || !timing.has_previous_frame) {
        return sample;
    }

    sample.output_width = render_info->screen_size_x;
    sample.output_height = render_info->screen_size_y;
    sample.render_info_available = true;
    return sample;
}

Parameter EncodePulseParameter(const FramePulsePayload& payload) noexcept
{
    Parameter parameter{};
    parameter.type = ParameterKind::Color4;
    parameter.size = static_cast<std::uint32_t>(enbcore::enb::kParameterPayloadBytes);

    const float values[4]{
        payload.frame,
        payload.delta_seconds,
        payload.width,
        payload.height,
    };
    static_assert(sizeof(values) == enbcore::enb::kParameterPayloadBytes,
                  "the pulse payload must fill the SDK parameter exactly");
    std::memcpy(parameter.data.data(), values, sizeof(values));
    return parameter;
}

FrameOutcome DriveFrame(FramePulseState& state,
                        const RenderInfo* const render_info,
                        const FrameTiming& timing) noexcept
{
    const FramePulseSample sample = BuildSample(render_info, timing);

    FramePulsePayload payload = InactiveFramePulsePayload();
    const FramePulseResult result = PublishFramePulse(state, payload, sample);

    const PulseParameterWrite write = PlanPulseParameterWrite(result, payload);

    return FrameOutcome{
        EncodePulseParameter(write.payload),
        write.decision,
        write.diagnostic,
        result.status,
    };
}

}  // namespace elder::runtime
