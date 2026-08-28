// WARP integration probe for Task 3's HDR prepass room-light contract.
//
// Each lane names one behavior that must survive shader refactors:
// exterior-preserves-room-payload, sealed-room-keeps-ambient-floor,
// partial-aperture-is-bounded, invalid-runtime-preserves-scene, and
// interior-transition-is-continuous.

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

#include "ElderHostCapabilities.fxh"
#include "ElderPipelineCommon.fxh"
#include "ElderRuntimeParameters.fxh"
#include "ElderPrepassCore.fxh"

RWStructuredBuffer<float4> ElderPrepassResults : register(u0);

static const uint kElderPrepassCaseCount = 10;

float4 ElderPrepassValidStatus()
{
    return float4(1.0, 1.0, 3.0, 20260717.0);
}

float4 ElderPrepassInvalidStatus()
{
    return float4(1.0, 0.0, 3.0, 20260717.0);
}

[numthreads(kElderPrepassCaseCount, 1, 1)]
void ElderPrepassWarpProbeMain(uint3 dispatch_thread_id : SV_DispatchThreadID)
{
    uint index = dispatch_thread_id.x;
    if (index >= kElderPrepassCaseCount)
    {
        return;
    }

    float2 uv = float2(0.5, 0.5);
    float raw_depth = 0.5;

    if (index == 0)
    {
        // exterior-preserves-room-payload
        float3 scene = float3(0.25, 0.5, 0.75);
        float4 room_light = float4(80.0, 78.0, 1.0, 0.0);
        float3 output = ElderComposePrepassWithRuntime(
            uv, scene, raw_depth, 0.0, room_light, ElderPrepassValidStatus());
        ElderPrepassResults[index] = float4(output, 1.0);
    }
    else if (index == 1)
    {
        // sealed-room-keeps-ambient-floor
        float3 scene = float3(0.05, 0.04, 0.03);
        float4 room_light = float4(0.08, 0.0, 0.0, 1.0);
        float3 output = ElderComposePrepassWithRuntime(
            uv, scene, raw_depth, 1.0, room_light, ElderPrepassValidStatus());
        ElderPrepassResults[index] = float4(output, 1.0);
    }
    else if (index == 2)
    {
        // partial-aperture-is-bounded
        float3 scene = float3(0.2, 0.2, 0.2);
        float4 room_light = float4(32.0, 30.0, 0.4, 0.0);
        float3 output = ElderComposePrepassWithRuntime(
            uv, scene, raw_depth, 1.0, room_light, ElderPrepassValidStatus());
        ElderPrepassResults[index] = float4(output, 1.0);
    }
    else if (index == 3)
    {
        // invalid-runtime-preserves-scene
        float3 scene = float3(0.125, 0.25, 0.5);
        float4 room_light = float4(32.0, 30.0, 0.4, 0.0);
        float3 output = ElderComposePrepassWithRuntime(
            uv, scene, raw_depth, 1.0, room_light, ElderPrepassInvalidStatus());
        ElderPrepassResults[index] = float4(output, 1.0);
    }
    else
    {
        // interior-transition-is-continuous
        if (index == 4)
        {
            float3 scene = float3(0.2, 0.2, 0.2);
            float4 room_light = float4(32.0, 30.0, 0.4, 0.0);
            float low = ElderComposePrepassWithRuntime(
                uv, scene, raw_depth, 0.25, room_light, ElderPrepassValidStatus()).x;
            float mid = ElderComposePrepassWithRuntime(
                uv, scene, raw_depth, 0.50, room_light, ElderPrepassValidStatus()).x;
            float high = ElderComposePrepassWithRuntime(
                uv, scene, raw_depth, 0.75, room_light, ElderPrepassValidStatus()).x;
            float full = ElderComposePrepassWithRuntime(
                uv, scene, raw_depth, 1.00, room_light, ElderPrepassValidStatus()).x;
            ElderPrepassResults[index] = float4(low, mid, high, full);
        }
        else if (index == 5)
        {
            // sealed-interior-contact-attenuates-without-crushing
            ElderScreenSpaceNeighborhood neighborhood =
                ElderSyntheticContactNeighborhood(float3(0.5, 0.5, 0.5), 0.42);
            float3 output = ElderComposePrepassWithRuntimeAndNeighborhood(
                float3(0.5, 0.5, 0.5),
                1.0,
                float4(0.0, 0.0, 0.0, 1.0),
                ElderPrepassValidStatus(),
                neighborhood);
            ElderPrepassResults[index] = float4(output, 1.0);
        }
        else if (index == 6)
        {
            // route-selection-prefers-native-then-bridge-then-spatial
            float native_route = float(ElderSelectPrepassRoute(true, true, true, true, true));
            float bridge_route = float(ElderSelectPrepassRoute(true, true, false, true, true));
            // Spatial must stand without the runtime pulse; the pulse gates
            // only the room-light routes above it.
            float spatial_route = float(ElderSelectPrepassRoute(true, false, false, false, true));
            float identity_route = float(ElderSelectPrepassRoute(true, false, true, true, false));
            ElderPrepassResults[index] = float4(native_route, bridge_route, spatial_route, identity_route);
        }
        else
        {
            if (index == 7)
            {
                // unsupported-reflection-and-subsurface-are-identity
                float3 scene = float3(0.3, 0.4, 0.5);
                ElderScreenSpaceNeighborhood neighborhood =
                    ElderSyntheticContactNeighborhood(scene, 0.42);
                float3 reflection = ElderApplyUnsupportedReflectionIdentity(
                    scene, neighborhood);
                float3 subsurface = ElderApplyUnsupportedSubsurfaceIdentity(
                    scene, neighborhood);
                ElderPrepassResults[index] = float4(
                    all(reflection == scene) ? 1.0 : 0.0,
                    all(subsurface == scene) ? 1.0 : 0.0,
                    0.0,
                    1.0);
            }
            else if (index == 8)
            {
                // status-valid-marker-is-exact
                bool accepted = ElderRuntimeStatusIsValid(
                    float4(1.0, 2.0, 3.0, 20260717.0));
                ElderPrepassResults[index] = float4(accepted ? 0.0 : 1.0, 0.0, 0.0, 1.0);
            }
            else
            {
                // status-generation-is-integer-exact
                bool accepted = ElderRuntimeStatusIsValid(
                    float4(1.0, 1.0, 3.5, 20260717.0));
                ElderPrepassResults[index] = float4(accepted ? 0.0 : 1.0, 0.0, 0.0, 1.0);
            }
        }
    }
}
