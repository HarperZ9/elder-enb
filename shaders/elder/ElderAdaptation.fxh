#ifndef ELDER_ADAPTATION_FXH
#define ELDER_ADAPTATION_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderAdaptation.fxh
#endif

float4 ElderStageOpticalIdentityWhenDisabled(
    float4 source,
    float4 candidate,
    bool stage_enabled,
    float intensity)
{
    return ElderStageIdentity(source, candidate, stage_enabled, intensity);
}

float ElderAdaptationMeasuredLuminance(float3 color)
{
    float3 finite_color = ElderFiniteOrBlack(color);
    return dot(finite_color, float3(0.2126, 0.7152, 0.0722));
}

float ElderUpdateAdaptedLuminance(
    float measured_luminance,
    float previous_luminance,
    float delta_seconds)
{
    if (!ElderFinite1(measured_luminance)
        || !ElderFinite1(previous_luminance)
        || measured_luminance <= 0.0
        || previous_luminance <= 0.0)
    {
        return previous_luminance;
    }

    float min_luminance = max(ElderAdaptationMinLuminance, 0.001);
    float max_luminance = max(ElderAdaptationMaxLuminance, min_luminance + 0.001);
    float target = clamp(measured_luminance, min_luminance, max_luminance);
    float history = clamp(previous_luminance, min_luminance, max_luminance);
    float delta = ElderFinite1(delta_seconds)
        ? clamp(delta_seconds, 0.0, 0.25)
        : 0.0;
    float rate = target > history
        ? max(ElderAdaptationBrightenRate, 0.0)
        : max(ElderAdaptationDarkenRate, 0.0);
    float response = saturate(1.0 - exp2(-rate * delta));
    float adapted = lerp(history, target, response);
    return ElderFinite1(adapted) ? clamp(adapted, min_luminance, max_luminance) : history;
}

#endif  // ELDER_ADAPTATION_FXH
