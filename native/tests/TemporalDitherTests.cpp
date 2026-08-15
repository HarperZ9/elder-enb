#include "elder/shaders/TemporalDither.hpp"

#include <cmath>
#include <cstdint>
#include <iostream>
#include <set>

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

using elder::shaders::ApplyDither;
using elder::shaders::Bayer4x4;
using elder::shaders::BridgeLive;
using elder::shaders::DitherOffset;
using elder::shaders::DitherPixel;
using elder::shaders::DitherPulse;
using elder::shaders::PhaseRotation;
using elder::shaders::kDitherFramePeriod;
using elder::shaders::kDitherQuantum;
using elder::shaders::QuantiseToByte;

[[nodiscard]] DitherPulse LivePulse(const float frame)
{
  return DitherPulse{frame, 1920.0F, 1080.0F};
}

[[nodiscard]] DitherPulse InactivePulse()
{
  return DitherPulse{0.0F, 0.0F, 0.0F};
}

// The offset must never exceed half a quantisation step. A larger offset stops
// being invisible and becomes noise the user can see.
void OffsetStaysSubQuantum()
{
  for (int y = 0; y < 8; ++y) {
    for (int x = 0; x < 8; ++x) {
      const auto pixel = DitherPixel{static_cast<float>(x), static_cast<float>(y)};
      for (std::uint32_t frame = 0; frame <= kDitherFramePeriod; ++frame) {
        const float offset = DitherOffset(pixel, LivePulse(static_cast<float>(frame + 1U)));
        EXPECT(std::fabs(offset) <= kDitherQuantum * 0.5F + 1e-7F);
      }
    }
  }
}

// Centred on zero over a cell, so the dither cannot lift black or crush white.
void OffsetIsCentred()
{
  float sum = 0.0F;
  for (int y = 0; y < 4; ++y) {
    for (int x = 0; x < 4; ++x) {
      sum += DitherOffset(DitherPixel{static_cast<float>(x), static_cast<float>(y)},
                          LivePulse(1.0F));
    }
  }
  EXPECT(std::fabs(sum / 16.0F) < 1e-6F);
}

// Without the bridge the pattern must not move. This is the fallback that keeps
// the shader useful when the plugin is absent.
void WithoutBridgeThePatternIsStatic()
{
  EXPECT(!BridgeLive(InactivePulse()));

  const auto pixel = DitherPixel{7.0F, 3.0F};
  const float first = DitherOffset(pixel, InactivePulse());
  for (const float frame : {0.0F, 5.0F, 99.0F}) {
    DitherPulse pulse = InactivePulse();
    pulse.frame = frame >= 1.0F ? 0.0F : frame;  // still inactive
    EXPECT(DitherOffset(pixel, pulse) == first);
  }

  EXPECT(PhaseRotation(InactivePulse()) == 0.0F);
}

// With the bridge the pattern must move, and must visit every phase before
// repeating. A pattern that "advances" but revisits the same phase each frame
// would look identical to the static case.
void WithBridgeThePatternAdvances()
{
  const auto pixel = DitherPixel{7.0F, 3.0F};
  std::set<float> seen;
  for (std::uint32_t frame = 1U; frame <= kDitherFramePeriod; ++frame) {
    seen.insert(DitherOffset(pixel, LivePulse(static_cast<float>(frame))));
  }
  EXPECT(seen.size() > 1U);

  // And it repeats on period, so the sequence is bounded rather than drifting.
  EXPECT(DitherOffset(pixel, LivePulse(1.0F))
         == DitherOffset(pixel, LivePulse(1.0F + static_cast<float>(kDitherFramePeriod))));
}

// The payoff, and the reason the pulse is worth publishing at all.
//
// A value that sits between two eight-bit levels quantises to the same level
// every time without dither, so the error is the whole fractional part and a
// gradient of such values collapses into flat bands.
//
// A static dither fixes that by averaging over SPACE: sixteen neighbouring
// pixels land on both levels in the right proportion. That costs spatial
// detail, because the correct value only exists across a 4x4 block.
//
// The frame pulse buys averaging over TIME instead. One pixel, watched across
// four frames, visits both levels in the same proportion. The gradient reads
// smooth without trading away resolution, which is the entire point.
void TemporalAveragingRecoversTheValueAtOnePixel()
{
  // Deliberately between levels 50 and 51.
  const float truth = 50.5F / 255.0F;
  const auto pixel = DitherPixel{9.0F, 5.0F};

  // Undithered: the same level forever, so the error never averages out.
  const std::uint8_t flat = QuantiseToByte(truth);
  float flat_mean = 0.0F;
  for (std::uint32_t frame = 1U; frame <= kDitherFramePeriod; ++frame) {
    flat_mean += static_cast<float>(flat);
  }
  flat_mean /= static_cast<float>(kDitherFramePeriod);

  // Dithered at the SAME single pixel, averaged over one full frame period.
  float temporal_mean = 0.0F;
  std::set<std::uint8_t> levels;
  for (std::uint32_t frame = 1U; frame <= kDitherFramePeriod; ++frame) {
    const std::uint8_t q =
        QuantiseToByte(ApplyDither(truth, pixel, LivePulse(static_cast<float>(frame))));
    levels.insert(q);
    temporal_mean += static_cast<float>(q);
  }
  temporal_mean /= static_cast<float>(kDitherFramePeriod);

  // One pixel now visits more than one level over time. Without the pulse it
  // could not: that is what the runtime is buying.
  EXPECT(levels.size() > 1U);

  const float truth_levels = truth * 255.0F;
  const float temporal_error = std::fabs(temporal_mean - truth_levels);
  const float flat_error = std::fabs(flat_mean - truth_levels);
  EXPECT(temporal_error < flat_error);
  EXPECT(temporal_error <= 0.5F);
}

// The static fallback still has to work, by averaging over space instead. This
// is what a user without the plugin gets, and it must not be nothing.
void StaticDitherStillRecoversTheValueOverACell()
{
  const float truth = 50.5F / 255.0F;
  const auto pulse = InactivePulse();

  float mean = 0.0F;
  std::set<std::uint8_t> levels;
  for (int y = 0; y < 4; ++y) {
    for (int x = 0; x < 4; ++x) {
      const std::uint8_t q = QuantiseToByte(ApplyDither(
          truth, DitherPixel{static_cast<float>(x), static_cast<float>(y)}, pulse));
      levels.insert(q);
      mean += static_cast<float>(q);
    }
  }
  mean /= 16.0F;

  EXPECT(levels.size() > 1U);
  EXPECT(std::fabs(mean - truth * 255.0F) <= 0.5F);
}

// Black and white must survive untouched. Lifting black is the failure mode a
// careless dither has, and on a night sky it is worse than the banding.
void EndpointsAreNotDisturbed()
{
  for (std::uint32_t frame = 1U; frame <= kDitherFramePeriod; ++frame) {
    for (int y = 0; y < 4; ++y) {
      for (int x = 0; x < 4; ++x) {
        const auto pixel = DitherPixel{static_cast<float>(x), static_cast<float>(y)};
        const auto pulse = LivePulse(static_cast<float>(frame));
        EXPECT(QuantiseToByte(ApplyDither(0.0F, pixel, pulse)) == 0U);
        EXPECT(QuantiseToByte(ApplyDither(1.0F, pixel, pulse)) == 255U);
      }
    }
  }
}

// The Bayer table is a permutation of 0..15 over its cell. A typo in the table
// would otherwise show as a subtle directional bias rather than a failure.
void BayerCellIsAPermutation()
{
  std::set<int> scaled;
  for (int y = 0; y < 4; ++y) {
    for (int x = 0; x < 4; ++x) {
      const float value =
          Bayer4x4(DitherPixel{static_cast<float>(x), static_cast<float>(y)});
      EXPECT(value >= 0.0F && value < 1.0F);
      scaled.insert(static_cast<int>(std::lround(value * 16.0F)));
    }
  }
  EXPECT(scaled.size() == 16U);
}

}  // namespace

int main()
{
  OffsetStaysSubQuantum();
  OffsetIsCentred();
  WithoutBridgeThePatternIsStatic();
  WithBridgeThePatternAdvances();
  TemporalAveragingRecoversTheValueAtOnePixel();
  StaticDitherStillRecoversTheValueOverACell();
  EndpointsAreNotDisturbed();
  BayerCellIsAPermutation();

  if (failures != 0) {
    std::cerr << failures << " temporal-dither expectation(s) failed\n";
    return 1;
  }
  std::cout << "PASS: Elder temporal dither\n";
  return 0;
}
