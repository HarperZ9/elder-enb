#pragma once

#include <elder/runtime/ShaderParameterBridge.hpp>

#include <enbcore/enb/SdkContract.hpp>

#include <cstdint>

namespace elder::runtime {

inline constexpr float kElderRuntimeProtocol = 1.0F;
inline constexpr float kElderRuntimeSchemaTag = 20'260'717.0F;
inline constexpr std::uint64_t kRenderPayloadGenerationModulus = 16'777'216ULL;

inline constexpr std::string_view kSkyrimBridgeRenderFrameSymbol = "SB_Render_Frame";
inline constexpr std::string_view kSkyrimBridgeInteriorFlagsSymbol =
    "SB_Interior_Flags";
inline constexpr std::string_view kSkyrimBridgeInteriorAmbientSymbol =
    "SB_Interior_Ambient";
inline constexpr std::string_view kSkyrimBridgeInteriorDirColorSymbol =
    "SB_Interior_DirColor";

struct RenderPayload final {
  RuntimeFloat4 room_light{};
  RuntimeFloat4 exposure_color{};
  RuntimeFloat4 status{};
};

[[nodiscard]] constexpr RuntimeFloat4 NeutralRoomLightPayload() noexcept
{
  return RuntimeFloat4{0.0F, 0.0F, 0.0F, 0.0F};
}

[[nodiscard]] constexpr RuntimeFloat4 NeutralExposureColorPayload() noexcept
{
  return RuntimeFloat4{1.0F, 1.0F, 1.0F, 1.0F};
}

[[nodiscard]] float FoldRenderPayloadGeneration(std::uint64_t generation) noexcept;
[[nodiscard]] RenderPayload MakeRenderPayload(
    RuntimeFloat4 room_light,
    RuntimeFloat4 exposure_color,
    std::uint64_t generation) noexcept;

struct PublicBridgeRoomLightSourceResult final {
  RuntimeFloat4 room_light{NeutralRoomLightPayload()};
  bool used_public_bridge{false};
};

// Optional source for the public SkyrimBridge ENB parameter surface. It has no
// DLL dependency and no private ABI: values are read by name through the same
// ENBGetParameter bridge as Elder's authored baseline capture. Invalid,
// missing, non-finite, exterior, or stale bridge values deliberately fall back
// to the neutral room-light payload so native/spatial shader behavior remains
// usable.
class PublicBridgeRoomLightSource final {
public:
  PublicBridgeRoomLightSource() noexcept = default;
  explicit PublicBridgeRoomLightSource(ShaderParameterBridge bridge) noexcept;

  void bind(ShaderParameterBridge bridge) noexcept;
  [[nodiscard]] bool ready() const noexcept;
  [[nodiscard]] PublicBridgeRoomLightSourceResult readRoomLight() noexcept;

private:
  ShaderParameterBridge bridge_{};
  float last_bridge_frame_{0.0F};
};

enum class RenderPayloadResultCode {
  published = 0,
  baseline_restored = 1,
  no_baseline = 2,
  invalid_payload = 3,
  missing_parameter = 4,
  bridge_unavailable = 5,
  write_failed = 6,
};

enum class RenderPayloadPhase {
  none = 0,
  capture_room_light = 10,
  capture_exposure_color = 11,
  capture_status = 12,
  invalidate_status = 20,
  write_room_light = 21,
  write_exposure_color = 22,
  validate_status = 23,
  restore_room_light = 30,
  restore_exposure_color = 31,
  restore_status = 32,
};

struct RenderPayloadResult final {
  RenderPayloadResultCode code{RenderPayloadResultCode::bridge_unavailable};
  RenderPayloadPhase phase{RenderPayloadPhase::none};

  [[nodiscard]] constexpr bool ok() const noexcept
  {
    return code == RenderPayloadResultCode::published
        || code == RenderPayloadResultCode::baseline_restored;
  }
};

class RenderPayloadController final {
public:
  RenderPayloadController() noexcept = default;
  explicit RenderPayloadController(ShaderParameterBridge bridge) noexcept;

  void bind(ShaderParameterBridge bridge) noexcept;
  [[nodiscard]] bool ready() const noexcept;

  [[nodiscard]] RenderPayloadResult publish(
      const RenderPayload& payload) noexcept;
  [[nodiscard]] RenderPayloadResult restoreBaseline() noexcept;
  [[nodiscard]] RenderPayloadResult handleLifecycle(
      enbcore::enb::CallbackId callback) noexcept;

private:
  [[nodiscard]] RenderPayloadResult captureBaseline() noexcept;
  [[nodiscard]] RenderPayloadResult write(
      std::string_view symbol,
      const RuntimeFloat4& value,
      RenderPayloadPhase phase) noexcept;
  [[nodiscard]] RenderPayloadResult restoreBaselineInternal() noexcept;
  [[nodiscard]] RenderPayloadResult rollbackAfter(
      RenderPayloadPhase failed_phase) noexcept;

  ShaderParameterBridge bridge_{};
  RenderPayload baseline_{};
  bool baseline_captured_{false};
};

}  // namespace elder::runtime
