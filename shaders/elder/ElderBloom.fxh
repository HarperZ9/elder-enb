#ifndef ELDER_BLOOM_FXH
#define ELDER_BLOOM_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderBloom.fxh
#endif

float4 ElderStageOpticalIdentityWhenDisabled(
    float4 source,
    float4 candidate,
    bool stage_enabled,
    float intensity)
{
    return ElderStageIdentity(source, candidate, stage_enabled, intensity);
}

float ElderBloomLuminance(float3 color)
{
    return dot(max(color, 0.0.xxx), float3(0.2126, 0.7152, 0.0722));
}

float3 ElderExtractBloomHighlight(float3 color)
{
    float3 finite_color = ElderFiniteOrBlack(color);
    float luma = ElderBloomLuminance(finite_color);
    float threshold = max(ElderBloomThreshold, 0.001);
    float above_threshold = max(luma - threshold, 0.0);
    if (above_threshold <= 0.0)
    {
        return 0.0.xxx;
    }

    float knee = max(ElderBloomSoftKnee, 0.001);
    float soft_knee = above_threshold * above_threshold
        / max(above_threshold + knee, 0.001);
    float highlight_scale = saturate((above_threshold + soft_knee)
        / max(luma, 0.001));
    return finite_color * highlight_scale;
}

float4 ElderApplyBloom(float2 uv, float4 source)
{
    if (!ElderStageIsActive() || ELDER_STAGE_INTENSITY <= 0.0)
    {
        return source;
    }

    if (ElderBloomRadius == 0u)
    {
        return source;
    }

    if (!ElderFinite3(source.rgb) || !ElderFinite1(source.a)
        || !ElderFinite3(ScreenSize.xyz))
    {
        return source;
    }

    float3 center_highlight = ElderExtractBloomHighlight(source.rgb);
    float center_luma = ElderBloomLuminance(center_highlight);
    if (center_luma <= 0.0)
    {
        return source;
    }

    float2 texel_size = 1.0 / max(ScreenSize.xy, float2(1.0, 1.0));
    float3 accumulated_highlight = center_highlight;
    float accumulated_weight = 1.0;

    [loop]
    for (uint tap_index = 1u; tap_index <= ElderBloomRadius; ++tap_index)
    {
        float tap_radius = float(tap_index) * max(ElderBloomRadiusScale, 0.25);
        float2 offset_x = texel_size * float2(tap_radius, 0.0);
        float2 offset_y = texel_size * float2(0.0, tap_radius);
        float2 tap_offsets[4] = {
            offset_x,
            -offset_x,
            offset_y,
            -offset_y
        };

        [unroll]
        for (uint axis_index = 0u; axis_index < 4u; ++axis_index)
        {
            float3 tap_color = TextureColor.SampleLevel(
                Sampler0, saturate(uv + tap_offsets[axis_index]), 0.0).rgb;
            float tap_weight = 1.0 / (1.0 + float(tap_index));
            accumulated_highlight += ElderExtractBloomHighlight(tap_color) * tap_weight;
            accumulated_weight += tap_weight;
        }
    }

    float3 filtered_highlight =
        accumulated_highlight / max(accumulated_weight, 0.0001);
    float3 bounded_add = min(
        filtered_highlight * 0.55,
        max(source.rgb, 0.02.xxx) * 0.22 + 0.08.xxx);
    float3 candidate_color = source.rgb + bounded_add;
    float4 candidate = float4(
        ElderFinite3(candidate_color) ? max(candidate_color, 0.0.xxx) : source.rgb,
        source.a);
    return ElderStageOpticalIdentityWhenDisabled(source, candidate, true, 1.0);
}

#endif  // ELDER_BLOOM_FXH
