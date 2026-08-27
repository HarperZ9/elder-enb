#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <d3d11.h>
#include <d3dcompiler.h>
#include <wrl/client.h>

#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <new>
#include <stdexcept>
#include <string>
#include <string_view>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "d3dcompiler.lib")

namespace {

using Microsoft::WRL::ComPtr;

constexpr std::uint32_t kRouteIdentity = 0U;
constexpr std::uint32_t kRouteSpatial = 1U;
constexpr std::uint32_t kRouteBridge = 2U;
constexpr std::uint32_t kRouteNative = 3U;
constexpr std::uint32_t kCaseCount = 4U;

struct Float4 {
  float x;
  float y;
  float z;
  float w;
};

struct ProbeInput {
  Float4 native_color;
  Float4 bridge_color;
  Float4 spatial_color;
  Float4 identity_color;
  Float4 availability;
};

struct ProbeOutput {
  Float4 wrapper_color;
  Float4 direct_color;
  Float4 zero_intensity_color;
  Float4 disabled_color;
  Float4 active_full_color;
  std::uint32_t route;
  float padding[3];
};

static_assert(sizeof(Float4) == 16U);
static_assert(sizeof(ProbeInput) == 80U);
static_assert(sizeof(ProbeOutput) == 96U);

[[noreturn]] void fail(const std::string& message) {
  throw std::runtime_error(message);
}

void check_hr(const HRESULT result, const std::string_view operation) {
  if (SUCCEEDED(result)) return;
  fail(std::string{operation} + " failed with HRESULT 0x"
       + std::to_string(static_cast<unsigned long>(result)));
}

std::string blob_text(ID3DBlob* blob) {
  if (blob == nullptr || blob->GetBufferPointer() == nullptr) return {};
  const auto* text = static_cast<const char*>(blob->GetBufferPointer());
  return std::string{text, text + blob->GetBufferSize()};
}

// Resolves probe includes the way the installed enbseries layout does: the
// probe's own directory covers sibling includes, and the shader root one level
// up anchors the host-qualified "elder/..." include paths. The stock
// D3DCompile include handler knows only the probe's directory, so the
// qualified nested includes cannot resolve without this.
class IncludeResolver final : public ID3DInclude {
 public:
  explicit IncludeResolver(const std::filesystem::path& probe_path)
      : search_roots_{probe_path.parent_path(),
                      probe_path.parent_path().parent_path()} {}

  HRESULT __stdcall Open(
      D3D_INCLUDE_TYPE,
      LPCSTR file_name,
      LPCVOID,
      LPCVOID* data,
      UINT* byte_count) override {
    if (file_name == nullptr || data == nullptr || byte_count == nullptr) {
      return E_INVALIDARG;
    }
    for (const std::filesystem::path& root : search_roots_) {
      const std::filesystem::path candidate = root / file_name;
      std::error_code probe_error;
      if (!std::filesystem::is_regular_file(candidate, probe_error)) {
        continue;
      }
      std::ifstream stream(candidate, std::ios::binary | std::ios::ate);
      if (!stream) return E_FAIL;
      const std::streamoff length = stream.tellg();
      if (length < 0
          || static_cast<std::uint64_t>(length)
              > static_cast<std::uint64_t>((std::numeric_limits<UINT>::max)())) {
        return E_FAIL;
      }
      stream.seekg(0, std::ios::beg);
      const auto size = static_cast<std::size_t>(length);
      auto* bytes = new (std::nothrow) char[size == 0U ? 1U : size];
      if (bytes == nullptr) return E_OUTOFMEMORY;
      if (size != 0U
          && !stream.read(bytes, static_cast<std::streamsize>(size))) {
        delete[] bytes;
        return E_FAIL;
      }
      *data = bytes;
      *byte_count = static_cast<UINT>(size);
      return S_OK;
    }
    return E_FAIL;
  }

  HRESULT __stdcall Close(const LPCVOID data) override {
    delete[] static_cast<const char*>(data);
    return S_OK;
  }

 private:
  std::array<std::filesystem::path, 2U> search_roots_;
};

ComPtr<ID3DBlob> compile_probe(
    const std::filesystem::path& probe_path,
    const bool declared_native_available) {
  if (!std::filesystem::is_regular_file(probe_path)) {
    fail("capability WARP probe shader does not exist: " + probe_path.string());
  }

  const std::string native_value = declared_native_available ? "1" : "0";
  const std::array<D3D_SHADER_MACRO, 2U> macros{{
      {"ELDER_CAPABILITY_WARP_NATIVE_AVAILABLE", native_value.c_str()},
      {nullptr, nullptr},
  }};

  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3DBlob> diagnostics;
  constexpr UINT flags = D3DCOMPILE_ENABLE_STRICTNESS
      | D3DCOMPILE_WARNINGS_ARE_ERRORS
      | D3DCOMPILE_OPTIMIZATION_LEVEL3;
  IncludeResolver includes{probe_path};
  const HRESULT hr = D3DCompileFromFile(
      probe_path.c_str(), macros.data(), &includes,
      "ElderCapabilityWarpProbeMain", "cs_5_0", flags, 0U, &bytecode,
      &diagnostics);
  if (FAILED(hr)) {
    fail("D3DCompileFromFile(capability probe) failed:\n"
         + blob_text(diagnostics.Get()));
  }
  if (diagnostics != nullptr && diagnostics->GetBufferSize() != 0U) {
    fail("capability probe emitted diagnostics:\n" + blob_text(diagnostics.Get()));
  }
  return bytecode;
}

struct WarpDevice {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
};

WarpDevice create_warp_device() {
  constexpr std::array<D3D_FEATURE_LEVEL, 2U> levels{
      D3D_FEATURE_LEVEL_11_1,
      D3D_FEATURE_LEVEL_11_0,
  };
  WarpDevice result;
  D3D_FEATURE_LEVEL selected{};
  HRESULT hr = D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_WARP, nullptr,
      D3D11_CREATE_DEVICE_SINGLETHREADED, levels.data(),
      static_cast<UINT>(levels.size()), D3D11_SDK_VERSION, &result.device,
      &selected, &result.context);
  if (hr == E_INVALIDARG) {
    hr = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_WARP, nullptr,
        D3D11_CREATE_DEVICE_SINGLETHREADED, levels.data() + 1U, 1U,
        D3D11_SDK_VERSION, &result.device, &selected, &result.context);
  }
  check_hr(hr, "D3D11CreateDevice(WARP)");
  if (selected < D3D_FEATURE_LEVEL_11_0) {
    fail("D3D11 WARP did not provide feature level 11_0");
  }
  return result;
}

template <typename T>
ComPtr<ID3D11Buffer> create_structured_buffer(
    ID3D11Device& device,
    const UINT bind_flags,
    const std::array<T, kCaseCount>* initial_values) {
  D3D11_BUFFER_DESC description{};
  description.ByteWidth = sizeof(T) * kCaseCount;
  description.Usage = D3D11_USAGE_DEFAULT;
  description.BindFlags = bind_flags;
  description.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
  description.StructureByteStride = sizeof(T);

  D3D11_SUBRESOURCE_DATA data{};
  D3D11_SUBRESOURCE_DATA* data_pointer = nullptr;
  if (initial_values != nullptr) {
    data.pSysMem = initial_values->data();
    data_pointer = &data;
  }

  ComPtr<ID3D11Buffer> buffer;
  check_hr(device.CreateBuffer(&description, data_pointer, &buffer),
           "CreateBuffer(structured)");
  return buffer;
}

std::array<ProbeOutput, kCaseCount> run_probe(
    const std::filesystem::path& probe_path,
    const bool declared_native_available) {
  const Float4 native{0.11F, 0.12F, 0.13F, 0.14F};
  const Float4 bridge{0.21F, 0.22F, 0.23F, 0.24F};
  const Float4 spatial{0.31F, 0.32F, 0.33F, 0.34F};
  const Float4 identity{0.41F, 0.42F, 0.43F, 0.44F};
  const std::array<ProbeInput, kCaseCount> inputs{{
      {native, bridge, spatial, identity, {1.0F, 1.0F, 1.0F, 1.0F}},
      {native, bridge, spatial, identity, {0.0F, 1.0F, 1.0F, 1.0F}},
      {native, bridge, spatial, identity, {0.0F, 0.0F, 1.0F, 1.0F}},
      {native, bridge, spatial, identity, {0.0F, 0.0F, 0.0F, 1.0F}},
  }};

  WarpDevice warp = create_warp_device();
  ComPtr<ID3DBlob> bytecode = compile_probe(probe_path, declared_native_available);

  ComPtr<ID3D11ComputeShader> shader;
  check_hr(
      warp.device->CreateComputeShader(
          bytecode->GetBufferPointer(), bytecode->GetBufferSize(), nullptr,
          &shader),
      "CreateComputeShader");

  ComPtr<ID3D11Buffer> input_buffer =
      create_structured_buffer(
          *warp.device.Get(), D3D11_BIND_SHADER_RESOURCE, &inputs);
  ComPtr<ID3D11Buffer> output_buffer =
      create_structured_buffer<ProbeOutput>(
          *warp.device.Get(), D3D11_BIND_UNORDERED_ACCESS, nullptr);

  D3D11_SHADER_RESOURCE_VIEW_DESC srv_description{};
  srv_description.Format = DXGI_FORMAT_UNKNOWN;
  srv_description.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
  srv_description.Buffer.NumElements = kCaseCount;
  ComPtr<ID3D11ShaderResourceView> input_view;
  check_hr(
      warp.device->CreateShaderResourceView(
          input_buffer.Get(), &srv_description, &input_view),
      "CreateShaderResourceView(input)");

  D3D11_UNORDERED_ACCESS_VIEW_DESC uav_description{};
  uav_description.Format = DXGI_FORMAT_UNKNOWN;
  uav_description.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
  uav_description.Buffer.NumElements = kCaseCount;
  ComPtr<ID3D11UnorderedAccessView> output_view;
  check_hr(
      warp.device->CreateUnorderedAccessView(
          output_buffer.Get(), &uav_description, &output_view),
      "CreateUnorderedAccessView(output)");

  D3D11_BUFFER_DESC staging_description{};
  staging_description.ByteWidth = sizeof(ProbeOutput) * kCaseCount;
  staging_description.Usage = D3D11_USAGE_STAGING;
  staging_description.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  ComPtr<ID3D11Buffer> staging;
  check_hr(
      warp.device->CreateBuffer(&staging_description, nullptr, &staging),
      "CreateBuffer(staging)");

  ID3D11ShaderResourceView* srv = input_view.Get();
  ID3D11UnorderedAccessView* uav = output_view.Get();
  warp.context->CSSetShader(shader.Get(), nullptr, 0U);
  warp.context->CSSetShaderResources(0U, 1U, &srv);
  warp.context->CSSetUnorderedAccessViews(0U, 1U, &uav, nullptr);
  warp.context->Dispatch(kCaseCount, 1U, 1U);

  ID3D11ShaderResourceView* null_srv = nullptr;
  ID3D11UnorderedAccessView* null_uav = nullptr;
  warp.context->CSSetShaderResources(0U, 1U, &null_srv);
  warp.context->CSSetUnorderedAccessViews(0U, 1U, &null_uav, nullptr);
  warp.context->CSSetShader(nullptr, nullptr, 0U);
  warp.context->CopyResource(staging.Get(), output_buffer.Get());

  D3D11_MAPPED_SUBRESOURCE mapped{};
  check_hr(
      warp.context->Map(staging.Get(), 0U, D3D11_MAP_READ, 0U, &mapped),
      "Map(staging)");
  std::array<ProbeOutput, kCaseCount> results{};
  std::memcpy(results.data(), mapped.pData, sizeof(results));
  warp.context->Unmap(staging.Get(), 0U);
  return results;
}

bool near_equal(const float actual, const float expected) {
  return std::fabs(actual - expected) <= 1.0e-6F;
}

bool same_color(const Float4& actual, const Float4& expected) {
  return near_equal(actual.x, expected.x) && near_equal(actual.y, expected.y)
      && near_equal(actual.z, expected.z) && near_equal(actual.w, expected.w);
}

bool same_float_bits(const float actual, const float expected) {
  std::uint32_t actual_bits{};
  std::uint32_t expected_bits{};
  std::memcpy(&actual_bits, &actual, sizeof(actual_bits));
  std::memcpy(&expected_bits, &expected, sizeof(expected_bits));
  return actual_bits == expected_bits;
}

bool same_color_bits(const Float4& actual, const Float4& expected) {
  return same_float_bits(actual.x, expected.x)
      && same_float_bits(actual.y, expected.y)
      && same_float_bits(actual.z, expected.z)
      && same_float_bits(actual.w, expected.w);
}

void expect_color(
    const ProbeOutput& output,
    const std::uint32_t route,
    const Float4& color,
    const std::string_view label) {
  if (output.route != route) {
    fail(std::string{label} + " selected route " + std::to_string(output.route));
  }
  if (!same_color(output.wrapper_color, color)) {
    fail(std::string{label} + " wrapper color did not match selected route");
  }
  if (!same_color(output.direct_color, color)) {
    fail(std::string{label} + " direct color did not match selected route");
  }
}

void expect_exact_color(
    const Float4& actual,
    const Float4& expected,
    const std::string_view label) {
  if (!same_color_bits(actual, expected)) {
    fail(std::string{label} + " did not preserve the exact original source");
  }
}

void expect_bridge_retain_load_bearing(
    const ProbeOutput& output,
    const Float4& bridge,
    const Float4& identity,
    const std::string_view label) {
  if (same_color(output.active_full_color, identity)) {
    fail(std::string{label}
         + " did not switch away from the original source when active");
  }
  if (same_color(output.active_full_color, bridge)) {
    fail(std::string{label}
         + " did not include the non-zero SB_Retain Bridge candidate");
  }
}

}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 2) {
      fail("usage: elder_capability_warp_tests <ElderCapabilityWarpProbe.hlsl>");
    }

    const std::filesystem::path probe_path = argv[1];
    const Float4 native{0.11F, 0.12F, 0.13F, 0.14F};
    const Float4 bridge{0.21F, 0.22F, 0.23F, 0.24F};
    const Float4 spatial{0.31F, 0.32F, 0.33F, 0.34F};
    const Float4 identity{0.41F, 0.42F, 0.43F, 0.44F};

    if (same_color(native, bridge) || same_color(native, spatial)
        || same_color(native, identity) || same_color(bridge, spatial)
        || same_color(bridge, identity) || same_color(spatial, identity)) {
      fail("capability test colors must remain distinct RGBA witnesses");
    }

    const auto ordered_results = run_probe(probe_path, true);
    expect_color(
        ordered_results[0], kRouteNative, native,
        "native availability selects native");
    expect_color(
        ordered_results[1], kRouteBridge, bridge,
        "no native selects Bridge");
    expect_exact_color(
        ordered_results[1].zero_intensity_color, identity,
        "Bridge zero intensity");
    expect_exact_color(
        ordered_results[1].disabled_color, identity,
        "Bridge disabled stage");
    expect_bridge_retain_load_bearing(
        ordered_results[1], bridge, identity,
        "Bridge active identity blend");
    expect_color(
        ordered_results[2], kRouteSpatial, spatial,
        "no native or Bridge selects spatial");
    expect_color(
        ordered_results[3], kRouteIdentity, identity,
        "only identity availability selects identity");

    const auto unavailable_native_results = run_probe(probe_path, false);
    expect_color(
        unavailable_native_results[0], kRouteBridge, bridge,
        "declared native unavailable selects Bridge");

    std::cout
        << "Elder capability WARP: native, Bridge, spatial, identity, "
           "and unavailable-native routes verified\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
