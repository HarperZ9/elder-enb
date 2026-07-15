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
#include <iostream>
#include <limits>
#include <map>
#include <new>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
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
      std::filesystem::path generated_directory)
      : shader_directory_(Canonical(std::move(shader_directory))),
        generated_directory_(Canonical(std::move(generated_directory))) {}

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
    if (requested == kGeneratedIncludeName) root = &generated_directory_;
    if (requested == kColorCoreIncludeName) root = &shader_directory_;
    if (root == nullptr) return E_ACCESSDENIED;
    try {
      const auto candidate = std::filesystem::weakly_canonical(*root / file_name);
      if (!IsWithin(*root, candidate)
          || !std::filesystem::is_regular_file(candidate)) {
        return E_ACCESSDENIED;
      }
      std::ifstream stream(candidate, std::ios::binary | std::ios::ate);
      const std::streamoff length = stream.tellg();
      if (!stream || length < 0
          || static_cast<std::uint64_t>(length)
              > std::numeric_limits<UINT>::max()) {
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
  [[nodiscard]] static std::filesystem::path Canonical(
      std::filesystem::path directory) {
    auto result = std::filesystem::weakly_canonical(std::move(directory));
    if (!std::filesystem::is_directory(result)) {
      Fail("shader include directory does not exist");
    }
    return result;
  }

  std::filesystem::path shader_directory_;
  std::filesystem::path generated_directory_;
};

struct CompiledShader {
  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3D11ShaderReflection> reflection;
};

[[nodiscard]] CompiledShader CompilePixelShader(
    const std::filesystem::path& shader_path,
    const std::filesystem::path& generated_directory) {
  IncludeResolver includes(shader_path.parent_path(), generated_directory);
  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3DBlob> diagnostics;
  constexpr UINT flags = D3DCOMPILE_ENABLE_STRICTNESS
      | D3DCOMPILE_WARNINGS_ARE_ERRORS
      | D3DCOMPILE_IEEE_STRICTNESS
      | D3DCOMPILE_OPTIMIZATION_LEVEL3;
  const HRESULT result = D3DCompileFromFile(
      shader_path.c_str(), nullptr, &includes,
      "ElderColorReferencePixelMain", "ps_5_0", flags, 0U,
      &bytecode, &diagnostics);
  if (FAILED(result)) {
    Fail("production pixel shader compilation failed:\n"
         + BlobText(diagnostics.Get()));
  }
  if (diagnostics != nullptr && diagnostics->GetBufferSize() != 0U) {
    Fail("production pixel shader emitted diagnostics:\n"
         + BlobText(diagnostics.Get()));
  }
  ComPtr<ID3D11ShaderReflection> reflection;
  CheckHr(D3DReflect(
              bytecode->GetBufferPointer(), bytecode->GetBufferSize(),
              __uuidof(ID3D11ShaderReflection),
              reinterpret_cast<void**>(reflection.GetAddressOf())),
          "D3DReflect(production pixel shader)");
  return {std::move(bytecode), std::move(reflection)};
}

[[nodiscard]] ComPtr<ID3DBlob> CompileVertexShader() {
  constexpr char source[] =
      "float4 main(uint id : SV_VertexID) : SV_Position {"
      "float2 p = id == 0 ? float2(-1,-1) : "
      "(id == 1 ? float2(-1,3) : float2(3,-1));"
      "return float4(p,0,1);}";
  ComPtr<ID3DBlob> bytecode;
  ComPtr<ID3DBlob> diagnostics;
  constexpr UINT flags = D3DCOMPILE_ENABLE_STRICTNESS
      | D3DCOMPILE_WARNINGS_ARE_ERRORS
      | D3DCOMPILE_IEEE_STRICTNESS
      | D3DCOMPILE_OPTIMIZATION_LEVEL3;
  const HRESULT result = D3DCompile(
      source, sizeof(source) - 1U, "ElderWarpFullscreenVertex", nullptr,
      nullptr, "main", "vs_5_0", flags, 0U, &bytecode, &diagnostics);
  if (FAILED(result)) {
    Fail("fullscreen vertex shader compilation failed:\n"
         + BlobText(diagnostics.Get()));
  }
  return bytecode;
}

struct ReflectedBuffer {
  UINT bind_point{};
  std::vector<std::byte> bytes;
  ID3D11ShaderReflectionConstantBuffer* reflection{};
};

[[nodiscard]] ReflectedBuffer ReflectBuffer(
    ID3D11ShaderReflection& reflection,
    const char* name) {
  D3D11_SHADER_INPUT_BIND_DESC binding{};
  CheckHr(reflection.GetResourceBindingDescByName(name, &binding),
          std::string{"resource reflection for "} + name);
  if (binding.Type != D3D_SIT_CBUFFER || binding.BindCount != 1U) {
    Fail(std::string{"unexpected constant-buffer binding for "} + name);
  }
  auto* buffer = reflection.GetConstantBufferByName(name);
  if (buffer == nullptr) Fail(std::string{"missing constant buffer "} + name);
  D3D11_SHADER_BUFFER_DESC description{};
  CheckHr(buffer->GetDesc(&description),
          std::string{"constant-buffer reflection for "} + name);
  ReflectedBuffer result{
      binding.BindPoint,
      std::vector<std::byte>(description.Size, std::byte{0}),
      buffer,
  };
  for (UINT index = 0U; index < description.Variables; ++index) {
    auto* variable = buffer->GetVariableByIndex(index);
    D3D11_SHADER_VARIABLE_DESC variable_description{};
    CheckHr(variable->GetDesc(&variable_description), "variable reflection");
    if (variable_description.DefaultValue != nullptr) {
      std::memcpy(result.bytes.data() + variable_description.StartOffset,
                  variable_description.DefaultValue,
                  variable_description.Size);
    }
  }
  return result;
}

template <class T>
void SetVariable(
    ReflectedBuffer& buffer,
    const char* name,
    const T& value) {
  auto* variable = buffer.reflection->GetVariableByName(name);
  if (variable == nullptr) Fail(std::string{"missing shader variable "} + name);
  D3D11_SHADER_VARIABLE_DESC description{};
  CheckHr(variable->GetDesc(&description),
          std::string{"variable reflection for "} + name);
  if (description.Size != sizeof(T)
      || description.StartOffset > buffer.bytes.size()
      || description.Size > buffer.bytes.size() - description.StartOffset) {
    Fail(std::string{"unexpected shader variable layout for "} + name);
  }
  std::memcpy(buffer.bytes.data() + description.StartOffset,
              &value, sizeof(T));
}

void SetBool(ReflectedBuffer& buffer, const char* name, const bool value) {
  const std::uint32_t encoded = value ? 1U : 0U;
  SetVariable(buffer, name, encoded);
}

void SetColorParameters(
    ReflectedBuffer& globals,
    const ColorCoreParameters& parameters) {
  SetVariable(globals, "ElderExposureCompensationEv", parameters.exposure_ev);
  SetVariable(globals, "ElderColorWarmCool", parameters.warm_cool);
  SetVariable(globals, "ElderColorTint", parameters.tint);
  SetVariable(globals, "ElderTonemapToe", parameters.toe);
  SetVariable(globals, "ElderTonemapShoulder", parameters.shoulder);
  SetVariable(globals, "ElderTonemapMidGray", parameters.mid_gray);
  SetVariable(globals, "ElderTonemapWhitePoint", parameters.white_point);
  SetVariable(globals, "ElderTonemapLocalContrast", parameters.local_contrast);
  SetVariable(globals, "ElderColorSaturation", parameters.saturation);
  SetVariable(globals, "ElderColorVibrance", parameters.vibrance);
  SetVariable(globals, "ElderHighlightDesaturation",
              parameters.highlight_desaturation);
  SetVariable(globals, "ElderHighlightGamutPreservation",
              parameters.highlight_gamut_preservation);
  SetVariable(globals, "ElderShadowHueStability",
              parameters.shadow_hue_stability);
  SetVariable(globals, "ElderShadowTint", parameters.shadow_tint);
  SetVariable(globals, "ElderHighlightTint", parameters.highlight_tint);
}

struct WarpRenderer {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
  ComPtr<ID3D11VertexShader> vertex_shader;
  ComPtr<ID3D11PixelShader> pixel_shader;
  ComPtr<ID3D11Texture2D> target;
  ComPtr<ID3D11RenderTargetView> target_view;
  ComPtr<ID3D11Texture2D> staging;
};

[[nodiscard]] WarpRenderer CreateRenderer(
    const CompiledShader& pixel,
    ID3DBlob& vertex_bytecode) {
  WarpRenderer result;
  D3D_FEATURE_LEVEL selected{};
  constexpr D3D_FEATURE_LEVEL levels[] = {
      D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0};
  HRESULT creation = D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_WARP, nullptr,
      D3D11_CREATE_DEVICE_SINGLETHREADED, levels, 2U,
      D3D11_SDK_VERSION, &result.device, &selected, &result.context);
  if (creation == E_INVALIDARG) {
    creation = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_WARP, nullptr,
        D3D11_CREATE_DEVICE_SINGLETHREADED, levels + 1U, 1U,
        D3D11_SDK_VERSION, &result.device, &selected, &result.context);
  }
  CheckHr(creation, "D3D11CreateDevice(WARP pixel)");
  CheckHr(result.device->CreateVertexShader(
              vertex_bytecode.GetBufferPointer(),
              vertex_bytecode.GetBufferSize(), nullptr, &result.vertex_shader),
          "CreateVertexShader");
  CheckHr(result.device->CreatePixelShader(
              pixel.bytecode->GetBufferPointer(),
              pixel.bytecode->GetBufferSize(), nullptr, &result.pixel_shader),
          "CreatePixelShader(production)");

  D3D11_TEXTURE2D_DESC target_description{};
  target_description.Width = 1U;
  target_description.Height = 1U;
  target_description.MipLevels = 1U;
  target_description.ArraySize = 1U;
  target_description.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
  target_description.SampleDesc.Count = 1U;
  target_description.Usage = D3D11_USAGE_DEFAULT;
  target_description.BindFlags = D3D11_BIND_RENDER_TARGET;
  CheckHr(result.device->CreateTexture2D(
              &target_description, nullptr, &result.target),
          "CreateTexture2D(render target)");
  CheckHr(result.device->CreateRenderTargetView(
              result.target.Get(), nullptr, &result.target_view),
          "CreateRenderTargetView");
  target_description.Usage = D3D11_USAGE_STAGING;
  target_description.BindFlags = 0U;
  target_description.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  CheckHr(result.device->CreateTexture2D(
              &target_description, nullptr, &result.staging),
          "CreateTexture2D(staging)");
  return result;
}

[[nodiscard]] ComPtr<ID3D11Buffer> UploadBuffer(
    WarpRenderer& renderer,
    const ReflectedBuffer& source) {
  D3D11_BUFFER_DESC description{};
  description.ByteWidth = static_cast<UINT>(source.bytes.size());
  description.Usage = D3D11_USAGE_IMMUTABLE;
  description.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
  D3D11_SUBRESOURCE_DATA data{};
  data.pSysMem = source.bytes.data();
  ComPtr<ID3D11Buffer> result;
  CheckHr(renderer.device->CreateBuffer(&description, &data, &result),
          "CreateBuffer(pixel constants)");
  return result;
}

[[nodiscard]] std::array<float, 4U> Render(
    WarpRenderer& renderer,
    const ReflectedBuffer& globals,
    const ReflectedBuffer& reference) {
  const auto globals_buffer = UploadBuffer(renderer, globals);
  const auto reference_buffer = UploadBuffer(renderer, reference);
  std::array<ID3D11Buffer*, D3D11_COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT>
      buffers{};
  buffers[globals.bind_point] = globals_buffer.Get();
  buffers[reference.bind_point] = reference_buffer.Get();
  if (globals.bind_point == reference.bind_point) {
    Fail("production shader constant buffers alias one register");
  }
  D3D11_VIEWPORT viewport{};
  viewport.Width = 1.0F;
  viewport.Height = 1.0F;
  viewport.MaxDepth = 1.0F;
  ID3D11RenderTargetView* target = renderer.target_view.Get();
  renderer.context->OMSetRenderTargets(1U, &target, nullptr);
  renderer.context->RSSetViewports(1U, &viewport);
  renderer.context->IASetPrimitiveTopology(
      D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
  renderer.context->VSSetShader(renderer.vertex_shader.Get(), nullptr, 0U);
  renderer.context->PSSetShader(renderer.pixel_shader.Get(), nullptr, 0U);
  renderer.context->PSSetConstantBuffers(
      0U, static_cast<UINT>(buffers.size()), buffers.data());
  renderer.context->Draw(3U, 0U);
  renderer.context->CopyResource(renderer.staging.Get(), renderer.target.Get());
  D3D11_MAPPED_SUBRESOURCE mapped{};
  CheckHr(renderer.context->Map(
              renderer.staging.Get(), 0U, D3D11_MAP_READ, 0U, &mapped),
          "Map(production pixel output)");
  std::array<float, 4U> result{};
  std::memcpy(result.data(), mapped.pData, sizeof(result));
  renderer.context->Unmap(renderer.staging.Get(), 0U);
  return result;
}

struct TestContext {
  std::size_t assertions{};
  std::vector<std::string> failures;

  void Expect(const bool condition, std::string message) {
    ++assertions;
    if (!condition) failures.push_back(std::move(message));
  }
};

[[nodiscard]] bool Near(const float actual, const float expected) {
  const float difference = std::fabs(actual - expected);
  return std::isfinite(actual)
      && difference <= 2.0e-5F
          + (4.0e-5F * std::max(std::fabs(actual), std::fabs(expected)));
}

void ExpectOutput(
    TestContext& context,
    const std::array<float, 4U>& actual,
    const LinearRgb expected,
    const std::string& label) {
  context.Expect(Near(actual[0], expected.r), label + " red mismatch");
  context.Expect(Near(actual[1], expected.g), label + " green mismatch");
  context.Expect(Near(actual[2], expected.b), label + " blue mismatch");
  context.Expect(std::bit_cast<std::uint32_t>(actual[3])
                     == std::bit_cast<std::uint32_t>(1.0F),
                 label + " alpha mismatch");
}

[[nodiscard]] LinearRgb CpuExpected(
    const LinearRgb scene,
    const ColorCoreParameters& parameters) {
  ColorCoreOutput output{};
  const auto result = EvaluateColorCore(ColorCoreInput{scene, parameters}, output);
  if (!result.ok()) Fail("CPU reference rejected a WARP production case");
  return output.display_linear;
}

void ExerciseProductionShader(
    TestContext& context,
    WarpRenderer& renderer,
    ReflectedBuffer globals,
    ReflectedBuffer reference) {
  const auto evaluate = [&](const char* label,
                            const LinearRgb scene,
                            const ColorCoreParameters& parameters,
                            const bool enabled) {
    ReflectedBuffer case_globals = globals;
    ReflectedBuffer case_reference = reference;
    SetBool(case_globals, "ElderMasterEnabled", enabled);
    SetColorParameters(case_globals, parameters);
    SetVariable(case_reference, "ElderReferenceSceneLinear", scene);
    const auto actual = Render(renderer, case_globals, case_reference);
    const LinearRgb expected = enabled ? CpuExpected(scene, parameters) : scene;
    ExpectOutput(context, actual, expected, label);
  };

  const ColorCoreParameters defaults = DefaultColorCoreParameters();
  evaluate("generated defaults", {0.18F, 0.62F, 2.0F}, defaults, true);

  ColorCoreParameters minimums = defaults;
  minimums.exposure_ev = -8.0F;
  minimums.warm_cool = -1.0F;
  minimums.tint = -1.0F;
  minimums.toe = 0.0F;
  minimums.shoulder = 0.0F;
  minimums.mid_gray = 0.05F;
  minimums.white_point = 1.0F;
  minimums.local_contrast = 0.0F;
  minimums.saturation = 0.0F;
  minimums.vibrance = -1.0F;
  minimums.highlight_desaturation = 0.0F;
  minimums.highlight_gamut_preservation = 0.0F;
  minimums.shadow_hue_stability = 0.0F;
  minimums.shadow_tint = {};
  minimums.highlight_tint = {};
  evaluate("all generated minimums", {0.18F, 0.62F, 2.0F}, minimums, true);

  ColorCoreParameters maximums = defaults;
  maximums.exposure_ev = 8.0F;
  maximums.warm_cool = 1.0F;
  maximums.tint = 1.0F;
  maximums.toe = 1.0F;
  maximums.shoulder = 1.0F;
  maximums.mid_gray = 0.5F;
  maximums.white_point = 32.0F;
  maximums.local_contrast = 2.0F;
  maximums.saturation = 2.0F;
  maximums.vibrance = 1.0F;
  maximums.highlight_desaturation = 1.0F;
  maximums.highlight_gamut_preservation = 1.0F;
  maximums.shadow_hue_stability = 1.0F;
  maximums.shadow_tint = {2.0F, 2.0F, 2.0F};
  maximums.highlight_tint = {2.0F, 2.0F, 2.0F};
  evaluate("all generated maximums", {0.18F, 0.62F, 2.0F}, maximums, true);

  ColorCoreParameters profile = defaults;
  profile.exposure_ev = -0.7F;
  profile.warm_cool = 0.35F;
  profile.tint = -0.2F;
  profile.toe = 0.31F;
  profile.shoulder = 0.67F;
  profile.local_contrast = 0.48F;
  profile.saturation = 1.12F;
  profile.vibrance = 0.24F;
  profile.shadow_tint = {0.92F, 1.0F, 1.08F};
  profile.highlight_tint = {1.06F, 1.0F, 0.94F};
  evaluate("representative authored profile", {0.08F, 0.45F, 11.2F},
           profile, true);
  evaluate("master-disabled passthrough", {0.08F, 0.45F, 11.2F},
           profile, false);

  ReflectedBuffer invalid_globals = globals;
  ReflectedBuffer valid_reference = reference;
  SetBool(invalid_globals, "ElderMasterEnabled", true);
  SetColorParameters(invalid_globals, defaults);
  const float quiet_nan = std::bit_cast<float>(0x7fc12345U);
  SetVariable(invalid_globals, "ElderExposureCompensationEv", quiet_nan);
  const LinearRgb scene{0.18F, 0.62F, 2.0F};
  SetVariable(valid_reference, "ElderReferenceSceneLinear", scene);
  ExpectOutput(context, Render(renderer, invalid_globals, valid_reference),
               CpuExpected(scene, defaults), "NaN parameter sanitizer");
  SetVariable(invalid_globals, "ElderExposureCompensationEv",
              std::numeric_limits<float>::infinity());
  ExpectOutput(context, Render(renderer, invalid_globals, valid_reference),
               CpuExpected(scene, defaults), "infinite parameter sanitizer");

  constexpr const char* scalar_parameters[] = {
      "ElderExposureCompensationEv",
      "ElderColorWarmCool",
      "ElderColorTint",
      "ElderTonemapToe",
      "ElderTonemapShoulder",
      "ElderTonemapMidGray",
      "ElderTonemapWhitePoint",
      "ElderTonemapLocalContrast",
      "ElderColorSaturation",
      "ElderColorVibrance",
      "ElderHighlightDesaturation",
      "ElderHighlightGamutPreservation",
      "ElderShadowHueStability",
  };
  for (const char* parameter : scalar_parameters) {
    ReflectedBuffer invalid = globals;
    SetBool(invalid, "ElderMasterEnabled", true);
    SetColorParameters(invalid, defaults);
    SetVariable(invalid, parameter, quiet_nan);
    ExpectOutput(context, Render(renderer, invalid, valid_reference),
                 CpuExpected(scene, defaults),
                 std::string{"NaN sanitizer for "} + parameter);
  }
  for (const char* parameter : {"ElderShadowTint", "ElderHighlightTint"}) {
    ReflectedBuffer invalid = globals;
    SetBool(invalid, "ElderMasterEnabled", true);
    SetColorParameters(invalid, defaults);
    SetVariable(invalid, parameter, LinearRgb{1.0F, quiet_nan, 1.0F});
    ExpectOutput(context, Render(renderer, invalid, valid_reference),
                 CpuExpected(scene, defaults),
                 std::string{"NaN sanitizer for "} + parameter);
  }

  for (const bool enabled : {true, false}) {
    ReflectedBuffer case_globals = globals;
    SetBool(case_globals, "ElderMasterEnabled", enabled);
    SetColorParameters(case_globals, defaults);
    for (const float invalid : {
             quiet_nan,
             std::numeric_limits<float>::infinity(),
             -std::numeric_limits<float>::infinity()}) {
      ReflectedBuffer invalid_reference = reference;
      SetVariable(invalid_reference, "ElderReferenceSceneLinear",
                  LinearRgb{invalid, 0.18F, 0.18F});
      const auto actual = Render(renderer, case_globals, invalid_reference);
      ExpectOutput(context, actual, {},
                   enabled ? "enabled non-finite scene fail-closed"
                           : "disabled non-finite scene fail-closed");
    }
  }
}

}  // namespace

int wmain(const int argument_count, wchar_t* arguments[]) {
  try {
    if (argument_count != 3) {
      std::cerr << "usage: elder_native_color_reference_warp_tests "
                   "<ElderColorReference.hlsl> <generated-directory>\n";
      return 2;
    }
    const auto shader_path = std::filesystem::weakly_canonical(arguments[1]);
    const auto generated_directory =
        std::filesystem::weakly_canonical(arguments[2]);
    const CompiledShader pixel =
        CompilePixelShader(shader_path, generated_directory);
    const auto vertex = CompileVertexShader();
    auto renderer = CreateRenderer(pixel, *vertex.Get());
    auto globals = ReflectBuffer(*pixel.reflection.Get(), "$Globals");
    auto reference = ReflectBuffer(
        *pixel.reflection.Get(), "ElderColorReferenceParameters");
    TestContext context;
    ExerciseProductionShader(
        context, renderer, std::move(globals), std::move(reference));
    if (!context.failures.empty()) {
      for (const auto& failure : context.failures) {
        std::cerr << "[FAIL] " << failure << '\n';
      }
      std::cerr << context.failures.size() << " failures across "
                << context.assertions << " assertions\n";
      return 1;
    }
    std::cout << "Elder production pixel shader WARP cases passed: "
              << context.assertions << " assertions\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "[FAIL] Elder production pixel shader WARP harness: "
              << error.what() << '\n';
    return 1;
  }
}
