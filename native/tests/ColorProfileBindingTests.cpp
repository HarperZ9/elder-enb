#include "elder/shaders/ColorProfileBinding.hpp"

#include <bit>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace {

using elder::shaders::BindNativeColorProfile;
using elder::shaders::ColorBindingDiagnostic;
using elder::shaders::CompileNativeParameterArtifacts;
using elder::shaders::ComposeNativeProfileStack;
using elder::shaders::ComputeNativeSchemaFingerprint;
using elder::shaders::NativeArtifacts;
using elder::shaders::NativeColorBinding;
using elder::shaders::NativeParameterSchema;
using elder::shaders::NativeProfile;
using elder::shaders::ParseNativeParameterSchema;
using elder::shaders::ParseNativeProfile;

struct TestContext {
  std::size_t assertions{};
  std::vector<std::string> failures;

  void expect(const bool condition, std::string message) {
    ++assertions;
    if (!condition) failures.push_back(std::move(message));
  }
};

[[nodiscard]] std::string ReadAll(const std::filesystem::path& path) {
  std::ifstream stream{path, std::ios::binary};
  std::ostringstream bytes;
  bytes << stream.rdbuf();
  return bytes.str();
}

[[nodiscard]] bool SameFloat(const float left, const float right) noexcept {
  return std::bit_cast<std::uint32_t>(left)
      == std::bit_cast<std::uint32_t>(right);
}

[[nodiscard]] std::string LayerHeader(
    const NativeParameterSchema& schema) {
  return "profile=ELDER_NATIVE_PROFILE_V1\nparameter_schema="
      + schema.schema_id + "\nparameter_schema_sha256=" + schema.abi_sha256
      + "\nopacity=1\n[parameters]\n";
}

void DefaultProfileBindsGeneratedDefaults(
    TestContext& context,
    const NativeParameterSchema& schema,
    const NativeProfile& base) {
  NativeColorBinding binding;
  const auto result = BindNativeColorProfile(schema, base, binding);
  context.expect(result.ok(), "generated default profile did not bind");
  context.expect(binding.enabled, "generated default disabled the color core");
  const auto defaults = elder::shaders::DefaultColorCoreParameters();
  context.expect(SameFloat(binding.parameters.exposure_ev, defaults.exposure_ev)
                     && SameFloat(binding.parameters.warm_cool, defaults.warm_cool)
                     && SameFloat(binding.parameters.tint, defaults.tint)
                     && SameFloat(binding.parameters.mid_gray, defaults.mid_gray)
                     && SameFloat(
                         binding.parameters.highlight_gamut_preservation,
                         defaults.highlight_gamut_preservation),
                 "generated profile and CPU defaults drifted");
}

void TypedLayerBindsExactColorInputs(
    TestContext& context,
    const NativeParameterSchema& schema,
    const NativeProfile& base) {
  const std::string layer_source = LayerHeader(schema)
      + "elder.exposure.compensation_ev=-0.5\n"
        "elder.color.warm_cool=0.5\n"
        "elder.color.tint=-0.25\n"
        "elder.color.highlight_gamut_preservation=0.8\n"
        "elder.color.shadow_tint=0.9|1|1.1\n";
  NativeProfile layer;
  context.expect(ParseNativeProfile(
                     layer_source, schema, false, layer).ok(),
                 "typed color layer did not parse");
  NativeProfile composed;
  context.expect(ComposeNativeProfileStack(
                     schema, base, std::vector{layer}, composed).ok(),
                 "typed color layer did not compose");
  NativeColorBinding binding;
  context.expect(BindNativeColorProfile(schema, composed, binding).ok(),
                 "typed color layer did not bind");
  context.expect(binding.enabled
                     && SameFloat(binding.parameters.exposure_ev, -0.5F)
                     && SameFloat(binding.parameters.warm_cool, 0.5F)
                     && SameFloat(binding.parameters.tint, -0.25F)
                     && SameFloat(
                         binding.parameters.highlight_gamut_preservation,
                         0.8F)
                     && SameFloat(binding.parameters.shadow_tint.r, 0.9F)
                     && SameFloat(binding.parameters.shadow_tint.g, 1.0F)
                     && SameFloat(binding.parameters.shadow_tint.b, 1.1F),
                 "typed profile-to-core mapping changed values");
}

void MasterGateAndFingerprintFailClosed(
    TestContext& context,
    const NativeParameterSchema& schema,
    const NativeProfile& base) {
  NativeProfile disable;
  context.expect(ParseNativeProfile(
                     LayerHeader(schema) + "elder.master.enabled=false\n",
                     schema,
                     false,
                     disable).ok(),
                 "master-disable layer did not parse");
  NativeProfile disabled_profile;
  context.expect(ComposeNativeProfileStack(
                     schema, base, std::vector{disable}, disabled_profile).ok(),
                 "master-disable layer did not compose");
  NativeColorBinding disabled;
  context.expect(BindNativeColorProfile(
                     schema, disabled_profile, disabled).ok()
                     && !disabled.enabled,
                 "master dependency did not disable the color core");

  NativeProfile tampered = base;
  tampered.parameter_schema_sha256.assign(64U, '0');
  NativeColorBinding sentinel;
  sentinel.enabled = false;
  sentinel.parameters.exposure_ev = 7.0F;
  const auto rejected = BindNativeColorProfile(schema, tampered, sentinel);
  context.expect(rejected.diagnostic == ColorBindingDiagnostic::invalid_schema,
                 "wrong profile fingerprint was accepted");
  context.expect(!sentinel.enabled
                     && SameFloat(sentinel.parameters.exposure_ev, 7.0F),
                 "failed binding mutated its output");

  NativeParameterSchema newer_schema = schema;
  newer_schema.parameters.at(1U).ui_label = "Compensation (new binary)";
  newer_schema.abi_sha256 = ComputeNativeSchemaFingerprint(newer_schema);
  NativeProfile newer_profile = base;
  newer_profile.parameter_schema_sha256 = newer_schema.abi_sha256;
  NativeColorBinding stale_binary_sentinel;
  stale_binary_sentinel.enabled = false;
  stale_binary_sentinel.parameters.exposure_ev = 6.0F;
  const auto stale_binary = BindNativeColorProfile(
      newer_schema, newer_profile, stale_binary_sentinel);
  context.expect(stale_binary.diagnostic == ColorBindingDiagnostic::invalid_schema,
                 "schema newer than the generated binding binary was accepted");
  context.expect(!stale_binary_sentinel.enabled
                     && SameFloat(
                         stale_binary_sentinel.parameters.exposure_ev, 6.0F),
                 "stale-binary rejection mutated its output");

  NativeProfile unresolved_layer = base;
  unresolved_layer.opacity = 0.5;
  NativeColorBinding opacity_sentinel;
  opacity_sentinel.enabled = false;
  opacity_sentinel.parameters.exposure_ev = 5.0F;
  const auto opacity_result = BindNativeColorProfile(
      schema, unresolved_layer, opacity_sentinel);
  context.expect(opacity_result.diagnostic == ColorBindingDiagnostic::invalid_profile,
                 "uncomposed profile opacity was accepted by the runtime binding");
  context.expect(!opacity_sentinel.enabled
                     && SameFloat(opacity_sentinel.parameters.exposure_ev, 5.0F),
                 "opacity rejection mutated its output");
}

}  // namespace

int main(const int argument_count, const char* const* arguments) {
  if (argument_count != 2) {
    std::cerr << "usage: elder_native_color_profile_binding_tests <schema.csv>\n";
    return 2;
  }
  TestContext context;
  NativeParameterSchema schema;
  context.expect(ParseNativeParameterSchema(
                     ReadAll(arguments[1]), schema).ok(),
                 "production schema setup failed");
  NativeArtifacts artifacts;
  context.expect(CompileNativeParameterArtifacts(schema, artifacts).ok(),
                 "production artifact setup failed");
  NativeProfile base;
  context.expect(ParseNativeProfile(
                     artifacts.default_profile, schema, true, base).ok(),
                 "generated base-profile setup failed");
  if (context.failures.empty()) {
    DefaultProfileBindsGeneratedDefaults(context, schema, base);
    TypedLayerBindsExactColorInputs(context, schema, base);
    MasterGateAndFingerprintFailClosed(context, schema, base);
  }
  if (!context.failures.empty()) {
    for (const auto& failure : context.failures) {
      std::cerr << "[FAIL] " << failure << '\n';
    }
    std::cerr << context.failures.size() << " failures across "
              << context.assertions << " assertions\n";
    return 1;
  }
  std::cout << "Elder native color profile binding passed: "
            << context.assertions << " assertions\n";
  return 0;
}
