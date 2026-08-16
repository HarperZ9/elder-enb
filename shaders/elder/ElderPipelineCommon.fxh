#ifndef ELDER_PIPELINE_COMMON_FXH
#define ELDER_PIPELINE_COMMON_FXH

#ifndef ELDER_HOST_CAPABILITIES_FXH
#error Include ElderHostCapabilities.fxh after stage declarations and before ElderPipelineCommon.fxh
#endif

#include "ElderQuality.fxh"

// Elder uses device depth where sky is near one. Every depth-aware stage uses
// this shared convention instead of local threshold drift.
#define ELDER_DEPTH_CONVENTION_DEVICE_Z_SKY_AT_ONE 1

bool ElderFinite1(float value)
{
    return (asuint(value) & 0x7fffffffu) < 0x7f800000u;
}

bool ElderFinite3(float3 value)
{
    return all((asuint(value) & 0x7fffffffu) < 0x7f800000u.xxx);
}

float3 ElderFiniteOrBlack(float3 value)
{
    return all((asuint(value) & 0x7fffffffu) < 0x7f800000u.xxx)
        ? max(value, 0.0.xxx)
        : 0.0.xxx;
}

float ElderDepthMask(float raw_depth, float threshold, float feather)
{
    float edge = clamp(feather, 0.00001, 0.005);
    return smoothstep(clamp(threshold, 0.99, 1.0),
                      min(clamp(threshold, 0.99, 1.0) + edge, 1.0),
                      raw_depth);
}

float4 ElderIdentityColor(float4 value)
{
    return value;
}

float ElderIdentityScalar(float value)
{
    return value;
}

struct ElderStageVSOutput
{
    float4 position : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

ElderStageVSOutput ElderFullscreenVertex(uint vertex_id : SV_VertexID)
{
    ElderStageVSOutput output;
    float2 triangle_position = vertex_id == 0u
        ? float2(-1.0, -1.0)
        : (vertex_id == 1u ? float2(-1.0, 3.0) : float2(3.0, -1.0));
    output.position = float4(triangle_position, 0.0, 1.0);
    output.texcoord = triangle_position * float2(0.5, -0.5) + 0.5;
    return output;
}

struct ElderCapabilityValue
{
    float4 color;
    float availability;
    uint route;
};

ElderCapabilityValue ElderNativeCapability(ElderCapabilityValue value)
{
    value.route = ELDER_CAPABILITY_NATIVE;
    return value;
}

ElderCapabilityValue ElderBridgeCapability(ElderCapabilityValue value)
{
    value.route = ELDER_CAPABILITY_BRIDGE;
    return value;
}

ElderCapabilityValue ElderSpatialCapability(ElderCapabilityValue value)
{
    value.route = ELDER_CAPABILITY_SPATIAL;
    return value;
}

ElderCapabilityValue ElderIdentityCapability(ElderCapabilityValue value)
{
    value.route = ELDER_CAPABILITY_IDENTITY;
    return value;
}

ElderCapabilityValue ElderMakeCapability(float4 color, float availability)
{
    ElderCapabilityValue value;
    value.color = color;
    value.availability = saturate(availability);
    value.route = ELDER_CAPABILITY_IDENTITY;
    return value;
}

ElderCapabilityValue ElderResolveCapability(
    ElderCapabilityValue native_value,
    ElderCapabilityValue bridge_value,
    ElderCapabilityValue spatial_value,
    ElderCapabilityValue identity_value)
{
#if ELDER_STAGE_CAPABILITY >= ELDER_CAPABILITY_NATIVE
#if ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE
    if (native_value.availability > 0.0)
    {
        return ElderNativeCapability(native_value);
    }
#endif
#endif
#if ELDER_STAGE_CAPABILITY >= ELDER_CAPABILITY_BRIDGE
#if ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE
    if (bridge_value.availability > 0.0)
    {
        return ElderBridgeCapability(bridge_value);
    }
#endif
#endif
#if ELDER_STAGE_CAPABILITY >= ELDER_CAPABILITY_SPATIAL
#if ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE
    if (spatial_value.availability > 0.0)
    {
        return ElderSpatialCapability(spatial_value);
    }
#endif
#endif
    return ElderIdentityCapability(identity_value);
}

float4 ElderResolveCapabilityColor(
    float4 native_color,
    float4 bridge_color,
    float4 spatial_color,
    float4 identity_color,
    float native_availability,
    float bridge_availability,
    float spatial_availability)
{
    ElderCapabilityValue selected = ElderResolveCapability(
        ElderMakeCapability(native_color, native_availability),
        ElderMakeCapability(bridge_color, bridge_availability),
        ElderMakeCapability(spatial_color, spatial_availability),
        ElderMakeCapability(identity_color, 1.0));
    return selected.color;
}

float4 ElderResolveCapabilityColor(
    float4 source,
    float native_availability,
    float bridge_availability,
    float spatial_availability)
{
    return ElderResolveCapabilityColor(
        source, source, source, source,
        native_availability, bridge_availability, spatial_availability);
}

#ifndef ELDER_STAGE_EXTERNAL_SB_RETAIN
float3 SB_Retain(float2 uv)
{
    [branch] if (uv.x < -1.0e15)
    {
        return uv.x.xxx * 0.0;
    }
    return 0.0.xxx;
}
#endif

float4 ElderStageIdentity(
    float4 identity_input,
    float4 candidate_output,
    bool stage_enabled,
    float intensity)
{
    if (!stage_enabled || intensity <= 0.0)
    {
        return ElderIdentityColor(identity_input);
    }

    if (intensity >= 1.0)
    {
        return ElderIdentityColor(candidate_output);
    }

    // Task 2 stages are intentionally inert. Later tasks add owned behavior
    // behind this same identity-preserving interface.
    return ElderIdentityColor(lerp(identity_input, candidate_output, saturate(intensity)));
}

#endif
