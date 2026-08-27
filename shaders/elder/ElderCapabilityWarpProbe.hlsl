#ifndef ELDER_CAPABILITY_WARP_NATIVE_AVAILABLE
#define ELDER_CAPABILITY_WARP_NATIVE_AVAILABLE 1
#endif

#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_NATIVE
#define ELDER_STAGE_OWNS_COLOR 0
#define ELDER_STAGE_OWNS_DEPTH 1
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW ELDER_CAPABILITY_WARP_NATIVE_AVAILABLE
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 1
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE ELDER_CAPABILITY_WARP_NATIVE_AVAILABLE
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_NONE
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_EXTERNAL_SB_RETAIN 1

#include "ElderHostCapabilities.fxh"
#include "ElderPipelineCommon.fxh"

struct ElderCapabilityWarpInput
{
    float4 native_color;
    float4 bridge_color;
    float4 spatial_color;
    float4 identity_color;
    float4 runtime_availability;
};

struct ElderCapabilityWarpOutput
{
    float4 wrapper_color;
    float4 direct_color;
    float4 zero_intensity_color;
    float4 disabled_color;
    float4 active_full_color;
    uint route;
    float3 padding;
};

StructuredBuffer<ElderCapabilityWarpInput> ElderCapabilityWarpInputs : register(t0);
RWStructuredBuffer<ElderCapabilityWarpOutput> ElderCapabilityWarpOutputs : register(u0);

float3 SB_Retain(float2 uv)
{
    return float3(0.03125, 0.0625, 0.09375) * (uv.x + uv.y);
}

[numthreads(1, 1, 1)]
void ElderCapabilityWarpProbeMain(uint3 dispatch_id : SV_DispatchThreadID)
{
    ElderCapabilityWarpInput input = ElderCapabilityWarpInputs[dispatch_id.x];
    ElderCapabilityValue direct = ElderResolveCapability(
        ElderMakeCapability(input.native_color, input.runtime_availability.x),
        ElderMakeCapability(input.bridge_color, input.runtime_availability.y),
        ElderMakeCapability(input.spatial_color, input.runtime_availability.z),
        ElderMakeCapability(input.identity_color, input.runtime_availability.w));

    ElderCapabilityWarpOutput output;
    output.wrapper_color = ElderResolveCapabilityColor(
        input.native_color,
        input.bridge_color,
        input.spatial_color,
        input.identity_color,
        input.runtime_availability.x,
        input.runtime_availability.y,
        input.runtime_availability.z);
    output.direct_color = direct.color;
    float4 bridge_candidate = float4(
        input.bridge_color.rgb + SB_Retain(float2(0.25, 0.75)),
        input.bridge_color.a);
    output.zero_intensity_color =
        ElderStageIdentity(input.identity_color, bridge_candidate, true, 0.0);
    output.disabled_color =
        ElderStageIdentity(input.identity_color, bridge_candidate, false, 1.0);
    output.active_full_color =
        ElderStageIdentity(input.identity_color, bridge_candidate, true, 1.0);
    output.route = direct.route;
    output.padding = 0.0.xxx;
    ElderCapabilityWarpOutputs[dispatch_id.x] = output;
}
