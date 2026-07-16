#include "elder/shaders/InteriorLight.hpp"

#include <algorithm>
#include <cmath>

namespace elder::shaders {
namespace {

[[nodiscard]] bool in_range(const float value, const float minimum, const float maximum) noexcept
{
  return value >= minimum && value <= maximum;
}

[[nodiscard]] RoomLightResult reject(const RoomLightDiagnostic diagnostic) noexcept
{
  return {RoomLightStatus::rejected, diagnostic};
}

[[nodiscard]] RoomLightDiagnostic validate(const RoomLightInput& input) noexcept
{
  if (!std::isfinite(input.exterior_sky_luminance)) {
    return RoomLightDiagnostic::sky_luminance_non_finite;
  }
  if (!in_range(input.exterior_sky_luminance, kMinInteriorSkyLuminance, kMaxInteriorSkyLuminance)) {
    return RoomLightDiagnostic::sky_luminance_out_of_range;
  }
  if (!std::isfinite(input.ambient_floor)) {
    return RoomLightDiagnostic::ambient_floor_non_finite;
  }
  if (!in_range(input.ambient_floor, kMinInteriorSkyLuminance, kMaxInteriorSkyLuminance)) {
    return RoomLightDiagnostic::ambient_floor_out_of_range;
  }
  if (!std::isfinite(input.occlusion)) {
    return RoomLightDiagnostic::occlusion_non_finite;
  }
  if (!in_range(input.occlusion, kMinUnitFraction, kMaxUnitFraction)) {
    return RoomLightDiagnostic::occlusion_out_of_range;
  }
  if (input.aperture_count > kMaxRoomApertures) {
    return RoomLightDiagnostic::aperture_count_out_of_range;
  }
  for (std::uint32_t index = 0U; index < input.aperture_count; ++index) {
    const RoomAperture& aperture = input.apertures[index];
    if (!std::isfinite(aperture.sky_visibility)) {
      return RoomLightDiagnostic::aperture_visibility_non_finite;
    }
    if (!in_range(aperture.sky_visibility, kMinUnitFraction, kMaxUnitFraction)) {
      return RoomLightDiagnostic::aperture_visibility_out_of_range;
    }
    if (!std::isfinite(aperture.glass_transmittance)) {
      return RoomLightDiagnostic::aperture_transmittance_non_finite;
    }
    if (!in_range(aperture.glass_transmittance, kMinUnitFraction, kMaxUnitFraction)) {
      return RoomLightDiagnostic::aperture_transmittance_out_of_range;
    }
  }
  return RoomLightDiagnostic::none;
}

}  // namespace

RoomLightResult EvaluateRoomLight(RoomLightOutput& output, const RoomLightInput& input) noexcept
{
  const RoomLightDiagnostic diagnostic = validate(input);
  if (diagnostic != RoomLightDiagnostic::none) {
    return reject(diagnostic);
  }

  float aperture_sum = 0.0F;
  for (std::uint32_t index = 0U; index < input.aperture_count; ++index) {
    const RoomAperture& aperture = input.apertures[index];
    aperture_sum += aperture.sky_visibility * aperture.glass_transmittance;
  }

  const float open_fraction = std::clamp(aperture_sum, kMinUnitFraction, kMaxUnitFraction);
  const float sky_reach = open_fraction * (kMaxUnitFraction - input.occlusion);
  const float exterior_daylight = input.exterior_sky_luminance * sky_reach;
  const float room_light =
      std::clamp(input.ambient_floor + exterior_daylight, kMinInteriorSkyLuminance, kMaxRoomLight);

  if (!std::isfinite(open_fraction) || !std::isfinite(exterior_daylight)
      || !std::isfinite(room_light)) {
    return reject(RoomLightDiagnostic::calculation_non_finite);
  }

  RoomLightOutput candidate;
  candidate.room_light = room_light;
  candidate.exterior_daylight = exterior_daylight;
  candidate.open_fraction = open_fraction;
  candidate.daylight_sealed = (sky_reach == 0.0F);

  output = candidate;
  return {RoomLightStatus::evaluated, RoomLightDiagnostic::none};
}

}  // namespace elder::shaders
