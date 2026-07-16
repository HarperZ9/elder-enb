#ifndef ELDER_ROOM_LIGHT_FXH
#define ELDER_ROOM_LIGHT_FXH

// Shader mirror of elder::shaders::EvaluateRoomLight (native/src/RoomLight.cpp).
// Occlusion-aware interior daylight for the Elder workshop stack: a room is lit
// by the exterior sky only through its apertures and only when not occluded, so
// a windowless or sealed room keeps only its ambient floor. Elder-owned: shares
// the physics with the Truth product, shares no source bytes.

#define ELDER_MAX_ROOM_APERTURES 8
static const float ElderRoomMaxLight = 1000000.0;

struct ElderRoomAperture
{
    float sky_visibility;
    float glass_transmittance;
};

struct ElderRoomLightInput
{
    float exterior_sky_luminance;
    float ambient_floor;
    float occlusion;
    uint aperture_count;
    ElderRoomAperture apertures[ELDER_MAX_ROOM_APERTURES];
};

struct ElderRoomLightOutput
{
    float room_light;
    float exterior_daylight;
    float open_fraction;
    float daylight_sealed;
};

ElderRoomLightOutput ElderEvaluateRoomLight(ElderRoomLightInput input)
{
    float aperture_sum = 0.0;
    [unroll]
    for (uint i = 0; i < ELDER_MAX_ROOM_APERTURES; ++i)
    {
        if (i < input.aperture_count)
        {
            aperture_sum += input.apertures[i].sky_visibility
                          * input.apertures[i].glass_transmittance;
        }
    }

    float open_fraction = saturate(aperture_sum);
    float sky_reach = open_fraction * (1.0 - input.occlusion);
    float exterior_daylight = input.exterior_sky_luminance * sky_reach;
    float room_light = clamp(input.ambient_floor + exterior_daylight, 0.0, ElderRoomMaxLight);

    ElderRoomLightOutput output;
    output.room_light = room_light;
    output.exterior_daylight = exterior_daylight;
    output.open_fraction = open_fraction;
    output.daylight_sealed = (sky_reach == 0.0) ? 1.0 : 0.0;
    return output;
}

#endif  // ELDER_ROOM_LIGHT_FXH
