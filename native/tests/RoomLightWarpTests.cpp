// WARP numeric-parity test for the Elder room-light model. The GPU probe and
// this harness independently build the same canonical cases; the harness runs
// the CPU reference and asserts field-by-field agreement, bringing the Elder
// room-light slice to the same CPU/HLSL-parity standard as its color core (and
// as Truth's interior-light slice).

#include "elder/shaders/InteriorLight.hpp"

#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <string>

#include <d3d11.h>
#include <d3dcompiler.h>
#include <wrl/client.h>

using Microsoft::WRL::ComPtr;
using elder::shaders::EvaluateRoomLight;
using elder::shaders::RoomAperture;
using elder::shaders::RoomLightInput;
using elder::shaders::RoomLightOutput;
using elder::shaders::RoomLightStatus;

namespace {

int failures = 0;

void expect(const bool condition, const std::string& message)
{
  if (!condition) {
    std::cerr << "expectation failed: " << message << '\n';
    ++failures;
  }
}

[[noreturn]] void fail(const std::string& message)
{
  std::cerr << "fatal: " << message << '\n';
  std::exit(2);
}

void check_hr(const HRESULT hr, const char* what)
{
  if (FAILED(hr)) {
    fail(std::string(what) + " failed");
  }
}

constexpr std::uint32_t kCaseCount = 5U;

struct Float4 {
  float x;
  float y;
  float z;
  float w;
};

// Mirror of the shader's ElderRoomLightCase.
[[nodiscard]] RoomLightInput cpu_case(const std::uint32_t index)
{
  RoomLightInput input{};
  input.exterior_sky_luminance = 100.0F;
  input.ambient_floor = 2.0F;
  input.occlusion = 0.0F;
  input.aperture_count = 1U;
  input.apertures[0] = RoomAperture{1.0F, 1.0F};

  if (index == 1U) {
    input.aperture_count = 0U;
  } else if (index == 2U) {
    input.occlusion = 1.0F;
  } else if (index == 3U) {
    input.ambient_floor = 1.0F;
    input.occlusion = 0.25F;
    input.apertures[0] = RoomAperture{0.5F, 0.8F};
  } else if (index == 4U) {
    input.exterior_sky_luminance = 50.0F;
    input.ambient_floor = 0.0F;
    input.aperture_count = 2U;
    input.apertures[0] = RoomAperture{1.0F, 1.0F};
    input.apertures[1] = RoomAperture{1.0F, 1.0F};
  }

  return input;
}

[[nodiscard]] ComPtr<ID3DBlob> compile_probe(const wchar_t* path)
{
  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3DBlob> diagnostics;
  const HRESULT hr = D3DCompileFromFile(
      path, nullptr, D3D_COMPILE_STANDARD_FILE_INCLUDE,
      "ElderRoomLightWarpProbeMain", "cs_5_0",
      D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_OPTIMIZATION_LEVEL3, 0U,
      &bytecode, &diagnostics);
  if (FAILED(hr)) {
    std::string message = "D3DCompileFromFile(room-light probe) failed";
    if (diagnostics) {
      message += ": ";
      message.append(static_cast<const char*>(diagnostics->GetBufferPointer()),
                     diagnostics->GetBufferSize());
    }
    fail(message);
  }
  return bytecode;
}

std::array<Float4, kCaseCount> run_gpu(const wchar_t* probe_path)
{
  constexpr std::array<D3D_FEATURE_LEVEL, 2> levels{
      D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0};
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
  D3D_FEATURE_LEVEL selected{};
  HRESULT hr = D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_WARP, nullptr, D3D11_CREATE_DEVICE_SINGLETHREADED,
      levels.data(), static_cast<UINT>(levels.size()), D3D11_SDK_VERSION,
      &device, &selected, &context);
  if (hr == E_INVALIDARG) {
    hr = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_WARP, nullptr, D3D11_CREATE_DEVICE_SINGLETHREADED,
        levels.data() + 1, 1U, D3D11_SDK_VERSION, &device, &selected, &context);
  }
  check_hr(hr, "D3D11CreateDevice(WARP)");

  const ComPtr<ID3DBlob> bytecode = compile_probe(probe_path);
  ComPtr<ID3D11ComputeShader> shader;
  check_hr(device->CreateComputeShader(bytecode->GetBufferPointer(),
                                       bytecode->GetBufferSize(), nullptr, &shader),
           "CreateComputeShader");

  D3D11_BUFFER_DESC output_desc{};
  output_desc.ByteWidth = sizeof(Float4) * kCaseCount;
  output_desc.Usage = D3D11_USAGE_DEFAULT;
  output_desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS;
  output_desc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
  output_desc.StructureByteStride = sizeof(Float4);
  ComPtr<ID3D11Buffer> output;
  check_hr(device->CreateBuffer(&output_desc, nullptr, &output), "CreateBuffer(output)");

  D3D11_UNORDERED_ACCESS_VIEW_DESC view_desc{};
  view_desc.Format = DXGI_FORMAT_UNKNOWN;
  view_desc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
  view_desc.Buffer.NumElements = kCaseCount;
  ComPtr<ID3D11UnorderedAccessView> output_view;
  check_hr(device->CreateUnorderedAccessView(output.Get(), &view_desc, &output_view),
           "CreateUnorderedAccessView(output)");

  D3D11_BUFFER_DESC staging_desc{};
  staging_desc.ByteWidth = sizeof(Float4) * kCaseCount;
  staging_desc.Usage = D3D11_USAGE_STAGING;
  staging_desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  ComPtr<ID3D11Buffer> staging;
  check_hr(device->CreateBuffer(&staging_desc, nullptr, &staging), "CreateBuffer(staging)");

  ID3D11UnorderedAccessView* output_pointer = output_view.Get();
  context->CSSetShader(shader.Get(), nullptr, 0U);
  context->CSSetUnorderedAccessViews(0U, 1U, &output_pointer, nullptr);
  context->Dispatch(1U, 1U, 1U);

  ID3D11UnorderedAccessView* null_view = nullptr;
  context->CSSetUnorderedAccessViews(0U, 1U, &null_view, nullptr);
  context->CSSetShader(nullptr, nullptr, 0U);
  context->CopyResource(staging.Get(), output.Get());

  D3D11_MAPPED_SUBRESOURCE mapped{};
  check_hr(context->Map(staging.Get(), 0U, D3D11_MAP_READ, 0U, &mapped), "Map(staging)");
  std::array<Float4, kCaseCount> results{};
  std::memcpy(results.data(), mapped.pData, sizeof(results));
  context->Unmap(staging.Get(), 0U);
  return results;
}

[[nodiscard]] bool near_value(const float a, const float b)
{
  return std::fabs(a - b) <= 1.0e-4F;
}

}  // namespace

int main(int argc, char** argv)
{
  if (argc < 2) {
    fail("usage: elder_native_room_light_warp_tests <probe.hlsl>");
  }

  const std::string narrow_path = argv[1];
  const std::wstring probe_path(narrow_path.begin(), narrow_path.end());

  const std::array<Float4, kCaseCount> gpu = run_gpu(probe_path.c_str());

  for (std::uint32_t index = 0U; index < kCaseCount; ++index) {
    RoomLightOutput cpu{};
    const auto result = EvaluateRoomLight(cpu, cpu_case(index));
    expect(result.status == RoomLightStatus::evaluated,
           "case " + std::to_string(index) + " evaluated");

    const Float4& g = gpu[index];
    const std::string tag = "case " + std::to_string(index) + ": ";
    expect(near_value(g.x, cpu.room_light), tag + "room_light parity");
    expect(near_value(g.y, cpu.exterior_daylight), tag + "exterior_daylight parity");
    expect(near_value(g.z, cpu.open_fraction), tag + "open_fraction parity");
    expect(near_value(g.w, cpu.daylight_sealed ? 1.0F : 0.0F), tag + "daylight_sealed parity");
  }

  if (failures != 0) {
    std::cerr << failures << " assertion(s) failed\n";
    return 1;
  }

  std::cout << "Elder room-light WARP parity: " << kCaseCount << " cases matched CPU\n";
  return 0;
}
