#include "elder/shaders/ColorCore.hpp"

#include <algorithm>
#include <cmath>

namespace elder::shaders {
namespace {

constexpr float kMaximumSceneChannel = 65536.0F;
constexpr float kMinimumLuminance = 1.0e-6F;

[[nodiscard]] bool IsFinite(const LinearRgb color) noexcept {
  return std::isfinite(color.r) && std::isfinite(color.g)
      && std::isfinite(color.b);
}

[[nodiscard]] bool InRange(
    const float value,
    const float minimum,
    const float maximum) noexcept {
  return std::isfinite(value) && value >= minimum && value <= maximum;
}

[[nodiscard]] bool InRange(
    const LinearRgb color,
    const float minimum,
    const float maximum) noexcept {
  return InRange(color.r, minimum, maximum)
      && InRange(color.g, minimum, maximum)
      && InRange(color.b, minimum, maximum);
}

[[nodiscard]] LinearRgb Scale(const LinearRgb color, const float scale) noexcept {
  return {color.r * scale, color.g * scale, color.b * scale};
}

[[nodiscard]] LinearRgb Multiply(
    const LinearRgb lhs,
    const LinearRgb rhs) noexcept {
  return {lhs.r * rhs.r, lhs.g * rhs.g, lhs.b * rhs.b};
}

[[nodiscard]] LinearRgb Mix(
    const LinearRgb lhs,
    const LinearRgb rhs,
    const float weight) noexcept {
  return {
      lhs.r + ((rhs.r - lhs.r) * weight),
      lhs.g + ((rhs.g - lhs.g) * weight),
      lhs.b + ((rhs.b - lhs.b) * weight),
  };
}

[[nodiscard]] float SmoothStep(
    const float lower,
    const float upper,
    const float value) noexcept {
  const float normalized = std::clamp(
      (value - lower) / (upper - lower), 0.0F, 1.0F);
  return normalized * normalized * (3.0F - (2.0F * normalized));
}

[[nodiscard]] LinearRgb WhiteBalance(
    const LinearRgb color,
    const float warm_cool,
    const float tint) noexcept {
  LinearRgb gains{
      std::exp2((0.32F * warm_cool) + (0.10F * tint)),
      std::exp2((-0.04F * std::fabs(warm_cool)) - (0.18F * tint)),
      std::exp2((-0.38F * warm_cool) + (0.08F * tint)),
  };
  const float gain_luminance = std::max(ElderLuminance(gains), kMinimumLuminance);
  gains = Scale(gains, 1.0F / gain_luminance);
  return Multiply(color, gains);
}

[[nodiscard]] float CompressedStops(
    const float stops,
    const ColorCoreParameters& parameters) noexcept {
  const float positive = std::max(stops, 0.0F);
  const float negative = std::max(-stops, 0.0F);
  const float shoulder_denominator = 1.0F
      + (0.42F * parameters.shoulder * positive);
  const float toe_denominator = 1.0F
      + (0.55F * parameters.toe * negative);
  const float shaped = (positive / shoulder_denominator)
      - (negative / toe_denominator);
  return shaped * (1.0F + (0.18F * parameters.local_contrast));
}

[[nodiscard]] float MapLuminance(
    const float luminance,
    const ColorCoreParameters& parameters) noexcept {
  if (luminance <= 0.0F) {
    return 0.0F;
  }
  const float stops = std::log2(
      std::max(luminance, kMinimumLuminance) / parameters.mid_gray);
  const float white_stops = std::log2(
      parameters.white_point / parameters.mid_gray);
  const float mapped = parameters.mid_gray
      * std::exp2(CompressedStops(stops, parameters));
  const float mapped_white = parameters.mid_gray
      * std::exp2(CompressedStops(white_stops, parameters));
  return mapped / std::max(mapped_white, kMinimumLuminance);
}

[[nodiscard]] LinearRgb ApplyTints(
    const LinearRgb color,
    const ColorCoreParameters& parameters) noexcept {
  const float luminance = ElderLuminance(color);
  const float shadow_weight = (1.0F - SmoothStep(0.08F, 0.55F, luminance))
      * (1.0F - (0.65F * parameters.shadow_hue_stability));
  const float highlight_weight = SmoothStep(0.45F, 2.0F, luminance);
  const LinearRgb shadowed = Multiply(
      color, Mix({1.0F, 1.0F, 1.0F}, parameters.shadow_tint, shadow_weight));
  return Multiply(
      shadowed,
      Mix({1.0F, 1.0F, 1.0F}, parameters.highlight_tint, highlight_weight));
}

[[nodiscard]] LinearRgb ApplyColorfulness(
    const LinearRgb color,
    const ColorCoreParameters& parameters) noexcept {
  const float luminance = ElderLuminance(color);
  const float maximum = std::max({color.r, color.g, color.b});
  const float minimum = std::min({color.r, color.g, color.b});
  const float chroma = std::max(maximum - minimum, 0.0F);
  const float relative_chroma = chroma / std::max(luminance + chroma, kMinimumLuminance);
  const float adaptive = 1.0F
      + (parameters.vibrance * (1.0F - relative_chroma));
  const float saturation = std::max(parameters.saturation * adaptive, 0.0F);
  LinearRgb result = {
      luminance + ((color.r - luminance) * saturation),
      luminance + ((color.g - luminance) * saturation),
      luminance + ((color.b - luminance) * saturation),
  };
  const float highlight = SmoothStep(0.62F, 1.0F, luminance)
      * parameters.highlight_desaturation;
  result = Mix(result, {luminance, luminance, luminance}, highlight);
  return result;
}

[[nodiscard]] LinearRgb CompressGamut(
    const LinearRgb color,
    const float strength) noexcept {
  const LinearRgb hard{
      std::clamp(color.r, 0.0F, 1.0F),
      std::clamp(color.g, 0.0F, 1.0F),
      std::clamp(color.b, 0.0F, 1.0F),
  };
  const LinearRgb positive{
      std::max(color.r, 0.0F),
      std::max(color.g, 0.0F),
      std::max(color.b, 0.0F),
  };
  const float maximum = std::max({positive.r, positive.g, positive.b, 1.0F});
  const LinearRgb hue_preserved = Scale(positive, 1.0F / maximum);
  return Mix(hard, hue_preserved, strength);
}

[[nodiscard]] ColorCoreDiagnostic Validate(
    const ColorCoreInput& input) noexcept {
  if (!IsFinite(input.scene_linear)) {
    return ColorCoreDiagnostic::scene_non_finite;
  }
  if (!InRange(input.scene_linear, 0.0F, kMaximumSceneChannel)) {
    return ColorCoreDiagnostic::scene_out_of_range;
  }
  const auto& parameters = input.parameters;
  if (!InRange(
          parameters.exposure_ev,
          static_cast<float>(generated::ElderExposureCompensationEvMinimum),
          static_cast<float>(generated::ElderExposureCompensationEvMaximum))) {
    return ColorCoreDiagnostic::exposure_invalid;
  }
  if (!InRange(
          parameters.warm_cool,
          static_cast<float>(generated::ElderColorWarmCoolMinimum),
          static_cast<float>(generated::ElderColorWarmCoolMaximum))) {
    return ColorCoreDiagnostic::warm_cool_invalid;
  }
  if (!InRange(
          parameters.tint,
          static_cast<float>(generated::ElderColorTintMinimum),
          static_cast<float>(generated::ElderColorTintMaximum))) {
    return ColorCoreDiagnostic::tint_invalid;
  }
  if (!InRange(parameters.toe,
               static_cast<float>(generated::ElderTonemapToeMinimum),
               static_cast<float>(generated::ElderTonemapToeMaximum))
      || !InRange(parameters.shoulder,
                  static_cast<float>(generated::ElderTonemapShoulderMinimum),
                  static_cast<float>(generated::ElderTonemapShoulderMaximum))
      || !InRange(parameters.mid_gray,
                  static_cast<float>(generated::ElderTonemapMidGrayMinimum),
                  static_cast<float>(generated::ElderTonemapMidGrayMaximum))
      || !InRange(parameters.white_point,
                  static_cast<float>(generated::ElderTonemapWhitePointMinimum),
                  static_cast<float>(generated::ElderTonemapWhitePointMaximum))
      || !InRange(
          parameters.local_contrast,
          static_cast<float>(generated::ElderTonemapLocalContrastMinimum),
          static_cast<float>(generated::ElderTonemapLocalContrastMaximum))) {
    return ColorCoreDiagnostic::tonemap_invalid;
  }
  if (!InRange(parameters.saturation,
               static_cast<float>(generated::ElderColorSaturationMinimum),
               static_cast<float>(generated::ElderColorSaturationMaximum))
      || !InRange(parameters.vibrance,
                  static_cast<float>(generated::ElderColorVibranceMinimum),
                  static_cast<float>(generated::ElderColorVibranceMaximum))
      || !InRange(
          parameters.highlight_desaturation,
          static_cast<float>(generated::ElderHighlightDesaturationMinimum),
          static_cast<float>(generated::ElderHighlightDesaturationMaximum))
      || !InRange(
          parameters.highlight_gamut_preservation,
          static_cast<float>(
              generated::ElderHighlightGamutPreservationMinimum),
          static_cast<float>(
              generated::ElderHighlightGamutPreservationMaximum))
      || !InRange(
          parameters.shadow_hue_stability,
          static_cast<float>(generated::ElderShadowHueStabilityMinimum),
          static_cast<float>(generated::ElderShadowHueStabilityMaximum))) {
    return ColorCoreDiagnostic::color_invalid;
  }
  if (!InRange(
          parameters.shadow_tint,
          static_cast<float>(generated::ElderShadowTintMinimum),
          static_cast<float>(generated::ElderShadowTintMaximum))
      || !InRange(
          parameters.highlight_tint,
          static_cast<float>(generated::ElderHighlightTintMinimum),
          static_cast<float>(generated::ElderHighlightTintMaximum))) {
    return ColorCoreDiagnostic::tint_color_invalid;
  }
  return ColorCoreDiagnostic::none;
}

}  // namespace

float ElderLuminance(const LinearRgb color) noexcept {
  return (0.2126F * color.r) + (0.7152F * color.g) + (0.0722F * color.b);
}

ColorCoreEvaluation EvaluateColorCore(
    const ColorCoreInput& input,
    ColorCoreOutput& output) noexcept {
  const ColorCoreDiagnostic diagnostic = Validate(input);
  if (diagnostic != ColorCoreDiagnostic::none) {
    return {ColorCoreStatus::rejected, diagnostic};
  }
  if (input.scene_linear.r == 0.0F && input.scene_linear.g == 0.0F
      && input.scene_linear.b == 0.0F) {
    output = {};
    return {ColorCoreStatus::evaluated, ColorCoreDiagnostic::none};
  }

  const float exposure = std::exp2(input.parameters.exposure_ev);
  LinearRgb working = Scale(input.scene_linear, exposure);
  working = WhiteBalance(
      working, input.parameters.warm_cool, input.parameters.tint);
  working = ApplyTints(working, input.parameters);
  const float source_luminance = ElderLuminance(working);
  const float mapped_luminance = MapLuminance(
      source_luminance, input.parameters);
  working = source_luminance <= 0.0F
      ? LinearRgb{}
      : Scale(working, mapped_luminance / source_luminance);
  working = ApplyColorfulness(working, input.parameters);
  working = CompressGamut(
      working, input.parameters.highlight_gamut_preservation);

  ColorCoreOutput candidate{working, source_luminance, mapped_luminance};
  if (!IsFinite(candidate.display_linear)
      || !std::isfinite(candidate.source_luminance)
      || !std::isfinite(candidate.mapped_luminance)) {
    return {ColorCoreStatus::rejected,
            ColorCoreDiagnostic::calculation_non_finite};
  }
  if (!InRange(candidate.display_linear, 0.0F, 1.0F)
      || candidate.source_luminance < 0.0F
      || candidate.mapped_luminance < 0.0F) {
    return {ColorCoreStatus::rejected,
            ColorCoreDiagnostic::calculation_out_of_range};
  }
  output = candidate;
  return {ColorCoreStatus::evaluated, ColorCoreDiagnostic::none};
}

}  // namespace elder::shaders
