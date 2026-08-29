#ifndef ELDER_LENS_FXH
#define ELDER_LENS_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderLens.fxh
#endif

float ElderLensScratchAlpha(float source_alpha)
{
    return ElderFinite1(source_alpha) ? source_alpha : 1.0;
}

float4 ElderNeutralLensScratch(float source_alpha)
{
    return float4(0.0.xxx, ElderLensScratchAlpha(source_alpha));
}

float4 ElderLensContribution(float3 radiance, float source_alpha)
{
    float cap_value = max(ElderLensEnergyCap, 0.0);
    float3 bounded_radiance = min(ElderFiniteOrBlack(radiance), cap_value.xxx);
    return float4(bounded_radiance, ElderLensScratchAlpha(source_alpha));
}

// A tap that leaves the frame fades to nothing instead of smearing the
// border texel across the ghost, which is what UV clamping used to do.
float ElderLensBorderFade(float2 tap_uv)
{
    float2 interior = saturate((0.5.xx - abs(tap_uv - 0.5.xx)) * 8.0);
    return interior.x * interior.y;
}

// The lens source is the raw downsampled HDR scene, not a thresholded
// bloom surface, so ghosting it directly would veil the frame with an
// inverted copy of ordinary scene content. This extraction is the same
// soft-knee family as ElderExtractBloomHighlight, anchored on the same
// receipted noon contour of this feed: the sun disc metered 1.2 to 1.45
// and near-sun sky stayed under 1.0, so the fixed 1.0 threshold passes
// the disc and fringe while ordinary scene contributes exactly zero. The
// sun-sprite raise can push sprite-lit pixels past that contour, and
// those are intended ghost sources.
float3 ElderLensHighlightOnly(float3 tap_color)
{
    float3 finite_color = ElderFiniteOrBlack(tap_color);
    float luma = dot(max(finite_color, 0.0.xxx), float3(0.2126, 0.7152, 0.0722));
    float above_threshold = max(luma - 1.0, 0.0);
    if (above_threshold <= 0.0)
    {
        return 0.0.xxx;
    }
    float soft_knee = above_threshold * above_threshold
        / max(above_threshold + 0.25, 0.001);
    float highlight_scale = saturate((above_threshold + soft_knee)
        / max(luma, 0.001));
    return finite_color * highlight_scale;
}

// ScreenSize.z is width over height. A vector measured in 0..1 UV space
// spans more pixels across than down, so a lens ring built from a UV length
// draws as a horizontal ellipse. Scaling x by ScreenSize.z moves the vector
// into a height-normalized space where equal length means equal pixel
// distance, so a ring built here is a true circle on screen.
float2 ElderLensAspectVector(float2 uv_vector)
{
    return float2(uv_vector.x * ScreenSize.z, uv_vector.y);
}

// The inverse: a unit direction in that height-normalized space becomes a UV
// sampling offset by dividing x back out, so a fixed step draws one pixel
// radius all the way around the ring.
float2 ElderLensAspectDirectionToUv(float2 aspect_direction)
{
    return float2(aspect_direction.x / max(ScreenSize.z, 0.0001), aspect_direction.y);
}

void ElderAccumulateLensGhost(
    inout float3 accumulated_lens,
    inout float accumulated_weight,
    float2 center_vector,
    float ghost_order)
{
    float ghost_scale = 0.45 + ghost_order * 0.28;
    // Each internal reflection disperses a little more, so the red and
    // blue taps sit at slightly different scales than the green tap.
    float dispersion = 0.012 * ghost_order;
    float2 uv_red = 0.5.xx - center_vector * (ghost_scale * (1.0 - dispersion));
    float2 uv_green = 0.5.xx - center_vector * ghost_scale;
    float2 uv_blue = 0.5.xx - center_vector * (ghost_scale * (1.0 + dispersion));
    // Each chromatic tap fades on its own exit so a border texel cannot
    // smear through the two taps still inside the frame.
    float3 ghost_color = float3(
        TextureDownsampled.SampleLevel(Sampler0, uv_red, 0.0).r
            * ElderLensBorderFade(uv_red),
        TextureDownsampled.SampleLevel(Sampler0, uv_green, 0.0).g,
        TextureDownsampled.SampleLevel(Sampler0, uv_blue, 0.0).b
            * ElderLensBorderFade(uv_blue));
    float center_falloff = 1.0
        - saturate(length(ElderLensAspectVector(uv_green - 0.5.xx)) * 1.6);
    float ghost_weight = (1.0 / (ghost_order + 1.0))
        * ElderLensBorderFade(uv_green)
        * center_falloff * center_falloff;
    accumulated_lens += ElderLensHighlightOnly(ghost_color) * ghost_weight;
    accumulated_weight += 1.0 / (ghost_order + 1.0);
}

float4 ElderApplyLens(float2 uv, float4 bloom_source)
{
    if (!ElderStageIsActive() || ELDER_STAGE_INTENSITY <= 0.0)
    {
        return ElderNeutralLensScratch(bloom_source.a);
    }

    if (ElderLensGhosts == 0u)
    {
        return ElderNeutralLensScratch(bloom_source.a);
    }

    if (!ElderFinite3(bloom_source.rgb) || !ElderFinite1(bloom_source.a)
        || !ElderFinite3(ScreenSize.xyz))
    {
        return ElderNeutralLensScratch(bloom_source.a);
    }

    float2 center_vector = uv - 0.5.xx;
    float3 accumulated_lens = 0.0.xxx;
    float accumulated_weight = 0.0;

#if ELDER_LENS_GHOSTS_VALUE >= 1
    ElderAccumulateLensGhost(accumulated_lens, accumulated_weight, center_vector, 1.0);
#endif
#if ELDER_LENS_GHOSTS_VALUE >= 2
    ElderAccumulateLensGhost(accumulated_lens, accumulated_weight, center_vector, 2.0);
#endif
#if ELDER_LENS_GHOSTS_VALUE >= 3
    ElderAccumulateLensGhost(accumulated_lens, accumulated_weight, center_vector, 3.0);
#endif

    float2 aspect_vector = ElderLensAspectVector(center_vector);
    float center_distance = length(aspect_vector);
    float2 aspect_direction = center_distance > 0.0001
        ? aspect_vector / center_distance
        : float2(0.0, 1.0);
    // The halo samples at UV offsets, so carry the isotropic direction back
    // to UV; the ring then sits at one pixel radius all the way around.
    float2 safe_direction = ElderLensAspectDirectionToUv(aspect_direction);
    // The halo is a ring at a fixed radius from the frame center: every
    // pixel samples the downsampled scene texel displaced toward center by
    // the ring width, and the window lights only the pixels sitting near
    // that radius, so bright sources smear into a circle instead of a
    // smudge.
    float halo_width = 0.22;
    float2 halo_uv = uv - safe_direction * halo_width;
    float3 halo_color = float3(
        TextureDownsampled.SampleLevel(
            Sampler0, uv - safe_direction * (halo_width * 0.985), 0.0).r,
        TextureDownsampled.SampleLevel(Sampler0, halo_uv, 0.0).g,
        TextureDownsampled.SampleLevel(
            Sampler0, uv - safe_direction * (halo_width * 1.015), 0.0).b);
    float ring_window = 1.0 - saturate(abs(center_distance - halo_width) * 4.0);
    float3 windowed_halo = ElderLensHighlightOnly(halo_color)
        * ring_window * ring_window * ElderLensBorderFade(halo_uv);

    float3 filtered_lens = accumulated_lens / max(accumulated_weight, 0.0001);
    float3 lens_add =
        filtered_lens * max(ElderLensGhostStrength, 0.0)
        + windowed_halo * max(ElderLensHaloStrength, 0.0);
    // The stage intensity is a master dial around a reference of 0.07. At the
    // default it multiplies by one, so the ghost and halo dials read at face
    // value instead of compounding into a sub-percent contribution. The
    // energy cap still bounds the absolute radiance this stage may add.
    float master_gain = saturate(ElderLensIntensity) * (1.0 / 0.07);
    float3 capped_lens = min(
        lens_add * master_gain,
        max(ElderLensEnergyCap, 0.0).xxx);
    return ElderLensContribution(capped_lens, bloom_source.a);
}

#endif  // ELDER_LENS_FXH
