#include "elder/shaders/TemporalDither.hpp"

#include <algorithm>
#include <cmath>

namespace elder::shaders {
namespace {

// Row-major 4x4 ordered Bayer matrix, times 16. Identical to the table in
// ElderTemporalDither.fxh; the two are compared by the WARP probe.
constexpr std::array<float, 16> kBayerScaled{
    0.0F, 8.0F, 2.0F, 10.0F,
    12.0F, 4.0F, 14.0F, 6.0F,
    3.0F, 11.0F, 1.0F, 9.0F,
    15.0F, 7.0F, 13.0F, 5.0F,
};

}  // namespace

bool BridgeLive(const DitherPulse& pulse) noexcept
{
  return std::isfinite(pulse.frame) && pulse.frame >= 1.0F;
}

float Bayer4x4(const DitherPixel pixel) noexcept
{
  const float cell_x = std::floor(std::fmod(std::fabs(pixel.x), 4.0F));
  const float cell_y = std::floor(std::fmod(std::fabs(pixel.y), 4.0F));
  const auto index = static_cast<std::size_t>(cell_y) * 4U
      + static_cast<std::size_t>(cell_x);
  // Centred on 0.5; see the note in ElderTemporalDither.fxh.
  return (kBayerScaled[index % kBayerScaled.size()] + 0.5F) / 16.0F;
}

float PhaseRotation(const DitherPulse& pulse) noexcept
{
  if (!BridgeLive(pulse)) {
    return 0.0F;
  }
  return std::fmod(pulse.frame, static_cast<float>(kDitherFramePeriod))
      / static_cast<float>(kDitherFramePeriod);
}

float DitherOffset(const DitherPixel pixel, const DitherPulse& pulse) noexcept
{
  const float bayer = Bayer4x4(pixel);
  float rotated = bayer + PhaseRotation(pulse);
  rotated -= std::floor(rotated);
  return (rotated - 0.5F) * kDitherQuantum;
}

float ApplyDither(const float value,
                  const DitherPixel pixel,
                  const DitherPulse& pulse) noexcept
{
  return std::clamp(value + DitherOffset(pixel, pulse), 0.0F, 1.0F);
}

std::uint8_t QuantiseToByte(const float value) noexcept
{
  const float clamped = std::clamp(value, 0.0F, 1.0F);
  return static_cast<std::uint8_t>(std::floor(clamped * 255.0F + 0.5F));
}

}  // namespace elder::shaders
