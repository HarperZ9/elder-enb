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
    // each optical surface near 4.0 at the balanced tier. The main effect
    // adds this surface straight to the scene, so the bound is the widest
    // lift any pixel can receive from bloom.
    float3 bounded_radiance = min(ElderFiniteOrBlack(radiance), 4.0.xxx);
    return float4(bounded_radiance, ElderBloomScratchAlpha(source_alpha));
}

float ElderBloomLuminance(float3 color)
{
    return dot(max(color, 0.0.xxx), float3(0.2126, 0.7152, 0.0722));
}

// The threshold must sit inside the range the host actually renders. An
// in-game luma contour of the chain input at noon-clear, the brightest
// scene the host produces, measured the sun disc at 1.2 to 1.45, its
// fringe at 1.0 to 1.2, near-sun sky at 0.8 to 1.0, and no pixel above
// 1.45 anywhere in frame. That contour predates this branch's sun-sprite
// energy raise, whose additive disc is bounded at 8.0, so sprite-lit
// pixels near the sun can now exceed it; the next playtest re-contours
// this input with the sprite live. A threshold above the rendered range
// extracts nothing in any scene and the whole chain runs black. The tier
// presets span 0.75 to 1.00 around the measured range.
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

bool ElderBloomChainActive()
{
    return ElderStageIsActive()
        && ELDER_STAGE_INTENSITY > 0.0
        && ElderBloomRadius != 0u;
}

// Chain surfaces are consumed by later passes in this file, and the 0.504
// host clamps chain writes to [0, 32768].
float3 ElderBloomBoundChain(float3 color)
{
    return clamp(ElderFiniteOrBlack(color), 0.0.xxx, 32768.0.xxx);
}

// First chain pass: threshold the downsampled HDR scene into the finest
// octave. Four linear taps, one scene texel out on each diagonal, cover
// the 2x reduction footprint with a small tent so a one-texel highlight
// cannot flicker between chain texels.
float4 ElderExtractBloomOctave(
    Texture2D scene_source, SamplerState chain_sampler,
    float2 uv, float source_texel)
{
    if (!ElderBloomChainActive())
    {
        return float4(0.0.xxx, 1.0);
    }

    float texel = ElderFinite1(source_texel) && source_texel > 0.0
        ? source_texel
        : (1.0 / 1024.0);
    float3 gathered = 0.0.xxx;
    gathered += scene_source.SampleLevel(
        chain_sampler, saturate(uv + texel * float2(-1.0, -1.0)), 0.0).rgb;
    gathered += scene_source.SampleLevel(
        chain_sampler, saturate(uv + texel * float2(1.0, -1.0)), 0.0).rgb;
    gathered += scene_source.SampleLevel(
        chain_sampler, saturate(uv + texel * float2(-1.0, 1.0)), 0.0).rgb;
    gathered += scene_source.SampleLevel(
        chain_sampler, saturate(uv + texel * float2(1.0, 1.0)), 0.0).rgb;
    float3 highlight = ElderExtractBloomHighlight(gathered * 0.25);
    return float4(ElderBloomBoundChain(highlight), 1.0);
}

// Downsample one octave into the next with a 3x3 tent at one octave texel
// of spacing. Each halving doubles the kernel's screen footprint, so six
// octaves spread a highlight across hundreds of display pixels. The C12a
// in-game A/B measured that a single-pass gather cannot reach past a few
// dozen: its bloom-on minus bloom-off delta stayed within ambient drift
// even at four times the shipped gain.
float4 ElderBloomDownsampleOctave(
    Texture2D octave_source, SamplerState chain_sampler,
    float2 uv, float source_texel)
{
    if (!ElderBloomChainActive())
    {
        return float4(0.0.xxx, 1.0);
    }

    static const float2 tent_offsets[9] = {
        float2(-1.0, -1.0), float2(0.0, -1.0), float2(1.0, -1.0),
        float2(-1.0,  0.0), float2(0.0,  0.0), float2(1.0,  0.0),
        float2(-1.0,  1.0), float2(0.0,  1.0), float2(1.0,  1.0)
    };
    static const float tent_weights[9] = {
        0.0625, 0.1250, 0.0625,
        0.1250, 0.2500, 0.1250,
        0.0625, 0.1250, 0.0625
    };

    float3 gathered = 0.0.xxx;
    [unroll]
    for (uint tent_index = 0u; tent_index < 9u; ++tent_index)
    {
        gathered += octave_source.SampleLevel(
            chain_sampler,
            saturate(uv + tent_offsets[tent_index] * source_texel),
            0.0).rgb * tent_weights[tent_index];
    }
    return float4(ElderBloomBoundChain(gathered), 1.0);
}

// Octave weight for the composite. ElderBloomRadius is the tier's octave
// budget: the performance tier composites the two finest octaves, the
// cinematic tier all six. The radius scale dial biases weight toward the coarse
// octaves, so raising it widens the halo without adding energy, because
// the composite normalizes the weights.
float ElderBloomOctaveWeight(uint octave_index)
{
    uint octave_budget = clamp(ElderBloomRadius, 1u, 6u);
    if (octave_index > octave_budget)
    {
        return 0.0;
    }
    float spread = clamp(ElderBloomRadiusScale, 0.25, 1.50);
    return pow(spread, float(octave_index - 1u));
}

float4 ElderApplyBloom(
    float4 source,
    float3 octave_512, float3 octave_256, float3 octave_128,
    float3 octave_64, float3 octave_32, float3 octave_16)
{
    if (!ElderBloomChainActive())
    {
        return ElderNeutralBloomScratch(source.a);
    }

    if (!ElderFinite3(source.rgb) || !ElderFinite1(source.a))
    {
        return ElderNeutralBloomScratch(source.a);
    }

    float3 chain_octaves[6] = {
        octave_512, octave_256, octave_128,
        octave_64, octave_32, octave_16
    };
    float3 accumulated_highlight = 0.0.xxx;
    float accumulated_weight = 0.0;
    [unroll]
    for (uint octave_index = 1u; octave_index <= 6u; ++octave_index)
    {
        float octave_weight = ElderBloomOctaveWeight(octave_index);
        accumulated_highlight += ElderFiniteOrBlack(
            chain_octaves[octave_index - 1u]) * octave_weight;
        accumulated_weight += octave_weight;
    }

    float3 filtered_highlight =
        accumulated_highlight / max(accumulated_weight, 0.0001);
    // Energy model, verified in-game at noon-clear with the 0.90
    // threshold and the shipped 0.12 dial: the composite lifts the
    // display frame by 17 luma steps at 30 to 45 pixels from the sun
    // center, decaying to 3 near 100 and to measurement noise past 160,
    // against a plus or minus 2 drift floor. The pyramid dilutes the
    // extracted disc across its octaves and the main effect adds this
    // surface straight to the scene; the 12.0 gain keeps that halo
    // visible over the daylight sky. The 1.45 disc peak in that receipt
    // predates the sun-sprite energy raise; with the sprite's additive
    // disc bounded at 8.0, pixels near the sun can reach the 4.0
    // contribution cap, which flattens the innermost halo instead of
    // clipping the frame. The bloom and sprite energy re-tune sits on
    // the next playtest list. A zero dial still disables the stage.
    float3 contribution_radiance =
        filtered_highlight * (saturate(ElderBloomIntensity) * 12.0);
    return ElderBloomContribution(contribution_radiance, source.a);
}

#endif  // ELDER_BLOOM_FXH
