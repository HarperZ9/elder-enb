#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_BRIDGE
#define ELDER_STAGE_OWNS_COLOR 1
#define ELDER_STAGE_OWNS_DEPTH 0
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 0
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 1
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 0
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

float4 ElderBridgeSunDirection
<
    string UIName = "SB_Sun_Direction";
    string UIWidget = "Color";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

float4 ElderBridgeRenderFrame
<
    string UIName = "SB_Render_Frame";
    string UIWidget = "Color";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

Texture2D TextureColor;

SamplerState Sampler0
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

bool ElderSunSpriteBridgeAvailable()
{
    return ElderFinite1(ElderBridgeRenderFrame.x)
        && ElderBridgeRenderFrame.x > 0.0
        && ElderFinite3(ElderBridgeSunDirection.xyz)
        && ElderFinite1(ElderBridgeSunDirection.w)
        && length(ElderBridgeSunDirection.xyz) > 0.0001
        && ElderBridgeSunDirection.w > 0.0;
}

#include "elder/ElderSunSprite.fxh"

float4 ElderSunSpriteMain(ElderStageVSOutput input) : SV_Target
{
    float4 source = TextureColor.Sample(Sampler0, input.texcoord);
    if (!ElderStageIsActive()
        || ELDER_STAGE_INTENSITY <= 0.0
        || !ElderSunSpriteBridgeAvailable())
    {
        return float4(ElderFiniteOrBlack(source.rgb), source.a);
    }
    float3 sprite = ElderEvaluateSunSprite(
        input.texcoord,
        ElderBridgeSunDirection.xyz,
        ElderBridgeSunDirection.w);
    return float4(ElderFiniteOrBlack(source.rgb + sprite), source.a);
}

technique11 Draw <string UIName = "Elder [80] Sun Sprite";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderSunSpriteMain()));
    }
}
