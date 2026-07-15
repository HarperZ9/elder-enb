#include "elder/shaders/ParameterSchema.hpp"

#include <bit>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace {

using elder::shaders::CompileNativeParameterArtifacts;
using elder::shaders::ComputeNativeSchemaFingerprint;
using elder::shaders::ComputeSha256;
using elder::shaders::ComposeNativeProfileStack;
using elder::shaders::EvaluateNativeProfileActivity;
using elder::shaders::LayerPolicy;
using elder::shaders::NativeArtifacts;
using elder::shaders::NativeParameterSchema;
using elder::shaders::NativeProfile;
using elder::shaders::ParameterType;
using elder::shaders::ParameterValue;
using elder::shaders::ParseNativeParameterSchema;
using elder::shaders::ParseNativeProfile;
using elder::shaders::ProfileDiagnostic;
using elder::shaders::SchemaDiagnostic;

struct TestContext {
  std::size_t assertions{};
  std::vector<std::string> failures;

  void expect(const bool condition, std::string message) {
    ++assertions;
    if (!condition) {
      failures.push_back(std::move(message));
    }
  }
};

[[nodiscard]] std::string ReadAll(const std::filesystem::path& path) {
  std::ifstream input{path, std::ios::binary};
  std::ostringstream stream;
  stream << input.rdbuf();
  return stream.str();
}

[[nodiscard]] std::string MinimalSchema(
    const std::string_view dependency = "elder.master.enabled==1") {
  return std::string{
      "schema,ordinal,semantic_id,symbol,type,unit,min,max,step,default,layer_min,layer_max,layer_identity,ui_group,ui_label,widget,layer_policy,dependency\n"
      "ELDER_NATIVE_PARAMETERS_V1,1,elder.master.enabled,ElderMasterEnabled,bool,unitless,0,1,1,1,0,1,1,Master,Enabled,checkbox,replace,always\n"
      "ELDER_NATIVE_PARAMETERS_V1,2,elder.exposure.bias,ElderExposureBias,float,ev,-4,4,0.05,0,-4,4,0,Exposure,Bias,spinner,add,"}
      + std::string{dependency} + "\n"
      "ELDER_NATIVE_PARAMETERS_V1,3,elder.color.gain,ElderColorGain,float,ratio,0,2,0.01,1,0,2,1,Color,Gain,spinner,multiply,elder.master.enabled==1\n"
      "ELDER_NATIVE_PARAMETERS_V1,4,elder.color.tint,ElderColorTint,color3,unitless,0,2,0.01,1|1|1,0,2,1|1|1,Color,Tint,color,multiply,elder.master.enabled==1\n";
}

[[nodiscard]] bool IsLowerHexSha256(const std::string_view value) noexcept {
  return value.size() == 64U
      && std::all_of(value.begin(), value.end(), [](const char current) {
           return (current >= '0' && current <= '9')
               || (current >= 'a' && current <= 'f');
         });
}

[[nodiscard]] std::string ProfileHeader(
    const NativeParameterSchema& schema,
    const std::string_view opacity) {
  return "profile=ELDER_NATIVE_PROFILE_V1\nparameter_schema="
      + schema.schema_id + "\nparameter_schema_sha256=" + schema.abi_sha256
      + "\nopacity=" + std::string{opacity} + "\n[parameters]\n";
}

[[nodiscard]] const elder::shaders::ParameterDefinition* Find(
    const NativeParameterSchema& schema,
    const std::string_view id) {
  for (const auto& parameter : schema.parameters) {
    if (parameter.semantic_id == id) {
      return &parameter;
    }
  }
  return nullptr;
}

void ProductionSchemaCompilesDeterministically(
    TestContext& context,
    const std::filesystem::path& schema_path) {
  const std::string source = ReadAll(schema_path);
  context.expect(!source.empty(), "production schema could not be read");

  NativeParameterSchema schema;
  const auto parsed = ParseNativeParameterSchema(source, schema);
  context.expect(parsed.ok(), "production schema was rejected: " + parsed.detail);
  if (!parsed.ok()) {
    return;
  }
  context.expect(schema.schema_id == "ELDER_NATIVE_PARAMETERS_V1",
                 "production schema ID changed");
  context.expect(IsLowerHexSha256(schema.abi_sha256),
                 "production schema did not receive a canonical ABI SHA-256");
  context.expect(schema.abi_sha256 == ComputeNativeSchemaFingerprint(schema),
                 "production schema ABI SHA-256 was not reproducible");
  context.expect(schema.parameters.size() == 16U,
                 "production schema parameter count changed");
  constexpr std::string_view deferred_controls[] = {
      "elder.exposure.night_bias_ev",
      "elder.exposure.interior_bias_ev",
      "elder.exposure.dark_adaptation_seconds",
      "elder.exposure.bright_adaptation_seconds",
  };
  for (const std::string_view semantic_id : deferred_controls) {
    context.expect(Find(schema, semantic_id) == nullptr,
                   "ABI V1 exposes an unimplemented temporal control: "
                       + std::string{semantic_id});
  }
  const auto* tint = Find(schema, "elder.color.shadow_tint");
  context.expect(tint != nullptr, "shadow tint semantic ID was not resolved");
  if (tint != nullptr) {
    context.expect(tint->type == ParameterType::color3,
                   "shadow tint type was not color3");
    context.expect(tint->layer_policy == LayerPolicy::multiply,
                   "shadow tint policy was not multiplicative");
    context.expect(tint->default_value.count == 3U,
                   "shadow tint did not retain three channels");
  }

  NativeArtifacts first;
  NativeArtifacts second;
  const auto first_result = CompileNativeParameterArtifacts(schema, first);
  const auto second_result = CompileNativeParameterArtifacts(schema, second);
  context.expect(first_result.ok(), "production artifact compilation failed");
  context.expect(second_result.ok(), "repeat artifact compilation failed");
  context.expect(first.hlsl_ui == second.hlsl_ui
                     && first.cpp_defaults == second.cpp_defaults
                     && first.manifest_json == second.manifest_json
                     && first.default_profile == second.default_profile,
                 "identical schema compilation changed output bytes");
  for (const std::string_view semantic_id : deferred_controls) {
    context.expect(first.hlsl_ui.find(semantic_id) == std::string::npos
                       && first.cpp_defaults.find(semantic_id)
                           == std::string::npos
                       && first.manifest_json.find(semantic_id)
                           == std::string::npos
                       && first.default_profile.find(semantic_id)
                           == std::string::npos,
                   "deferred temporal control leaked into a generated artifact: "
                       + std::string{semantic_id});
  }
  context.expect(first.hlsl_ui.find("float ElderExposureCompensationEv")
                     != std::string::npos,
                 "generated HLSL omitted exposure compensation");
  context.expect(first.hlsl_ui.find("string UIName = \"Exposure | Compensation EV\"")
                     != std::string::npos,
                 "generated HLSL omitted the ENB UI label");
  context.expect(first.hlsl_ui.find("float3 ElderShadowTint")
                     != std::string::npos,
                 "generated HLSL omitted the color control");
  context.expect(first.manifest_json.find("\"semantic_id\":\"elder.tonemap.toe\"")
                     != std::string::npos,
                 "manifest omitted a stable semantic ID");
  context.expect(first.manifest_json.find(schema.abi_sha256)
                     != std::string::npos
                     && first.hlsl_ui.find(schema.abi_sha256)
                     != std::string::npos
                     && first.cpp_defaults.find(schema.abi_sha256)
                     != std::string::npos,
                 "generated artifacts omitted the schema ABI SHA-256");
  context.expect(first.cpp_defaults.find("ElderTonemapMidGrayDefault")
                     != std::string::npos,
                 "generated C++ defaults omitted tonemap bindings");
  context.expect(first.default_profile.find("profile=ELDER_NATIVE_PROFILE_V1\n") == 0U,
                 "default profile header changed");
  context.expect(first.default_profile.find("elder.color.shadow_tint=1|1|1")
                     != std::string::npos,
                 "default profile omitted the canonical color value");
  context.expect(first.hlsl_ui.find("KreatE") == std::string::npos
                     && first.hlsl_ui.find("Silent Horizons") == std::string::npos
                     && first.manifest_json.find("PresetOverlay") == std::string::npos,
                 "native artifacts acquired a legacy runtime dependency");
  context.expect(first.hlsl_ui.find("0.050000000000000003")
                     == std::string::npos
                     && first.manifest_json.find("11.199999999999999")
                         == std::string::npos
                     && first.default_profile.find("0.71999999999999997")
                         == std::string::npos,
                 "generated artifacts use noisy binary floating-point text");
  for (const auto& parameter : schema.parameters) {
    context.expect(first.hlsl_ui.find(parameter.semantic_id)
                       != std::string::npos
                       && first.hlsl_ui.find(parameter.symbol)
                           != std::string::npos
                       && first.hlsl_ui.find(
                              parameter.ui_group + " | " + parameter.ui_label)
                           != std::string::npos
                       && first.cpp_defaults.find(parameter.symbol)
                           != std::string::npos
                       && first.manifest_json.find(parameter.semantic_id)
                           != std::string::npos
                       && first.manifest_json.find(
                              "\"ui_label\":\"" + parameter.ui_label + "\"")
                           != std::string::npos
                       && first.default_profile.find(parameter.semantic_id + "=")
                           != std::string::npos,
                   "parameter did not round-trip through every generated artifact: "
                       + parameter.semantic_id);
  }
}

void Sha256KnownVectorsAreStable(TestContext& context) {
  context.expect(
      ComputeSha256("")
          == "e3b0c44298fc1c149afbf4c8996fb924"
             "27ae41e4649b934ca495991b7852b855",
      "SHA-256 empty-string known vector changed");
  context.expect(
      ComputeSha256("abc")
          == "ba7816bf8f01cfea414140de5dae2223"
             "b00361a396177a9cb410ff61f20015ad",
      "SHA-256 abc known vector changed");
}

void ParserIsTransactionalAndStrict(TestContext& context) {
  NativeParameterSchema sentinel;
  sentinel.schema_id = "sentinel";
  sentinel.parameters.push_back({});
  const NativeParameterSchema original = sentinel;

  const auto reject = [&](const std::string& source,
                          const SchemaDiagnostic expected,
                          const std::string& label) {
    NativeParameterSchema output = sentinel;
    const auto result = ParseNativeParameterSchema(source, output);
    context.expect(result.diagnostic == expected,
                   label + " returned the wrong diagnostic");
    context.expect(output.schema_id == original.schema_id
                       && output.parameters.size() == original.parameters.size(),
                   label + " mutated output on failure");
  };

  reject("", SchemaDiagnostic::empty_input, "empty schema");
  reject("wrong,header\n", SchemaDiagnostic::wrong_header, "wrong header");

  std::string duplicate = MinimalSchema();
  duplicate += "ELDER_NATIVE_PARAMETERS_V1,5,elder.color.gain,ElderOther,float,ratio,0,2,0.01,1,0,2,1,Color,Other,spinner,replace,always\n";
  reject(duplicate, SchemaDiagnostic::duplicate_semantic_id,
         "duplicate semantic ID");

  std::string wrong_ordinal = MinimalSchema();
  const std::size_t ordinal = wrong_ordinal.find(",4,elder.color.tint");
  wrong_ordinal.replace(ordinal, 3U, ",7,");
  reject(wrong_ordinal, SchemaDiagnostic::noncontiguous_ordinal,
         "noncontiguous ordinal");

  reject(MinimalSchema("elder.missing.control==1"),
         SchemaDiagnostic::unknown_dependency,
         "unknown dependency");

  std::string cycle = MinimalSchema("elder.color.gain==1");
  const std::string old_dependency =
      "elder.master.enabled==1\nELDER_NATIVE_PARAMETERS_V1,4";
  const std::size_t dependency = cycle.find(old_dependency);
  cycle.replace(dependency,
                old_dependency.size(),
                "elder.exposure.bias==0\nELDER_NATIVE_PARAMETERS_V1,4");
  reject(cycle, SchemaDiagnostic::dependency_cycle, "dependency cycle");

  std::string invalid_bool = MinimalSchema();
  const std::size_t bool_default = invalid_bool.find(",1,0,1,1,Master,Enabled");
  invalid_bool.replace(bool_default, 3U, ",2,");
  reject(invalid_bool, SchemaDiagnostic::invalid_default,
         "non-boolean default");

  std::string invalid_color = MinimalSchema();
  const std::size_t color_default = invalid_color.find("1|1|1,0,2,1|1|1,Color,Tint");
  invalid_color.replace(color_default, 5U, "1|1");
  reject(invalid_color, SchemaDiagnostic::invalid_default,
         "short color default");

  std::string padded_label = MinimalSchema();
  const std::size_t label = padded_label.find(",Exposure,Bias,spinner");
  padded_label.replace(label, std::string{",Exposure,Bias,spinner"}.size(),
                       ", Exposure,Bias,spinner");
  reject(padded_label, SchemaDiagnostic::invalid_text,
         "whitespace-padded UI group");
}

void ProfilesRejectUnknownNamesAndWrongTypes(TestContext& context) {
  NativeParameterSchema schema;
  const auto schema_result = ParseNativeParameterSchema(MinimalSchema(), schema);
  context.expect(schema_result.ok(), "minimal schema failed setup");
  if (!schema_result.ok()) {
    return;
  }
  const std::string valid =
      ProfileHeader(schema, "1")
      +
      "elder.master.enabled=true\n"
      "elder.exposure.bias=-0.25\n"
      "elder.color.gain=1.1\n"
      "elder.color.tint=0.9|1|1.1\n";
  NativeProfile profile;
  const auto parsed = ParseNativeProfile(valid, schema, true, profile);
  context.expect(parsed.ok(), "valid complete native profile was rejected");
  context.expect(profile.values.size() == 4U,
                 "valid complete profile lost parameters");

  const NativeProfile sentinel = profile;
  const auto reject = [&](std::string text,
                          const ProfileDiagnostic expected,
                          const std::string& label) {
    NativeProfile output = sentinel;
    const auto result = ParseNativeProfile(text, schema, true, output);
    context.expect(result.diagnostic == expected,
                   label + " returned the wrong diagnostic");
    context.expect(output.values.size() == sentinel.values.size()
                       && output.parameter_schema_id == sentinel.parameter_schema_id,
                   label + " mutated output on failure");
  };

  std::string unknown = valid;
  unknown += "elder.color.typo=1\n";
  reject(unknown, ProfileDiagnostic::unknown_parameter, "unknown profile key");

  std::string wrong_bool = valid;
  wrong_bool.replace(wrong_bool.find("elder.master.enabled=true"),
                     std::string{"elder.master.enabled=true"}.size(),
                     "elder.master.enabled=0.25");
  reject(wrong_bool, ProfileDiagnostic::invalid_value, "wrong bool type");

  std::string wrong_color = valid;
  wrong_color.replace(wrong_color.find("0.9|1|1.1"), 9U, "0.9|1");
  reject(wrong_color, ProfileDiagnostic::invalid_value, "wrong color arity");

  std::string missing = valid;
  missing.erase(missing.find("elder.color.gain=1.1\n"),
                std::string{"elder.color.gain=1.1\n"}.size());
  reject(missing, ProfileDiagnostic::missing_parameter,
         "incomplete base profile");

  std::string wrong_fingerprint = valid;
  wrong_fingerprint.replace(
      wrong_fingerprint.find(schema.abi_sha256), 64U, std::string(64U, '0'));
  reject(wrong_fingerprint, ProfileDiagnostic::wrong_schema_fingerprint,
         "wrong schema fingerprint");
}

void LayerCompositionIsTypedDeterministicAndBounded(TestContext& context) {
  NativeParameterSchema schema;
  const auto schema_result = ParseNativeParameterSchema(MinimalSchema(), schema);
  context.expect(schema_result.ok(), "minimal schema failed setup");
  if (!schema_result.ok()) {
    return;
  }
  NativeArtifacts artifacts;
  const auto artifact_result = CompileNativeParameterArtifacts(schema, artifacts);
  context.expect(artifact_result.ok(), "minimal artifacts failed setup");
  if (!artifact_result.ok()) {
    return;
  }

  NativeProfile base;
  const auto base_result = ParseNativeProfile(
      artifacts.default_profile, schema, true, base);
  context.expect(base_result.ok(), "generated default profile did not parse");
  if (!base_result.ok()) {
    return;
  }
  const std::string layer_text =
      ProfileHeader(schema, "0.5")
      +
      "elder.exposure.bias=2\n"
      "elder.color.gain=1.5\n"
      "elder.color.tint=0.5|1|2\n";
  NativeProfile layer;
  const auto layer_result = ParseNativeProfile(layer_text, schema, false, layer);
  context.expect(layer_result.ok(), "valid partial layer was rejected");
  if (!layer_result.ok()) {
    return;
  }
  NativeProfile first;
  NativeProfile second;
  const std::vector layers{layer};
  const auto first_result = ComposeNativeProfileStack(schema, base, layers, first);
  const auto second_result = ComposeNativeProfileStack(schema, base, layers, second);
  context.expect(first_result.ok(), "valid layer stack was rejected");
  context.expect(second_result.ok(), "repeat layer stack was rejected");
  if (!first_result.ok() || !second_result.ok()) {
    return;
  }
  context.expect(first.values.size() == schema.parameters.size(),
                 "layer stack lost complete-profile values");
  context.expect(first.values == second.values,
                 "identical layer stack changed output values");
  context.expect(std::fabs(first.values.at("elder.exposure.bias").components[0]
                           - 1.0) < 1.0e-12,
                 "additive layer did not scale by opacity");
  context.expect(std::fabs(first.values.at("elder.color.gain").components[0]
                           - 1.25) < 1.0e-12,
                 "multiplicative layer did not blend from identity");
  const auto& tint = first.values.at("elder.color.tint");
  context.expect(std::fabs(tint.components[0] - 0.75) < 1.0e-12
                     && std::fabs(tint.components[1] - 1.0) < 1.0e-12
                     && std::fabs(tint.components[2] - 1.5) < 1.0e-12,
                 "color multiplier did not compose component-wise");

  NativeProfile discrete_layer = layer;
  discrete_layer.values.clear();
  discrete_layer.values.emplace(
      "elder.master.enabled", ParameterValue{{0.0, 0.0, 0.0}, 1U});
  NativeProfile rejected = base;
  const auto discrete = ComposeNativeProfileStack(
      schema, base, std::vector{discrete_layer}, rejected);
  context.expect(discrete.diagnostic == ProfileDiagnostic::discrete_partial_opacity,
                 "partial-opacity boolean replacement was accepted");
  context.expect(rejected.values == base.values,
                 "failed layer composition mutated output");
}

void FingerprintsDependenciesAndOperandsAreEnforced(TestContext& context) {
  NativeParameterSchema schema;
  const auto parsed = ParseNativeParameterSchema(MinimalSchema(), schema);
  context.expect(parsed.ok(), "minimal schema failed fingerprint setup");
  if (!parsed.ok()) return;

  NativeParameterSchema tampered = schema;
  tampered.parameters[1].maximum = 3.95;
  context.expect(ComputeNativeSchemaFingerprint(tampered) != schema.abi_sha256,
                 "semantic schema change did not alter ABI SHA-256");
  NativeArtifacts rejected_artifacts;
  context.expect(CompileNativeParameterArtifacts(tampered, rejected_artifacts).diagnostic
                     == SchemaDiagnostic::schema_fingerprint_mismatch,
                 "stale schema fingerprint was accepted");

  tampered = schema;
  tampered.parameters[1].unit =
      static_cast<elder::shaders::ParameterUnit>(255U);
  tampered.abi_sha256 = ComputeNativeSchemaFingerprint(tampered);
  context.expect(CompileNativeParameterArtifacts(tampered, rejected_artifacts).diagnostic
                     == SchemaDiagnostic::invalid_enum,
                 "invalid programmatic unit enum was accepted");
  tampered = schema;
  tampered.parameters[1].layer_policy =
      static_cast<LayerPolicy>(255U);
  tampered.abi_sha256 = ComputeNativeSchemaFingerprint(tampered);
  context.expect(CompileNativeParameterArtifacts(tampered, rejected_artifacts).diagnostic
                     == SchemaDiagnostic::invalid_enum,
                 "invalid programmatic layer policy was accepted");

  NativeArtifacts artifacts;
  context.expect(CompileNativeParameterArtifacts(schema, artifacts).ok(),
                 "minimal artifact setup failed");
  NativeProfile base;
  context.expect(ParseNativeProfile(
                     artifacts.default_profile, schema, true, base).ok(),
                 "minimal base profile setup failed");
  NativeProfile disable;
  const std::string disable_text = ProfileHeader(schema, "1")
      + "elder.master.enabled=false\n"
        "elder.exposure.bias=4\n";
  context.expect(ParseNativeProfile(disable_text, schema, false, disable).ok(),
                 "disable layer was rejected");
  NativeProfile composed;
  context.expect(ComposeNativeProfileStack(
                     schema, base, std::vector{disable}, composed).ok(),
                 "disable layer composition failed");
  context.expect(composed.values.at("elder.master.enabled").components[0] == 0.0,
                 "master dependency control was not applied");
  context.expect(composed.values.at("elder.exposure.bias").components[0] == 0.0,
                 "inactive dependent layer operand was applied");
  std::map<std::string, bool, std::less<>> activity;
  context.expect(EvaluateNativeProfileActivity(schema, composed, activity).ok(),
                 "profile activity evaluation failed");
  context.expect(activity.at("elder.master.enabled")
                     && !activity.at("elder.exposure.bias")
                     && !activity.at("elder.color.gain")
                     && !activity.at("elder.color.tint"),
                 "dependency activity state was incorrect");

  NativeParameterSchema additive = schema;
  additive.parameters[1].minimum = 0.0;
  additive.parameters[1].maximum = 2.0;
  additive.parameters[1].step = 0.01;
  additive.parameters[1].default_value.components[0] = 0.34;
  additive.parameters[1].layer_minimum = -1.0;
  additive.parameters[1].layer_maximum = 1.0;
  additive.parameters[1].layer_identity.components[0] = 0.0;
  additive.abi_sha256 = ComputeNativeSchemaFingerprint(additive);
  NativeArtifacts additive_artifacts;
  context.expect(CompileNativeParameterArtifacts(additive, additive_artifacts).ok(),
                 "additive operand schema was rejected");
  NativeProfile additive_base;
  context.expect(ParseNativeProfile(
                     additive_artifacts.default_profile,
                     additive,
                     true,
                     additive_base).ok(),
                 "additive base profile was rejected");
  NativeProfile reducing_layer;
  const std::string reducing_text = ProfileHeader(additive, "1")
      + "elder.exposure.bias=-0.2\n";
  context.expect(ParseNativeProfile(
                     reducing_text, additive, false, reducing_layer).ok(),
                 "negative additive layer operand was rejected");
  NativeProfile reduced;
  context.expect(ComposeNativeProfileStack(
                     additive,
                     additive_base,
                     std::vector{reducing_layer},
                     reduced).ok(),
                 "negative additive layer composition failed");
  context.expect(std::fabs(
                     reduced.values.at("elder.exposure.bias").components[0]
                     - 0.14) < 1.0e-12,
                 "negative additive operand did not reduce the final value");
}

}  // namespace

int main(const int argc, const char* const* argv) {
  if (argc != 2) {
    std::cerr << "usage: elder_native_shader_schema_tests <schema.csv>\n";
    return 2;
  }

  TestContext context;
  ProductionSchemaCompilesDeterministically(context, argv[1]);
  Sha256KnownVectorsAreStable(context);
  ParserIsTransactionalAndStrict(context);
  ProfilesRejectUnknownNamesAndWrongTypes(context);
  LayerCompositionIsTypedDeterministicAndBounded(context);
  FingerprintsDependenciesAndOperandsAreEnforced(context);

  if (!context.failures.empty()) {
    for (const auto& failure : context.failures) {
      std::cerr << "[FAIL] " << failure << '\n';
    }
    std::cerr << context.failures.size() << " failures across "
              << context.assertions << " assertions\n";
    return 1;
  }
  std::cout << "Elder native schema cases passed: "
            << context.assertions << " assertions\n";
  return 0;
}
