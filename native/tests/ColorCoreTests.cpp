#include "elder/shaders/ColorCore.hpp"

#include <bit>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

namespace {

using elder::shaders::ColorCoreDiagnostic;
using elder::shaders::ColorCoreInput;
using elder::shaders::ColorCoreOutput;
using elder::shaders::DefaultColorCoreParameters;
using elder::shaders::ElderLuminance;
using elder::shaders::EvaluateColorCore;
using elder::shaders::LinearRgb;

struct TestContext {
  std::size_t assertions{};
  std::vector<std::string> failures;

  void expect(const bool condition, std::string message) {
    ++assertions;
    if (!condition) failures.push_back(std::move(message));
  }
};

[[nodiscard]] bool SameBits(const float lhs, const float rhs) noexcept {
  return std::bit_cast<std::uint32_t>(lhs)
      == std::bit_cast<std::uint32_t>(rhs);
}

[[nodiscard]] bool SameOutput(
    const ColorCoreOutput& lhs,
    const ColorCoreOutput& rhs) noexcept {
  return SameBits(lhs.display_linear.r, rhs.display_linear.r)
      && SameBits(lhs.display_linear.g, rhs.display_linear.g)
      && SameBits(lhs.display_linear.b, rhs.display_linear.b)
      && SameBits(lhs.source_luminance, rhs.source_luminance)
      && SameBits(lhs.mapped_luminance, rhs.mapped_luminance);
}

[[nodiscard]] ColorCoreInput ReferenceInput() noexcept {
  return {{0.18F, 0.18F, 0.18F}, DefaultColorCoreParameters()};
}

void InvalidInputsRejectWithoutMutation(TestContext& context) {
  const float infinity = std::numeric_limits<float>::infinity();
  const ColorCoreOutput sentinel{{-1.0F, 2.0F, -3.0F}, -4.0F, 5.0F};
  const auto reject = [&](ColorCoreInput input,
                          const ColorCoreDiagnostic expected,
                          const std::string& label) {
    ColorCoreOutput output = sentinel;
    const auto result = EvaluateColorCore(input, output);
    context.expect(!result.ok(), label + " was accepted");
    context.expect(result.diagnostic == expected,
                   label + " returned the wrong diagnostic");
    context.expect(SameOutput(output, sentinel),
                   label + " mutated output on rejection");
  };

  auto input = ReferenceInput(); input.scene_linear.r = infinity;
  reject(input, ColorCoreDiagnostic::scene_non_finite, "non-finite scene");
  input = ReferenceInput(); input.scene_linear.b = -0.01F;
  reject(input, ColorCoreDiagnostic::scene_out_of_range, "negative scene");
  input = ReferenceInput(); input.parameters.exposure_ev = 8.01F;
  reject(input, ColorCoreDiagnostic::exposure_invalid, "exposure overflow");
  input = ReferenceInput(); input.parameters.warm_cool = -1.01F;
  reject(input, ColorCoreDiagnostic::warm_cool_invalid, "warm-cool underflow");
  input = ReferenceInput(); input.parameters.tint = infinity;
  reject(input, ColorCoreDiagnostic::tint_invalid, "non-finite tint");
  input = ReferenceInput(); input.parameters.mid_gray = 0.0F;
  reject(input, ColorCoreDiagnostic::tonemap_invalid, "zero middle gray");
  input = ReferenceInput(); input.parameters.saturation = -0.01F;
  reject(input, ColorCoreDiagnostic::color_invalid, "negative saturation");
  input = ReferenceInput(); input.parameters.shadow_tint.g = 2.01F;
  reject(input, ColorCoreDiagnostic::tint_color_invalid, "shadow tint overflow");
}

void BlackIsExactZeroAndDeterministic(TestContext& context) {
  ColorCoreInput input = ReferenceInput();
  input.scene_linear = {};
  ColorCoreOutput first{{1.0F, 1.0F, 1.0F}, 1.0F, 1.0F};
  ColorCoreOutput second{};
  context.expect(EvaluateColorCore(input, first).ok(), "black evaluation failed");
  context.expect(EvaluateColorCore(input, second).ok(), "repeat black evaluation failed");
  context.expect(SameBits(first.display_linear.r, 0.0F)
                     && SameBits(first.display_linear.g, 0.0F)
                     && SameBits(first.display_linear.b, 0.0F)
                     && SameBits(first.source_luminance, 0.0F)
                     && SameBits(first.mapped_luminance, 0.0F),
                 "black was not exact positive zero");
  context.expect(SameOutput(first, second), "black evaluation changed bits");
}

void GrayRampIsMonotonicAndWhitePointIsAnchored(TestContext& context) {
  float prior = -1.0F;
  for (std::uint32_t index = 0U; index <= 8192U; ++index) {
    const float value = 16.0F * static_cast<float>(index) / 8192.0F;
    ColorCoreInput input{{value, value, value}, DefaultColorCoreParameters()};
    ColorCoreOutput output{};
    context.expect(EvaluateColorCore(input, output).ok(),
                   "gray ramp evaluation failed");
    context.expect(output.display_linear.r + 1.0e-6F >= prior,
                   "gray ramp was not monotonic");
    context.expect(std::fabs(output.display_linear.r - output.display_linear.g)
                       < 0.015F
                       && std::fabs(output.display_linear.g - output.display_linear.b)
                       < 0.015F,
                   "neutral gray acquired excessive chroma");
    prior = output.display_linear.r;
  }

  ColorCoreInput white{{11.2F, 11.2F, 11.2F}, DefaultColorCoreParameters()};
  white.parameters.shadow_tint = {1.0F, 1.0F, 1.0F};
  white.parameters.highlight_tint = {1.0F, 1.0F, 1.0F};
  white.parameters.vibrance = 0.0F;
  ColorCoreOutput output{};
  context.expect(EvaluateColorCore(white, output).ok(),
                 "white-point evaluation failed");
  context.expect(std::fabs(output.mapped_luminance - 1.0F) < 2.0e-5F,
                 "white point did not map to display white");
}

void WarmCoolAndTintAxesAreDirectional(TestContext& context) {
  ColorCoreInput warm = ReferenceInput();
  warm.parameters.warm_cool = 0.8F;
  ColorCoreInput cool = ReferenceInput();
  cool.parameters.warm_cool = -0.8F;
  ColorCoreInput magenta = ReferenceInput();
  magenta.parameters.tint = 0.8F;
  ColorCoreInput green = ReferenceInput();
  green.parameters.tint = -0.8F;
  ColorCoreOutput warm_output{};
  ColorCoreOutput cool_output{};
  ColorCoreOutput magenta_output{};
  ColorCoreOutput green_output{};
  context.expect(EvaluateColorCore(warm, warm_output).ok(), "warm evaluation failed");
  context.expect(EvaluateColorCore(cool, cool_output).ok(), "cool evaluation failed");
  context.expect(EvaluateColorCore(magenta, magenta_output).ok(),
                 "magenta evaluation failed");
  context.expect(EvaluateColorCore(green, green_output).ok(),
                 "green evaluation failed");
  context.expect(warm_output.display_linear.r > cool_output.display_linear.r
                     && warm_output.display_linear.b < cool_output.display_linear.b,
                 "warm-cool axis did not move red and blue oppositely");
  context.expect(magenta_output.display_linear.g < green_output.display_linear.g
                     && (magenta_output.display_linear.r
                         + magenta_output.display_linear.b)
                         > (green_output.display_linear.r
                            + green_output.display_linear.b),
                 "positive tint did not move toward magenta and away from green");
}

void DenseHdrGridIsFiniteBoundedAndDeterministic(TestContext& context) {
  for (std::uint32_t red = 0U; red <= 24U; ++red) {
    for (std::uint32_t green = 0U; green <= 24U; ++green) {
      for (std::uint32_t blue = 0U; blue <= 24U; ++blue) {
        ColorCoreInput input{
            {
                32.0F * static_cast<float>(red) / 24.0F,
                32.0F * static_cast<float>(green) / 24.0F,
                32.0F * static_cast<float>(blue) / 24.0F,
            },
            DefaultColorCoreParameters(),
        };
        input.parameters.exposure_ev =
            -2.0F + (4.0F * static_cast<float>((red + green + blue) % 17U) / 16.0F);
        input.parameters.warm_cool =
            -0.8F + (1.6F * static_cast<float>((3U * red + blue) % 19U) / 18.0F);
        input.parameters.tint =
            -0.8F + (1.6F * static_cast<float>((green + 2U * blue) % 13U) / 12.0F);
        ColorCoreOutput first{};
        ColorCoreOutput second{};
        const auto first_result = EvaluateColorCore(input, first);
        const auto second_result = EvaluateColorCore(input, second);
        context.expect(first_result.ok() && second_result.ok(),
                       "dense HDR sample was rejected");
        context.expect(SameOutput(first, second),
                       "dense HDR sample changed output bits");
        context.expect(std::isfinite(first.display_linear.r)
                           && std::isfinite(first.display_linear.g)
                           && std::isfinite(first.display_linear.b)
                           && first.display_linear.r >= 0.0F
                           && first.display_linear.r <= 1.0F
                           && first.display_linear.g >= 0.0F
                           && first.display_linear.g <= 1.0F
                           && first.display_linear.b >= 0.0F
                           && first.display_linear.b <= 1.0F,
                       "dense HDR output escaped display bounds");
      }
    }
  }
}

}  // namespace

int main() {
  TestContext context;
  InvalidInputsRejectWithoutMutation(context);
  BlackIsExactZeroAndDeterministic(context);
  GrayRampIsMonotonicAndWhitePointIsAnchored(context);
  WarmCoolAndTintAxesAreDirectional(context);
  DenseHdrGridIsFiniteBoundedAndDeterministic(context);

  if (!context.failures.empty()) {
    for (const auto& failure : context.failures) {
      std::cerr << "[FAIL] " << failure << '\n';
    }
    std::cerr << context.failures.size() << " failures across "
              << context.assertions << " assertions\n";
    return 1;
  }
  std::cout << "Elder native color-core cases passed: "
            << context.assertions << " assertions\n";
  return 0;
}
