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
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_UNDERWATER
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_PARAMETER_SLOT 8

#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderStageParameters.fxh"
#include "elder/ElderPipelineCommon.fxh"

Texture2D TextureColor;
Texture2D TextureDepth;

SamplerState Sampler0
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

#include "elder/ElderUnderwater.fxh"

float4 ElderUnderwaterMain(ElderStageVSOutput input) : SV_Target
{
    float4 source = TextureColor.Sample(Sampler0, input.texcoord);
    if (!ElderStageIsActive() || ELDER_STAGE_INTENSITY <= 0.0)
    {
        return float4(ElderFiniteOrBlack(source.rgb), source.a);
    }
    float raw_depth = TextureDepth.SampleLevel(Sampler0, input.texcoord, 0.0).x;
    float3 medium = ElderFinite1(raw_depth)
        ? ElderEvaluateUnderwater(input.texcoord, source.rgb, raw_depth)
        : ElderFiniteOrBlack(source.rgb);
    return float4(medium, source.a);
}

technique11 Draw <string UIName = "Elder [90] Underwater";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderUnderwaterMain()));
    }
}
