#ifndef ELDER_COLOR_CORE_FXH
#define ELDER_COLOR_CORE_FXH

static const float3 ElderLuminanceWeights = float3(0.2126, 0.7152, 0.0722);
static const float ElderMinimumLuminance = 0.000001;

bool ElderColorFinite(float value)
{
    return (asuint(value) & 0x7f800000u) != 0x7f800000u;
}

bool ElderColorFinite3(float3 value)
{
    uint3 exponent = asuint(value) & 0x7f800000u;
    return all(exponent != 0x7f800000u.xxx);
}

struct ElderColorCoreParameters
{
    float exposure_ev;
    float warm_cool;
    float tint;
    float toe;
    float shoulder;
    float mid_gray;
    float white_point;
    float local_contrast;
    float saturation;
    float vibrance;
    float highlight_desaturation;
    float highlight_gamut_preservation;
    float shadow_hue_stability;
    float3 shadow_tint;
    float3 highlight_tint;
};

float ElderColorLuminance(float3 color)
{
    return dot(color, ElderLuminanceWeights);
}

float ElderColorSmoothStep(float lower, float upper, float value)
{
    float normalized = saturate((value - lower) / (upper - lower));
    return normalized * normalized * (3.0 - (2.0 * normalized));
}

float3 ElderColorWhiteBalance(
    float3 color,
    float warm_cool,
    float tint)
{
    float3 gains = exp2(float3(
        (0.32 * warm_cool) + (0.10 * tint),
        (-0.04 * abs(warm_cool)) - (0.18 * tint),
        (-0.38 * warm_cool) + (0.08 * tint)));
    gains /= max(ElderColorLuminance(gains), ElderMinimumLuminance);
    return color * gains;
}

float ElderColorCompressedStops(
    float stops,
    ElderColorCoreParameters parameters)
{
    float positive = max(stops, 0.0);
    float negative = max(-stops, 0.0);
    float shoulder_denominator = 1.0
        + (0.42 * parameters.shoulder * positive);
    float toe_denominator = 1.0 + (0.55 * parameters.toe * negative);
    float shaped = (positive / shoulder_denominator)
        - (negative / toe_denominator);
    return shaped * (1.0 + (0.18 * parameters.local_contrast));
}

float ElderColorMapLuminance(
    float luminance,
    ElderColorCoreParameters parameters)
{
    if (luminance <= 0.0)
    {
        return 0.0;
    }
    float stops = log2(max(luminance, ElderMinimumLuminance)
        / parameters.mid_gray);
    float white_stops = log2(parameters.white_point / parameters.mid_gray);
    float mapped = parameters.mid_gray
        * exp2(ElderColorCompressedStops(stops, parameters));
    float mapped_white = parameters.mid_gray
        * exp2(ElderColorCompressedStops(white_stops, parameters));
    return mapped / max(mapped_white, ElderMinimumLuminance);
}

float3 ElderColorApplyTints(
    float3 color,
    ElderColorCoreParameters parameters)
{
    float luminance = ElderColorLuminance(color);
    float shadow_weight = (1.0 - ElderColorSmoothStep(0.08, 0.55, luminance))
        * (1.0 - (0.65 * parameters.shadow_hue_stability));
    float highlight_weight = ElderColorSmoothStep(0.45, 2.0, luminance);
    float3 shadowed = color * lerp(1.0.xxx, parameters.shadow_tint, shadow_weight);
    return shadowed * lerp(1.0.xxx, parameters.highlight_tint, highlight_weight);
}

float3 ElderColorApplyColorfulness(
    float3 color,
    ElderColorCoreParameters parameters)
{
    float luminance = ElderColorLuminance(color);
    float maximum = max(color.r, max(color.g, color.b));
    float minimum = min(color.r, min(color.g, color.b));
    float chroma = max(maximum - minimum, 0.0);
    float relative_chroma = chroma
        / max(luminance + chroma, ElderMinimumLuminance);
    float adaptive = 1.0 + (parameters.vibrance * (1.0 - relative_chroma));
    float saturation = max(parameters.saturation * adaptive, 0.0);
    float3 result = luminance.xxx + ((color - luminance.xxx) * saturation);
    float highlight = ElderColorSmoothStep(0.62, 1.0, luminance)
        * parameters.highlight_desaturation;
    return lerp(result, luminance.xxx, highlight);
}

float3 ElderColorCompressGamut(float3 color, float strength)
{
    float3 hard = saturate(color);
    float3 positive = max(color, 0.0.xxx);
    float maximum = max(1.0, max(positive.r, max(positive.g, positive.b)));
    float3 hue_preserved = positive / maximum;
    return lerp(hard, hue_preserved, strength);
}

float3 ElderEvaluateColorCore(
    float3 scene_linear,
    ElderColorCoreParameters parameters)
{
    if (!ElderColorFinite3(scene_linear))
    {
        return 0.0.xxx;
    }
    scene_linear = clamp(scene_linear, 0.0.xxx, 65536.0.xxx);
    if (all(scene_linear == 0.0.xxx))
    {
        return 0.0.xxx;
    }
    float3 working = scene_linear * exp2(parameters.exposure_ev);
    working = ElderColorWhiteBalance(
        working, parameters.warm_cool, parameters.tint);
    working = ElderColorApplyTints(working, parameters);
    float source_luminance = ElderColorLuminance(working);
    float mapped_luminance = ElderColorMapLuminance(source_luminance, parameters);
    working = source_luminance <= 0.0
        ? 0.0.xxx
        : working * (mapped_luminance / source_luminance);
    working = ElderColorApplyColorfulness(working, parameters);
    float3 result = ElderColorCompressGamut(
        working, parameters.highlight_gamut_preservation);
    return ElderColorFinite3(result) ? saturate(result) : 0.0.xxx;
}

#endif
