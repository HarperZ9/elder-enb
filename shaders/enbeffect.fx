#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_NATIVE
#define ELDER_STAGE_OWNS_COLOR 1
#define ELDER_STAGE_OWNS_DEPTH 0
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 1
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 0
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_MAIN
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_PARAMETER_SLOT 5

#include "ElderNativeParameters.fxh"
#include "ElderColorCore.fxh"
#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderStageParameters.fxh"
#include "elder/ElderPipelineCommon.fxh"

// ENBSeries 0.504 main-effect interface. The stage consumes current HDR scene,
// ENB bloom/lens surfaces, and the scalar adaptation result without claiming
// arbitrary full-frame history or object motion.
float4 Timer;
float EInteriorFactor;
float4 Params01[7];
float4 ENBParams01;

Texture2D TextureColor;
Texture2D TextureBloom;
Texture2D TextureLens;
Texture2D TextureAdaptation;

SamplerState Sampler0
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

SamplerState Sampler1
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

ElderColorCoreParameters ElderBuildNativeColorCoreParameters()
{
    ElderColorCoreParameters parameters;
    parameters.exposure_ev =
        ElderNativeSanitize_ElderExposureCompensationEv();
    parameters.warm_cool = ElderNativeSanitize_ElderColorWarmCool();
    parameters.tint = ElderNativeSanitize_ElderColorTint();
    parameters.toe = ElderNativeSanitize_ElderTonemapToe();
    parameters.shoulder = ElderNativeSanitize_ElderTonemapShoulder();
    parameters.mid_gray = ElderNativeSanitize_ElderTonemapMidGray();
    parameters.white_point = ElderNativeSanitize_ElderTonemapWhitePoint();
    parameters.local_contrast =
        ElderNativeSanitize_ElderTonemapLocalContrast();
    parameters.saturation = ElderNativeSanitize_ElderColorSaturation();
    parameters.vibrance = ElderNativeSanitize_ElderColorVibrance();
    parameters.highlight_desaturation =
        ElderNativeSanitize_ElderHighlightDesaturation();
    parameters.highlight_gamut_preservation =
        ElderNativeSanitize_ElderHighlightGamutPreservation();
    parameters.shadow_hue_stability =
        ElderNativeSanitize_ElderShadowHueStability();
    parameters.shadow_tint = ElderNativeSanitize_ElderShadowTint();
    parameters.highlight_tint = ElderNativeSanitize_ElderHighlightTint();
    return parameters;
}

static const float ELDER_HDR_DISPLAY_MAX = 64.0;

float3 ElderBoundHdrDisplay(float3 color)
{
    return min(ElderFiniteOrBlack(color), ELDER_HDR_DISPLAY_MAX.xxx);
}

float3 ElderBoundOpticalContribution(float3 contribution)
{
    float optical_cap = lerp(0.18, 0.45, saturate(ElderMainEffectOpticalShape));
    return min(ElderFiniteOrBlack(contribution), optical_cap.xxx);
}

float3 ElderResolveMainSource(float2 texcoord)
{
    float3 scene_color = ElderBoundHdrDisplay(
        TextureColor.Sample(Sampler0, texcoord).rgb);
    float3 bloom_add = ElderBoundOpticalContribution(TextureBloom.Sample(Sampler1, texcoord).rgb);
    float3 lens_add = ElderBoundOpticalContribution(TextureLens.Sample(Sampler1, texcoord).rgb);
    float3 optical_color = ElderBoundHdrDisplay(scene_color + bloom_add + lens_add);
    return optical_color;
}

float3 ElderResolveMainCapability(float3 color, float adaptation_scalar)
{
    return ElderResolveCapabilityColor(
        float4(color, 1.0),
        ElderFinite1(adaptation_scalar) ? 1.0 : 0.0,
        0.0,
        0.0).rgb;
}

// Adaptation consumption. The adaptation stage publishes a smoothed scene
// luminance through TextureAdaptation, and publishes the raw 0.18 mid-gray
// anchor when its dial is off, which resolves this steer to exactly zero.
// This turns the scalar into a bounded exposure steer toward mid-gray. The
// bounds keep it reading as eye response rather than auto-brightness, and
// the adaptation stage's own dials shape the scalar upstream, so this
// consumer stays parameter-free.
static const float ELDER_AUTO_EXPOSURE_TARGET = 0.18;
static const float ELDER_AUTO_EXPOSURE_MAX_BRIGHTEN_EV = 1.0;
static const float ELDER_AUTO_EXPOSURE_MAX_DARKEN_EV = 2.0;

float ElderMainAutoExposureEv(float adaptation_scalar)
{
    if (!ElderFinite1(adaptation_scalar) || adaptation_scalar <= 0.0)
    {
        return 0.0;
    }

    float adapted = clamp(adaptation_scalar, 0.001, 64.0);
    float auto_ev = log2(ELDER_AUTO_EXPOSURE_TARGET / adapted);
    return clamp(
        auto_ev,
        -ELDER_AUTO_EXPOSURE_MAX_DARKEN_EV,
        ELDER_AUTO_EXPOSURE_MAX_BRIGHTEN_EV);
}

float4 ElderMainEffectPixel(ElderStageVSOutput input) : SV_Target
{
    float adaptation_scalar =
        TextureAdaptation.SampleLevel(Sampler0, input.texcoord, 0.0).x;
    float3 linear_color = ElderResolveMainCapability(
        ElderResolveMainSource(input.texcoord),
        adaptation_scalar);
    if (!ElderSuiteEnabled
        || !ElderMainEffectEnabled
        || ElderMainEffectIntensity <= 0.0
        || !ElderNativeActive_ElderMasterEnabled()
        || !ElderNativeSanitize_ElderMasterEnabled())
    {
        return float4(ElderBoundHdrDisplay(linear_color), 1.0);
    }

    ElderColorCoreParameters core_parameters =
        ElderBuildNativeColorCoreParameters();
    core_parameters.exposure_ev += ElderMainAutoExposureEv(adaptation_scalar);
    float3 evaluated = ElderEvaluateColorCore(linear_color, core_parameters);
    float3 mixed = lerp(
        linear_color,
        evaluated,
        saturate(ElderMainEffectIntensity));
    return float4(ElderBoundHdrDisplay(mixed), 1.0);
}

float4 ElderMainEffectFallbackPixel(ElderStageVSOutput input) : SV_Target
{
    return float4(
        ElderBoundHdrDisplay(TextureColor.Sample(Sampler0, input.texcoord).rgb),
        1.0);
}

technique11 Draw <string UIName = "Elder ENB";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderMainEffectPixel()));
    }
}

technique11 ELDERPASSTHROUGH <string UIName = "Elder: Safe passthrough";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderMainEffectFallbackPixel()));
    }
}

technique11 ORIGINALPOSTPROCESS <string UIName = "Vanilla";> // do not modify this technique
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderMainEffectFallbackPixel()));
    }
}
