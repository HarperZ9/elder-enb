#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_IDENTITY
#define ELDER_STAGE_OWNS_COLOR 1
#define ELDER_STAGE_OWNS_DEPTH 0
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 0
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 0
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_LENS
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_PARAMETER_SLOT 4

#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderStageParameters.fxh"
#include "elder/ElderPipelineCommon.fxh"

// ENB 0.504 lens interface: the host binds TextureDownsampled here, the
// same square downsampled HDR scene feed the bloom chain thresholds. It
// does not bind TextureBloom at this stage, and an unbound ps_5_0 view
// reads zero, so a lens stage declaring one renders black on every path.
Texture2D TextureDownsampled;
float4 ScreenSize;

// Linear filtering: every ghost and halo tap lands between texels of the
// square scene feed at display resolution.
SamplerState Sampler0
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

#include "elder/ElderLens.fxh"

float4 ElderLensMain(ElderStageVSOutput input) : SV_Target
{
    float4 source = TextureDownsampled.Sample(Sampler0, input.texcoord);
    return ElderApplyLens(input.texcoord, source);
}

technique11 Draw <string UIName = "Elder [50] Lens";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderLensMain()));
    }
}
