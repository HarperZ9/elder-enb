#include "elder/runtime/RenderPayloadController.hpp"

#include <cmath>

namespace elder::runtime {
namespace {

[[nodiscard]] bool integer_exact(const float value) noexcept
{
  return std::nearbyint(value) == value;
}

[[nodiscard]] bool room_light_valid(const RuntimeFloat4& value) noexcept
{
  return IsFiniteFloat4(value)
      && value[0] >= 0.0F
      && value[0] <= 1'000'000.0F
      && value[1] >= 0.0F
      && value[1] <= value[0]
      && value[2] >= 0.0F
      && value[2] <= 1.0F
      && value[3] >= 0.0F
      && value[3] <= 1.0F;
}

[[nodiscard]] bool exposure_color_valid(const RuntimeFloat4& value) noexcept
{
  return IsFiniteFloat4(value)
      && value[0] >= 0.0F
      && value[0] <= 64.0F
      && value[1] >= 0.0F
      && value[1] <= 64.0F
      && value[2] >= 0.0F
      && value[2] <= 64.0F
      && value[3] >= 0.0F
      && value[3] <= 64.0F;
}

[[nodiscard]] bool status_valid(const RuntimeFloat4& value) noexcept
{
  return IsFiniteFloat4(value)
      && value[0] == kElderRuntimeProtocol
      && value[1] == 1.0F
      && value[2] >= 0.0F
      && value[2] <= static_cast<float>(kRenderPayloadGenerationModulus)
      && integer_exact(value[2])
      && value[3] == kElderRuntimeSchemaTag;
}

[[nodiscard]] bool payload_valid(const RenderPayload& payload) noexcept
{
  return room_light_valid(payload.room_light)
      && exposure_color_valid(payload.exposure_color)
      && status_valid(payload.status);
}

[[nodiscard]] RuntimeFloat4 invalid_status_from(const RuntimeFloat4& status) noexcept
{
  RuntimeFloat4 invalid = status;
  invalid[1] = 0.0F;
  return invalid;
}

[[nodiscard]] RenderPayloadResult missing_or_unavailable(
    const ShaderParameterBridgeResult result,
    const RenderPayloadPhase phase) noexcept
{
  if (result.code == ShaderParameterBridgeCode::bridge_unavailable) {
    return {RenderPayloadResultCode::bridge_unavailable, phase};
  }
  return {RenderPayloadResultCode::missing_parameter, phase};
}

}  // namespace

float FoldRenderPayloadGeneration(const std::uint64_t generation) noexcept
{
  if (generation == 0U) {
    return 0.0F;
  }

  const std::uint64_t folded =
      ((generation - 1U) % kRenderPayloadGenerationModulus) + 1U;
  return static_cast<float>(folded);
}

RenderPayload MakeRenderPayload(const RuntimeFloat4 room_light,
                                const RuntimeFloat4 exposure_color,
                                const std::uint64_t generation) noexcept
{
  return RenderPayload{
      room_light,
      exposure_color,
      RuntimeFloat4{
          kElderRuntimeProtocol,
          1.0F,
          FoldRenderPayloadGeneration(generation),
          kElderRuntimeSchemaTag,
      },
  };
}

RenderPayloadController::RenderPayloadController(
    const ShaderParameterBridge bridge) noexcept
    : bridge_(bridge)
{
}

void RenderPayloadController::bind(const ShaderParameterBridge bridge) noexcept
{
  bridge_ = bridge;
  baseline_ = {};
  baseline_captured_ = false;
}

bool RenderPayloadController::ready() const noexcept
{
  return bridge_.available();
}

RenderPayloadResult RenderPayloadController::publish(
    const RenderPayload& payload) noexcept
{
  if (!payload_valid(payload)) {
    return {RenderPayloadResultCode::invalid_payload, RenderPayloadPhase::none};
  }

  if (!baseline_captured_) {
    const RenderPayloadResult captured = captureBaseline();
    if (!captured.ok()) {
      return captured;
    }
  }

  RenderPayloadResult result = write(
      kElderRuntimeStatusSymbol,
      invalid_status_from(payload.status),
      RenderPayloadPhase::invalidate_status);
  if (!result.ok()) {
    return rollbackAfter(RenderPayloadPhase::invalidate_status);
  }

  result = write(
      kElderRuntimeRoomLightSymbol,
      payload.room_light,
      RenderPayloadPhase::write_room_light);
  if (!result.ok()) {
    return rollbackAfter(RenderPayloadPhase::write_room_light);
  }

  result = write(
      kElderRuntimeExposureColorSymbol,
      payload.exposure_color,
      RenderPayloadPhase::write_exposure_color);
  if (!result.ok()) {
    return rollbackAfter(RenderPayloadPhase::write_exposure_color);
  }

  result = write(
      kElderRuntimeStatusSymbol,
      payload.status,
      RenderPayloadPhase::validate_status);
  if (!result.ok()) {
    return rollbackAfter(RenderPayloadPhase::validate_status);
  }

  return {RenderPayloadResultCode::published, RenderPayloadPhase::none};
}

RenderPayloadResult RenderPayloadController::restoreBaseline() noexcept
{
  if (!baseline_captured_) {
    return {RenderPayloadResultCode::no_baseline, RenderPayloadPhase::none};
  }
  return restoreBaselineInternal();
}

RenderPayloadResult RenderPayloadController::handleLifecycle(
    const enbcore::enb::CallbackId callback) noexcept
{
  switch (callback) {
  case enbcore::enb::CallbackId::PreSave:
  case enbcore::enb::CallbackId::PreReset:
  case enbcore::enb::CallbackId::OnExit:
    return restoreBaseline();
  case enbcore::enb::CallbackId::EndFrame:
  case enbcore::enb::CallbackId::BeginFrame:
  case enbcore::enb::CallbackId::PostLoad:
  case enbcore::enb::CallbackId::OnInit:
  case enbcore::enb::CallbackId::PostReset:
    return {RenderPayloadResultCode::no_baseline, RenderPayloadPhase::none};
  }

  return {RenderPayloadResultCode::no_baseline, RenderPayloadPhase::none};
}

RenderPayloadResult RenderPayloadController::captureBaseline() noexcept
{
  RuntimeFloat4 room_light{};
  ShaderParameterBridgeResult result = bridge_.getColor4(
      kElderRenderPayloadShader,
      kElderRuntimeRoomLightSymbol,
      room_light);
  if (!result.ok()) {
    return missing_or_unavailable(result, RenderPayloadPhase::capture_room_light);
  }

  RuntimeFloat4 exposure_color{};
  result = bridge_.getColor4(
      kElderRenderPayloadShader,
      kElderRuntimeExposureColorSymbol,
      exposure_color);
  if (!result.ok()) {
    return missing_or_unavailable(result, RenderPayloadPhase::capture_exposure_color);
  }

  RuntimeFloat4 status{};
  result = bridge_.getColor4(
      kElderRenderPayloadShader,
      kElderRuntimeStatusSymbol,
      status);
  if (!result.ok()) {
    return missing_or_unavailable(result, RenderPayloadPhase::capture_status);
  }

  baseline_ = RenderPayload{room_light, exposure_color, status};
  baseline_captured_ = true;
  return {RenderPayloadResultCode::baseline_restored, RenderPayloadPhase::none};
}

RenderPayloadResult RenderPayloadController::write(
    const std::string_view symbol,
    const RuntimeFloat4& value,
    const RenderPayloadPhase phase) noexcept
{
  const ShaderParameterBridgeResult result =
      bridge_.setColor4(kElderRenderPayloadShader, symbol, value);
  if (result.ok()) {
    return {RenderPayloadResultCode::published, RenderPayloadPhase::none};
  }
  if (result.code == ShaderParameterBridgeCode::bridge_unavailable) {
    return {RenderPayloadResultCode::bridge_unavailable, phase};
  }
  return {RenderPayloadResultCode::write_failed, phase};
}

RenderPayloadResult RenderPayloadController::restoreBaselineInternal() noexcept
{
  RenderPayloadResult result = write(
      kElderRuntimeStatusSymbol,
      invalid_status_from(baseline_.status),
      RenderPayloadPhase::restore_status);
  if (!result.ok()) {
    return result;
  }

  result = write(
      kElderRuntimeRoomLightSymbol,
      baseline_.room_light,
      RenderPayloadPhase::restore_room_light);
  if (!result.ok()) {
    return result;
  }

  result = write(
      kElderRuntimeExposureColorSymbol,
      baseline_.exposure_color,
      RenderPayloadPhase::restore_exposure_color);
  if (!result.ok()) {
    return result;
  }

  result = write(
      kElderRuntimeStatusSymbol,
      baseline_.status,
      RenderPayloadPhase::restore_status);
  if (!result.ok()) {
    return result;
  }

  return {RenderPayloadResultCode::baseline_restored, RenderPayloadPhase::none};
}

RenderPayloadResult RenderPayloadController::rollbackAfter(
    const RenderPayloadPhase failed_phase) noexcept
{
  static_cast<void>(restoreBaselineInternal());
  return {RenderPayloadResultCode::write_failed, failed_phase};
}

}  // namespace elder::runtime
