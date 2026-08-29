#ifndef ELDER_DEPTH_OF_FIELD_FXH
#define ELDER_DEPTH_OF_FIELD_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderDepthOfField.fxh
#endif

// Six blade vertices around the aperture; taps walk the polygon edges.
static const float ELDER_DOF_BLADE_COUNT = 6.0;
static const float ELDER_DOF_FULL_TURN = 6.28318530718;
// One unit of CoC at MaxBlur 1.0 reaches this bokeh radius in pixels.
static const float ELDER_DOF_RADIUS_SCALE_PIXELS = 48.0;
// Below half a pixel of radius the gather cannot change the image.
static const float ELDER_DOF_MIN_RADIUS_PIXELS = 0.5;

float4 ElderStageOpticalIdentityWhenDisabled(
    float4 source,
    float4 candidate,
    bool stage_enabled,
    float intensity)
{
    return ElderStageIdentity(source, candidate, stage_enabled, intensity);
}

// Central-region autofocus measurement. Depth values are linearized to view
// distance over the far plane, samples closer than 0.001 of the far plane
// are rejected as first-person geometry, and the survivors blend under a
// center-of-screen weight plus a near-subject weight, since the thing a
// player looks at is usually the nearest thing near screen center. Returns
// a negative sentinel when every sample was rejected.
float ElderMeasureAutofocusDistance()
{
#if ELDER_DOF_RINGS_VALUE == 0
    return -1.0;
#else
    float total_weight = 0.0;
    float weighted_distance = 0.0;

    [loop]
    for (uint row_index = 0u; row_index < 7u; ++row_index)
    {
        [loop]
        for (uint column_index = 0u; column_index < 7u; ++column_index)
        {
            float2 sample_uv = float2(0.3, 0.3)
                + float2(float(column_index), float(row_index)) * (0.4 / 6.0);
            float device_z = TextureDepth.SampleLevel(Sampler0, sample_uv, 0.0).x;
            float scene_distance = ElderLinearizeDepth(device_z);
            if (!ElderFinite1(scene_distance) || scene_distance < 0.001)
            {
                continue;
            }
            float2 centered = sample_uv - float2(0.5, 0.5);
            float center_weight = exp(-dot(centered, centered) * 12.0);
            float subject_weight = 1.0 / (scene_distance * 20.0 + 1.0);
            float sample_weight = center_weight * subject_weight;
            weighted_distance += scene_distance * sample_weight;
            total_weight += sample_weight;
        }
    }

    if (total_weight <= 0.0)
    {
        return -1.0;
    }
    return weighted_distance / total_weight;
#endif
}

// Resolves the working focus distance in linear far-plane units. The
// measurement pass publishes a negative sentinel when nothing usable was
// in view, and its rejection floor keeps every real measurement at or
// above 0.001, so a readback of exactly zero can only be an unwritten or
// cleared focus surface. Anything at or below zero falls through to
// manual focus, the same boundary ElderResolvedFocusFromTarget uses.
// Manual focus squares the dial so its travel concentrates in the near
// field where Skyrim subjects actually stand.
float ElderResolveFocusDistance(float measured_distance)
{
    float manual_focus =
        ElderDepthOfFieldFocusDepth * ElderDepthOfFieldFocusDepth;
    if (!ElderDepthOfFieldAutofocus
        || !ElderFinite1(measured_distance)
        || measured_distance <= 0.0)
    {
        return clamp(manual_focus, 0.0001, 1.0);
    }
    return clamp(measured_distance, 0.0001, 1.0);
}

// The Focus technique published its resolved distance through the host's
// focus surface; every later pass reads it back from texel zero.
float ElderResolvedFocusFromTarget()
{
    float focus_distance = TextureFocus.Load(int3(0, 0, 0)).x;
    if (!ElderFinite1(focus_distance) || focus_distance <= 0.0)
    {
        float manual_focus =
            ElderDepthOfFieldFocusDepth * ElderDepthOfFieldFocusDepth;
        return clamp(manual_focus, 0.0001, 1.0);
    }
    return clamp(focus_distance, 0.0001, 1.0);
}

// Circle of confusion for both planes, in 0..1. Division by the focus
// distance makes the response proportional: a fixed world offset defocuses
// more when the subject is close, which follows a physical thin lens
// without needing camera metadata. The foreground side carries a ten-fold
// scale because near separations are tiny in far-plane units.
float2 ElderDepthOfFieldCoC(float scene_distance, float focus_distance)
{
    float span = max(focus_distance, 0.0001);
    float dead_zone = ElderDepthOfFieldFocusRange * 0.1;
    float delta = scene_distance - focus_distance;
    float far_coc = smoothstep(0.0, 1.0, saturate(
        (delta - dead_zone) * ElderDepthOfFieldBackgroundStrength / span));
    float near_coc = smoothstep(0.0, 1.0, saturate(
        (-delta - dead_zone)
        * ElderDepthOfFieldForegroundStrength * 10.0 / span));
    return float2(far_coc, near_coc);
}

// Blur radius in pixels. ElderDepthOfFieldMaxBlur is a radius dial, never a
// CoC multiplier; scaling the CoC itself is the historic double-application
// that kept every tap under one texel.
float ElderDepthOfFieldRadiusPixels(float coc)
{
    return coc
        * max(ElderDepthOfFieldMaxBlur, 0.0)
        * ELDER_DOF_RADIUS_SCALE_PIXELS;
}

// Ring budget for one gather, scaled to the pixel radius in flight. Rings
// sit two pixels apart out to the tier bound, which keeps tap density
// near the bilinear footprint: a six-pixel radius gathers three rings at
// any tier, and only a radius past twice the tier budget saturates it.
// The tier cap remains the quality contract; this scaling removes the
// radius-independent worst case, which at the cinematic tier cost about
// nine hundred fetches per pixel for every radius above half a pixel.
uint ElderActiveDofRings(float radius_pixels)
{
    uint radius_rings = (uint)ceil(max(radius_pixels, 0.0) * 0.5);
    return clamp(radius_rings, 1u, ElderDOFRings);
}

// A tap direction walks the hexagon edge between two adjacent blade
// vertices, so rings read as bokeh polygons instead of the perfect disc no
// mechanical iris produces.
float2 ElderApertureDirection(float blade_position)
{
    float segment_index = floor(blade_position);
    float segment_fraction = blade_position - segment_index;
    float angle_a =
        (segment_index / ELDER_DOF_BLADE_COUNT) * ELDER_DOF_FULL_TURN;
    float angle_b =
        ((segment_index + 1.0) / ELDER_DOF_BLADE_COUNT) * ELDER_DOF_FULL_TURN;
    float2 vertex_a;
    float2 vertex_b;
    sincos(angle_a, vertex_a.y, vertex_a.x);
    sincos(angle_b, vertex_b.y, vertex_b.x);
    return lerp(vertex_a, vertex_b, segment_fraction);
}

// First scratch pass: publish far CoC in x and near CoC in y for the frame.
// z repeats the near value so the merge pass has a defined lane even before
// the spread runs; w stays zero until the merge writes the blend factor.
float4 ElderComputeCocTarget(float2 uv)
{
#if ELDER_DOF_RINGS_VALUE == 0
    return 0.0.xxxx;
#else
    if (!ElderStageIsActive())
    {
        return 0.0.xxxx;
    }
    float device_z = TextureDepth.SampleLevel(Sampler0, uv, 0.0).x;
    float scene_distance = ElderLinearizeDepth(device_z);
    if (!ElderFinite1(scene_distance))
    {
        return 0.0.xxxx;
    }
    float focus_distance = ElderResolvedFocusFromTarget();
    float2 coc = ElderDepthOfFieldCoC(scene_distance, focus_distance);
    return float4(coc.x, coc.y, coc.y, 0.0);
#endif
}

// Near-field CoC must spread outward past the subject silhouette or the
// foreground blur ends in a hard edge exactly at the geometry. Each axis
// takes a cone-weighted maximum over dense one-texel taps: a tap's near
// CoC votes with full weight at its own pixel and falls linearly to zero
// at its own blur radius, the exact separable form of the reach a
// silhouette needs. The vertical half runs in the merge pass, which
// cannot read the surface it writes and therefore needs this dedicated
// scratch lane. Two honest limits, held for the next playtest: reach
// caps at twelve texels per axis against a blur radius that scales to
// 48 pixels, so an extreme foreground blur still meets a coverage edge
// past the spread; and the border clamp resamples the edge texel, which
// under-spreads silhouettes touching the frame edge.
float ElderSpreadNearCoc(float2 uv)
{
#if ELDER_DOF_RINGS_VALUE == 0
    return 0.0;
#else
    if (!ElderStageIsActive())
    {
        return 0.0;
    }
    float2 texel_size = ElderScreenTexel(ScreenSize);
    float spread_value = 0.0;

    [loop]
    for (int tap_index = -12; tap_index <= 12; ++tap_index)
    {
        float2 tap_uv = saturate(
            uv + float2(float(tap_index) * texel_size.x, 0.0));
        float tap_raw =
            RenderTargetRGBA32.SampleLevel(Sampler0, tap_uv, 0.0).y;
        float tap_near = ElderFinite1(tap_raw) ? tap_raw : 0.0;
        float tap_reach = ElderDepthOfFieldRadiusPixels(tap_near);
        float tap_weight = saturate(
            1.0 - abs(float(tap_index))
                / max(tap_reach, ELDER_DOF_MIN_RADIUS_PIXELS));
        spread_value = max(spread_value, tap_near * tap_weight);
    }
    return spread_value;
#endif
}

// Completes the near-CoC spread vertically and republishes the full CoC
// surface. The far and near planes are recomputed from depth and focus
// because this pass writes the same surface the first CoC pass filled, and
// a surface cannot be sampled while bound for output.
float4 ElderMergeNearCoc(float2 uv)
{
#if ELDER_DOF_RINGS_VALUE == 0
    return 0.0.xxxx;
#else
    if (!ElderStageIsActive())
    {
        return 0.0.xxxx;
    }
    float device_z = TextureDepth.SampleLevel(Sampler0, uv, 0.0).x;
    float scene_distance = ElderLinearizeDepth(device_z);
    float focus_distance = ElderResolvedFocusFromTarget();
    float2 coc = ElderFinite1(scene_distance)
        ? ElderDepthOfFieldCoC(scene_distance, focus_distance)
        : float2(0.0, 0.0);

    float2 texel_size = ElderScreenTexel(ScreenSize);
    float spread_value = 0.0;

    [loop]
    for (int tap_index = -12; tap_index <= 12; ++tap_index)
    {
        float2 tap_uv = saturate(
            uv + float2(0.0, float(tap_index) * texel_size.y));
        float tap_raw =
            RenderTargetR16F.SampleLevel(Sampler0, tap_uv, 0.0).x;
        float tap_near = ElderFinite1(tap_raw) ? tap_raw : 0.0;
        float tap_reach = ElderDepthOfFieldRadiusPixels(tap_near);
        float tap_weight = saturate(
            1.0 - abs(float(tap_index))
                / max(tap_reach, ELDER_DOF_MIN_RADIUS_PIXELS));
        spread_value = max(spread_value, tap_near * tap_weight);
    }

    float merged_near = max(spread_value, coc.y);
    return float4(
        coc.x, coc.y, merged_near, smoothstep(0.0, 1.0, merged_near));
#endif
}

// Far-field bokeh gather. Each sample weight divides by one plus its
// brightest channel, which keeps a single hot specular from swallowing the
// whole polygon while still letting highlights grow into visible bokeh
// shapes. A tap whose own far CoC is small sits at or before the focal
// plane; its weight collapses so sharp geometry cannot leak into the
// defocused background.
float4 ElderGatherFarBokeh(float2 uv)
{
#if ELDER_DOF_RINGS_VALUE == 0
    return float4(
        ElderFiniteOrBlack(TextureOriginal.SampleLevel(Sampler0, uv, 0.0).rgb),
        0.0);
#else
    float3 center_color = ElderFiniteOrBlack(
        TextureOriginal.SampleLevel(Sampler0, uv, 0.0).rgb);
    if (!ElderStageIsActive())
    {
        return float4(center_color, 0.0);
    }
    float4 coc_sample = RenderTargetRGBA32.SampleLevel(Sampler0, uv, 0.0);
    float center_far = ElderFinite1(coc_sample.x) ? saturate(coc_sample.x) : 0.0;
    float radius_pixels = ElderDepthOfFieldRadiusPixels(center_far);
    if (radius_pixels < ELDER_DOF_MIN_RADIUS_PIXELS)
    {
        return float4(center_color, center_far);
    }

    float2 texel_size = ElderScreenTexel(ScreenSize);
    float center_weight = 1.0
        / (max(max(center_color.r, center_color.g), center_color.b) + 1.0);
    float3 accumulated_color = center_color * center_weight;
    float accumulated_weight = center_weight;
    uint active_rings = ElderActiveDofRings(radius_pixels);

    [loop]
    for (uint ring_index = 0u; ring_index < active_rings; ++ring_index)
    {
        float ring_scale = (float(ring_index) + 1.0) / float(active_rings);
        uint tap_count = (ring_index + 1u) * 6u;

        [loop]
        for (uint tap_index = 0u; tap_index < tap_count; ++tap_index)
        {
            float blade_position =
                (float(tap_index) / float(tap_count)) * ELDER_DOF_BLADE_COUNT;
            float2 tap_direction = ElderApertureDirection(blade_position);
            float2 tap_uv = saturate(
                uv + tap_direction * (radius_pixels * ring_scale) * texel_size);
            float tap_far =
                RenderTargetRGBA32.SampleLevel(Sampler0, tap_uv, 0.0).x;
            float3 tap_color = ElderFiniteOrBlack(
                TextureOriginal.SampleLevel(Sampler1, tap_uv, 0.0).rgb);
            float tap_weight = 1.0
                / (max(max(tap_color.r, tap_color.g), tap_color.b) + 1.0);
            tap_weight *= saturate((ElderFinite1(tap_far) ? tap_far : 0.0) * 10.0);
            accumulated_color += tap_color * tap_weight;
            accumulated_weight += tap_weight;
        }
    }

    float3 bokeh_color = accumulated_color / max(accumulated_weight, 0.0001);
    return float4(ElderFiniteOrBlack(bokeh_color), center_far);
#endif
}

// Near-field bokeh gather. Taps weight by their spread near CoC so the
// foreground haze grows past the silhouette; the alpha lane carries the
// gathered coverage the composite uses to blend over sharp pixels behind
// the near subject.
float4 ElderGatherNearBokeh(float2 uv)
{
#if ELDER_DOF_RINGS_VALUE == 0
    return float4(
        ElderFiniteOrBlack(TextureOriginal.SampleLevel(Sampler0, uv, 0.0).rgb),
        0.0);
#else
    float3 center_color = ElderFiniteOrBlack(
        TextureOriginal.SampleLevel(Sampler0, uv, 0.0).rgb);
    if (!ElderStageIsActive())
    {
        return float4(center_color, 0.0);
    }
    float4 coc_sample = RenderTargetRGBA32.SampleLevel(Sampler0, uv, 0.0);
    float center_near = ElderFinite1(coc_sample.z) ? saturate(coc_sample.z) : 0.0;
    float radius_pixels = ElderDepthOfFieldRadiusPixels(center_near);
    if (radius_pixels < ELDER_DOF_MIN_RADIUS_PIXELS)
    {
        return float4(center_color, saturate(center_near));
    }

    float2 texel_size = ElderScreenTexel(ScreenSize);
    float3 accumulated_color = center_color;
    float accumulated_weight = 1.0;
    float accumulated_coverage = saturate(center_near);
    float coverage_count = 1.0;
    uint active_rings = ElderActiveDofRings(radius_pixels);

    [loop]
    for (uint ring_index = 0u; ring_index < active_rings; ++ring_index)
    {
        float ring_scale = (float(ring_index) + 1.0) / float(active_rings);
        uint tap_count = (ring_index + 1u) * 6u;

        [loop]
        for (uint tap_index = 0u; tap_index < tap_count; ++tap_index)
        {
            float blade_position =
                (float(tap_index) / float(tap_count)) * ELDER_DOF_BLADE_COUNT;
            float2 tap_direction = ElderApertureDirection(blade_position);
            float2 tap_uv = saturate(
                uv + tap_direction * (radius_pixels * ring_scale) * texel_size);
            float tap_near =
                RenderTargetRGBA32.SampleLevel(Sampler0, tap_uv, 0.0).z;
            float tap_coverage = saturate(ElderFinite1(tap_near) ? tap_near : 0.0);
            float3 tap_color = ElderFiniteOrBlack(
                TextureOriginal.SampleLevel(Sampler1, tap_uv, 0.0).rgb);
            accumulated_color += tap_color * tap_coverage;
            accumulated_weight += tap_coverage;
            accumulated_coverage += tap_coverage;
            coverage_count += 1.0;
        }
    }

    float3 bokeh_color = accumulated_color / max(accumulated_weight, 0.0001);
    float coverage = saturate(accumulated_coverage / coverage_count * 2.0);
    return float4(ElderFiniteOrBlack(bokeh_color), coverage);
#endif
}

// Composite entry. The sharp frame arrives as the source argument, the far
// gather waits in its wide scratch surface, the near gather arrived through
// the main chain, and the merged CoC surface steers both blends. The alpha
// lane leaves carrying the total blur amount so the smoothing passes can
// reject taps across the in-focus boundary.
float4 ElderApplyDepthOfField(float2 uv, float4 source)
{
#if ELDER_DOF_RINGS_VALUE == 0
    return source;
#else
    if (ElderDOFRings == 0u)
    {
        return source;
    }
    float4 coc_sample = RenderTargetRGBA32.SampleLevel(Sampler0, uv, 0.0);
    float far_coc = ElderFinite1(coc_sample.x) ? saturate(coc_sample.x) : 0.0;
    float near_blend = ElderFinite1(coc_sample.w) ? saturate(coc_sample.w) : 0.0;

    float4 far_sample = RenderTargetRGBA64F.SampleLevel(Sampler1, uv, 0.0);
    float3 far_color = ElderFiniteOrBlack(far_sample.rgb);
    float4 near_sample = TextureColor.SampleLevel(Sampler1, uv, 0.0);
    float3 near_color = ElderFiniteOrBlack(near_sample.rgb);
    float near_coverage =
        ElderFinite1(near_sample.a) ? saturate(near_sample.a) : 0.0;

    float3 sharp_color = ElderFiniteOrBlack(source.rgb);
    float far_blend = smoothstep(0.0, 1.0, far_coc);
    float3 composed = lerp(sharp_color, far_color, far_blend);
    float near_mix = max(near_blend, near_coverage);
    composed = lerp(composed, near_color, near_mix);

    float blur_amount = saturate(max(far_blend, near_mix));
    return float4(ElderFiniteOrBlack(composed), blur_amount);
#endif
}

// Post-gather smoothing, separable across the last two techniques. Tap
// rejection by blur-amount similarity keeps the pass from pulling sharp
// in-focus pixels across a bokeh boundary, and a center with no blur keeps
// its exact value. The final pass restores an opaque alpha lane for the
// stages that follow this one.
float4 ElderSmoothBokeh(float2 uv, float2 axis_direction, bool restore_alpha)
{
#if ELDER_DOF_RINGS_VALUE == 0
    float4 center_pass = TextureColor.SampleLevel(Sampler0, uv, 0.0);
    return restore_alpha
        ? float4(ElderFiniteOrBlack(center_pass.rgb), 1.0)
        : center_pass;
#else
    float4 center_sample = TextureColor.SampleLevel(Sampler0, uv, 0.0);
    float center_blur =
        ElderFinite1(center_sample.a) ? saturate(center_sample.a) : 0.0;
    float3 center_color = ElderFiniteOrBlack(center_sample.rgb);
    if (!ElderStageIsActive() || center_blur <= 0.001)
    {
        return restore_alpha
            ? float4(center_color, 1.0)
            : float4(center_color, center_blur);
    }

    float2 texel_size = ElderScreenTexel(ScreenSize);
    float3 accumulated_color = center_color;
    float accumulated_weight = 1.0;

    [loop]
    for (int tap_index = 1; tap_index <= 4; ++tap_index)
    {
        float tap_falloff =
            exp(-float(tap_index) * float(tap_index) * 0.5);
        float2 tap_offset = axis_direction
            * (float(tap_index) * center_blur * 2.0) * texel_size;

        float4 side_a =
            TextureColor.SampleLevel(Sampler1, saturate(uv + tap_offset), 0.0);
        float side_a_match =
            saturate(1.0 - abs(saturate(side_a.a) - center_blur) * 4.0);
        accumulated_color +=
            ElderFiniteOrBlack(side_a.rgb) * (tap_falloff * side_a_match);
        accumulated_weight += tap_falloff * side_a_match;

        float4 side_b =
            TextureColor.SampleLevel(Sampler1, saturate(uv - tap_offset), 0.0);
        float side_b_match =
            saturate(1.0 - abs(saturate(side_b.a) - center_blur) * 4.0);
        accumulated_color +=
            ElderFiniteOrBlack(side_b.rgb) * (tap_falloff * side_b_match);
        accumulated_weight += tap_falloff * side_b_match;
    }

    float3 smoothed_color = accumulated_color / max(accumulated_weight, 0.0001);
    float output_alpha = restore_alpha ? 1.0 : center_blur;
    return float4(ElderFiniteOrBlack(smoothed_color), output_alpha);
#endif
}

#endif  // ELDER_DEPTH_OF_FIELD_FXH
