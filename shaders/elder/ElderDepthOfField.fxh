#ifndef ELDER_DEPTH_OF_FIELD_FXH
#define ELDER_DEPTH_OF_FIELD_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderDepthOfField.fxh
#endif

float4 ElderStageOpticalIdentityWhenDisabled(
    float4 source,
    float4 candidate,
    bool stage_enabled,
    float intensity)
{
    return ElderStageIdentity(source, candidate, stage_enabled, intensity);
}

float ElderDepthOfFieldFocusTarget(float raw_depth)
{
    float focus_depth = ElderFinite1(FocusInfo.x) && FocusInfo.x > 0.0
        && FocusInfo.x < 1.0
        ? FocusInfo.x
        : ElderDepthOfFieldFocusDepth;
    return ElderFinite1(focus_depth)
        ? clamp(focus_depth, 0.01, 0.99)
        : clamp(raw_depth, 0.01, 0.99);
}

float ElderDepthOfFieldBlurAmount(float raw_depth)
{
    if (!ElderFinite1(raw_depth) || raw_depth <= 0.0 || raw_depth >= 0.999)
    {
        return 0.0;
    }

    float focus_depth = ElderDepthOfFieldFocusTarget(raw_depth);
    float focus_range = max(ElderDepthOfFieldFocusRange, 0.001);
    float focus_delta = raw_depth - focus_depth;
    float side_strength = focus_delta < 0.0
        ? ElderDepthOfFieldForegroundStrength
        : ElderDepthOfFieldBackgroundStrength;
    float blur_shape = saturate(abs(focus_delta) / focus_range - 0.25);
    // Normalized circle of confusion in 0..1. ElderDepthOfFieldMaxBlur is a
    // radius, not a strength; it scales the tap offsets, never the CoC.
    return saturate(blur_shape * max(side_strength, 0.0) * 2.5);
}

float4 ElderApplyDepthOfField(float2 uv, float4 source)
{
#if ELDER_DOF_RINGS_VALUE == 0
    return source;
#else
    if (!ElderStageIsActive() || ELDER_STAGE_INTENSITY <= 0.0)
    {
        return source;
    }

    if (ElderDOFRings == 0u)
    {
        return source;
    }

    float raw_depth = TextureDepth.SampleLevel(Sampler0, uv, 0.0).x;
    if (!ElderFinite3(source.rgb) || !ElderFinite1(source.a)
        || !ElderFinite1(raw_depth)
        || !ElderFinite3(ScreenSize.xyz))
    {
        return source;
    }

    float blur_amount = ElderDepthOfFieldBlurAmount(raw_depth);
    if (blur_amount <= 0.0)
    {
        return source;
    }

    float2 texel_size = ElderScreenTexel(ScreenSize);
    float focus_range = max(ElderDepthOfFieldFocusRange, 0.001);
    float3 accumulated_color = ElderFiniteOrBlack(source.rgb);
    float accumulated_weight = 1.0;

    [loop]
    for (uint ring_index = 0u; ring_index < ElderDOFRings; ++ring_index)
    {
        // Eight texels per ring at MaxBlur 1.0 and a fully defocused pixel.
        // The old form multiplied MaxBlur in twice (once inside blur_amount),
        // which kept every tap under one texel and made the stage a no-op.
        float ring_radius = (float(ring_index) + 1.0)
            * blur_amount
            * max(ElderDepthOfFieldMaxBlur, 0.0)
            * 8.0;
        float2 offset_x = texel_size * float2(ring_radius, 0.0);
        float2 offset_y = texel_size * float2(0.0, ring_radius);
        float2 tap_offsets[4] = {
            offset_x,
            -offset_x,
            offset_y,
            -offset_y
        };

        [unroll]
        for (uint tap_index = 0u; tap_index < 4u; ++tap_index)
        {
            float2 tap_uv = saturate(uv + tap_offsets[tap_index]);
            float tap_depth = TextureDepth.SampleLevel(Sampler0, tap_uv, 0.0).x;
            float4 tap_color = TextureColor.SampleLevel(Sampler0, tap_uv, 0.0);
            float depth_weight = ElderFinite1(tap_depth)
                ? saturate(1.0 - abs(tap_depth - raw_depth) / (focus_range * 2.0 + 0.001))
                : 0.0;
            float3 finite_tap = ElderFiniteOrBlack(tap_color.rgb);
            accumulated_color += finite_tap * depth_weight;
            accumulated_weight += depth_weight;
        }
    }

    float3 blurred_color = accumulated_color / max(accumulated_weight, 0.0001);
    float3 bounded_color = lerp(source.rgb, blurred_color, saturate(blur_amount));
    float4 candidate = float4(
        ElderFinite3(bounded_color) ? max(bounded_color, 0.0.xxx) : source.rgb,
        source.a);
    return ElderStageOpticalIdentityWhenDisabled(source, candidate, true, 1.0);
#endif
}

#endif  // ELDER_DEPTH_OF_FIELD_FXH
