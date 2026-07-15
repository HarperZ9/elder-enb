#include "elder/shaders/ColorProfileBinding.hpp"

#include <cmath>
#include <limits>
#include <map>
#include <string>
#include <string_view>

namespace elder::shaders {
namespace {

[[nodiscard]] bool ReadScalar(
    const NativeProfile& profile,
    const std::string_view semantic_id,
    float& output) noexcept {
  const auto found = profile.values.find(semantic_id);
  if (found == profile.values.end() || found->second.count != 1U) return false;
  const double value = found->second.components[0];
  if (!std::isfinite(value)
      || value < -static_cast<double>(std::numeric_limits<float>::max())
      || value > static_cast<double>(std::numeric_limits<float>::max())) {
    return false;
  }
  output = static_cast<float>(value);
  return true;
}

[[nodiscard]] bool ReadColor(
    const NativeProfile& profile,
    const std::string_view semantic_id,
    LinearRgb& output) noexcept {
  const auto found = profile.values.find(semantic_id);
  if (found == profile.values.end() || found->second.count != 3U) return false;
  LinearRgb candidate{};
  float* channels[] = {&candidate.r, &candidate.g, &candidate.b};
  for (std::uint8_t index = 0U; index < 3U; ++index) {
    const double value = found->second.components[index];
    if (!std::isfinite(value)
        || value < -static_cast<double>(std::numeric_limits<float>::max())
        || value > static_cast<double>(std::numeric_limits<float>::max())) {
      return false;
    }
    *channels[index] = static_cast<float>(value);
  }
  output = candidate;
  return true;
}

[[nodiscard]] bool Active(
    const std::map<std::string, bool, std::less<>>& activity,
    const std::string_view semantic_id) noexcept {
  const auto found = activity.find(semantic_id);
  return found != activity.end() && found->second;
}

}  // namespace

ColorBindingResult BindNativeColorProfile(
    const NativeParameterSchema& schema,
    const NativeProfile& profile,
    NativeColorBinding& output) noexcept {
  try {
    if (schema.abi_sha256 != generated::kNativeParameterSchemaSha256) {
      return {ColorBindingDiagnostic::invalid_schema};
    }
    if (!std::isfinite(profile.opacity) || profile.opacity != 1.0) {
      return {ColorBindingDiagnostic::invalid_profile};
    }
    std::map<std::string, bool, std::less<>> activity;
    const ProfileResult activity_result = EvaluateNativeProfileActivity(
        schema, profile, activity);
    if (!activity_result.ok()) {
      return {activity_result.diagnostic == ProfileDiagnostic::wrong_schema_id
                  || activity_result.diagnostic
                      == ProfileDiagnostic::wrong_schema_fingerprint
              ? ColorBindingDiagnostic::invalid_schema
              : ColorBindingDiagnostic::invalid_profile};
    }

    NativeColorBinding candidate;
    float master{};
    if (!ReadScalar(
            profile, generated::ElderMasterEnabledSemanticId, master)) {
      return {ColorBindingDiagnostic::missing_parameter};
    }
    candidate.enabled = master == 1.0F;
    if (!candidate.enabled) {
      output = candidate;
      return {};
    }

    constexpr std::string_view required_activity[] = {
        generated::ElderExposureCompensationEvSemanticId,
        generated::ElderColorWarmCoolSemanticId,
        generated::ElderColorTintSemanticId,
        generated::ElderTonemapToeSemanticId,
        generated::ElderTonemapShoulderSemanticId,
        generated::ElderTonemapMidGraySemanticId,
        generated::ElderTonemapWhitePointSemanticId,
        generated::ElderTonemapLocalContrastSemanticId,
        generated::ElderColorSaturationSemanticId,
        generated::ElderColorVibranceSemanticId,
        generated::ElderHighlightDesaturationSemanticId,
        generated::ElderHighlightGamutPreservationSemanticId,
        generated::ElderShadowHueStabilitySemanticId,
        generated::ElderShadowTintSemanticId,
        generated::ElderHighlightTintSemanticId,
    };
    for (const std::string_view semantic_id : required_activity) {
      if (!Active(activity, semantic_id)) {
        return {ColorBindingDiagnostic::inactive_parameter};
      }
    }

    auto& parameters = candidate.parameters;
    const bool scalars_ok =
        ReadScalar(profile,
                   generated::ElderExposureCompensationEvSemanticId,
                   parameters.exposure_ev)
        && ReadScalar(profile,
                      generated::ElderColorWarmCoolSemanticId,
                      parameters.warm_cool)
        && ReadScalar(profile,
                      generated::ElderColorTintSemanticId,
                      parameters.tint)
        && ReadScalar(profile,
                      generated::ElderTonemapToeSemanticId,
                      parameters.toe)
        && ReadScalar(profile,
                      generated::ElderTonemapShoulderSemanticId,
                      parameters.shoulder)
        && ReadScalar(profile,
                      generated::ElderTonemapMidGraySemanticId,
                      parameters.mid_gray)
        && ReadScalar(profile,
                      generated::ElderTonemapWhitePointSemanticId,
                      parameters.white_point)
        && ReadScalar(profile,
                      generated::ElderTonemapLocalContrastSemanticId,
                      parameters.local_contrast)
        && ReadScalar(profile,
                      generated::ElderColorSaturationSemanticId,
                      parameters.saturation)
        && ReadScalar(profile,
                      generated::ElderColorVibranceSemanticId,
                      parameters.vibrance)
        && ReadScalar(profile,
                      generated::ElderHighlightDesaturationSemanticId,
                      parameters.highlight_desaturation)
        && ReadScalar(
            profile,
            generated::ElderHighlightGamutPreservationSemanticId,
            parameters.highlight_gamut_preservation)
        && ReadScalar(profile,
                      generated::ElderShadowHueStabilitySemanticId,
                      parameters.shadow_hue_stability);
    if (!scalars_ok
        || !ReadColor(profile,
                      generated::ElderShadowTintSemanticId,
                      parameters.shadow_tint)
        || !ReadColor(profile,
                      generated::ElderHighlightTintSemanticId,
                      parameters.highlight_tint)) {
      return {ColorBindingDiagnostic::conversion_out_of_range};
    }

    ColorCoreOutput probe{};
    const ColorCoreEvaluation validation = EvaluateColorCore(
        ColorCoreInput{{0.18F, 0.18F, 0.18F}, parameters}, probe);
    if (!validation.ok()) {
      return {ColorBindingDiagnostic::invalid_profile};
    }
    output = candidate;
    return {};
  } catch (...) {
    return {ColorBindingDiagnostic::invalid_profile};
  }
}

}  // namespace elder::shaders
