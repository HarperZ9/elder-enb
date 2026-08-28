#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_NATIVE
#define ELDER_STAGE_OWNS_COLOR 1
#define ELDER_STAGE_OWNS_DEPTH 0
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 0
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 1
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 0
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_ADAPTATION
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_PARAMETER_SLOT 3

#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderStageParameters.fxh"
#include "elder/ElderPipelineCommon.fxh"

Texture2D TextureCurrent;
Texture2D TexturePrevious;
float4 Timer;

SamplerState Sampler0
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

#include "elder/ElderAdaptation.fxh"

// The host walks this stage by fixed technique names, the same protocol as
// the depth of field chain. It binds TextureCurrent as the 256x256 internal
// downscale of the scene and runs Downsample onto a 16x16 target, then
// rebinds that 16x16 result as TextureCurrent and runs Draw onto the 1x1
// adaptation output. Without a Downsample technique the 16x16 surface is
// never written and Draw meters an unwritten target. Both intermediate
// surfaces are R32, so only the red channel survives between passes.

float4 ElderAdaptationDownsamplePixel(ElderStageVSOutput input) : SV_Target
{
    // Each 16x16 output texel averages its own 16x16 block of the 256x256
    // input, so the two passes together meter every texel of the host
    // downscale exactly once.
    float3 block_color = 0.0.xxx;
    [loop]
    for (uint block_y = 0u; block_y < 16u; ++block_y)
    {
        [loop]
        for (uint block_x = 0u; block_x < 16u; ++block_x)
        {
            float2 block_offset =
                ((float2(block_x, block_y) + 0.5.xx) / 16.0 - 0.5.xx) / 16.0;
            block_color += ElderFiniteOrBlack(
                TextureCurrent.SampleLevel(
                    Sampler0, input.texcoord + block_offset, 0.0).rgb);
        }
    }
    block_color /= 256.0;
    float block_luminance = ElderAdaptationMeasuredLuminance(block_color);
    return float4(block_luminance.xxx, 1.0);
}

float4 ElderAdaptationMain(ElderStageVSOutput input) : SV_Target
{
    float previous_scalar =
        TexturePrevious.SampleLevel(Sampler0, float2(0.5, 0.5), 0.0).x;

    // Here TextureCurrent is the 16x16 luminance grid Downsample wrote, an
    // R32 surface, so the measurement lives in the red channel alone.
    float measured_luminance = 0.0;
    [loop]
    for (uint grid_y = 0u; grid_y < 16u; ++grid_y)
    {
        [loop]
        for (uint grid_x = 0u; grid_x < 16u; ++grid_x)
        {
            float2 grid_uv = (float2(grid_x, grid_y) + 0.5.xx) / 16.0;
            float grid_luminance =
                TextureCurrent.SampleLevel(Sampler0, grid_uv, 0.0).x;
            measured_luminance += ElderFinite1(grid_luminance)
                ? max(grid_luminance, 0.0)
                : 0.0;
        }
    }
    measured_luminance /= 256.0;

    float delta_seconds = ElderAdaptationDeltaSeconds(Timer);
    float adapted_luminance = ElderUpdateAdaptedLuminance(
        measured_luminance, previous_scalar, delta_seconds);

    // The published scalar is one side of a fixed contract with
    // enbeffect.fx, which reads this target as smoothed scene luminance.
    // The contract holds with the dial off too: publish the raw 0.18
    // mid-gray anchor so the consumer's exposure steer resolves to exactly
    // zero. Passing scene color through here fed unsmoothed red-channel
    // radiance into the exposure math, and the dial-clamped neutral would
    // leak a nonzero steer whenever the luminance range excludes 0.18.
    float published_scalar = ElderStageIsActive() ? adapted_luminance : 0.18;
    return float4(published_scalar.xxx, 1.0);
}

// Fixed-name helper pass. No UIName, so it never shifts the GUI dropdown
// arithmetic that TECHNIQUE=1 indexes.
technique11 Downsample
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderAdaptationDownsamplePixel()));
    }
}

technique11 Draw <string UIName = "Elder [40] Adaptation";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderAdaptationMain()));
    }
}
