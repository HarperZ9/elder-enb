#pragma once

#include <cstdint>

namespace elder::shaders {

// Occlusion-aware interior daylight for the Elder workshop stack. A room is lit
// by the exterior sky only through its window/portal apertures and only when it
// is not occluded, so a windowless or sealed cell keeps only its ambient floor.
// This is Elder-owned work: it shares the model's physics with the Truth
// product but not one byte of source (own names, own file, own layering so the
// disjointness gate stays satisfied).

inline constexpr std::uint32_t kMaxRoomApertures = 8U;
inline constexpr float kMinInteriorSkyLuminance = 0.0F;
inline constexpr float kMaxInteriorSkyLuminance = 1'000'000.0F;
inline constexpr float kMinUnitFraction = 0.0F;
inline constexpr float kMaxUnitFraction = 1.0F;
inline constexpr float kMaxRoomLight = 1'000'000.0F;

struct RoomAperture {
  float sky_visibility;  // [0,1] fraction of the opening's cone that sees sky.
  float glass_transmittance;  // [0,1] opening/glazing transmittance.
};

struct RoomLightInput {
  float exterior_sky_luminance;  // [0, 1e6]
  float ambient_floor;           // [0, 1e6] the room's own baseline light.
  float occlusion;               // [0,1]; 1 = fully occluded (basement / sealed).
  std::uint32_t aperture_count;  // <= kMaxRoomApertures.
  RoomAperture apertures[kMaxRoomApertures];
};

struct RoomLightOutput {
  float room_light;          // ambient_floor + clamped exterior daylight.
  float exterior_daylight;   // exterior contribution alone (0 for basements).
  float open_fraction;       // clamped [0,1] total sky-open fraction.
  bool daylight_sealed;      // true when no exterior light reaches the room.
};

enum class RoomLightStatus : std::uint8_t {
  evaluated = 0,
  rejected = 1,
};

enum class RoomLightDiagnostic : std::uint16_t {
  none = 0,
  sky_luminance_non_finite = 100,
  sky_luminance_out_of_range = 101,
  ambient_floor_non_finite = 110,
  ambient_floor_out_of_range = 111,
  occlusion_non_finite = 120,
  occlusion_out_of_range = 121,
  aperture_count_out_of_range = 130,
  aperture_visibility_non_finite = 140,
  aperture_visibility_out_of_range = 141,
  aperture_transmittance_non_finite = 150,
  aperture_transmittance_out_of_range = 151,
  calculation_non_finite = 180,
};

struct RoomLightResult {
  RoomLightStatus status;
  RoomLightDiagnostic diagnostic;
};

// Validate every field, compute a bounded candidate, and assign the output
// exactly once. On any rejection the caller's output is preserved bit-for-bit.
[[nodiscard]] RoomLightResult EvaluateRoomLight(RoomLightOutput& output,
                                                const RoomLightInput& input) noexcept;

}  // namespace elder::shaders
