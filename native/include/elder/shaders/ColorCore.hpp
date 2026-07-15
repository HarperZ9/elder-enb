#pragma once

#include "elder/shaders/generated/ElderNativeParameterDefaults.hpp"

#include <cstdint>

namespace elder::shaders {

struct LinearRgb {
  float r;
  float g;
  float b;
};

struct ColorCoreParameters {
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
  LinearRgb shadow_tint;
  LinearRgb highlight_tint;
};

struct ColorCoreInput {
  LinearRgb scene_linear;
  ColorCoreParameters parameters;
};

struct ColorCoreOutput {
  LinearRgb display_linear;
  float source_luminance;
  float mapped_luminance;
};

enum class ColorCoreStatus : std::uint8_t {
  evaluated = 0,
  rejected = 1,
};

enum class ColorCoreDiagnostic : std::uint16_t {
  none = 0,
  scene_non_finite = 1,
  scene_out_of_range = 2,
  exposure_invalid = 10,
  warm_cool_invalid = 11,
  tint_invalid = 12,
  tonemap_invalid = 20,
  color_invalid = 30,
  tint_color_invalid = 31,
  calculation_non_finite = 40,
  calculation_out_of_range = 41,
};

struct ColorCoreEvaluation {
  ColorCoreStatus status;
  ColorCoreDiagnostic diagnostic;

  [[nodiscard]] bool ok() const noexcept {
    return status == ColorCoreStatus::evaluated;
  }
};

[[nodiscard]] constexpr ColorCoreParameters DefaultColorCoreParameters() noexcept {
  return {
      static_cast<float>(generated::ElderExposureCompensationEvDefault),
      static_cast<float>(generated::ElderColorWarmCoolDefault),
      static_cast<float>(generated::ElderColorTintDefault),
      static_cast<float>(generated::ElderTonemapToeDefault),
      static_cast<float>(generated::ElderTonemapShoulderDefault),
      static_cast<float>(generated::ElderTonemapMidGrayDefault),
      static_cast<float>(generated::ElderTonemapWhitePointDefault),
      static_cast<float>(generated::ElderTonemapLocalContrastDefault),
      static_cast<float>(generated::ElderColorSaturationDefault),
      static_cast<float>(generated::ElderColorVibranceDefault),
      static_cast<float>(generated::ElderHighlightDesaturationDefault),
      static_cast<float>(generated::ElderHighlightGamutPreservationDefault),
      static_cast<float>(generated::ElderShadowHueStabilityDefault),
      {
          static_cast<float>(generated::ElderShadowTintDefault[0]),
          static_cast<float>(generated::ElderShadowTintDefault[1]),
          static_cast<float>(generated::ElderShadowTintDefault[2]),
      },
      {
          static_cast<float>(generated::ElderHighlightTintDefault[0]),
          static_cast<float>(generated::ElderHighlightTintDefault[1]),
          static_cast<float>(generated::ElderHighlightTintDefault[2]),
      },
  };
}

[[nodiscard]] float ElderLuminance(LinearRgb color) noexcept;

[[nodiscard]] ColorCoreEvaluation EvaluateColorCore(
    const ColorCoreInput& input,
    ColorCoreOutput& output) noexcept;

}  // namespace elder::shaders
