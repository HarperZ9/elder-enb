#ifndef ELDER_UNDERWATER_FXH
#define ELDER_UNDERWATER_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderUnderwater.fxh
#endif

float3 ElderUnderwaterTransmittance(float distance_through_water)
{
    // Per-meter absorption of coastal water: red dies first, blue last.
    float3 absorption = float3(0.42, 0.16, 0.08);
    return exp2(-absorption * max(distance_through_water, 0.0) * 1.4426950408889634);
}

float3 ElderEvaluateUnderwater(
    float2 uv,
    float3 scene,
    float device_z)
{
    if (!ElderStageIsActive() || ElderUnderwaterIntensity <= 0.0)
    {
        return scene;
    }

    // The linearized depth ramp spans about 3000 world units and a Skyrim
    // meter is about 70 units, so the ramp converts to meters of water
    // between the camera and the surface it sees. The density dial spans
    // clear mountain water up to a murky harbor. The old form multiplied
    // device depth by a few hundredths, which left transmittance near one
    // at every distance and made the whole stage invisible.
    float view_meters = ElderLinearizeDepth(device_z) * (3000.0 / 70.0);
    float density = lerp(0.5, 2.5, saturate(ElderUnderwaterDensityShape));
    float distance_through_water = view_meters * density;
    float3 transmittance = ElderUnderwaterTransmittance(distance_through_water);
    float3 water_radiance = float3(0.015, 0.075, 0.095);
    float3 medium = scene * transmittance
        + water_radiance * (1.0.xxx - transmittance);
    return ElderFiniteOrBlack(
        lerp(scene, medium, saturate(ElderUnderwaterIntensity)));
}

#endif  // ELDER_UNDERWATER_FXH
