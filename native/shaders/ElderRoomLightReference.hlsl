// FXC compile witness for ElderRoomLight.fxh. Compiled as ps_5_0 with
// warnings-as-errors; the entry forces full consumption of the model so
// nothing dead-strips.

#include "ElderRoomLight.fxh"

float4 ElderRoomLightReferencePixelMain(float4 position : SV_Position) : SV_Target
{
    ElderRoomLightInput input = (ElderRoomLightInput)0;
    input.exterior_sky_luminance = 100.0;
    input.ambient_floor = 2.0;
    input.occlusion = 0.0;
    input.aperture_count = 1;
    input.apertures[0].sky_visibility = 1.0;
    input.apertures[0].glass_transmittance = 1.0;

    ElderRoomLightOutput output = ElderEvaluateRoomLight(input);

    return float4(output.room_light,
                  output.exterior_daylight,
                  output.open_fraction,
                  output.daylight_sealed);
}
