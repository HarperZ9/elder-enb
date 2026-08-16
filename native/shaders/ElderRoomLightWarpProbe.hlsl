// WARP parity probe for ElderRoomLight.fxh. Each thread rebuilds one canonical
// case identically to the C++ harness, evaluates the model on the GPU, and
// writes the four outputs; the harness runs the CPU reference and asserts
// field-by-field agreement.

#include "ElderRoomLight.fxh"

RWStructuredBuffer<float4> ElderRoomLightResults : register(u0);

static const uint kElderRoomLightCaseCount = 5;

ElderRoomLightInput ElderRoomLightCase(uint index)
{
    ElderRoomLightInput input = (ElderRoomLightInput)0;
    input.exterior_sky_luminance = 100.0;
    input.ambient_floor = 2.0;
    input.occlusion = 0.0;
    input.aperture_count = 1;
    input.apertures[0].sky_visibility = 1.0;
    input.apertures[0].glass_transmittance = 1.0;

    if (index == 1)
    {
        input.aperture_count = 0;  // basement
    }
    else if (index == 2)
    {
        input.occlusion = 1.0;  // sealed windowed room
    }
    else if (index == 3)
    {
        input.ambient_floor = 1.0;
        input.occlusion = 0.25;
        input.apertures[0].sky_visibility = 0.5;
        input.apertures[0].glass_transmittance = 0.8;
    }
    else if (index == 4)
    {
        input.exterior_sky_luminance = 50.0;
        input.ambient_floor = 0.0;
        input.aperture_count = 2;
        input.apertures[0].sky_visibility = 1.0;
        input.apertures[0].glass_transmittance = 1.0;
        input.apertures[1].sky_visibility = 1.0;
        input.apertures[1].glass_transmittance = 1.0;
    }

    return input;
}

[numthreads(kElderRoomLightCaseCount, 1, 1)]
void ElderRoomLightWarpProbeMain(uint3 dispatch_thread_id : SV_DispatchThreadID)
{
    uint index = dispatch_thread_id.x;
    if (index >= kElderRoomLightCaseCount)
    {
        return;
    }

    ElderRoomLightOutput output = ElderEvaluateRoomLight(ElderRoomLightCase(index));
    ElderRoomLightResults[index] = ElderRoomLightRuntimePayload(output);
}
