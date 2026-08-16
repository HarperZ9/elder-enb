#pragma once

#include <elder/runtime/ShaderParameterBridge.hpp>

#include <enbcore/enb/SdkContract.hpp>

#include <cstdint>

namespace elder::runtime {

inline constexpr float kElderRuntimeProtocol = 1.0F;
inline constexpr float kElderRuntimeSchemaTag = 20'260'717.0F;
inline constexpr std::uint64_t kRenderPayloadGenerationModulus = 16'777'216ULL;

struct RenderPayload final {
  RuntimeFloat4 room_light{};
  RuntimeFloat4 exposure_color{};
  RuntimeFloat4 status{};
};

[[nodiscard]] float FoldRenderPayloadGeneration(std::uint64_t generation) noexcept;
[[nodiscard]] RenderPayload MakeRenderPayload(
    RuntimeFloat4 room_light,
    RuntimeFloat4 exposure_color,
    std::uint64_t generation) noexcept;

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
