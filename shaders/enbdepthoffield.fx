#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_SPATIAL
#define ELDER_STAGE_OWNS_COLOR 1
#define ELDER_STAGE_OWNS_DEPTH 1
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 0
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 0
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_DOF
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_PARAMETER_SLOT 1

#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderStageParameters.fxh"
#include "elder/ElderPipelineCommon.fxh"

// ENBSeries 0.504 depth-of-field interface. The host walks the fixed-name
// technique chain ReadFocus, Focus, DOF, then DOF1 through DOF7 in order.
// The first two write the host's own focus surfaces by name; the annotated
// members write the declared scratch surfaces; the rest write the main
// chain. A single free-named technique never enters that walk, which is why
// the previous one-technique stage produced no visible defocus on the
// proven 0.504 binary.
Texture2D TextureColor;
Texture2D TextureOriginal;
Texture2D TextureDepth;
Texture2D TextureCurrent;
Texture2D TextureFocus;
Texture2D RenderTargetRGBA32;
Texture2D RenderTargetR16F;
Texture2D RenderTargetRGBA64F;
float4 ScreenSize;

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

#include "elder/ElderDepthOfField.fxh"

// The measurement technique renders through the host's vertex stream at
// full quad coverage, so every texel of the small focus surface is
// written at any allocation size, and each covered pixel samples the same
// fixed measurement points, so texel zero always holds the measured
// value. A corner quad scaled to one sixteenth was tried here first: its
// right and bottom edges land exactly on the first pixel center for
// eight-texel and smaller targets, and the top-left rasterization rule
// then covers nothing, leaving texel zero at the clear value.
float4 ElderReadFocusPixel(ElderStageVSOutput input) : SV_Target
{
    float measured_distance = ElderMeasureAutofocusDistance();
    return float4(measured_distance.xxx, 1.0);
}

float4 ElderFocusPixel(ElderStageVSOutput input) : SV_Target
{
    float measured_distance = TextureCurrent.Load(int3(0, 0, 0)).x;
    float focus_distance = ElderResolveFocusDistance(measured_distance);
    return float4(focus_distance.xxx, 1.0);
}

float4 ElderCocPixel(ElderStageVSOutput input) : SV_Target
{
    return ElderComputeCocTarget(input.texcoord);
}

float4 ElderNearSpreadPixel(ElderStageVSOutput input) : SV_Target
{
    float spread_value = ElderSpreadNearCoc(input.texcoord);
    return float4(spread_value.xxx, 1.0);
}

float4 ElderNearMergePixel(ElderStageVSOutput input) : SV_Target
{
    return ElderMergeNearCoc(input.texcoord);
}

float4 ElderFarBokehPixel(ElderStageVSOutput input) : SV_Target
{
    return ElderGatherFarBokeh(input.texcoord);
}

float4 ElderNearBokehPixel(ElderStageVSOutput input) : SV_Target
{
    return ElderGatherNearBokeh(input.texcoord);
}

// The identity input pins alpha to zero so a disabled stage hands the
// smoothing passes a zero blur amount and they leave the frame untouched.
float4 ElderCompositePixel(ElderStageVSOutput input) : SV_Target
{
    float4 source = float4(
        ElderFiniteOrBlack(
            TextureOriginal.SampleLevel(Sampler0, input.texcoord, 0.0).rgb),
        0.0);
    float4 selected = ElderApplyDepthOfField(input.texcoord, source);
    return ElderStageIdentity(
        source, selected, ElderStageIsActive(), ELDER_STAGE_INTENSITY);
}

float4 ElderSmoothHorizontalPixel(ElderStageVSOutput input) : SV_Target
{
    return ElderSmoothBokeh(input.texcoord, float2(1.0, 0.0), false);
}

float4 ElderSmoothVerticalPixel(ElderStageVSOutput input) : SV_Target
{
    return ElderSmoothBokeh(input.texcoord, float2(0.0, 1.0), true);
}

technique11 ReadFocus
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderReadFocusPixel()));
    }
}

technique11 Focus
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderFocusPixel()));
    }
}

// Tier 0 budgets zero rings, and every gather in ElderDepthOfField.fxh
// compiles to a copy there, so the eight full-resolution members below
// would spend their passes reproducing the input frame. This guard keeps
// the walk to one main-chain passthrough at that tier. The fixed name DOF
// and its UIName survive, so the GUI dropdown and the shipped TECHNIQUE=1
// key hold across tiers; the RenderTarget annotation goes away because
// the single member must write the main chain.
#if ELDER_DOF_RINGS_VALUE == 0

float4 ElderTierZeroPassthroughPixel(ElderStageVSOutput input) : SV_Target
{
    return float4(
        ElderFiniteOrBlack(
            TextureOriginal.SampleLevel(Sampler0, input.texcoord, 0.0).rgb),
        1.0);
}

technique11 DOF <string UIName = "Elder [20] Depth of Field";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(
            CompileShader(ps_5_0, ElderTierZeroPassthroughPixel()));
    }
}

#else

// The one UIName-bearing member: the GUI dropdown lists it at index one and
// the shipped TECHNIQUE=1 preset key selects it. Helper members carry no
// UIName so they never shift that arithmetic.
technique11 DOF <string UIName = "Elder [20] Depth of Field"; string RenderTarget = "RenderTargetRGBA32";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderCocPixel()));
    }
}

technique11 DOF1 <string RenderTarget = "RenderTargetR16F";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderNearSpreadPixel()));
    }
}

technique11 DOF2 <string RenderTarget = "RenderTargetRGBA32";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderNearMergePixel()));
    }
}

technique11 DOF3 <string RenderTarget = "RenderTargetRGBA64F";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderFarBokehPixel()));
    }
}

technique11 DOF4
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderNearBokehPixel()));
    }
}

technique11 DOF5
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderCompositePixel()));
    }
}

technique11 DOF6
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderSmoothHorizontalPixel()));
    }
}

technique11 DOF7
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderSmoothVerticalPixel()));
    }
}

#endif  // ELDER_DOF_RINGS_VALUE == 0
