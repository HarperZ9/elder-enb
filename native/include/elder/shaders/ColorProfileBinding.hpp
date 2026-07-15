#pragma once

#include "elder/shaders/ColorCore.hpp"
#include "elder/shaders/ParameterSchema.hpp"

#include <cstdint>

namespace elder::shaders {

struct NativeColorBinding {
  bool enabled{true};
  ColorCoreParameters parameters{DefaultColorCoreParameters()};
};

enum class ColorBindingDiagnostic : std::uint16_t {
  none = 0,
  invalid_schema = 1,
  invalid_profile = 2,
  missing_parameter = 3,
  inactive_parameter = 4,
  conversion_out_of_range = 5,
};

struct ColorBindingResult {
  ColorBindingDiagnostic diagnostic{ColorBindingDiagnostic::none};

  [[nodiscard]] bool ok() const noexcept {
    return diagnostic == ColorBindingDiagnostic::none;
  }
};

[[nodiscard]] ColorBindingResult BindNativeColorProfile(
    const NativeParameterSchema& schema,
    const NativeProfile& profile,
    NativeColorBinding& output) noexcept;

}  // namespace elder::shaders
