#ifndef ELDER_SCREEN_SPACE_FXH
#define ELDER_SCREEN_SPACE_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderScreenSpace.fxh
#endif

// Elder-owned current-frame spatial approximations. The prepass builds this
// from current color/depth/normal/mask samples around the pixel selected by the
// active capability route; there is no carried state or inferred velocity.

struct ElderScreenSpaceSample
{
    float3 color;
    float raw_depth;
    float3 normal;
    float mask;
};

struct ElderScreenSpaceNeighborhood
{
    ElderScreenSpaceSample center;
    ElderScreenSpaceSample left;
    ElderScreenSpaceSample right;
    ElderScreenSpaceSample up;
    ElderScreenSpaceSample down;
};

ElderScreenSpaceSample ElderMakeScreenSpaceSample(
    float3 color,
    float raw_depth,
    float3 normal,
    float mask)
{
    ElderScreenSpaceSample sample_value;
    sample_value.color = ElderFinite3(color) ? max(color, 0.0.xxx) : 0.0.xxx;
    sample_value.raw_depth = ElderFinite1(raw_depth) ? raw_depth : 1.0;
    sample_value.normal = ElderFinite3(normal) ? normal : float3(0.5, 0.5, 1.0);
    sample_value.mask = ElderFinite1(mask) ? saturate(mask) : 0.0;
    return sample_value;
}

ElderScreenSpaceNeighborhood ElderGatherScreenNeighborhood(
    ElderScreenSpaceSample center,
    ElderScreenSpaceSample left,
    ElderScreenSpaceSample right,
    ElderScreenSpaceSample up,
    ElderScreenSpaceSample down)
{
    ElderScreenSpaceNeighborhood neighborhood;
    neighborhood.center = center;
    neighborhood.left = left;
    neighborhood.right = right;
    neighborhood.up = up;
    neighborhood.down = down;
    return neighborhood;
}

ElderScreenSpaceNeighborhood ElderNeutralScreenNeighborhood(
    float3 scene,
    float raw_depth)
{
    ElderScreenSpaceSample center = ElderMakeScreenSpaceSample(
        scene, raw_depth, float3(0.5, 0.5, 1.0), 0.0);
    return ElderGatherScreenNeighborhood(center, center, center, center, center);
}

ElderScreenSpaceNeighborhood ElderSyntheticContactNeighborhood(
    float3 scene,
    float raw_depth)
{
    ElderScreenSpaceSample center = ElderMakeScreenSpaceSample(
        scene, raw_depth, float3(0.5, 0.5, 1.0), 0.0);
    ElderScreenSpaceSample near_depth = ElderMakeScreenSpaceSample(
        scene, raw_depth + 0.08, float3(0.5, 0.35, 0.92), 0.15);
    ElderScreenSpaceSample far_depth = ElderMakeScreenSpaceSample(
        scene, raw_depth - 0.04, float3(0.5, 0.65, 0.92), 0.20);
    return ElderGatherScreenNeighborhood(
        center, near_depth, far_depth, near_depth, far_depth);
}

float3 ElderScreenNormalUnit(float3 encoded_normal)
{
    float3 normal_value = encoded_normal * 2.0 - 1.0;
    float normal_length = max(dot(normal_value, normal_value), 0.000001);
    return normal_value * rsqrt(normal_length);
}

float ElderScreenDepthDelta(float a, float b)
{
    return ElderFinite1(a) && ElderFinite1(b) ? abs(a - b) : 0.0;
}

float ElderScreenNormalDelta(float3 a, float3 b)
{
    return 1.0 - saturate(dot(ElderScreenNormalUnit(a), ElderScreenNormalUnit(b)));
}

float ElderScreenMaskDelta(float a, float b)
{
    return abs(saturate(a) - saturate(b));
}

float ElderScreenLuma(float3 color)
{
    return dot(max(color, 0.0.xxx), float3(0.2126, 0.7152, 0.0722));
}

float ElderScreenColorDelta(float3 a, float3 b)
{
    return abs(ElderScreenLuma(a) - ElderScreenLuma(b));
}

float ElderScreenGeometryConfidence(float raw_depth)
{
    if (!ElderFinite1(raw_depth))
    {
        return 0.0;
    }
    return 1.0 - ElderDepthMask(raw_depth, 0.995, 0.002);
}

float ElderNeighborhoodContactSignal(ElderScreenSpaceNeighborhood neighborhood)
{
    float depth_edge = max(
        max(ElderScreenDepthDelta(neighborhood.center.raw_depth, neighborhood.left.raw_depth),
            ElderScreenDepthDelta(neighborhood.center.raw_depth, neighborhood.right.raw_depth)),
        max(ElderScreenDepthDelta(neighborhood.center.raw_depth, neighborhood.up.raw_depth),
            ElderScreenDepthDelta(neighborhood.center.raw_depth, neighborhood.down.raw_depth)));
    float normal_edge = max(
        max(ElderScreenNormalDelta(neighborhood.center.normal, neighborhood.left.normal),
            ElderScreenNormalDelta(neighborhood.center.normal, neighborhood.right.normal)),
        max(ElderScreenNormalDelta(neighborhood.center.normal, neighborhood.up.normal),
            ElderScreenNormalDelta(neighborhood.center.normal, neighborhood.down.normal)));
    float material_edge = max(
        max(ElderScreenMaskDelta(neighborhood.center.mask, neighborhood.left.mask),
            ElderScreenMaskDelta(neighborhood.center.mask, neighborhood.right.mask)),
        max(ElderScreenMaskDelta(neighborhood.center.mask, neighborhood.up.mask),
            ElderScreenMaskDelta(neighborhood.center.mask, neighborhood.down.mask)));
    float color_edge = max(
        max(ElderScreenColorDelta(neighborhood.center.color, neighborhood.left.color),
            ElderScreenColorDelta(neighborhood.center.color, neighborhood.right.color)),
        max(ElderScreenColorDelta(neighborhood.center.color, neighborhood.up.color),
            ElderScreenColorDelta(neighborhood.center.color, neighborhood.down.color)));

    float geometry = ElderScreenGeometryConfidence(neighborhood.center.raw_depth);
    return saturate(
        geometry
        * (depth_edge * 6.0 + normal_edge * 0.45 + material_edge * 0.25
           + color_edge * 0.10));
}

float3 ElderApplyDepthNormalContactOcclusion(
    float3 scene,
    ElderScreenSpaceNeighborhood neighborhood)
{
    if (ElderAODirections == 0u || ElderAOSteps == 0u)
    {
        return scene;
    }

    float tier_budget = saturate(
        min(float(ElderAODirections), 4.0) * 0.25
        * min(float(ElderAOSteps), 2.0) * 0.5);
    float contact = ElderNeighborhoodContactSignal(neighborhood);
    float attenuation = min(contact * tier_budget * 0.035, 0.04);
    float3 attenuated = scene * (1.0 - attenuation);
    float3 floor_value = scene * 0.94;
    return max(floor_value, attenuated);
}

float3 ElderApplyUnsupportedReflectionIdentity(
    float3 scene,
    ElderScreenSpaceNeighborhood neighborhood)
{
    return scene;
}

float3 ElderApplyUnsupportedSubsurfaceIdentity(
    float3 scene,
    ElderScreenSpaceNeighborhood neighborhood)
{
    return scene;
}

float3 ElderApplyWeatherAtmosphere(
    float3 scene,
    ElderScreenSpaceNeighborhood neighborhood,
    float interior_factor)
{
    float raw_depth = neighborhood.center.raw_depth;
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
    float3 scene,
    ElderScreenSpaceNeighborhood neighborhood,
    float interior_factor)
{
    float3 candidate = scene;
    candidate = ElderApplyDepthNormalContactOcclusion(candidate, neighborhood);
    candidate = ElderApplyUnsupportedReflectionIdentity(candidate, neighborhood);
    candidate = ElderApplyUnsupportedSubsurfaceIdentity(candidate, neighborhood);
    candidate = ElderApplyWeatherAtmosphere(candidate, neighborhood, interior_factor);
    return ElderFinite3(candidate) ? candidate : scene;
}

#endif  // ELDER_SCREEN_SPACE_FXH
