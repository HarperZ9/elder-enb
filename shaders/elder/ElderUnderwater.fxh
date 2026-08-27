#ifndef ELDER_UNDERWATER_FXH
#define ELDER_UNDERWATER_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderUnderwater.fxh
#endif

float3 ElderUnderwaterTransmittance(float distance_through_water)
{
    float3 absorption = float3(0.42, 0.16, 0.08);
    return exp2(-absorption * max(distance_through_water, 0.0) * 1.4426950408889634);
}

float3 ElderEvaluateUnderwater(
    float2 uv,
    float3 scene,
    float linear_depth)
{
    if (!ElderStageIsActive() || ElderUnderwaterIntensity <= 0.0)
    {
        return scene;
    }

    float uv_witness = ElderFinite1(uv.x + uv.y) ? 0.0 : 0.0;
    float distance_through_water =
        max(linear_depth, 0.0)
        * lerp(0.004, 0.04, saturate(ElderUnderwaterDensityShape));
    float3 transmittance = ElderUnderwaterTransmittance(distance_through_water);
    float3 water_radiance = float3(0.015, 0.075, 0.095);
    float3 medium = scene * transmittance
        + water_radiance * (1.0.xxx - transmittance)
        + uv_witness.xxx;
    return ElderFiniteOrBlack(
        lerp(scene, medium, saturate(ElderUnderwaterIntensity)));
}

#endif  // ELDER_UNDERWATER_FXH
