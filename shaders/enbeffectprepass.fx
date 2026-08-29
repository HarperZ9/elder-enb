#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_NATIVE
#define ELDER_STAGE_OWNS_COLOR 1
#define ELDER_STAGE_OWNS_DEPTH 1
#define ELDER_STAGE_OWNS_NORMAL 0
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
    // Host-fed lanes can carry non-finite values; the finite guard keeps
    // the sink exactly zero even then, so the retention term never taints
    // the frame.
    return ElderFiniteOrBlack(sink.rgb) * uv.x * retain_scale;
}

Texture2D TextureColor;
Texture2D TextureDepth;
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
        float3(0.5, 0.5, 1.0),
        TextureMask.SampleLevel(Sampler0, uv, 0.0).a);
}

ElderScreenSpaceNeighborhood ElderReadPrepassNeighborhood(
    float2 uv,
    float3 selected_center,
    float raw_depth,
    float3 normal_value,
    float mask_value)
{
    float2 texel = ElderScreenTexel(ScreenSize);
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

    // The runtime pulse gates only the room-light composition. Bounded spatial
    // work needs no runtime, so an absent pulse must not silence the stage.
    bool runtime_available =
        ElderPrepassRuntimeAvailable(ElderRuntimeRoomLight, ElderRuntimeStatus);

    float4 selected = float4(finite_source, source.a);
    // The 0.504 host publishes no normal surface; the neutral encoded
    // normal keeps the neighborhood shape and the normal edge term at
    // its true zero.
    float3 normal_value = float3(0.5, 0.5, 1.0);
    // The 0.504 prepass mask carries the skinned-object and sss payload
    // in alpha; red is undocumented.
    float mask_value = TextureMask.SampleLevel(Sampler0, input.texcoord, 0.0).a;
    float spatial_available = ElderFinite1(raw_depth)
        && ElderFinite1(mask_value) ? 1.0 : 0.0;

    if (ElderPrepassNativeAvailable() && runtime_available)
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
    else if (ElderPrepassBridgeAvailable() && runtime_available)
    {
        float3 bridge_source = finite_source + SB_Retain(input.texcoord);
        // The bridge route runs when a native lane is unavailable. When
        // the unavailable lane is EInteriorFactor itself, the bridge
        // interior flag carries the interior state instead.
        float bridge_interior = ElderFinite1(EInteriorFactor)
            ? EInteriorFactor
            : saturate(SB_Interior_Flags.x);
        ElderScreenSpaceNeighborhood neighborhood = ElderReadPrepassNeighborhood(
            input.texcoord, bridge_source, raw_depth, normal_value, mask_value);
        selected.rgb = ElderComposePrepassWithRuntimeAndNeighborhood(
            bridge_source,
            bridge_interior,
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
