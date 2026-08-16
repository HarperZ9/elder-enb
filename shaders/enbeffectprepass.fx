#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_NATIVE
#define ELDER_STAGE_OWNS_COLOR 1
#define ELDER_STAGE_OWNS_DEPTH 1
#define ELDER_STAGE_OWNS_NORMAL 1
#define ELDER_STAGE_OWNS_MASK 1
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 1
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 1
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 1
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_PREPASS
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_PARAMETER_SLOT 0
#define ELDER_STAGE_EXTERNAL_SB_RETAIN 1

#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderStageParameters.fxh"
#include "elder/ElderPipelineCommon.fxh"
#include "elder/ElderRuntimeParameters.fxh"
#include "elder/ElderPrepassCore.fxh"

// ENBSeries 0.504 HDR prepass interface. These resources are current-frame
// inputs only; the prepass owns no full-frame history and no object velocity.
float4 Timer;
float4 ScreenSize;
float4 Weather;
float ENightDayFactor;
float EInteriorFactor;

// Optional SkyrimBridge-compatible values. They are hidden and retained only
// when this Bridge-declaring stage compiles; absence selects native/spatial or
// identity routes without hard dependency.
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

float3 SB_Retain(float2 uv)
{
    float4 sink = ElderBridgeSunDirection + ElderBridgeRenderFrame;
    float retain_scale = Timer.x < -1.0e15 ? 0.0001 : 0.0;
    return sink.rgb * uv.x * retain_scale;
}

Texture2D TextureColor;
Texture2D TextureDepth;
Texture2D TextureNormal;
Texture2D TextureMask;

SamplerState Sampler0
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

bool ElderPrepassNativeAvailable()
{
    return ElderFinite1(ENightDayFactor)
        && ElderFinite1(EInteriorFactor)
        && ElderFinite3(Weather.xyz);
}

bool ElderPrepassBridgeAvailable()
{
    return ElderFinite1(ElderBridgeRenderFrame.x)
        && ElderBridgeRenderFrame.x > 0.0
        && ElderFinite3(ElderBridgeSunDirection.xyz);
}

float4 ElderPrepassMain(ElderStageVSOutput input) : SV_Target
{
    float4 source = TextureColor.Sample(Sampler0, input.texcoord);
    float raw_depth = TextureDepth.SampleLevel(Sampler0, input.texcoord, 0.0).x;
    float3 finite_source = ElderPrepassFiniteSceneOrBlack(source.rgb);

    if (!ElderPrepassRuntimeAvailable(ElderRuntimeRoomLight, ElderRuntimeStatus))
    {
        return float4(finite_source, source.a);
    }

    float3 normal_value =
        TextureNormal.SampleLevel(Sampler0, input.texcoord, 0.0).xyz;
    float mask_value = TextureMask.SampleLevel(Sampler0, input.texcoord, 0.0).x;
    float spatial_available = ElderFinite1(raw_depth)
        && ElderFinite3(normal_value)
        && ElderFinite1(mask_value) ? 1.0 : 0.0;
    float3 native_scene = ElderComposePrepass(
        input.texcoord, finite_source, raw_depth, EInteriorFactor);
    float3 bridge_scene = ElderComposePrepassWithRuntime(
        input.texcoord,
        finite_source + SB_Retain(input.texcoord),
        raw_depth,
        EInteriorFactor,
        ElderRuntimeRoomLight,
        ElderRuntimeStatus);
    float3 spatial_scene = ElderComposeSpatialPrepassFallback(
        input.texcoord, finite_source, raw_depth, EInteriorFactor);
    float4 selected = ElderResolveCapabilityColor(
        float4(native_scene, source.a),
        float4(bridge_scene, source.a),
        float4(spatial_scene, source.a),
        float4(finite_source, source.a),
        ElderPrepassNativeAvailable()
            && ElderPrepassRuntimeAvailable(ElderRuntimeRoomLight, ElderRuntimeStatus) ? 1.0 : 0.0,
        ElderPrepassBridgeAvailable() ? 1.0 : 0.0,
        spatial_available);
    return ElderStageIdentity(
        float4(finite_source, source.a), selected, ElderStageIsActive(), ELDER_STAGE_INTENSITY);
}

technique11 Draw <string UIName = "Elder [10] Prepass";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderPrepassMain()));
    }
}
