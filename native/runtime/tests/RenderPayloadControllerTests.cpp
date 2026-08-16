#include "elder/runtime/RenderPayloadController.hpp"
#include "elder/runtime/ShaderParameterBridge.hpp"

#include <enbcore/enb/SdkContract.hpp>

#include <array>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <limits>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

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

using elder::runtime::DecodeColor4Parameter;
using elder::runtime::EncodeColor4Parameter;
using elder::runtime::FoldRenderPayloadGeneration;
using elder::runtime::MakeRenderPayload;
using elder::runtime::NeutralExposureColorPayload;
using elder::runtime::NeutralRoomLightPayload;
using elder::runtime::PublicBridgeRoomLightSource;
using elder::runtime::PublicBridgeRoomLightSourceResult;
using elder::runtime::RenderPayload;
using elder::runtime::RenderPayloadController;
using elder::runtime::RenderPayloadPhase;
using elder::runtime::RenderPayloadResultCode;
using elder::runtime::ShaderParameterBridge;
using elder::runtime::kElderRenderPayloadShader;
using elder::runtime::kElderRuntimeExposureColorSymbol;
using elder::runtime::kElderRuntimeProtocol;
using elder::runtime::kElderRuntimeRoomLightSymbol;
using elder::runtime::kElderRuntimeSchemaTag;
using elder::runtime::kElderRuntimeStatusSymbol;
using elder::runtime::kSkyrimBridgeInteriorAmbientSymbol;
using elder::runtime::kSkyrimBridgeInteriorDirColorSymbol;
using elder::runtime::kSkyrimBridgeInteriorFlagsSymbol;
using elder::runtime::kSkyrimBridgeRenderFrameSymbol;
using enbcore::enb::CallbackId;
using enbcore::enb::Parameter;
using enbcore::enb::SdkBoolean;

using Float4 = std::array<float, 4>;

[[nodiscard]] bool same_bits(const float lhs, const float rhs)
{
  return std::bit_cast<std::uint32_t>(lhs) == std::bit_cast<std::uint32_t>(rhs);
}

[[nodiscard]] bool same_float4_bits(const Float4& lhs, const Float4& rhs)
{
  for (std::size_t index = 0U; index < lhs.size(); ++index) {
    if (!same_bits(lhs[index], rhs[index])) {
      return false;
    }
  }
  return true;
}

struct Operation final {
  enum class Kind {
    get,
    set,
  };

  Kind kind{Kind::get};
  std::string shader;
  std::string symbol;
  Float4 value{};
};

struct FakeHost final {
  std::unordered_map<std::string, Parameter> parameters;
  std::vector<Operation> operations;
  std::uint32_t get_calls{0U};
  std::uint32_t set_calls{0U};
  std::uint32_t fail_set_call{0U};

  void put(const std::string_view symbol, const Float4& value)
  {
    parameters[std::string{symbol}] = EncodeColor4Parameter(value);
  }

  [[nodiscard]] Float4 read(const std::string_view symbol) const
  {
    const auto found = parameters.find(std::string{symbol});
    if (found == parameters.end()) {
      return {};
    }
    return DecodeColor4Parameter(found->second);
  }

  [[nodiscard]] std::uint32_t set_count() const
  {
    std::uint32_t count = 0U;
    for (const Operation& operation : operations) {
      if (operation.kind == Operation::Kind::set) {
        ++count;
      }
    }
    return count;
  }
};

FakeHost* active_host = nullptr;

[[nodiscard]] std::string from_sdk_string(char* const value)
{
  return value == nullptr ? std::string{} : std::string{value};
}

SdkBoolean fake_get_parameter(char*,
                              char* const shader,
                              char* const symbol,
                              Parameter* const parameter)
{
  ++active_host->get_calls;
  const std::string symbol_text = from_sdk_string(symbol);
  const auto found = active_host->parameters.find(symbol_text);
  if (found == active_host->parameters.end() || parameter == nullptr) {
    active_host->operations.push_back(
        Operation{Operation::Kind::get, from_sdk_string(shader), symbol_text, {}});
    return 0;
  }

  *parameter = found->second;
  active_host->operations.push_back(Operation{
      Operation::Kind::get,
      from_sdk_string(shader),
      symbol_text,
      DecodeColor4Parameter(*parameter)});
  return 1;
}

SdkBoolean fake_set_parameter(char*,
                              char* const shader,
                              char* const symbol,
                              Parameter* const parameter)
{
  ++active_host->set_calls;
  const std::string symbol_text = from_sdk_string(symbol);
  const Float4 value = parameter == nullptr ? Float4{} : DecodeColor4Parameter(*parameter);
  active_host->operations.push_back(
      Operation{Operation::Kind::set, from_sdk_string(shader), symbol_text, value});

  if (active_host->fail_set_call != 0U
      && active_host->set_calls == active_host->fail_set_call) {
    return 0;
  }

  if (parameter == nullptr) {
    return 0;
  }
  active_host->parameters[symbol_text] = *parameter;
  return 1;
}

[[nodiscard]] ShaderParameterBridge fake_bridge()
{
  return ShaderParameterBridge{&fake_get_parameter, &fake_set_parameter};
}

[[nodiscard]] FakeHost host_with_baselines()
{
  FakeHost host;
  host.put(kElderRuntimeRoomLightSymbol, Float4{9.0F, 8.0F, 0.75F, 1.0F});
  host.put(kElderRuntimeExposureColorSymbol, Float4{0.5F, 0.6F, 0.7F, 0.8F});
  host.put(kElderRuntimeStatusSymbol, Float4{0.0F, 0.0F, 0.0F, 0.0F});
  return host;
}

[[nodiscard]] RenderPayload live_payload()
{
  return MakeRenderPayload(
      Float4{2.0F, 1.0F, 0.25F, 0.0F},
      Float4{1.1F, 1.2F, 1.3F, 1.0F},
      42U);
}

void symbols_match_the_hidden_shader_contract()
{
  EXPECT(kElderRenderPayloadShader == std::string_view{"ENBEFFECTPREPASS.FX"});
  EXPECT(kElderRuntimeRoomLightSymbol == std::string_view{"ElderRuntimeRoomLight"});
  EXPECT(kElderRuntimeExposureColorSymbol == std::string_view{"ElderRuntimeExposureColor"});
  EXPECT(kElderRuntimeStatusSymbol == std::string_view{"ElderRuntimeStatus"});
  EXPECT(kSkyrimBridgeRenderFrameSymbol == std::string_view{"SB_Render_Frame"});
  EXPECT(kSkyrimBridgeInteriorFlagsSymbol == std::string_view{"SB_Interior_Flags"});
  EXPECT(kSkyrimBridgeInteriorAmbientSymbol == std::string_view{"SB_Interior_Ambient"});
  EXPECT(kSkyrimBridgeInteriorDirColorSymbol == std::string_view{"SB_Interior_DirColor"});
}

void payload_status_uses_protocol_valid_generation_and_schema_tag()
{
  const RenderPayload payload = MakeRenderPayload(
      Float4{1.0F, 0.0F, 0.0F, 1.0F},
      Float4{1.0F, 1.0F, 1.0F, 1.0F},
      16'777'216ULL + 7ULL);

  EXPECT(same_bits(payload.status[0], kElderRuntimeProtocol));
  EXPECT(same_bits(payload.status[1], 1.0F));
  EXPECT(same_bits(payload.status[2], FoldRenderPayloadGeneration(16'777'216ULL + 7ULL)));
  EXPECT(same_bits(payload.status[3], kElderRuntimeSchemaTag));
}

void status_exactness_rejects_noncanonical_validity_and_generation()
{
  std::array<RenderPayload, 4> invalid_payloads{
      live_payload(),
      live_payload(),
      live_payload(),
      live_payload(),
  };
  invalid_payloads[0].status[1] = 2.0F;
  invalid_payloads[1].status[2] = 42.5F;
  invalid_payloads[2].status[2] = -1.0F;
  invalid_payloads[3].status[2] = 33'554'432.0F;

  for (const RenderPayload& payload : invalid_payloads) {
    FakeHost host = host_with_baselines();
    active_host = &host;
    RenderPayloadController controller{fake_bridge()};

    const auto result = controller.publish(payload);

    EXPECT(result.code == RenderPayloadResultCode::invalid_payload);
    EXPECT(host.get_calls == 0U);
    EXPECT(host.set_calls == 0U);
  }
}

void public_bridge_source_derives_bounded_room_light_from_current_interior_scalars()
{
  FakeHost host = host_with_baselines();
  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{120.0F, 0.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorAmbientSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  active_host = &host;

  PublicBridgeRoomLightSource source{fake_bridge()};
  const PublicBridgeRoomLightSourceResult result = source.readRoomLight();

  EXPECT(result.used_public_bridge);
  EXPECT(std::fabs(result.room_light[0] - 1.25F) <= 1.0e-5F);
  EXPECT(std::fabs(result.room_light[1] - 0.25F) <= 1.0e-5F);
  EXPECT(std::fabs(result.room_light[2] - 0.2F) <= 1.0e-5F);
  EXPECT(same_bits(result.room_light[3], 0.0F));
}

void public_bridge_source_falls_back_to_neutral_when_absent_stale_or_nonfinite()
{
  {
    FakeHost host = host_with_baselines();
    host.put(kSkyrimBridgeRenderFrameSymbol, Float4{120.0F, 0.0F, 0.0F, 0.0F});
    host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
    host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
    active_host = &host;

    PublicBridgeRoomLightSource source{fake_bridge()};
    const PublicBridgeRoomLightSourceResult result = source.readRoomLight();

    EXPECT(!result.used_public_bridge);
    EXPECT(same_float4_bits(result.room_light, NeutralRoomLightPayload()));
  }

  {
    FakeHost host = host_with_baselines();
    host.put(kSkyrimBridgeRenderFrameSymbol, Float4{120.0F, 0.0F, 0.0F, 0.0F});
    host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
    host.put(kSkyrimBridgeInteriorAmbientSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
    host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
    active_host = &host;

    PublicBridgeRoomLightSource source{fake_bridge()};
    EXPECT(source.readRoomLight().used_public_bridge);
    const PublicBridgeRoomLightSourceResult stale = source.readRoomLight();

    EXPECT(!stale.used_public_bridge);
    EXPECT(same_float4_bits(stale.room_light, NeutralRoomLightPayload()));
  }

  {
    FakeHost host = host_with_baselines();
    host.put(kSkyrimBridgeRenderFrameSymbol, Float4{121.0F, 0.0F, 0.0F, 0.0F});
    host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
    host.put(kSkyrimBridgeInteriorAmbientSymbol,
             Float4{std::numeric_limits<float>::quiet_NaN(), 1.0F, 1.0F, 0.0F});
    host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
    active_host = &host;

    PublicBridgeRoomLightSource source{fake_bridge()};
    const PublicBridgeRoomLightSourceResult result = source.readRoomLight();

    EXPECT(!result.used_public_bridge);
    EXPECT(same_float4_bits(result.room_light, NeutralRoomLightPayload()));
  }
}

void public_bridge_source_rejects_malformed_flag_bit_patterns()
{
  FakeHost host = host_with_baselines();
  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{122.0F, 0.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorFlagsSymbol,
           Float4{std::bit_cast<float>(1U), 1.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorAmbientSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  active_host = &host;

  PublicBridgeRoomLightSource source{fake_bridge()};
  const PublicBridgeRoomLightSourceResult result = source.readRoomLight();

  EXPECT(!result.used_public_bridge);
  EXPECT(same_float4_bits(result.room_light, NeutralRoomLightPayload()));
}

void public_bridge_source_accepts_representable_progression_above_folded_generation_range()
{
  FakeHost host = host_with_baselines();
  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{16'777'216.0F, 0.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorAmbientSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  active_host = &host;

  PublicBridgeRoomLightSource source{fake_bridge()};
  EXPECT(source.readRoomLight().used_public_bridge);

  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{16'777'218.0F, 0.0F, 0.0F, 0.0F});
  const PublicBridgeRoomLightSourceResult progressed = source.readRoomLight();

  EXPECT(progressed.used_public_bridge);
  EXPECT(!same_float4_bits(progressed.room_light, NeutralRoomLightPayload()));
}

void public_bridge_source_rejects_same_frame_as_stale()
{
  FakeHost host = host_with_baselines();
  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{240.0F, 0.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorAmbientSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  active_host = &host;

  PublicBridgeRoomLightSource source{fake_bridge()};
  EXPECT(source.readRoomLight().used_public_bridge);
  const PublicBridgeRoomLightSourceResult stale = source.readRoomLight();

  EXPECT(!stale.used_public_bridge);
  EXPECT(same_float4_bits(stale.room_light, NeutralRoomLightPayload()));
}

void public_bridge_source_rejects_arbitrary_backward_frame_jumps()
{
  FakeHost host = host_with_baselines();
  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{2000.0F, 0.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorAmbientSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  active_host = &host;

  PublicBridgeRoomLightSource source{fake_bridge()};
  EXPECT(source.readRoomLight().used_public_bridge);

  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{1998.0F, 0.0F, 0.0F, 0.0F});
  const PublicBridgeRoomLightSourceResult rollback = source.readRoomLight();

  EXPECT(!rollback.used_public_bridge);
  EXPECT(same_float4_bits(rollback.room_light, NeutralRoomLightPayload()));
}

void public_bridge_source_accepts_uint32_wrap_to_small_positive_frame()
{
  FakeHost host = host_with_baselines();
  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{4'294'967'040.0F, 0.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorAmbientSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  active_host = &host;

  PublicBridgeRoomLightSource source{fake_bridge()};
  EXPECT(source.readRoomLight().used_public_bridge);

  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{4.0F, 0.0F, 0.0F, 0.0F});
  const PublicBridgeRoomLightSourceResult wrapped = source.readRoomLight();

  EXPECT(wrapped.used_public_bridge);
  EXPECT(!same_float4_bits(wrapped.room_light, NeutralRoomLightPayload()));
}

void controller_publish_uses_public_bridge_source_when_available()
{
  FakeHost host = host_with_baselines();
  host.put(kSkyrimBridgeRenderFrameSymbol, Float4{123.0F, 0.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorFlagsSymbol, Float4{1.0F, 1.0F, 0.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorAmbientSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  host.put(kSkyrimBridgeInteriorDirColorSymbol, Float4{1.0F, 1.0F, 1.0F, 0.0F});
  active_host = &host;

  PublicBridgeRoomLightSource source{fake_bridge()};
  RenderPayloadController controller{fake_bridge()};
  const PublicBridgeRoomLightSourceResult bridge_room = source.readRoomLight();
  const auto result = controller.publish(
      MakeRenderPayload(bridge_room.room_light, NeutralExposureColorPayload(), 50U));

  EXPECT(bridge_room.used_public_bridge);
  EXPECT(result.code == RenderPayloadResultCode::published);
  EXPECT(std::fabs(host.read(kElderRuntimeRoomLightSymbol)[0] - 1.25F) <= 1.0e-5F);
  EXPECT(same_float4_bits(host.read(kElderRuntimeExposureColorSymbol),
                          NeutralExposureColorPayload()));
}

void publish_captures_baselines_then_invalidates_writes_payload_and_validates_last()
{
  FakeHost host = host_with_baselines();
  active_host = &host;
  RenderPayloadController controller{fake_bridge()};
  const RenderPayload payload = live_payload();

  const auto result = controller.publish(payload);

  EXPECT(result.code == RenderPayloadResultCode::published);
  EXPECT(result.phase == RenderPayloadPhase::none);
  EXPECT(host.operations.size() == 7U);

  EXPECT(host.operations[0].kind == Operation::Kind::get);
  EXPECT(host.operations[0].symbol == kElderRuntimeRoomLightSymbol);
  EXPECT(host.operations[1].kind == Operation::Kind::get);
  EXPECT(host.operations[1].symbol == kElderRuntimeExposureColorSymbol);
  EXPECT(host.operations[2].kind == Operation::Kind::get);
  EXPECT(host.operations[2].symbol == kElderRuntimeStatusSymbol);

  const Float4 invalid_status{
      payload.status[0], 0.0F, payload.status[2], payload.status[3]};
  EXPECT(host.operations[3].kind == Operation::Kind::set);
  EXPECT(host.operations[3].symbol == kElderRuntimeStatusSymbol);
  EXPECT(same_float4_bits(host.operations[3].value, invalid_status));

  EXPECT(host.operations[4].kind == Operation::Kind::set);
  EXPECT(host.operations[4].symbol == kElderRuntimeRoomLightSymbol);
  EXPECT(same_float4_bits(host.operations[4].value, payload.room_light));

  EXPECT(host.operations[5].kind == Operation::Kind::set);
  EXPECT(host.operations[5].symbol == kElderRuntimeExposureColorSymbol);
  EXPECT(same_float4_bits(host.operations[5].value, payload.exposure_color));

  EXPECT(host.operations[6].kind == Operation::Kind::set);
  EXPECT(host.operations[6].symbol == kElderRuntimeStatusSymbol);
  EXPECT(same_float4_bits(host.operations[6].value, payload.status));

  EXPECT(same_float4_bits(host.read(kElderRuntimeRoomLightSymbol), payload.room_light));
  EXPECT(same_float4_bits(host.read(kElderRuntimeExposureColorSymbol), payload.exposure_color));
  EXPECT(same_float4_bits(host.read(kElderRuntimeStatusSymbol), payload.status));
}

void every_primary_write_failure_rolls_back_to_authored_baselines()
{
  const Float4 baseline_room{9.0F, 8.0F, 0.75F, 1.0F};
  const Float4 baseline_exposure{0.5F, 0.6F, 0.7F, 0.8F};
  const Float4 baseline_status{0.0F, 0.0F, 0.0F, 0.0F};

  for (std::uint32_t failed_set = 1U; failed_set <= 4U; ++failed_set) {
    FakeHost host = host_with_baselines();
    host.fail_set_call = failed_set;
    active_host = &host;

    RenderPayloadController controller{fake_bridge()};
    const auto result = controller.publish(live_payload());

    EXPECT(result.code == RenderPayloadResultCode::write_failed);
    EXPECT(host.set_count() > failed_set);
    EXPECT(same_float4_bits(host.read(kElderRuntimeRoomLightSymbol), baseline_room));
    EXPECT(same_float4_bits(host.read(kElderRuntimeExposureColorSymbol), baseline_exposure));
    EXPECT(same_float4_bits(host.read(kElderRuntimeStatusSymbol), baseline_status));
  }
}

void lifecycle_save_reset_and_exit_restore_the_authored_baseline()
{
  constexpr std::array lifecycle_callbacks{
      CallbackId::PreSave,
      CallbackId::PreReset,
      CallbackId::OnExit,
  };
  const Float4 baseline_room{9.0F, 8.0F, 0.75F, 1.0F};
  const Float4 baseline_exposure{0.5F, 0.6F, 0.7F, 0.8F};
  const Float4 baseline_status{0.0F, 0.0F, 0.0F, 0.0F};

  FakeHost host = host_with_baselines();
  active_host = &host;
  RenderPayloadController controller{fake_bridge()};

  for (const CallbackId callback : lifecycle_callbacks) {
    EXPECT(controller.publish(live_payload()).code == RenderPayloadResultCode::published);
    const auto restored = controller.handleLifecycle(callback);
    EXPECT(restored.code == RenderPayloadResultCode::baseline_restored);
    EXPECT(same_float4_bits(host.read(kElderRuntimeRoomLightSymbol), baseline_room));
    EXPECT(same_float4_bits(host.read(kElderRuntimeExposureColorSymbol), baseline_exposure));
    EXPECT(same_float4_bits(host.read(kElderRuntimeStatusSymbol), baseline_status));
  }
}

void missing_key_fails_before_any_runtime_write()
{
  FakeHost host = host_with_baselines();
  host.parameters.erase(std::string{kElderRuntimeExposureColorSymbol});
  active_host = &host;
  RenderPayloadController controller{fake_bridge()};

  const auto result = controller.publish(live_payload());

  EXPECT(result.code == RenderPayloadResultCode::missing_parameter);
  EXPECT(result.phase == RenderPayloadPhase::capture_exposure_color);
  EXPECT(host.set_calls == 0U);
}

void nonfinite_payload_values_are_rejected_before_baseline_capture()
{
  constexpr float nan = std::numeric_limits<float>::quiet_NaN();
  constexpr float infinity = std::numeric_limits<float>::infinity();

  std::array<RenderPayload, 3> invalid_payloads{
      live_payload(),
      live_payload(),
      live_payload(),
  };
  invalid_payloads[0].room_light[0] = nan;
  invalid_payloads[1].exposure_color[1] = infinity;
  invalid_payloads[2].status[2] = nan;

  for (const RenderPayload& payload : invalid_payloads) {
    FakeHost host = host_with_baselines();
    active_host = &host;
    RenderPayloadController controller{fake_bridge()};

    const auto result = controller.publish(payload);

    EXPECT(result.code == RenderPayloadResultCode::invalid_payload);
    EXPECT(host.get_calls == 0U);
    EXPECT(host.set_calls == 0U);
  }
}

}  // namespace

int main()
{
  symbols_match_the_hidden_shader_contract();
  payload_status_uses_protocol_valid_generation_and_schema_tag();
  status_exactness_rejects_noncanonical_validity_and_generation();
  public_bridge_source_derives_bounded_room_light_from_current_interior_scalars();
  public_bridge_source_falls_back_to_neutral_when_absent_stale_or_nonfinite();
  public_bridge_source_rejects_malformed_flag_bit_patterns();
  public_bridge_source_accepts_representable_progression_above_folded_generation_range();
  public_bridge_source_rejects_same_frame_as_stale();
  public_bridge_source_rejects_arbitrary_backward_frame_jumps();
  public_bridge_source_accepts_uint32_wrap_to_small_positive_frame();
  controller_publish_uses_public_bridge_source_when_available();
  publish_captures_baselines_then_invalidates_writes_payload_and_validates_last();
  every_primary_write_failure_rolls_back_to_authored_baselines();
  lifecycle_save_reset_and_exit_restore_the_authored_baseline();
  missing_key_fails_before_any_runtime_write();
  nonfinite_payload_values_are_rejected_before_baseline_capture();

  if (failures != 0) {
    std::cerr << failures << " render-payload controller assertion(s) failed\n";
    return 1;
  }

  std::cout << "PASS: Elder render-payload controller\n";
  return 0;
}
