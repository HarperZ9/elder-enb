#include "elder/shaders/InteriorLight.hpp"

#include <bit>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <limits>
#include <string_view>

namespace {

int failures = 0;

void expect(const bool condition, const char* expression, const char* file, const int line)
{
  if (condition) {
    return;
  }
  std::cerr << file << ':' << line << ": expectation failed: " << expression << '\n';
  ++failures;
}

#define EXPECT(expression) expect((expression), #expression, __FILE__, __LINE__)

using elder::shaders::EvaluateRoomLight;
using elder::shaders::kMaxRoomApertures;
using elder::shaders::kMaxRoomLight;
using elder::shaders::RoomAperture;
using elder::shaders::RoomLightDiagnostic;
using elder::shaders::RoomLightInput;
using elder::shaders::RoomLightOutput;
using elder::shaders::RoomLightStatus;

[[nodiscard]] bool near_value(const float a, const float b, const float tol = 1.0e-4F)
{
  return std::fabs(a - b) <= tol;
}

[[nodiscard]] bool same_bits(const float a, const float b)
{
  return std::bit_cast<std::uint32_t>(a) == std::bit_cast<std::uint32_t>(b);
}

[[nodiscard]] RoomLightInput open_room()
{
  RoomLightInput input{};
  input.exterior_sky_luminance = 100.0F;
  input.ambient_floor = 2.0F;
  input.occlusion = 0.0F;
  input.aperture_count = 1U;
  input.apertures[0] = RoomAperture{1.0F, 1.0F};
  return input;
}

void stable_codes_are_explicit()
{
  EXPECT(static_cast<std::uint8_t>(RoomLightStatus::evaluated) == 0U);
  EXPECT(static_cast<std::uint8_t>(RoomLightStatus::rejected) == 1U);
  EXPECT(static_cast<std::uint16_t>(RoomLightDiagnostic::none) == 0U);
  EXPECT(static_cast<std::uint16_t>(RoomLightDiagnostic::occlusion_out_of_range) == 121U);
  EXPECT(static_cast<std::uint16_t>(RoomLightDiagnostic::aperture_count_out_of_range) == 130U);
}

void open_room_receives_clamped_daylight()
{
  RoomLightOutput output{};
  const auto result = EvaluateRoomLight(output, open_room());
  EXPECT(result.status == RoomLightStatus::evaluated);
  EXPECT(near_value(output.open_fraction, 1.0F));
  EXPECT(near_value(output.exterior_daylight, 100.0F));
  EXPECT(near_value(output.room_light, 102.0F));
  EXPECT(!output.daylight_sealed);
}

void basement_receives_no_exterior_daylight()
{
  RoomLightInput input{};
  input.exterior_sky_luminance = 100.0F;
  input.ambient_floor = 2.0F;
  input.occlusion = 0.0F;
  input.aperture_count = 0U;

  RoomLightOutput output{};
  const auto result = EvaluateRoomLight(output, input);
  EXPECT(result.status == RoomLightStatus::evaluated);
  EXPECT(same_bits(output.exterior_daylight, 0.0F));
  EXPECT(near_value(output.room_light, 2.0F));
  EXPECT(output.daylight_sealed);
}

void full_occlusion_seals_a_windowed_room()
{
  RoomLightInput input = open_room();
  input.occlusion = 1.0F;
  RoomLightOutput output{};
  const auto result = EvaluateRoomLight(output, input);
  EXPECT(result.status == RoomLightStatus::evaluated);
  EXPECT(same_bits(output.exterior_daylight, 0.0F));
  EXPECT(output.daylight_sealed);
}

void aperture_sum_clamps_to_unity()
{
  RoomLightInput input{};
  input.exterior_sky_luminance = 50.0F;
  input.ambient_floor = 0.0F;
  input.occlusion = 0.0F;
  input.aperture_count = 2U;
  input.apertures[0] = RoomAperture{1.0F, 1.0F};
  input.apertures[1] = RoomAperture{1.0F, 1.0F};
  RoomLightOutput output{};
  const auto result = EvaluateRoomLight(output, input);
  EXPECT(result.status == RoomLightStatus::evaluated);
  EXPECT(near_value(output.open_fraction, 1.0F));
  EXPECT(near_value(output.exterior_daylight, 50.0F));
}

void partial_aperture_and_occlusion_compose()
{
  RoomLightInput input{};
  input.exterior_sky_luminance = 100.0F;
  input.ambient_floor = 1.0F;
  input.occlusion = 0.25F;
  input.aperture_count = 1U;
  input.apertures[0] = RoomAperture{0.5F, 0.8F};  // 0.40 open
  RoomLightOutput output{};
  const auto result = EvaluateRoomLight(output, input);
  EXPECT(result.status == RoomLightStatus::evaluated);
  EXPECT(near_value(output.open_fraction, 0.40F));
  EXPECT(near_value(output.exterior_daylight, 30.0F));  // 100*0.4*0.75
  EXPECT(near_value(output.room_light, 31.0F));
  EXPECT(!output.daylight_sealed);
}

void room_light_clamps_at_ceiling()
{
  RoomLightInput input = open_room();
  input.exterior_sky_luminance = kMaxRoomLight;
  input.ambient_floor = kMaxRoomLight;
  RoomLightOutput output{};
  const auto result = EvaluateRoomLight(output, input);
  EXPECT(result.status == RoomLightStatus::evaluated);
  EXPECT(near_value(output.room_light, kMaxRoomLight, 1.0F));
}

void invalid_input_preserves_output_bit_for_bit()
{
  RoomLightOutput output{};
  output.room_light = 7.0F;
  output.exterior_daylight = 8.0F;
  output.open_fraction = 0.5F;
  output.daylight_sealed = true;

  RoomLightInput input = open_room();
  input.exterior_sky_luminance = std::nanf("");
  const auto result = EvaluateRoomLight(output, input);

  EXPECT(result.status == RoomLightStatus::rejected);
  EXPECT(result.diagnostic == RoomLightDiagnostic::sky_luminance_non_finite);
  EXPECT(same_bits(output.room_light, 7.0F));
  EXPECT(same_bits(output.exterior_daylight, 8.0F));
  EXPECT(same_bits(output.open_fraction, 0.5F));
  EXPECT(output.daylight_sealed);
}

void out_of_range_occlusion_rejects()
{
  RoomLightInput input = open_room();
  input.occlusion = 1.5F;
  RoomLightOutput output{};
  const auto result = EvaluateRoomLight(output, input);
  EXPECT(result.status == RoomLightStatus::rejected);
  EXPECT(result.diagnostic == RoomLightDiagnostic::occlusion_out_of_range);
}

void too_many_apertures_rejects()
{
  RoomLightInput input = open_room();
  input.aperture_count = kMaxRoomApertures + 1U;
  RoomLightOutput output{};
  const auto result = EvaluateRoomLight(output, input);
  EXPECT(result.status == RoomLightStatus::rejected);
  EXPECT(result.diagnostic == RoomLightDiagnostic::aperture_count_out_of_range);
}

}  // namespace

int main()
{
  stable_codes_are_explicit();
  open_room_receives_clamped_daylight();
  basement_receives_no_exterior_daylight();
  full_occlusion_seals_a_windowed_room();
  aperture_sum_clamps_to_unity();
  partial_aperture_and_occlusion_compose();
  room_light_clamps_at_ceiling();
  invalid_input_preserves_output_bit_for_bit();
  out_of_range_occlusion_rejects();
  too_many_apertures_rejects();

  if (failures != 0) {
    std::cerr << failures << " assertion(s) failed\n";
    return 1;
  }
  std::cout << "Elder room-light tests passed\n";
  return 0;
}
