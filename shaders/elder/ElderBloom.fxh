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
    // The bound matches the consumer allowance in enbeffect.fx, which caps
    // each optical surface near 4.0 at the balanced tier. The old 1.25
    // bound sat at the daylight sky's own radiance, and the difference add
    // downstream lifts a pixel only where bloom exceeds the scene, so no
    // daytime pixel could ever receive bloom.
    float3 bounded_radiance = min(ElderFiniteOrBlack(radiance), 4.0.xxx);
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

    // No dark-center early-out. The halo of a bright neighbor has to land
    // on pixels whose own highlight is zero, or bloom never extends past
    // the emitting silhouette. The stock 0.504 bloom gathers on every
    // pixel the same way.
    float3 center_highlight = ElderExtractBloomHighlight(source.rgb);

    // Tap spacing lives on the bloom surface, not the display. ENB 0.504
    // runs the bloom chain on fixed-size square targets and describes them
    // through the host BloomSize uniform, packed like ScreenSize:
    // x = width, y = 1/width, z = aspect, w = 1/aspect. Display texels
    // here pinned the spread to a few pixels and quartered it at 4K. The
    // vertical step scales by the display aspect so the kernel renders as
    // a circle on screen, matching the stock blur. A zero or non-finite
    // BloomSize falls back to the fixed 1024 chain width.
    float bloom_texel = ElderFinite1(BloomSize.y) && BloomSize.y > 0.0
        ? BloomSize.y
        : (1.0 / 1024.0);
    float2 texel_size =
        float2(bloom_texel, bloom_texel * max(ScreenSize.z, 0.1));
    float3 accumulated_highlight = center_highlight;
    float accumulated_weight = 1.0;

    [loop]
    for (uint tap_index = 1u; tap_index <= ElderBloomRadius; ++tap_index)
    {
        // Four bloom-surface texels of spacing per step keeps the spread a
        // fixed fraction of the frame at every display resolution.
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
    // Energy model. The normalized gather dilutes a blown highlight to
    // about half its radiance, so under the shipped 0.12 dial the noon
    // sun's bloom peaked near 0.9 while the sky it must exceed sits near
    // 1.0. The in-game A/B measured bloom on minus bloom off as zero at
    // the disc. The gain of 6.0 puts an 8.0 radiance highlight at the
    // stage bound from the shipped dial, so its halo clears the sky and
    // the difference add in enbeffect.fx has energy to pass. Dimmer
    // highlights scale down through the same soft knee, and a zero dial
    // still disables the stage.
    float3 contribution_radiance =
        filtered_highlight * (saturate(ElderBloomIntensity) * 6.0);
    return ElderBloomContribution(contribution_radiance, source.a);
}

#endif  // ELDER_BLOOM_FXH
