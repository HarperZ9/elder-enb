#ifndef ELDER_PREPASS_CORE_FXH
#define ELDER_PREPASS_CORE_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderPrepassCore.fxh
#endif

#include "ElderRuntimeParameters.fxh"
#include "ElderScreenSpace.fxh"

float3 ElderPrepassFiniteSceneOrBlack(float3 scene)
{
    return ElderFinite3(scene) ? scene : 0.0.xxx;
}

bool ElderPrepassRuntimeAvailable(float4 room_light, float4 status)
{
    return ElderRuntimeStatusIsValid(status)
        && ElderRuntimeRoomLightIsValid(room_light);
}

float3 ElderApplyRuntimeRoomLight(
    float3 scene,
    float4 room_light_payload,
    float interior_factor)
{
    float interior = saturate(interior_factor);
    if (interior <= 0.0)
    {
        return scene;
    }

    float4 room_light = ElderRuntimeSanitizeRoomLight(room_light_payload);
    float bounded_luminance = room_light.x;
    float exterior_daylight = min(room_light.y, bounded_luminance);
    float open_fraction = room_light.z;
    float sealed = room_light.w;
    float ambient_floor = max(bounded_luminance - exterior_daylight, 0.0);
    float luminance_floor = max(bounded_luminance, 0.001);
    float ambient_ratio = saturate(ambient_floor / luminance_floor);
    float daylight_ratio =
        saturate(exterior_daylight / luminance_floor) * open_fraction * (1.0 - sealed);

    // Keep the default restrained: room light provides a bounded interior lift,
    // never a second exposure stack and never a crushing multiplier.
    float lift = 0.08 * ambient_ratio + 0.16 * daylight_ratio;
    float3 candidate = scene * (1.0 + lift * interior);

    // Preserve the authored ambient floor. Other prepass spatial effects may be
    // introduced around it, but the room-light blend may not darken the scene.
    return max(scene, candidate);
}

uint ElderSelectPrepassRoute(
    bool stage_active,
    bool runtime_valid,
    bool native_available,
    bool bridge_available,
    bool spatial_available)
{
    if (!stage_active || !runtime_valid)
    {
        return ELDER_CAPABILITY_IDENTITY;
    }

#if ELDER_STAGE_CAPABILITY >= ELDER_CAPABILITY_NATIVE
#if ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE
    if (native_available)
    {
        return ELDER_CAPABILITY_NATIVE;
    }
#endif
#endif
#if ELDER_STAGE_CAPABILITY >= ELDER_CAPABILITY_BRIDGE
#if ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE
    if (bridge_available)
    {
        return ELDER_CAPABILITY_BRIDGE;
    }
#endif
#endif
#if ELDER_STAGE_CAPABILITY >= ELDER_CAPABILITY_SPATIAL
#if ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE
    if (spatial_available)
    {
        return ELDER_CAPABILITY_SPATIAL;
    }
#endif
#endif

    return ELDER_CAPABILITY_IDENTITY;
}

float3 ElderComposeSpatialPrepassFallback(
    float3 scene,
    ElderScreenSpaceNeighborhood neighborhood,
    float interior_factor)
{
    float3 finite_scene = ElderPrepassFiniteSceneOrBlack(scene);
    float3 candidate =
        ElderApplyBoundedScreenSpace(finite_scene, neighborhood, interior_factor);
    return ElderFinite3(candidate) ? candidate : finite_scene;
}

float3 ElderComposePrepassWithRuntimeAndNeighborhood(
    float3 scene,
    float interior_factor,
    float4 room_light_payload,
    float4 runtime_status,
    ElderScreenSpaceNeighborhood neighborhood)
{
    float3 finite_scene = ElderPrepassFiniteSceneOrBlack(scene);
    if (!ElderPrepassRuntimeAvailable(room_light_payload, runtime_status))
    {
        return finite_scene;
    }

    float interior = ElderFinite1(interior_factor) ? saturate(interior_factor) : 0.0;
    float3 candidate = finite_scene;
    candidate = ElderApplyRuntimeRoomLight(candidate, room_light_payload, interior);
    candidate = ElderApplyBoundedScreenSpace(candidate, neighborhood, interior);
    return ElderFinite3(candidate) ? candidate : finite_scene;
}

float3 ElderComposePrepassWithRuntime(
    float2 uv,
    float3 scene,
    float raw_depth,
    float interior_factor,
    float4 room_light_payload,
    float4 runtime_status)
{
    return ElderComposePrepassWithRuntimeAndNeighborhood(
        scene,
        interior_factor,
        room_light_payload,
        runtime_status,
        ElderNeutralScreenNeighborhood(scene, raw_depth));
}

float3 ElderComposePrepass(
    float2 uv,
    float3 scene,
    float raw_depth,
    float interior_factor)
{
    return ElderComposePrepassWithRuntime(
        uv,
        scene,
        raw_depth,
        interior_factor,
        ElderRuntimeRoomLight,
        ElderRuntimeStatus);
}

#endif  // ELDER_PREPASS_CORE_FXH
