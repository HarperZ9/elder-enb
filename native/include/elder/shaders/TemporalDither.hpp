#pragma once

#include <array>
#include <cstdint>

namespace elder::shaders {

// CPU reference for ElderTemporalDither.fxh.
//
// The shader adds a sub-quantum offset before ENB's eight-bit write so a smooth
// gradient dithers instead of banding, and advances the pattern per frame using
// the runtime pulse so the pattern averages out rather than sitting there as a
// fixed texture.
//
// This mirrors the HLSL exactly so the behaviour can be asserted without a GPU,
// and so a WARP probe has something to be compared against.

inline constexpr float kDitherQuantum = 1.0F / 255.0F;

// Frame phases before the pattern repeats. Four, matching the Bayer cell.
inline constexpr std::uint32_t kDitherFramePeriod = 4U;

struct DitherPixel {
  float x;
  float y;
};

// The runtime pulse as the dither reads it. `frame` is 0 when the bridge is not
// live, matching the shader's inactive payload.
struct DitherPulse {
  float frame;
  float output_width;
  float output_height;
};

[[nodiscard]] bool BridgeLive(const DitherPulse& pulse) noexcept;

// Normalised [0,1) ordered Bayer value for a pixel.
[[nodiscard]] float Bayer4x4(DitherPixel pixel) noexcept;

// Per-frame rotation of the pattern in value space, in [0,1). Zero when the
// bridge is not live, which is what makes the effect degrade to a static
// dither rather than disappearing.
[[nodiscard]] float PhaseRotation(const DitherPulse& pulse) noexcept;

// The signed offset added before quantisation, in output units. Centred on
// zero so the dither cannot lift black.
[[nodiscard]] float DitherOffset(DitherPixel pixel, const DitherPulse& pulse) noexcept;

// Applies the dither to one display-referred channel value, clamped to [0,1].
[[nodiscard]] float ApplyDither(float value,
                                DitherPixel pixel,
                                const DitherPulse& pulse) noexcept;

// Quantises to eight bits, the step the dither exists to survive.
[[nodiscard]] std::uint8_t QuantiseToByte(float value) noexcept;

}  // namespace elder::shaders
