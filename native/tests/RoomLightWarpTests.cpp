// WARP numeric-parity test for the Elder room-light model. The GPU probe and
// this harness independently build the same canonical cases; the harness runs
// the CPU reference and asserts field-by-field agreement, bringing the Elder
// room-light slice to the same CPU/HLSL-parity standard as its color core (and
// as Truth's interior-light slice).

#include "elder/shaders/InteriorLight.hpp"

#include <array>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <new>
#include <string>
#include <string_view>
#include <vector>

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
constexpr std::uint32_t kPrepassCaseCount = 10U;

constexpr std::array<std::string_view, kPrepassCaseCount> kPrepassCaseNames{
    "exterior-preserves-room-payload",
    "sealed-room-keeps-ambient-floor",
    "partial-aperture-is-bounded",
    "invalid-runtime-preserves-scene",
    "interior-transition-is-continuous",
    "sealed-interior-contact-attenuates-without-crushing",
    "route-selection-prefers-native-then-bridge-then-spatial",
    "unsupported-reflection-and-subsurface-are-identity",
    "status-valid-marker-is-exact",
    "status-generation-is-integer-exact"};

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
      UINT* byte_count) override
  {
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
      if (!stream) {
        return E_FAIL;
      }
      const std::streamoff length = stream.tellg();
      if (length < 0
          || static_cast<std::uint64_t>(length)
              > static_cast<std::uint64_t>((std::numeric_limits<UINT>::max)())) {
        return E_FAIL;
      }
      stream.seekg(0, std::ios::beg);
      const auto size = static_cast<std::size_t>(length);
      auto* bytes = new (std::nothrow) char[size == 0U ? 1U : size];
      if (bytes == nullptr) {
        return E_OUTOFMEMORY;
      }
      if (size != 0U && !stream.read(bytes, static_cast<std::streamsize>(size))) {
        delete[] bytes;
        return E_FAIL;
      }
      *data = bytes;
      *byte_count = static_cast<UINT>(size);
      return S_OK;
    }
    return E_FAIL;
  }

  HRESULT __stdcall Close(const LPCVOID data) override
  {
    delete[] static_cast<const char*>(data);
    return S_OK;
  }

 private:
  std::array<std::filesystem::path, 2U> search_roots_;
};

[[nodiscard]] ComPtr<ID3DBlob> compile_probe(
    const wchar_t* path, const char* entry_point, const char* label)
{
  IncludeResolver includes{std::filesystem::path{path}};
  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3DBlob> diagnostics;
  const HRESULT hr = D3DCompileFromFile(
      path, nullptr, &includes,
      entry_point, "cs_5_0",
      D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_OPTIMIZATION_LEVEL3, 0U,
      &bytecode, &diagnostics);
  if (FAILED(hr)) {
    std::string message = "D3DCompileFromFile(";
    message += label;
    message += ") failed";
    if (diagnostics) {
      message += ": ";
      message.append(static_cast<const char*>(diagnostics->GetBufferPointer()),
                     diagnostics->GetBufferSize());
    }
    fail(message);
  }
  return bytecode;
}

std::vector<Float4> run_gpu(
    const wchar_t* probe_path,
    const char* entry_point,
    const std::uint32_t case_count,
    const char* label)
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

  const ComPtr<ID3DBlob> bytecode = compile_probe(probe_path, entry_point, label);
  ComPtr<ID3D11ComputeShader> shader;
  check_hr(device->CreateComputeShader(bytecode->GetBufferPointer(),
                                       bytecode->GetBufferSize(), nullptr, &shader),
           "CreateComputeShader");

  D3D11_BUFFER_DESC output_desc{};
  output_desc.ByteWidth = sizeof(Float4) * case_count;
  output_desc.Usage = D3D11_USAGE_DEFAULT;
  output_desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS;
  output_desc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
  output_desc.StructureByteStride = sizeof(Float4);
  ComPtr<ID3D11Buffer> output;
  check_hr(device->CreateBuffer(&output_desc, nullptr, &output), "CreateBuffer(output)");

  D3D11_UNORDERED_ACCESS_VIEW_DESC view_desc{};
  view_desc.Format = DXGI_FORMAT_UNKNOWN;
  view_desc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
  view_desc.Buffer.NumElements = case_count;
  ComPtr<ID3D11UnorderedAccessView> output_view;
  check_hr(device->CreateUnorderedAccessView(output.Get(), &view_desc, &output_view),
           "CreateUnorderedAccessView(output)");

  D3D11_BUFFER_DESC staging_desc{};
  staging_desc.ByteWidth = sizeof(Float4) * case_count;
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
  std::vector<Float4> results(case_count);
  std::memcpy(results.data(), mapped.pData, sizeof(Float4) * results.size());
  context->Unmap(staging.Get(), 0U);
  return results;
}

[[nodiscard]] bool near_value(const float a, const float b)
{
  return std::fabs(a - b) <= 1.0e-4F;
}

[[nodiscard]] bool same_bits(const float a, const float b)
{
  return std::bit_cast<std::uint32_t>(a) == std::bit_cast<std::uint32_t>(b);
}

void run_room_light_parity(const wchar_t* probe_path)
{
  const std::vector<Float4> gpu = run_gpu(
      probe_path, "ElderRoomLightWarpProbeMain", kCaseCount, "room-light probe");

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
}

void expect_exact_rgb(
    const Float4& value, const float x, const float y, const float z, const std::string& tag)
{
  expect(same_bits(value.x, x), tag + " preserves red exactly");
  expect(same_bits(value.y, y), tag + " preserves green exactly");
  expect(same_bits(value.z, z), tag + " preserves blue exactly");
}

void run_prepass_integration(const wchar_t* probe_path)
{
  const std::vector<Float4> gpu = run_gpu(
      probe_path, "ElderPrepassWarpProbeMain", kPrepassCaseCount, "prepass probe");

  {
    const Float4& g = gpu[0U];
    const std::string tag(kPrepassCaseNames[0U]);
    expect_exact_rgb(g, 0.25F, 0.5F, 0.75F, tag);
  }

  {
    const Float4& g = gpu[1U];
    const std::string tag(kPrepassCaseNames[1U]);
    expect(g.x >= 0.05F && g.y >= 0.04F && g.z >= 0.03F,
           tag + " does not crush the authored ambient floor");
    expect(g.x <= 0.065F && g.y <= 0.052F && g.z <= 0.039F,
           tag + " keeps sealed-room lift restrained");
  }

  {
    const Float4& g = gpu[2U];
    const std::string tag(kPrepassCaseNames[2U]);
    expect(g.x > 0.2F && g.y > 0.2F && g.z > 0.2F,
           tag + " applies the valid interior room-light payload");
    expect(g.x <= 0.28F && g.y <= 0.28F && g.z <= 0.28F,
           tag + " remains bounded");
  }

  {
    const Float4& g = gpu[3U];
    const std::string tag(kPrepassCaseNames[3U]);
    expect_exact_rgb(g, 0.125F, 0.25F, 0.5F, tag);
  }

  {
    const Float4& g = gpu[4U];
    const std::string tag(kPrepassCaseNames[4U]);
    expect(g.x >= 0.2F, tag + " starts at or above the exterior identity");
    expect(g.x <= g.y && g.y <= g.z && g.z <= g.w,
           tag + " is monotonic across the interior factor");
    expect(g.w <= 0.28F, tag + " remains bounded at full interior");
    expect((g.y - g.x) <= 0.03F && (g.z - g.y) <= 0.03F && (g.w - g.z) <= 0.03F,
           tag + " changes continuously without steps");
  }

  {
    const Float4& g = gpu[5U];
    const std::string tag(kPrepassCaseNames[5U]);
    expect(g.x < 0.5F && g.y < 0.5F && g.z < 0.5F,
           tag + " permits bounded contact attenuation");
    expect(g.x >= 0.47F && g.y >= 0.47F && g.z >= 0.47F,
           tag + " preserves an explicit ambient floor");
  }

  {
    const Float4& g = gpu[6U];
    const std::string tag(kPrepassCaseNames[6U]);
    expect(near_value(g.x, 3.0F), tag + " native route");
    expect(near_value(g.y, 2.0F), tag + " bridge route");
    expect(near_value(g.z, 1.0F), tag + " spatial route without runtime pulse");
    expect(near_value(g.w, 0.0F), tag + " identity route when no capability fits");
  }

  {
    const Float4& g = gpu[7U];
    const std::string tag(kPrepassCaseNames[7U]);
    expect(near_value(g.x, 1.0F), tag + " reflection identity");
    expect(near_value(g.y, 1.0F), tag + " subsurface identity");
  }

  {
    const Float4& g = gpu[8U];
    const std::string tag(kPrepassCaseNames[8U]);
    expect(near_value(g.x, 1.0F), tag + " rejects status.y values other than 1.0");
  }

  {
    const Float4& g = gpu[9U];
    const std::string tag(kPrepassCaseNames[9U]);
    expect(near_value(g.x, 1.0F), tag + " rejects fractional folded generations");
  }
}

}  // namespace

int main(int argc, char** argv)
{
  if (argc < 2) {
    fail("usage: elder_native_room_light_warp_tests <room-light-probe.hlsl> [prepass-probe.hlsl]");
  }

  const std::string narrow_path = argv[1];
  const std::wstring probe_path(narrow_path.begin(), narrow_path.end());
  run_room_light_parity(probe_path.c_str());

  if (argc >= 3) {
    const std::string narrow_prepass_path = argv[2];
    const std::wstring prepass_path(narrow_prepass_path.begin(), narrow_prepass_path.end());
    run_prepass_integration(prepass_path.c_str());
  }

  if (failures != 0) {
    std::cerr << failures << " assertion(s) failed\n";
    return 1;
  }

  std::cout << "Elder room-light WARP parity: " << kCaseCount << " cases matched CPU\n";
  if (argc >= 3) {
    std::cout << "Elder prepass room-light integration: "
              << kPrepassCaseCount << " cases matched contract\n";
  }
  return 0;
}
