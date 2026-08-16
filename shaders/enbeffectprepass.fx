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

// Optional SkyrimBridge-compatible public values. They are hidden and retained
// only when this Bridge-declaring stage compiles; absence selects native/spatial
// or identity routes without a DLL dependency or private ABI.
float4 SB_Render_Frame
<
    string UIName = "SB_Render_Frame";
    string UIWidget = "Color";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

float4 SB_Interior_Flags
<
    string UIName = "SB_Interior_Flags";
    string UIWidget = "Color";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

float4 SB_Interior_Ambient
<
    string UIName = "SB_Interior_Ambient";
    string UIWidget = "Color";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

float4 SB_Interior_DirColor
<
    string UIName = "SB_Interior_DirColor";
    string UIWidget = "Color";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

float3 SB_Retain(float2 uv)
{
    float4 sink =
        SB_Render_Frame + SB_Interior_Flags + SB_Interior_Ambient + SB_Interior_DirColor;
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

ElderScreenSpaceSample ElderReadPrepassSample(float2 uv)
{
    return ElderMakeScreenSpaceSample(
        TextureColor.SampleLevel(Sampler0, uv, 0.0).rgb,
        TextureDepth.SampleLevel(Sampler0, uv, 0.0).x,
        TextureNormal.SampleLevel(Sampler0, uv, 0.0).xyz,
        TextureMask.SampleLevel(Sampler0, uv, 0.0).x);
}

ElderScreenSpaceNeighborhood ElderReadPrepassNeighborhood(
    float2 uv,
    float3 selected_center,
    float raw_depth,
    float3 normal_value,
    float mask_value)
{
    float2 safe_size = max(ScreenSize.xy, float2(1.0, 1.0));
    float2 texel = 1.0 / safe_size;
    ElderScreenSpaceSample center = ElderMakeScreenSpaceSample(
        selected_center, raw_depth, normal_value, mask_value);
    return ElderGatherScreenNeighborhood(
        center,
        ElderReadPrepassSample(saturate(uv - float2(texel.x, 0.0))),
        ElderReadPrepassSample(saturate(uv + float2(texel.x, 0.0))),
        ElderReadPrepassSample(saturate(uv - float2(0.0, texel.y))),
        ElderReadPrepassSample(saturate(uv + float2(0.0, texel.y))));
}

bool ElderPrepassNativeAvailable()
{
    return ElderFinite1(ENightDayFactor)
        && ElderFinite1(EInteriorFactor)
        && ElderFinite3(Weather.xyz);
}

bool ElderPrepassBridgeAvailable()
{
    return ElderFinite1(SB_Render_Frame.x)
        && SB_Render_Frame.x > 0.0
        && ElderFinite1(SB_Interior_Flags.x)
        && ElderFinite1(SB_Interior_Flags.y)
        && ElderFinite3(SB_Interior_Ambient.xyz)
        && ElderFinite3(SB_Interior_DirColor.xyz);
}

float4 ElderPrepassMain(ElderStageVSOutput input) : SV_Target
{
    float4 source = TextureColor.Sample(Sampler0, input.texcoord);
    if (!ElderStageIsActive())
    {
        return source;
    }

    float raw_depth = TextureDepth.SampleLevel(Sampler0, input.texcoord, 0.0).x;
    float3 finite_source = ElderPrepassFiniteSceneOrBlack(source.rgb);

    bool runtime_available =
        ElderPrepassRuntimeAvailable(ElderRuntimeRoomLight, ElderRuntimeStatus);
    if (!runtime_available)
    {
        return float4(finite_source, source.a);
    }

    float4 selected = float4(finite_source, source.a);
    float3 normal_value =
        TextureNormal.SampleLevel(Sampler0, input.texcoord, 0.0).xyz;
    float mask_value = TextureMask.SampleLevel(Sampler0, input.texcoord, 0.0).x;
    float spatial_available = ElderFinite1(raw_depth)
        && ElderFinite3(normal_value)
        && ElderFinite1(mask_value) ? 1.0 : 0.0;

    if (ElderPrepassNativeAvailable())
    {
        ElderScreenSpaceNeighborhood neighborhood = ElderReadPrepassNeighborhood(
            input.texcoord, finite_source, raw_depth, normal_value, mask_value);
        selected.rgb = ElderComposePrepassWithRuntimeAndNeighborhood(
            finite_source,
            EInteriorFactor,
            ElderRuntimeRoomLight,
            ElderRuntimeStatus,
            neighborhood);
    }
    else if (ElderPrepassBridgeAvailable())
    {
        float3 bridge_source = finite_source + SB_Retain(input.texcoord);
        ElderScreenSpaceNeighborhood neighborhood = ElderReadPrepassNeighborhood(
            input.texcoord, bridge_source, raw_depth, normal_value, mask_value);
        selected.rgb = ElderComposePrepassWithRuntimeAndNeighborhood(
            bridge_source,
            EInteriorFactor,
            ElderRuntimeRoomLight,
            ElderRuntimeStatus,
            neighborhood);
    }
    else if (spatial_available > 0.0)
    {
        ElderScreenSpaceNeighborhood neighborhood = ElderReadPrepassNeighborhood(
            input.texcoord, finite_source, raw_depth, normal_value, mask_value);
        selected.rgb = ElderComposeSpatialPrepassFallback(
            finite_source, neighborhood, EInteriorFactor);
    }

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
