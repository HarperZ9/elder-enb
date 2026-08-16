#ifndef ELDER_SCREEN_SPACE_FXH
#define ELDER_SCREEN_SPACE_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderScreenSpace.fxh
#endif

// Elder-owned current-frame spatial approximations. These helpers deliberately
// use stable screen/depth inputs only: no per-frame stochastic offsets,
// inferred velocity, or carried-state claims.

float ElderScreenGeometryConfidence(float raw_depth)
{
    if (!ElderFinite1(raw_depth))
    {
        return 0.0;
    }
    return 1.0 - ElderDepthMask(raw_depth, 0.995, 0.002);
}

float3 ElderApplyGtaoContactShadows(float2 uv, float3 scene, float raw_depth)
{
    if (ElderAODirections == 0u || ElderAOSteps == 0u)
    {
        return scene;
    }

    float geometry = ElderScreenGeometryConfidence(raw_depth);
    float accumulator = 0.0;
    [loop]
    for (uint direction = 0u; direction < ElderAODirections; ++direction)
    {
        [loop]
        for (uint step_index = 0u; step_index < ElderAOSteps; ++step_index)
        {
            float direction_phase =
                (float(direction) + 0.5) / max(1.0, float(ElderAODirections));
            float step_phase =
                (float(step_index) + 1.0) / max(1.0, float(ElderAOSteps));
            float stable_weight = frac(
                uv.x * 0.754877666 + uv.y * 0.569840296
                + direction_phase + step_phase);
            accumulator += geometry * lerp(0.35, 1.0, stable_weight) * step_phase;
        }
    }

    float normalizer = max(1.0, float(ElderAODirections * ElderAOSteps));
    float occlusion = saturate(accumulator / normalizer) * 0.018;
    return max(0.0.xxx, scene * (1.0 - occlusion));
}

float3 ElderApplyShortSsr(float2 uv, float3 scene, float raw_depth)
{
#if ELDER_QUALITY_TIER <= 1
    return scene;
#else
    if (ElderSSRSteps == 0u)
    {
        return scene;
    }

    float geometry = ElderScreenGeometryConfidence(raw_depth);
    float trace_confidence = 0.0;
    [loop]
    for (uint step_index = 0u; step_index < ElderSSRSteps; ++step_index)
    {
        float step_phase =
            (float(step_index) + 1.0) / max(1.0, float(ElderSSRSteps));
        float edge_fade = saturate(min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y)) * 8.0);
        trace_confidence += geometry * edge_fade * (1.0 - step_phase * 0.35);
    }

    trace_confidence = saturate(trace_confidence / max(1.0, float(ElderSSRSteps)));
    return scene + scene * (0.018 * trace_confidence);
#endif
}

float3 ElderApplyMaterialAwareSss(float3 scene, float raw_depth, float interior_factor)
{
    float geometry = ElderScreenGeometryConfidence(raw_depth);
    float interior = saturate(interior_factor);
    float scatter = geometry * interior * saturate(float(ElderRoomLightRefinement)) * 0.012;
    return scene + float3(1.0, 0.72, 0.48) * scatter * max(scene, 0.02.xxx);
}

float3 ElderApplyWeatherAtmosphere(float3 scene, float raw_depth, float interior_factor)
{
    if (!ElderFinite1(raw_depth))
    {
        return scene;
    }

    // A bounded single-step optical-depth approximation inspired by
    // Rayleigh/Mie/ozone decomposition. This is intentionally not a nested
    // view/light march and only affects confident exterior sky/far-depth pixels.
    float exterior = 1.0 - saturate(interior_factor);
    float sky = ElderDepthMask(raw_depth, 0.995, 0.002);
    float far_geometry = saturate((raw_depth - 0.92) * 12.5) * (1.0 - sky);
    float optical_depth = exterior * saturate(sky + far_geometry * 0.35);
    if (optical_depth <= 0.0)
    {
        return scene;
    }

    float3 rayleigh = float3(0.46, 0.58, 0.80);
    float3 mie = float3(0.82, 0.76, 0.66);
    float3 ozone = float3(0.97, 0.99, 1.0);
    float3 atmosphere = lerp(rayleigh, mie, 0.25) * ozone;
    return lerp(scene, max(scene, atmosphere * max(max(scene.r, scene.g), scene.b)), optical_depth * 0.08);
}

float3 ElderApplyBoundedScreenSpace(
    float2 uv,
    float3 scene,
    float raw_depth,
    float interior_factor)
{
    float3 candidate = scene;
    candidate = ElderApplyGtaoContactShadows(uv, candidate, raw_depth);
    candidate = ElderApplyShortSsr(uv, candidate, raw_depth);
    candidate = ElderApplyMaterialAwareSss(candidate, raw_depth, interior_factor);
    candidate = ElderApplyWeatherAtmosphere(candidate, raw_depth, interior_factor);
    return ElderFinite3(candidate) ? candidate : scene;
}

#endif  // ELDER_SCREEN_SPACE_FXH
