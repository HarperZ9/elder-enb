#ifndef ELDER_BLOOM_FXH
#define ELDER_BLOOM_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderBloom.fxh
#endif

float ElderBloomScratchAlpha(float source_alpha)
{
    return ElderFinite1(source_alpha) ? source_alpha : 1.0;
}

float4 ElderNeutralBloomScratch(float source_alpha)
{
    return float4(0.0.xxx, ElderBloomScratchAlpha(source_alpha));
}

float4 ElderBloomContribution(float3 radiance, float source_alpha)
{
    float3 bounded_radiance = min(ElderFiniteOrBlack(radiance), 1.25.xxx);
    return float4(bounded_radiance, ElderBloomScratchAlpha(source_alpha));
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
        return ElderNeutralBloomScratch(source.a);
    }

    if (ElderBloomRadius == 0u)
    {
        return ElderNeutralBloomScratch(source.a);
    }

    if (!ElderFinite3(source.rgb) || !ElderFinite1(source.a)
        || !ElderFinite3(ScreenSize.xyz))
    {
        return ElderNeutralBloomScratch(source.a);
    }

    float3 center_highlight = ElderExtractBloomHighlight(source.rgb);
    float center_luma = ElderBloomLuminance(center_highlight);
    if (center_luma <= 0.0)
    {
        return ElderNeutralBloomScratch(source.a);
    }

    float2 texel_size = ElderScreenTexel(ScreenSize);
    float3 accumulated_highlight = center_highlight;
    float accumulated_weight = 1.0;

    [loop]
    for (uint tap_index = 1u; tap_index <= ElderBloomRadius; ++tap_index)
    {
        // Four texels of spacing per step. The old spacing kept the whole
        // kernel inside roughly one texel, which reduced the stage to a
        // dimmed copy of its own highlight mask.
        float tap_radius =
            float(tap_index) * max(ElderBloomRadiusScale, 0.25) * 4.0;
        float2 offset_x = texel_size * float2(tap_radius, 0.0);
        float2 offset_y = texel_size * float2(0.0, tap_radius);
        float2 offset_diagonal = texel_size * (tap_radius * 0.70710678).xx;
        float2 tap_offsets[8] = {
            offset_x,
            -offset_x,
            offset_y,
            -offset_y,
            offset_diagonal,
            -offset_diagonal,
            float2(offset_diagonal.x, -offset_diagonal.y),
            float2(-offset_diagonal.x, offset_diagonal.y)
        };

        [unroll]
        for (uint axis_index = 0u; axis_index < 8u; ++axis_index)
        {
            float3 tap_color = TextureColor.SampleLevel(
                Sampler1, saturate(uv + tap_offsets[axis_index]), 0.0).rgb;
            float tap_weight = 1.0 / (1.0 + float(tap_index));
            accumulated_highlight += ElderExtractBloomHighlight(tap_color) * tap_weight;
            accumulated_weight += tap_weight;
        }
    }

    float3 filtered_highlight =
        accumulated_highlight / max(accumulated_weight, 0.0001);
    // The intensity dial is the only attenuation. A second fixed multiplier
    // sat here before and pushed the whole stage under the visibility floor.
    float3 contribution_radiance =
        filtered_highlight * saturate(ElderBloomIntensity);
    return ElderBloomContribution(contribution_radiance, source.a);
}

#endif  // ELDER_BLOOM_FXH
