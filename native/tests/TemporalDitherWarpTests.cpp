// Parity between ElderTemporalDither.fxh and the C++ reference.
//
// The Bayer table and the phase rotation exist in both languages. Duplicated
// constants drift, and a drifted dither would not fail loudly: it would just
// stop cancelling, and the banding would quietly come back. This runs the
// shipped HLSL on a software device and compares it to the reference.

#include "elder/shaders/TemporalDither.hpp"

#include <array>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#include <d3d11.h>
#include <d3dcompiler.h>
#include <wrl/client.h>

namespace {

using Microsoft::WRL::ComPtr;

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

[[noreturn]] void Fail(const std::string& message)
{
  std::cerr << "fatal: " << message << '\n';
  std::exit(2);
}

void CheckHr(const HRESULT hr, const char* what)
{
  if (FAILED(hr)) {
    Fail(std::string{what} + " failed");
  }
}

struct Element {
  float x;
  float y;
  float frame;
  float unused;
};

struct Result {
  float bayer;
  float rotation;
  float offset;
  float dithered;
};

[[nodiscard]] std::vector<Result> RunProbe(const std::filesystem::path& probe,
                                           const std::vector<Element>& inputs)
{
  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3DBlob> errors;
  const HRESULT compiled = D3DCompileFromFile(
      probe.c_str(), nullptr, D3D_COMPILE_STANDARD_FILE_INCLUDE,
      "ElderTemporalDitherWarpProbeMain", "cs_5_0",
      D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_WARNINGS_ARE_ERRORS
          | D3DCOMPILE_IEEE_STRICTNESS | D3DCOMPILE_OPTIMIZATION_LEVEL3,
      0U, &bytecode, &errors);
  if (FAILED(compiled)) {
    std::string diagnostic = "probe compilation failed";
    if (errors && errors->GetBufferSize() != 0U) {
      diagnostic += ":\n";
      diagnostic.append(static_cast<const char*>(errors->GetBufferPointer()),
                        errors->GetBufferSize());
    }
    Fail(diagnostic);
  }

  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
  constexpr std::array<D3D_FEATURE_LEVEL, 2> levels{D3D_FEATURE_LEVEL_11_1,
                                                    D3D_FEATURE_LEVEL_11_0};
  D3D_FEATURE_LEVEL selected{};
  HRESULT creation = D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_WARP, nullptr, D3D11_CREATE_DEVICE_SINGLETHREADED,
      levels.data(), static_cast<UINT>(levels.size()), D3D11_SDK_VERSION, &device,
      &selected, &context);
  if (creation == E_INVALIDARG) {
    creation = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_WARP, nullptr, D3D11_CREATE_DEVICE_SINGLETHREADED,
        levels.data() + 1, 1U, D3D11_SDK_VERSION, &device, &selected, &context);
  }
  CheckHr(creation, "D3D11CreateDevice(WARP)");

  ComPtr<ID3D11ComputeShader> shader;
  CheckHr(device->CreateComputeShader(bytecode->GetBufferPointer(),
                                      bytecode->GetBufferSize(), nullptr, &shader),
          "CreateComputeShader");

  const auto element_count = static_cast<UINT>(inputs.size());

  D3D11_BUFFER_DESC input_desc{};
  input_desc.ByteWidth = static_cast<UINT>(sizeof(Element) * inputs.size());
  input_desc.Usage = D3D11_USAGE_DEFAULT;
  input_desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
  input_desc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
  input_desc.StructureByteStride = sizeof(Element);
  D3D11_SUBRESOURCE_DATA input_data{};
  input_data.pSysMem = inputs.data();
  ComPtr<ID3D11Buffer> input_buffer;
  CheckHr(device->CreateBuffer(&input_desc, &input_data, &input_buffer),
          "CreateBuffer(input)");

  D3D11_SHADER_RESOURCE_VIEW_DESC srv_desc{};
  srv_desc.Format = DXGI_FORMAT_UNKNOWN;
  srv_desc.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
  srv_desc.Buffer.NumElements = element_count;
  ComPtr<ID3D11ShaderResourceView> srv;
  CheckHr(device->CreateShaderResourceView(input_buffer.Get(), &srv_desc, &srv),
          "CreateShaderResourceView");

  D3D11_BUFFER_DESC output_desc = input_desc;
  output_desc.ByteWidth = static_cast<UINT>(sizeof(Result) * inputs.size());
  output_desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS;
  output_desc.StructureByteStride = sizeof(Result);
  ComPtr<ID3D11Buffer> output_buffer;
  CheckHr(device->CreateBuffer(&output_desc, nullptr, &output_buffer),
          "CreateBuffer(output)");

  D3D11_UNORDERED_ACCESS_VIEW_DESC uav_desc{};
  uav_desc.Format = DXGI_FORMAT_UNKNOWN;
  uav_desc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
  uav_desc.Buffer.NumElements = element_count;
  ComPtr<ID3D11UnorderedAccessView> uav;
  CheckHr(device->CreateUnorderedAccessView(output_buffer.Get(), &uav_desc, &uav),
          "CreateUnorderedAccessView");

  D3D11_BUFFER_DESC staging_desc{};
  staging_desc.ByteWidth = output_desc.ByteWidth;
  staging_desc.Usage = D3D11_USAGE_STAGING;
  staging_desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  ComPtr<ID3D11Buffer> staging;
  CheckHr(device->CreateBuffer(&staging_desc, nullptr, &staging),
          "CreateBuffer(staging)");

  ID3D11ShaderResourceView* srv_pointer = srv.Get();
  ID3D11UnorderedAccessView* uav_pointer = uav.Get();
  context->CSSetShader(shader.Get(), nullptr, 0U);
  context->CSSetShaderResources(0U, 1U, &srv_pointer);
  context->CSSetUnorderedAccessViews(0U, 1U, &uav_pointer, nullptr);
  context->Dispatch((element_count + 63U) / 64U, 1U, 1U);

  ID3D11ShaderResourceView* null_srv = nullptr;
  ID3D11UnorderedAccessView* null_uav = nullptr;
  context->CSSetShaderResources(0U, 1U, &null_srv);
  context->CSSetUnorderedAccessViews(0U, 1U, &null_uav, nullptr);
  context->CSSetShader(nullptr, nullptr, 0U);
  context->CopyResource(staging.Get(), output_buffer.Get());

  D3D11_MAPPED_SUBRESOURCE mapped{};
  CheckHr(context->Map(staging.Get(), 0U, D3D11_MAP_READ, 0U, &mapped), "Map");
  std::vector<Result> results(inputs.size());
  std::memcpy(results.data(), mapped.pData, output_desc.ByteWidth);
  context->Unmap(staging.Get(), 0U);
  return results;
}

}  // namespace

int main(int argc, char** argv)
{
  if (argc < 2) {
    std::cerr << "usage: elder_native_temporal_dither_warp_tests <probe.hlsl>\n";
    return 2;
  }
  const std::filesystem::path probe{argv[1]};
  if (!std::filesystem::exists(probe)) {
    std::cerr << "probe shader is absent: " << probe.string() << '\n';
    return 2;
  }

  // Every cell of the pattern, across the inactive case and one full frame
  // period, so the comparison covers the whole table and every phase.
  std::vector<Element> inputs;
  for (float frame = 0.0F; frame <= 4.0F; frame += 1.0F) {
    for (int y = 0; y < 4; ++y) {
      for (int x = 0; x < 4; ++x) {
        inputs.push_back(Element{static_cast<float>(x), static_cast<float>(y), frame, 0.0F});
      }
    }
  }

  const std::vector<Result> results = RunProbe(probe, inputs);
  EXPECT(results.size() == inputs.size());

  constexpr float tolerance = 1.0e-6F;
  std::size_t compared = 0U;
  for (std::size_t i = 0; i < results.size() && i < inputs.size(); ++i) {
    const Element& in = inputs[i];
    const elder::shaders::DitherPulse pulse{in.frame, 1920.0F, 1080.0F};
    const elder::shaders::DitherPixel pixel{in.x, in.y};

    EXPECT(std::fabs(results[i].bayer - elder::shaders::Bayer4x4(pixel)) <= tolerance);
    EXPECT(std::fabs(results[i].rotation - elder::shaders::PhaseRotation(pulse))
           <= tolerance);
    EXPECT(std::fabs(results[i].offset - elder::shaders::DitherOffset(pixel, pulse))
           <= tolerance);

    const float expected_dithered =
        elder::shaders::ApplyDither(50.5F / 255.0F, pixel, pulse);
    EXPECT(std::fabs(results[i].dithered - expected_dithered) <= tolerance);
    ++compared;
  }

  if (failures != 0) {
    std::cerr << failures << " parity expectation(s) failed\n";
    return 1;
  }
  std::cout << "PASS: Elder temporal dither WARP parity (" << compared
            << " elements)\n";
  return 0;
}
