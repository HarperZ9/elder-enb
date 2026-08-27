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

float4 ElderAdaptationMain(ElderStageVSOutput input) : SV_Target
{
    float4 source = TextureCurrent.Sample(Sampler0, input.texcoord);
    float previous_scalar =
        TexturePrevious.SampleLevel(Sampler0, float2(0.5, 0.5), 0.0).x;
    float measured_luminance = ElderAdaptationMeasuredLuminance(source.rgb);
    float delta_seconds = ElderAdaptationDeltaSeconds(Timer);
    float adapted_luminance = ElderUpdateAdaptedLuminance(
        measured_luminance, previous_scalar, delta_seconds);
    float stable_alpha = ElderFinite1(source.a) ? source.a : 1.0;
    float4 scalar_output = float4(adapted_luminance.xxx, stable_alpha);
    return ElderStageIsActive() ? scalar_output : source;
}

technique11 Draw <string UIName = "Elder [40] Adaptation";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderAdaptationMain()));
    }
}
