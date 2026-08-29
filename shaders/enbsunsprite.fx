#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_NATIVE
#define ELDER_STAGE_OWNS_COLOR 0
#define ELDER_STAGE_OWNS_DEPTH 0
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 1
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 1
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 1
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_SUNSPRITE
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_PARAMETER_SLOT 7

#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderStageParameters.fxh"
#include "elder/ElderPipelineCommon.fxh"

// ENBSeries 0.504 sun-sprite interface. ENB draws this stage additively
// (srcblend = one, destblend = one) into the HDR scene, so every inactive
// path must return black; returning scene color here would double it.
// LightParameters.xy is the sun position in y-up clip-space NDC and .w is
// ENB's own sun visibility. TextureMask holds the per-frame sun occlusion
// mask, sampled at its center the way the stock 0.504 sample file does.
float4 ScreenSize;
float4 LightParameters;

float4 ElderBridgeSunNdc
<
    string UIName = "SB_Sun_NDC";
    string UIWidget = "Color";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

float4 ElderBridgeRenderFrame
<
    string UIName = "SB_Render_Frame";
    string UIWidget = "Color";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

Texture2D TextureMask;

SamplerState Sampler0
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

#include "elder/ElderSunSprite.fxh"

// Bridge absence never gates the sprite: with no bridge data the native
// path draws from LightParameters alone. A live bridge tints the sprite
// by elevation and fades it across -0.05..0.02 radians, reaching zero at
// or below -0.05, so bridge elevation can suppress a sprite the native
// path would draw. SB_Sun_NDC carries .xy = NDC, .z = on-screen flag,
// .w = sun elevation in radians.
bool ElderSunSpriteBridgeAvailable()
{
    return ElderFinite1(ElderBridgeRenderFrame.x)
        && ElderBridgeRenderFrame.x > 0.0
        && ElderFinite3(ElderBridgeSunNdc.xyz)
        && ElderFinite1(ElderBridgeSunNdc.w)
        && ElderBridgeSunNdc.z > 0.5;
}

float4 ElderSunSpriteMain(ElderStageVSOutput input) : SV_Target
{
    if (!ElderStageIsActive() || ELDER_STAGE_INTENSITY <= 0.0)
    {
        return float4(0.0.xxx, 0.0);
    }

    float2 sun_ndc = LightParameters.xy;
    float sun_visibility = saturate(LightParameters.w);
    if (!ElderFinite3(float3(sun_ndc, LightParameters.w))
        || sun_visibility <= 0.0
        || any(abs(sun_ndc) > 1.2.xx))
    {
        return float4(0.0.xxx, 0.0);
    }

    // Cubing the mask sharpens cloud occlusion, matching the stock sample.
    float sun_mask = TextureMask.SampleLevel(Sampler0, 0.5.xx, 0.0).x;
    float visibility = sun_mask * sun_mask * sun_mask * sun_visibility;

    float3 sun_color = float3(1.0, 0.85, 0.66);
    if (ElderSunSpriteBridgeAvailable())
    {
        float elevation = ElderBridgeSunNdc.w;
        float warmth = 1.0 - saturate(elevation / 0.35);
        sun_color = lerp(float3(1.0, 0.92, 0.80), float3(1.0, 0.52, 0.26), warmth);
        visibility *= smoothstep(-0.05, 0.02, elevation);
    }

    float2 sun_uv = sun_ndc * float2(0.5, -0.5) + 0.5.xx;
    float3 sprite = ElderEvaluateSunSprite(
        input.texcoord,
        sun_uv,
        max(ScreenSize.z, 0.1),
        visibility,
        sun_color);
    return float4(ElderFiniteOrBlack(sprite), 0.0);
}

technique11 Draw <string UIName = "Elder [80] Sun Sprite";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderSunSpriteMain()));
    }
}
