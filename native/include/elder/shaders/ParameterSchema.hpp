#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <map>
#include <string>
#include <string_view>
#include <vector>

namespace elder::shaders {

inline constexpr std::string_view kNativeParameterSchemaId =
    "ELDER_NATIVE_PARAMETERS_V1";
inline constexpr std::string_view kNativeProfileId =
    "ELDER_NATIVE_PROFILE_V1";

enum class ParameterType : std::uint8_t {
  boolean = 0,
  integer = 1,
  scalar = 2,
  color3 = 3,
};

enum class ParameterUnit : std::uint8_t {
  unitless = 0,
  ev = 1,
  kelvin = 2,
  seconds = 3,
  percent = 4,
  ratio = 5,
};

enum class UiWidget : std::uint8_t {
  checkbox = 0,
  spinner = 1,
  color = 2,
};

enum class LayerPolicy : std::uint8_t {
  replace = 0,
  add = 1,
  multiply = 2,
};

enum class DependencyOperator : std::uint8_t {
  always = 0,
  equals = 1,
  not_equals = 2,
};

enum class SchemaDiagnostic : std::uint16_t {
  none = 0,
  empty_input = 1,
  malformed_csv = 2,
  wrong_header = 3,
  wrong_column_count = 4,
  wrong_schema_id = 5,
  invalid_ordinal = 6,
  noncontiguous_ordinal = 7,
  invalid_semantic_id = 8,
  duplicate_semantic_id = 9,
  invalid_symbol = 10,
  duplicate_symbol = 11,
  invalid_type = 12,
  invalid_unit = 13,
  invalid_numeric = 14,
  invalid_range = 15,
  invalid_default = 16,
  invalid_widget = 17,
  invalid_layer_policy = 18,
  incompatible_metadata = 19,
  invalid_dependency = 20,
  unknown_dependency = 21,
  dependency_cycle = 22,
  empty_schema = 23,
  invalid_text = 24,
  invalid_enum = 25,
  invalid_step_alignment = 26,
  schema_fingerprint_mismatch = 27,
};

enum class ProfileDiagnostic : std::uint16_t {
  none = 0,
  empty_input = 1,
  malformed_line = 2,
  wrong_profile_id = 3,
  wrong_schema_id = 4,
  invalid_opacity = 5,
  missing_parameters_section = 6,
  unknown_parameter = 7,
  duplicate_parameter = 8,
  invalid_value = 9,
  missing_parameter = 10,
  invalid_base_profile = 11,
  discrete_partial_opacity = 12,
  calculation_non_finite = 13,
  wrong_schema_fingerprint = 14,
};

struct ParameterValue {
  std::array<double, 3> components{};
  std::uint8_t count{1};

  [[nodiscard]] bool operator==(const ParameterValue&) const noexcept = default;
};

struct DependencyPredicate {
  DependencyOperator operation{DependencyOperator::always};
  std::string semantic_id;
  ParameterValue comparison{};
};

struct ParameterDefinition {
  std::uint32_t ordinal{};
  std::string semantic_id;
  std::string symbol;
  ParameterType type{ParameterType::scalar};
  ParameterUnit unit{ParameterUnit::unitless};
  double minimum{};
  double maximum{};
  double step{};
  ParameterValue default_value{};
  double layer_minimum{};
  double layer_maximum{};
  ParameterValue layer_identity{};
  std::string ui_group;
  std::string ui_label;
  UiWidget widget{UiWidget::spinner};
  LayerPolicy layer_policy{LayerPolicy::replace};
  DependencyPredicate dependency{};
};

struct NativeParameterSchema {
  std::string schema_id;
  std::string abi_sha256;
  std::vector<ParameterDefinition> parameters;
};

struct SchemaResult {
  SchemaDiagnostic diagnostic{SchemaDiagnostic::none};
  std::size_t line{};
  std::string detail;

  [[nodiscard]] bool ok() const noexcept {
    return diagnostic == SchemaDiagnostic::none;
  }
};

struct NativeArtifacts {
  std::string hlsl_ui;
  std::string cpp_defaults;
  std::string manifest_json;
  std::string default_profile;
};

struct NativeProfile {
  std::string parameter_schema_id;
  std::string parameter_schema_sha256;
  double opacity{1.0};
  std::map<std::string, ParameterValue, std::less<>> values;
};

struct ProfileResult {
  ProfileDiagnostic diagnostic{ProfileDiagnostic::none};
  std::size_t line{};
  std::string detail;

  [[nodiscard]] bool ok() const noexcept {
    return diagnostic == ProfileDiagnostic::none;
  }
};

[[nodiscard]] SchemaResult ParseNativeParameterSchema(
    std::string_view csv,
    NativeParameterSchema& output) noexcept;

[[nodiscard]] SchemaResult CompileNativeParameterArtifacts(
    const NativeParameterSchema& schema,
    NativeArtifacts& output) noexcept;

[[nodiscard]] ProfileResult ParseNativeProfile(
    std::string_view text,
    const NativeParameterSchema& schema,
    bool require_complete,
    NativeProfile& output) noexcept;

[[nodiscard]] ProfileResult ComposeNativeProfileStack(
    const NativeParameterSchema& schema,
    const NativeProfile& base,
    const std::vector<NativeProfile>& layers,
    NativeProfile& output) noexcept;

[[nodiscard]] ProfileResult EvaluateNativeProfileActivity(
    const NativeParameterSchema& schema,
    const NativeProfile& profile,
    std::map<std::string, bool, std::less<>>& output) noexcept;

[[nodiscard]] std::string ComputeNativeSchemaFingerprint(
    const NativeParameterSchema& schema) noexcept;

[[nodiscard]] std::string ComputeSha256(std::string_view bytes) noexcept;

[[nodiscard]] bool SameValueBits(
    const ParameterValue& lhs,
    const ParameterValue& rhs) noexcept;

}  // namespace elder::shaders
