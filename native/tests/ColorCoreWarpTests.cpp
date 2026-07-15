#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <d3d11.h>
#include <d3dcompiler.h>
#include <wrl/client.h>

#include "elder/shaders/ColorCore.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <new>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <vector>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "d3dcompiler.lib")

namespace {

using elder::shaders::ColorCoreInput;
using elder::shaders::ColorCoreOutput;
using elder::shaders::ColorCoreParameters;
using elder::shaders::DefaultColorCoreParameters;
using elder::shaders::EvaluateColorCore;
using elder::shaders::LinearRgb;
using Microsoft::WRL::ComPtr;

constexpr char kGeneratedIncludeName[] = "ElderNativeParameters.fxh";
constexpr char kColorCoreIncludeName[] = "ElderColorCore.fxh";
constexpr char kShaderEntryPoint[] = "ElderColorWarpProbeMain";
constexpr char kShaderTarget[] = "cs_5_0";
constexpr UINT kThreadsPerGroup = 64U;
constexpr float kAbsoluteTolerance = 2.0e-5F;
constexpr float kRelativeTolerance = 4.0e-5F;

struct GpuFloat4 {
  float x;
  float y;
  float z;
  float w;
};

static_assert(sizeof(GpuFloat4) == 16U);
static_assert(std::is_trivially_copyable_v<GpuFloat4>);

struct Sample {
  std::string label;
  GpuFloat4 scene;
};

struct ComparisonReport {
  std::size_t assertions{};
  std::size_t failures{};
  float maximum_absolute_error{};
  float maximum_relative_error{};
  std::string worst_component;
  std::vector<std::string> messages;

  void Expect(const bool condition, std::string message) {
    ++assertions;
    if (condition) return;
    ++failures;
    if (messages.size() < 24U) messages.push_back(std::move(message));
  }
};

[[noreturn]] void Fail(std::string message) {
  throw std::runtime_error(std::move(message));
}

void CheckHr(const HRESULT result, const std::string_view operation) {
  if (SUCCEEDED(result)) return;
  std::ostringstream message;
  message << operation << " failed with HRESULT 0x" << std::hex
          << std::uppercase << static_cast<std::uint32_t>(result);
  Fail(message.str());
}

[[nodiscard]] std::string BlobText(ID3DBlob* blob) {
  if (blob == nullptr || blob->GetBufferPointer() == nullptr) return {};
  const auto* begin = static_cast<const char*>(blob->GetBufferPointer());
  return std::string(begin, begin + blob->GetBufferSize());
}

[[nodiscard]] bool EqualPathComponent(
    const std::filesystem::path& left,
    const std::filesystem::path& right) {
  return _wcsicmp(left.c_str(), right.c_str()) == 0;
}

[[nodiscard]] bool IsWithin(
    const std::filesystem::path& root,
    const std::filesystem::path& candidate) {
  auto root_part = root.begin();
  auto candidate_part = candidate.begin();
  for (; root_part != root.end(); ++root_part, ++candidate_part) {
    if (candidate_part == candidate.end()
        || !EqualPathComponent(*root_part, *candidate_part)) {
      return false;
    }
  }
  return true;
}

class IncludeResolver final : public ID3DInclude {
 public:
  IncludeResolver(
      std::filesystem::path shader_directory,
      std::filesystem::path generated_include_directory)
      : shader_directory_(CanonicalDirectory(std::move(shader_directory))),
        generated_include_directory_(
            CanonicalDirectory(std::move(generated_include_directory))) {}

  HRESULT __stdcall Open(
      D3D_INCLUDE_TYPE,
      LPCSTR file_name,
      LPCVOID,
      LPCVOID* data,
      UINT* byte_count) override {
    if (file_name == nullptr || data == nullptr || byte_count == nullptr) {
      return E_INVALIDARG;
    }

    const std::string_view requested{file_name};
    const std::filesystem::path* root = nullptr;
    if (requested == std::string_view{kGeneratedIncludeName}) {
      root = &generated_include_directory_;
    } else if (requested == std::string_view{kColorCoreIncludeName}) {
      root = &shader_directory_;
    } else {
      return E_ACCESSDENIED;
    }

    try {
      const std::filesystem::path candidate =
          std::filesystem::weakly_canonical(*root / file_name);
      if (!IsWithin(*root, candidate)
          || !std::filesystem::is_regular_file(candidate)) {
        return E_ACCESSDENIED;
      }

      std::ifstream stream(candidate, std::ios::binary | std::ios::ate);
      if (!stream) return E_FAIL;
      const std::streamoff length = stream.tellg();
      if (length < 0
          || static_cast<std::uint64_t>(length)
              > static_cast<std::uint64_t>(std::numeric_limits<UINT>::max())) {
        return E_FAIL;
      }
      stream.seekg(0, std::ios::beg);

      const auto size = static_cast<std::size_t>(length);
      auto* bytes = new (std::nothrow) char[std::max<std::size_t>(size, 1U)];
      if (bytes == nullptr) return E_OUTOFMEMORY;
      if (size != 0U
          && !stream.read(bytes, static_cast<std::streamsize>(size))) {
        delete[] bytes;
        return E_FAIL;
      }

      *data = bytes;
      *byte_count = static_cast<UINT>(size);
      return S_OK;
    } catch (...) {
      return E_FAIL;
    }
  }

  HRESULT __stdcall Close(const LPCVOID data) override {
    delete[] static_cast<const char*>(data);
    return S_OK;
  }

 private:
  [[nodiscard]] static std::filesystem::path CanonicalDirectory(
      std::filesystem::path directory) {
    const auto canonical = std::filesystem::weakly_canonical(directory);
    if (!std::filesystem::is_directory(canonical)) {
      Fail("shader include directory does not exist");
    }
    return canonical;
  }

  std::filesystem::path shader_directory_;
  std::filesystem::path generated_include_directory_;
};

struct CompiledProbe {
  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3D11ShaderReflection> reflection;
};

[[nodiscard]] CompiledProbe CompileProbe(
    const std::filesystem::path& shader_path,
    const std::filesystem::path& generated_include_directory) {
  if (!std::filesystem::is_regular_file(shader_path)) {
    Fail("WARP probe shader does not exist: " + shader_path.string());
  }
  if (!std::filesystem::is_regular_file(
          generated_include_directory / kGeneratedIncludeName)) {
    Fail("generated shader contract does not exist: "
         + (generated_include_directory / kGeneratedIncludeName).string());
  }

  IncludeResolver includes(shader_path.parent_path(), generated_include_directory);
  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3DBlob> diagnostics;
  constexpr UINT flags = D3DCOMPILE_ENABLE_STRICTNESS
      | D3DCOMPILE_WARNINGS_ARE_ERRORS
      | D3DCOMPILE_IEEE_STRICTNESS
      | D3DCOMPILE_OPTIMIZATION_LEVEL3;
  const HRESULT compile_result = D3DCompileFromFile(
      shader_path.c_str(), nullptr, &includes, kShaderEntryPoint,
      kShaderTarget, flags, 0U, &bytecode, &diagnostics);
  if (FAILED(compile_result)) {
    Fail("strict WARP probe compilation failed:\n" + BlobText(diagnostics.Get()));
  }
  if (diagnostics != nullptr && diagnostics->GetBufferSize() != 0U) {
    Fail("strict WARP probe compilation emitted diagnostics:\n"
         + BlobText(diagnostics.Get()));
  }

  ComPtr<ID3D11ShaderReflection> reflection;
  CheckHr(
      D3DReflect(
          bytecode->GetBufferPointer(), bytecode->GetBufferSize(),
          __uuidof(ID3D11ShaderReflection),
          reinterpret_cast<void**>(reflection.GetAddressOf())),
      "D3DReflect");
  return {std::move(bytecode), std::move(reflection)};
}

void ValidateResourceBinding(
    ID3D11ShaderReflection& reflection,
    const char* name,
    const D3D_SHADER_INPUT_TYPE expected_type,
    const UINT expected_slot) {
  D3D11_SHADER_INPUT_BIND_DESC binding{};
  CheckHr(
      reflection.GetResourceBindingDescByName(name, &binding),
      std::string{"shader reflection for "} + name);
  if (binding.Type != expected_type || binding.BindPoint != expected_slot
      || binding.BindCount != 1U) {
    Fail(std::string{"unexpected shader binding for "} + name);
  }
}

struct ReflectedGlobals {
  UINT bind_point{};
  std::vector<std::byte> bytes;
};

enum class ParameterShape : std::uint8_t {
  boolean,
  scalar,
  color3,
};

struct ExpectedParameter {
  const char* name;
  ParameterShape shape;
  std::array<float, 3U> value;
};

[[nodiscard]] std::vector<ExpectedParameter> ExpectedGeneratedParameters(
    const ColorCoreParameters& parameters) {
  return {
      {"ElderMasterEnabled", ParameterShape::boolean, {1.0F, 0.0F, 0.0F}},
      {"ElderExposureCompensationEv", ParameterShape::scalar,
       {parameters.exposure_ev, 0.0F, 0.0F}},
      {"ElderColorWarmCool", ParameterShape::scalar,
       {parameters.warm_cool, 0.0F, 0.0F}},
      {"ElderColorTint", ParameterShape::scalar,
       {parameters.tint, 0.0F, 0.0F}},
      {"ElderTonemapToe", ParameterShape::scalar,
       {parameters.toe, 0.0F, 0.0F}},
      {"ElderTonemapShoulder", ParameterShape::scalar,
       {parameters.shoulder, 0.0F, 0.0F}},
      {"ElderTonemapMidGray", ParameterShape::scalar,
       {parameters.mid_gray, 0.0F, 0.0F}},
      {"ElderTonemapWhitePoint", ParameterShape::scalar,
       {parameters.white_point, 0.0F, 0.0F}},
      {"ElderTonemapLocalContrast", ParameterShape::scalar,
       {parameters.local_contrast, 0.0F, 0.0F}},
      {"ElderColorSaturation", ParameterShape::scalar,
       {parameters.saturation, 0.0F, 0.0F}},
      {"ElderColorVibrance", ParameterShape::scalar,
       {parameters.vibrance, 0.0F, 0.0F}},
      {"ElderHighlightDesaturation", ParameterShape::scalar,
       {parameters.highlight_desaturation, 0.0F, 0.0F}},
      {"ElderHighlightGamutPreservation", ParameterShape::scalar,
       {parameters.highlight_gamut_preservation, 0.0F, 0.0F}},
      {"ElderShadowHueStability", ParameterShape::scalar,
       {parameters.shadow_hue_stability, 0.0F, 0.0F}},
      {"ElderShadowTint", ParameterShape::color3,
       {parameters.shadow_tint.r, parameters.shadow_tint.g,
        parameters.shadow_tint.b}},
      {"ElderHighlightTint", ParameterShape::color3,
       {parameters.highlight_tint.r, parameters.highlight_tint.g,
        parameters.highlight_tint.b}},
  };
}

[[nodiscard]] bool NearDefault(const float actual, const float expected) {
  return std::isfinite(actual)
      && std::fabs(actual - expected)
          <= 2.0e-7F * std::max(1.0F, std::fabs(expected));
}

[[nodiscard]] ReflectedGlobals ReflectAndBindDefaults(
    ID3D11ShaderReflection& reflection,
    const ColorCoreParameters& parameters) {
  D3D11_SHADER_INPUT_BIND_DESC resource{};
  CheckHr(
      reflection.GetResourceBindingDescByName("$Globals", &resource),
      "shader reflection for $Globals");
  if (resource.Type != D3D_SIT_CBUFFER || resource.BindCount != 1U) {
    Fail("generated parameters were not compiled into one constant buffer");
  }

  ID3D11ShaderReflectionConstantBuffer* globals =
      reflection.GetConstantBufferByName("$Globals");
  if (globals == nullptr) Fail("generated $Globals constant buffer is absent");
  D3D11_SHADER_BUFFER_DESC buffer_description{};
  CheckHr(globals->GetDesc(&buffer_description), "$Globals reflection");
  if (buffer_description.Size == 0U
      || (buffer_description.Size % 16U) != 0U
      || buffer_description.Size > D3D11_REQ_CONSTANT_BUFFER_ELEMENT_COUNT * 16U) {
    Fail("generated $Globals constant buffer has an invalid size");
  }

  ReflectedGlobals result{
      resource.BindPoint,
      std::vector<std::byte>(buffer_description.Size, std::byte{0}),
  };
  for (UINT index = 0U; index < buffer_description.Variables; ++index) {
    ID3D11ShaderReflectionVariable* variable = globals->GetVariableByIndex(index);
    D3D11_SHADER_VARIABLE_DESC description{};
    CheckHr(variable->GetDesc(&description), "$Globals variable reflection");
    if (description.StartOffset > result.bytes.size()
        || description.Size > result.bytes.size() - description.StartOffset) {
      Fail("reflected generated parameter lies outside $Globals");
    }
    if (description.DefaultValue != nullptr) {
      std::memcpy(
          result.bytes.data() + description.StartOffset,
          description.DefaultValue, description.Size);
    }
  }

  for (const ExpectedParameter& expected :
       ExpectedGeneratedParameters(parameters)) {
    ID3D11ShaderReflectionVariable* variable =
        globals->GetVariableByName(expected.name);
    if (variable == nullptr) {
      Fail(std::string{"generated parameter was optimized out or is absent: "}
           + expected.name);
    }
    D3D11_SHADER_VARIABLE_DESC variable_description{};
    CheckHr(
        variable->GetDesc(&variable_description),
        std::string{"reflection for generated parameter "} + expected.name);
    D3D11_SHADER_TYPE_DESC type_description{};
    CheckHr(
        variable->GetType()->GetDesc(&type_description),
        std::string{"type reflection for generated parameter "} + expected.name);

    const UINT component_count = expected.shape == ParameterShape::color3 ? 3U : 1U;
    const UINT expected_size = component_count * sizeof(float);
    const bool expected_boolean = expected.shape == ParameterShape::boolean;
    const D3D_SHADER_VARIABLE_TYPE expected_type =
        expected_boolean ? D3D_SVT_BOOL : D3D_SVT_FLOAT;
    const D3D_SHADER_VARIABLE_CLASS expected_class =
        expected.shape == ParameterShape::color3
        ? D3D_SVC_VECTOR
        : D3D_SVC_SCALAR;
    if (variable_description.Size != expected_size
        || type_description.Type != expected_type
        || type_description.Class != expected_class
        || type_description.Rows != 1U
        || type_description.Columns != component_count) {
      Fail(std::string{"generated parameter has the wrong reflected type: "}
           + expected.name);
    }
    if (variable_description.DefaultValue == nullptr) {
      Fail(std::string{"generated parameter has no reflected default: "}
           + expected.name);
    }
    if (variable_description.StartOffset > result.bytes.size()
        || variable_description.Size
            > result.bytes.size() - variable_description.StartOffset) {
      Fail(std::string{"generated parameter lies outside $Globals: "}
           + expected.name);
    }

    auto* destination = result.bytes.data() + variable_description.StartOffset;
    if (expected_boolean) {
      std::uint32_t reflected{};
      std::memcpy(
          &reflected, variable_description.DefaultValue, sizeof(reflected));
      if (reflected == 0U) {
        std::ostringstream message;
        message << "generated ElderMasterEnabled default is not true: "
                << reflected << " (0x" << std::hex << reflected << ')';
        Fail(message.str());
      }
      std::memcpy(destination, &reflected, sizeof(reflected));
      continue;
    }

    std::array<float, 3U> reflected{};
    std::memcpy(
        reflected.data(), variable_description.DefaultValue,
        variable_description.Size);
    for (UINT component = 0U; component < component_count; ++component) {
      if (!NearDefault(reflected[component], expected.value[component])) {
        std::ostringstream message;
        message << "generated default drift for " << expected.name
                << '[' << component << "]: reflected="
                << std::setprecision(9) << reflected[component]
                << " cpu=" << expected.value[component];
        Fail(message.str());
      }
    }
    std::memcpy(destination, expected.value.data(), variable_description.Size);
  }
  return result;
}

[[nodiscard]] std::vector<Sample> BuildAdversarialSamples() {
  std::vector<Sample> samples;
  const auto add = [&](std::string label, const float red, const float green,
                       const float blue) {
    samples.push_back({std::move(label), {red, green, blue, 0.0F}});
  };

  add("exact black", 0.0F, 0.0F, 0.0F);
  add("near-black neutral below epsilon", 1.0e-8F, 1.0e-8F, 1.0e-8F);
  add("near-black sparse red", 1.0e-6F, 0.0F, 0.0F);
  add("near-black sparse green", 0.0F, 1.0e-6F, 0.0F);
  add("near-black sparse blue", 0.0F, 0.0F, 1.0e-6F);

  constexpr std::array<float, 12U> boundaries{
      0.08F, 0.18F, 0.45F, 0.55F, 0.62F, 1.0F,
      2.0F, 11.2F, 16.0F, 31.999F, 32.0F, 1.0e-4F,
  };
  for (const float boundary : boundaries) {
    const std::array<float, 3U> neighborhood{
        std::nextafter(boundary, 0.0F), boundary,
        std::nextafter(boundary, std::numeric_limits<float>::infinity()),
    };
    for (std::size_t index = 0U; index < neighborhood.size(); ++index) {
      const float value = neighborhood[index];
      std::ostringstream label;
      label << "neutral boundary " << std::setprecision(9) << boundary
            << " neighbor " << index;
      add(label.str(), value, value, value);
    }
  }

  add("HDR red primary", 32.0F, 0.0F, 0.0F);
  add("HDR green primary", 0.0F, 32.0F, 0.0F);
  add("HDR blue primary", 0.0F, 0.0F, 32.0F);
  add("HDR white", 32.0F, 32.0F, 32.0F);
  add("HDR lopsided warm", 32.0F, 0.001F, 16.0F);
  add("HDR lopsided cool", 0.001F, 16.0F, 32.0F);
  add("extreme HDR maximum lower neighbor",
      std::nextafter(65536.0F, 0.0F),
      std::nextafter(65536.0F, 0.0F),
      std::nextafter(65536.0F, 0.0F));
  add("extreme HDR maximum", 65536.0F, 65536.0F, 65536.0F);
  add("extreme HDR red primary", 65536.0F, 0.0F, 0.0F);
  add("extreme HDR green primary", 0.0F, 65536.0F, 0.0F);
  add("extreme HDR blue primary", 0.0F, 0.0F, 65536.0F);
  add("gamut boundary red high", 1.0001F, 0.9999F, 0.5F);
  add("gamut boundary green high", 0.5F, 1.0001F, 0.9999F);
  add("gamut boundary blue high", 0.9999F, 0.5F, 1.0001F);
  add("mixed shadow chroma", 0.001F, 0.08F, 0.45F);
  add("mixed midtone chroma", 0.18F, 0.62F, 1.0F);
  add("mixed HDR chroma", 2.0F, 11.2F, 32.0F);

  constexpr std::array<float, 10U> grid{
      0.0F, 1.0e-6F, 0.08F, 0.18F, 0.62F,
      1.0F, 2.0F, 11.2F, 32.0F, 65536.0F,
  };
  for (std::size_t red = 0U; red < grid.size(); ++red) {
    for (std::size_t green = 0U; green < grid.size(); ++green) {
      for (std::size_t blue = 0U; blue < grid.size(); ++blue) {
        std::ostringstream label;
        label << "grid[" << red << ',' << green << ',' << blue << ']';
        add(label.str(), grid[red], grid[green], grid[blue]);
      }
    }
  }

  for (std::size_t index = 0U; index < samples.size(); ++index) {
    samples[index].scene.w =
        0.125F * static_cast<float>(1U + (index % 7U));
  }
  return samples;
}

struct WarpDevice {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
};

[[nodiscard]] WarpDevice CreateWarpDevice() {
  constexpr UINT flags = D3D11_CREATE_DEVICE_SINGLETHREADED;
  constexpr std::array<D3D_FEATURE_LEVEL, 2U> feature_levels{
      D3D_FEATURE_LEVEL_11_1,
      D3D_FEATURE_LEVEL_11_0,
  };
  WarpDevice result;
  D3D_FEATURE_LEVEL selected{};
  HRESULT creation = D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_WARP, nullptr, flags,
      feature_levels.data(), static_cast<UINT>(feature_levels.size()),
      D3D11_SDK_VERSION, &result.device, &selected, &result.context);
  if (creation == E_INVALIDARG) {
    creation = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_WARP, nullptr, flags,
        feature_levels.data() + 1U, 1U, D3D11_SDK_VERSION,
        &result.device, &selected, &result.context);
  }
  CheckHr(creation, "D3D11CreateDevice(WARP)");
  if (selected < D3D_FEATURE_LEVEL_11_0) {
    Fail("D3D11 WARP did not provide feature level 11_0");
  }
  return result;
}

[[nodiscard]] ComPtr<ID3D11Buffer> CreateStructuredBuffer(
    ID3D11Device& device,
    const UINT byte_width,
    const UINT bind_flags,
    const void* initial_data) {
  D3D11_BUFFER_DESC description{};
  description.ByteWidth = byte_width;
  description.Usage = D3D11_USAGE_DEFAULT;
  description.BindFlags = bind_flags;
  description.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
  description.StructureByteStride = sizeof(GpuFloat4);
  D3D11_SUBRESOURCE_DATA data{};
  data.pSysMem = initial_data;
  ComPtr<ID3D11Buffer> buffer;
  CheckHr(
      device.CreateBuffer(
          &description, initial_data == nullptr ? nullptr : &data, &buffer),
      "ID3D11Device::CreateBuffer(structured)");
  return buffer;
}

[[nodiscard]] std::vector<GpuFloat4> ExecuteProbe(
    WarpDevice& warp,
    const CompiledProbe& probe,
    const ReflectedGlobals& globals,
    const std::vector<Sample>& samples) {
  if (samples.empty()) Fail("WARP parity corpus is empty");
  const std::uint64_t byte_width_64 = samples.size() * sizeof(GpuFloat4);
  if (byte_width_64 > std::numeric_limits<UINT>::max()) {
    Fail("WARP parity corpus is too large for a D3D11 buffer");
  }
  const auto byte_width = static_cast<UINT>(byte_width_64);

  std::vector<GpuFloat4> input_values;
  input_values.reserve(samples.size());
  for (const Sample& sample : samples) input_values.push_back(sample.scene);

  ComPtr<ID3D11ComputeShader> shader;
  CheckHr(
      warp.device->CreateComputeShader(
          probe.bytecode->GetBufferPointer(), probe.bytecode->GetBufferSize(),
          nullptr, &shader),
      "ID3D11Device::CreateComputeShader");
  const ComPtr<ID3D11Buffer> input = CreateStructuredBuffer(
      *warp.device.Get(), byte_width, D3D11_BIND_SHADER_RESOURCE,
      input_values.data());
  const ComPtr<ID3D11Buffer> output = CreateStructuredBuffer(
      *warp.device.Get(), byte_width, D3D11_BIND_UNORDERED_ACCESS, nullptr);

  D3D11_SHADER_RESOURCE_VIEW_DESC srv_description{};
  srv_description.Format = DXGI_FORMAT_UNKNOWN;
  srv_description.ViewDimension = D3D11_SRV_DIMENSION_BUFFER;
  srv_description.Buffer.NumElements = static_cast<UINT>(samples.size());
  ComPtr<ID3D11ShaderResourceView> input_view;
  CheckHr(
      warp.device->CreateShaderResourceView(
          input.Get(), &srv_description, &input_view),
      "ID3D11Device::CreateShaderResourceView");

  D3D11_UNORDERED_ACCESS_VIEW_DESC uav_description{};
  uav_description.Format = DXGI_FORMAT_UNKNOWN;
  uav_description.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
  uav_description.Buffer.NumElements = static_cast<UINT>(samples.size());
  ComPtr<ID3D11UnorderedAccessView> output_view;
  CheckHr(
      warp.device->CreateUnorderedAccessView(
          output.Get(), &uav_description, &output_view),
      "ID3D11Device::CreateUnorderedAccessView");

  D3D11_BUFFER_DESC constant_description{};
  constant_description.ByteWidth = static_cast<UINT>(globals.bytes.size());
  constant_description.Usage = D3D11_USAGE_IMMUTABLE;
  constant_description.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
  D3D11_SUBRESOURCE_DATA constant_data{};
  constant_data.pSysMem = globals.bytes.data();
  ComPtr<ID3D11Buffer> constants;
  CheckHr(
      warp.device->CreateBuffer(
          &constant_description, &constant_data, &constants),
      "ID3D11Device::CreateBuffer($Globals)");

  D3D11_BUFFER_DESC staging_description{};
  staging_description.ByteWidth = byte_width;
  staging_description.Usage = D3D11_USAGE_STAGING;
  staging_description.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  ComPtr<ID3D11Buffer> staging;
  CheckHr(
      warp.device->CreateBuffer(&staging_description, nullptr, &staging),
      "ID3D11Device::CreateBuffer(staging)");

  ID3D11Buffer* constant_pointer = constants.Get();
  ID3D11ShaderResourceView* input_pointer = input_view.Get();
  ID3D11UnorderedAccessView* output_pointer = output_view.Get();
  warp.context->CSSetShader(shader.Get(), nullptr, 0U);
  warp.context->CSSetConstantBuffers(
      globals.bind_point, 1U, &constant_pointer);
  warp.context->CSSetShaderResources(0U, 1U, &input_pointer);
  warp.context->CSSetUnorderedAccessViews(
      0U, 1U, &output_pointer, nullptr);
  const auto group_count = static_cast<UINT>(
      (samples.size() + kThreadsPerGroup - 1U) / kThreadsPerGroup);
  warp.context->Dispatch(group_count, 1U, 1U);

  ID3D11ShaderResourceView* null_srv = nullptr;
  ID3D11UnorderedAccessView* null_uav = nullptr;
  ID3D11Buffer* null_buffer = nullptr;
  warp.context->CSSetShaderResources(0U, 1U, &null_srv);
  warp.context->CSSetUnorderedAccessViews(0U, 1U, &null_uav, nullptr);
  warp.context->CSSetConstantBuffers(globals.bind_point, 1U, &null_buffer);
  warp.context->CSSetShader(nullptr, nullptr, 0U);
  warp.context->CopyResource(staging.Get(), output.Get());

  D3D11_MAPPED_SUBRESOURCE mapped{};
  CheckHr(
      warp.context->Map(
          staging.Get(), 0U, D3D11_MAP_READ, 0U, &mapped),
      "ID3D11DeviceContext::Map");
  std::vector<GpuFloat4> gpu_results(samples.size());
  std::memcpy(gpu_results.data(), mapped.pData, byte_width);
  warp.context->Unmap(staging.Get(), 0U);
  return gpu_results;
}

void CompareComponent(
    ComparisonReport& report,
    const Sample& sample,
    const std::size_t sample_index,
    const char channel,
    const float cpu,
    const float gpu) {
  if (!std::isfinite(gpu)) {
    report.Expect(
        false, sample.label + " GPU channel " + channel + " is non-finite");
    return;
  }
  const float error = std::fabs(cpu - gpu);
  const float scale = std::max(std::fabs(cpu), std::fabs(gpu));
  const float relative = scale == 0.0F ? 0.0F : error / scale;
  if (error > report.maximum_absolute_error) {
    report.maximum_absolute_error = error;
    report.worst_component = sample.label + " channel " + channel;
  }
  report.maximum_relative_error =
      std::max(report.maximum_relative_error, relative);
  const float allowed = kAbsoluteTolerance + (kRelativeTolerance * scale);
  if (error <= allowed) {
    report.Expect(true, {});
    return;
  }
  std::ostringstream message;
  message << sample.label << " (#" << sample_index << ") channel " << channel
          << " diverged: cpu=" << std::setprecision(9) << cpu
          << " gpu=" << gpu << " abs_error=" << error
          << " allowed=" << allowed;
  report.Expect(false, message.str());
}

[[nodiscard]] ComparisonReport CompareCpuAndGpu(
    const std::vector<Sample>& samples,
    const std::vector<GpuFloat4>& gpu_results,
    const ColorCoreParameters& parameters) {
  if (samples.size() != gpu_results.size()) {
    Fail("CPU and WARP result counts differ");
  }
  ComparisonReport report;
  for (std::size_t index = 0U; index < samples.size(); ++index) {
    const Sample& sample = samples[index];
    const GpuFloat4& gpu = gpu_results[index];
    ColorCoreOutput cpu{};
    const auto evaluation = EvaluateColorCore(
        ColorCoreInput{
            LinearRgb{sample.scene.x, sample.scene.y, sample.scene.z},
            parameters,
        },
        cpu);
    report.Expect(evaluation.ok(), sample.label + " was rejected by CPU core");
    if (!evaluation.ok()) continue;

    CompareComponent(
        report, sample, index, 'R', cpu.display_linear.r, gpu.x);
    CompareComponent(
        report, sample, index, 'G', cpu.display_linear.g, gpu.y);
    CompareComponent(
        report, sample, index, 'B', cpu.display_linear.b, gpu.z);
    report.Expect(
        std::bit_cast<std::uint32_t>(gpu.w)
            == std::bit_cast<std::uint32_t>(sample.scene.w),
        sample.label + " dispatch sentinel did not round-trip");
  }
  report.Expect(
      std::bit_cast<std::uint32_t>(gpu_results.front().x) == 0U
          && std::bit_cast<std::uint32_t>(gpu_results.front().y) == 0U
          && std::bit_cast<std::uint32_t>(gpu_results.front().z) == 0U,
      "exact black was not exact positive zero on WARP");
  return report;
}

void ValidateProbeReflection(ID3D11ShaderReflection& reflection) {
  D3D11_SHADER_DESC description{};
  CheckHr(reflection.GetDesc(&description), "compute shader reflection");
  if (D3D11_SHVER_GET_TYPE(description.Version)
          != D3D11_SHVER_COMPUTE_SHADER
      || D3D11_SHVER_GET_MAJOR(description.Version) != 5U
      || D3D11_SHVER_GET_MINOR(description.Version) != 0U) {
    Fail("WARP probe did not compile as a cs_5_0 compute shader");
  }
  UINT thread_x{};
  UINT thread_y{};
  UINT thread_z{};
  const UINT total_threads =
      reflection.GetThreadGroupSize(&thread_x, &thread_y, &thread_z);
  if (thread_x != kThreadsPerGroup || thread_y != 1U || thread_z != 1U
      || total_threads != kThreadsPerGroup) {
    Fail("WARP probe has an unexpected thread-group shape");
  }
  ValidateResourceBinding(
      reflection, "ElderWarpSceneValues", D3D_SIT_STRUCTURED, 0U);
  ValidateResourceBinding(
      reflection, "ElderWarpResults", D3D_SIT_UAV_RWSTRUCTURED, 0U);
}

}  // namespace

int wmain(const int argument_count, wchar_t* arguments[]) {
  try {
    if (argument_count != 3) {
      std::cerr << "usage: elder_native_color_core_warp_tests "
                   "<ElderColorWarpProbe.hlsl> <generated-include-directory>\n";
      return 2;
    }
    const std::filesystem::path shader_path =
        std::filesystem::weakly_canonical(arguments[1]);
    const std::filesystem::path generated_include_directory =
        std::filesystem::weakly_canonical(arguments[2]);

    const CompiledProbe probe =
        CompileProbe(shader_path, generated_include_directory);
    ValidateProbeReflection(*probe.reflection.Get());
    const ColorCoreParameters parameters = DefaultColorCoreParameters();
    const ReflectedGlobals globals =
        ReflectAndBindDefaults(*probe.reflection.Get(), parameters);
    const std::vector<Sample> samples = BuildAdversarialSamples();
    WarpDevice warp = CreateWarpDevice();
    const std::vector<GpuFloat4> gpu_results =
        ExecuteProbe(warp, probe, globals, samples);
    const ComparisonReport report =
        CompareCpuAndGpu(samples, gpu_results, parameters);

    if (report.failures != 0U) {
      for (const std::string& message : report.messages) {
        std::cerr << "[FAIL] " << message << '\n';
      }
      if (report.failures > report.messages.size()) {
        std::cerr << "[FAIL] " << (report.failures - report.messages.size())
                  << " additional failures suppressed\n";
      }
      std::cerr << report.failures << " failures across "
                << report.assertions << " assertions\n";
      return 1;
    }

    std::cout << "Elder CPU<->D3D11 WARP parity passed: "
              << samples.size() << " adversarial vectors, "
              << report.assertions << " assertions, abs_tol="
              << kAbsoluteTolerance << ", rel_tol=" << kRelativeTolerance
              << ", max_abs_error=" << report.maximum_absolute_error
              << ", max_rel_error=" << report.maximum_relative_error
              << ", worst=" << report.worst_component << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "[FAIL] Elder CPU<->D3D11 WARP parity harness: "
              << error.what() << '\n';
    return 1;
  }
}
