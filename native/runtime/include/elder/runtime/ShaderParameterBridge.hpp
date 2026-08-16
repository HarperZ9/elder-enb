#pragma once

#include <enbcore/enb/SdkContract.hpp>

#include <array>
#include <string_view>

namespace elder::runtime {

using RuntimeFloat4 = std::array<float, 4>;

inline constexpr std::string_view kElderRenderPayloadShader = "ENBEFFECTPREPASS.FX";
inline constexpr std::string_view kElderRuntimeRoomLightSymbol =
    "ElderRuntimeRoomLight";
inline constexpr std::string_view kElderRuntimeExposureColorSymbol =
    "ElderRuntimeExposureColor";
inline constexpr std::string_view kElderRuntimeStatusSymbol = "ElderRuntimeStatus";

[[nodiscard]] enbcore::enb::Parameter EncodeColor4Parameter(
    const RuntimeFloat4& value) noexcept;
[[nodiscard]] RuntimeFloat4 DecodeColor4Parameter(
    const enbcore::enb::Parameter& parameter) noexcept;
[[nodiscard]] bool IsFiniteFloat4(const RuntimeFloat4& value) noexcept;
[[nodiscard]] bool IsColor4Parameter(
    const enbcore::enb::Parameter& parameter) noexcept;

enum class ShaderParameterBridgeCode {
  ok = 0,
  bridge_unavailable = 1,
  missing_parameter = 2,
  invalid_parameter = 3,
  write_failed = 4,
};

struct ShaderParameterBridgeResult final {
  ShaderParameterBridgeCode code{ShaderParameterBridgeCode::bridge_unavailable};

  [[nodiscard]] constexpr bool ok() const noexcept
  {
    return code == ShaderParameterBridgeCode::ok;
  }
};

// Thin ENB SDK adapter. It owns no render state and never touches D3D objects:
// it only forwards null-terminated shader/symbol names to ENBGetParameter and
// ENBSetParameter, then verifies the COLOR4 payload shape at this boundary.
class ShaderParameterBridge final {
public:
  ShaderParameterBridge() noexcept = default;
  ShaderParameterBridge(enbcore::enb::GetParameter get_parameter,
                        enbcore::enb::SetParameter set_parameter) noexcept;

  [[nodiscard]] bool available() const noexcept;

  [[nodiscard]] ShaderParameterBridgeResult getColor4(
      std::string_view shader,
      std::string_view symbol,
      RuntimeFloat4& value) const noexcept;

  [[nodiscard]] ShaderParameterBridgeResult setColor4(
      std::string_view shader,
      std::string_view symbol,
      const RuntimeFloat4& value) const noexcept;

private:
  enbcore::enb::GetParameter get_parameter_{nullptr};
  enbcore::enb::SetParameter set_parameter_{nullptr};
};

}  // namespace elder::runtime
