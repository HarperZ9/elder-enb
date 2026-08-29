#ifndef ELDER_ADAPTATION_FXH
#define ELDER_ADAPTATION_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderAdaptation.fxh
#endif

float ElderAdaptationMinimumLuminance()
{
    return max(ElderAdaptationMinLuminance, 0.001);
}

float ElderAdaptationMaximumLuminance()
{
    float minimum_luminance = ElderAdaptationMinimumLuminance();
    return max(ElderAdaptationMaxLuminance, minimum_luminance + 0.001);
}

float ElderAdaptationNeutralLuminance()
{
    return clamp(0.18, ElderAdaptationMinimumLuminance(), ElderAdaptationMaximumLuminance());
}

float ElderAdaptationMeasuredLuminance(float3 color)
{
    float3 finite_color = ElderFiniteOrBlack(color);
    return dot(finite_color, float3(0.2126, 0.7152, 0.0722));
}

float ElderAdaptationDeltaSeconds(float4 timer_value)
{
    float fallback_delta = 1.0 / 60.0;
    float candidate_delta = ElderFinite1(timer_value.w) && timer_value.w > 0.0
        ? timer_value.w
        : fallback_delta;
    return clamp(candidate_delta, 1.0 / 240.0, 0.25);
}

float ElderSeedAdaptationHistory(
    float measured_luminance,
    float previous_luminance)
{
    float minimum_luminance = ElderAdaptationMinimumLuminance();
    float maximum_luminance = ElderAdaptationMaximumLuminance();
    float measured_seed = ElderFinite1(measured_luminance)
        && measured_luminance > 0.0
        ? clamp(measured_luminance, minimum_luminance, maximum_luminance)
        : ElderAdaptationNeutralLuminance();
    return ElderFinite1(previous_luminance) && previous_luminance > 0.0
        ? clamp(previous_luminance, minimum_luminance, maximum_luminance)
        : measured_seed;
}

float ElderUpdateAdaptedLuminance(
    float measured_luminance,
    float previous_luminance,
    float delta_seconds)
{
    float min_luminance = ElderAdaptationMinimumLuminance();
    float max_luminance = ElderAdaptationMaximumLuminance();
    float target = ElderFinite1(measured_luminance) && measured_luminance > 0.0
        ? clamp(measured_luminance, min_luminance, max_luminance)
        : ElderAdaptationNeutralLuminance();
    // Intensity scales the distance in stops between the neutral anchor
    // and the adaptation target, so the dial weakens the published steer
    // at steady state. A value of one leaves the measured target at its
    // clamped value up to exp2 and log2 intrinsic precision. The old form
    // multiplied the response rate by Intensity, but lerp toward a fixed
    // target converges to that target for any positive response, so the
    // dial had no steady-state effect at all.
    float neutral = ElderAdaptationNeutralLuminance();
    float strength = saturate(ElderAdaptationIntensity);
    target = clamp(neutral * exp2(strength * log2(target / neutral)),
        min_luminance, max_luminance);
    float history = ElderSeedAdaptationHistory(measured_luminance, previous_luminance);
    float delta = ElderFinite1(delta_seconds)
        ? clamp(delta_seconds, 0.0, 0.25)
        : (1.0 / 60.0);
    float rate = target > history
        ? max(ElderAdaptationBrightenRate, 0.0)
        : max(ElderAdaptationDarkenRate, 0.0);
    float response = saturate(1.0 - exp2(-rate * delta));
    float adapted = lerp(history, target, response);
    return ElderFinite1(adapted) ? clamp(adapted, min_luminance, max_luminance) : history;
}

#endif  // ELDER_ADAPTATION_FXH
