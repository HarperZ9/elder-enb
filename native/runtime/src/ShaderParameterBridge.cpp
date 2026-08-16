#include "elder/runtime/ShaderParameterBridge.hpp"

#include <cstring>
#include <cmath>

namespace elder::runtime {
namespace {

[[nodiscard]] char* sdk_string(const std::string_view value) noexcept
{
  return const_cast<char*>(value.data());
}

}  // namespace

enbcore::enb::Parameter EncodeColor4Parameter(const RuntimeFloat4& value) noexcept
{
  enbcore::enb::Parameter parameter{};
  parameter.type = enbcore::enb::ParameterKind::Color4;
  parameter.size = static_cast<std::uint32_t>(enbcore::enb::kParameterPayloadBytes);
  static_assert(sizeof(float) * 4U == enbcore::enb::kParameterPayloadBytes);
  std::memcpy(parameter.data.data(), value.data(), parameter.size);
  return parameter;
}

RuntimeFloat4 DecodeColor4Parameter(const enbcore::enb::Parameter& parameter) noexcept
{
  RuntimeFloat4 value{};
  if (parameter.size >= enbcore::enb::kParameterPayloadBytes) {
    std::memcpy(value.data(), parameter.data.data(), value.size() * sizeof(float));
  }
  return value;
}

bool IsFiniteFloat4(const RuntimeFloat4& value) noexcept
{
  return std::isfinite(value[0]) && std::isfinite(value[1])
      && std::isfinite(value[2]) && std::isfinite(value[3]);
}

bool IsColor4Parameter(const enbcore::enb::Parameter& parameter) noexcept
{
  return parameter.type == enbcore::enb::ParameterKind::Color4
      && parameter.size == enbcore::enb::kParameterPayloadBytes;
}

ShaderParameterBridge::ShaderParameterBridge(
    const enbcore::enb::GetParameter get_parameter,
    const enbcore::enb::SetParameter set_parameter) noexcept
    : get_parameter_(get_parameter), set_parameter_(set_parameter)
{
}

bool ShaderParameterBridge::available() const noexcept
{
  return get_parameter_ != nullptr && set_parameter_ != nullptr;
}

ShaderParameterBridgeResult ShaderParameterBridge::getColor4(
    const std::string_view shader,
    const std::string_view symbol,
    RuntimeFloat4& value) const noexcept
{
  if (!available()) {
    return {ShaderParameterBridgeCode::bridge_unavailable};
  }

  enbcore::enb::Parameter parameter{};
  if (get_parameter_(nullptr, sdk_string(shader), sdk_string(symbol), &parameter) == 0) {
    return {ShaderParameterBridgeCode::missing_parameter};
  }
  if (!IsColor4Parameter(parameter)) {
    return {ShaderParameterBridgeCode::invalid_parameter};
  }

  const RuntimeFloat4 decoded = DecodeColor4Parameter(parameter);
  if (!IsFiniteFloat4(decoded)) {
    return {ShaderParameterBridgeCode::invalid_parameter};
  }
  value = decoded;
  return {ShaderParameterBridgeCode::ok};
}

ShaderParameterBridgeResult ShaderParameterBridge::setColor4(
    const std::string_view shader,
    const std::string_view symbol,
    const RuntimeFloat4& value) const noexcept
{
  if (!available()) {
    return {ShaderParameterBridgeCode::bridge_unavailable};
  }
  if (!IsFiniteFloat4(value)) {
    return {ShaderParameterBridgeCode::invalid_parameter};
  }

  enbcore::enb::Parameter parameter = EncodeColor4Parameter(value);
  if (set_parameter_(nullptr, sdk_string(shader), sdk_string(symbol), &parameter) == 0) {
    return {ShaderParameterBridgeCode::write_failed};
  }
  return {ShaderParameterBridgeCode::ok};
}

}  // namespace elder::runtime
