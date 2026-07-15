#include "elder/shaders/ParameterSchema.hpp"

#include <algorithm>
#include <bit>
#include <charconv>
#include <cmath>
#include <cstdint>
#include <functional>
#include <iomanip>
#include <limits>
#include <locale>
#include <optional>
#include <set>
#include <sstream>
#include <unordered_map>
#include <utility>

namespace elder::shaders {
namespace {

constexpr std::string_view kHeader =
    "schema,ordinal,semantic_id,symbol,type,unit,min,max,step,default,"
    "layer_min,layer_max,layer_identity,ui_group,ui_label,widget,"
    "layer_policy,dependency";
constexpr std::size_t kColumnCount = 18U;
constexpr std::size_t kMaximumSchemaBytes = 4U * 1024U * 1024U;
constexpr std::size_t kMaximumProfileBytes = 4U * 1024U * 1024U;
constexpr std::size_t kMaximumRows = 1024U;
constexpr std::size_t kMaximumFieldBytes = 4096U;

[[nodiscard]] std::string ComputeFingerprintUnchecked(
    const NativeParameterSchema& schema);

[[nodiscard]] SchemaResult SchemaFailure(
    const SchemaDiagnostic diagnostic,
    const std::size_t line,
    std::string detail) {
  return {diagnostic, line, std::move(detail)};
}

[[nodiscard]] ProfileResult ProfileFailure(
    const ProfileDiagnostic diagnostic,
    const std::size_t line,
    std::string detail) {
  return {diagnostic, line, std::move(detail)};
}

[[nodiscard]] std::vector<std::string_view> Lines(const std::string_view text) {
  std::vector<std::string_view> lines;
  std::size_t start = 0U;
  while (start < text.size()) {
    const std::size_t newline = text.find('\n', start);
    const std::size_t end = newline == std::string_view::npos
        ? text.size()
        : newline;
    std::size_t content_end = end;
    if (content_end > start && text[content_end - 1U] == '\r') {
      --content_end;
    }
    lines.emplace_back(text.substr(start, content_end - start));
    if (newline == std::string_view::npos) {
      break;
    }
    start = newline + 1U;
  }
  return lines;
}

[[nodiscard]] bool ContainsInvalidTextByte(const std::string_view text) noexcept {
  for (const unsigned char value : text) {
    if (value == 0U || value == '\r' || value == '\n') {
      return true;
    }
  }
  return false;
}

[[nodiscard]] bool ParseCsvRow(
    const std::string_view row,
    std::vector<std::string>& fields) {
  fields.clear();
  std::string field;
  bool quoted = false;
  bool quote_closed = false;
  for (std::size_t index = 0U; index < row.size(); ++index) {
    const char value = row[index];
    if (quoted) {
      if (value == '"') {
        if (index + 1U < row.size() && row[index + 1U] == '"') {
          field.push_back('"');
          ++index;
        } else {
          quoted = false;
          quote_closed = true;
        }
      } else {
        field.push_back(value);
      }
      continue;
    }
    if (quote_closed) {
      if (value != ',') {
        return false;
      }
      fields.push_back(std::move(field));
      field.clear();
      quote_closed = false;
      continue;
    }
    if (value == ',') {
      fields.push_back(std::move(field));
      field.clear();
    } else if (value == '"') {
      if (!field.empty()) {
        return false;
      }
      quoted = true;
    } else {
      field.push_back(value);
    }
  }
  if (quoted) {
    return false;
  }
  fields.push_back(std::move(field));
  return true;
}

[[nodiscard]] bool ParseUnsigned(
    const std::string_view text,
    std::uint32_t& output) noexcept {
  if (text.empty()) {
    return false;
  }
  std::uint32_t candidate{};
  const auto result = std::from_chars(
      text.data(), text.data() + text.size(), candidate, 10);
  if (result.ec != std::errc{} || result.ptr != text.data() + text.size()) {
    return false;
  }
  output = candidate;
  return true;
}

[[nodiscard]] bool ParseNumber(
    const std::string_view text,
    double& output) noexcept {
  if (text.empty()) {
    return false;
  }
  double candidate{};
  const auto result = std::from_chars(
      text.data(), text.data() + text.size(), candidate,
      std::chars_format::general);
  if (result.ec != std::errc{} || result.ptr != text.data() + text.size()
      || !std::isfinite(candidate)) {
    return false;
  }
  output = candidate == 0.0 ? 0.0 : candidate;
  return true;
}

[[nodiscard]] bool IsIntegral(const double value) noexcept {
  return std::isfinite(value) && std::trunc(value) == value;
}

[[nodiscard]] bool IsSemanticSegment(const std::string_view segment) noexcept {
  if (segment.empty()
      || !(segment.front() >= 'a' && segment.front() <= 'z')) {
    return false;
  }
  return std::all_of(segment.begin() + 1, segment.end(), [](const char value) {
    return (value >= 'a' && value <= 'z')
        || (value >= '0' && value <= '9') || value == '_';
  });
}

[[nodiscard]] bool IsSemanticId(const std::string_view value) noexcept {
  if (!value.starts_with("elder.")) {
    return false;
  }
  std::size_t start = 0U;
  std::size_t segments = 0U;
  while (start <= value.size()) {
    const std::size_t dot = value.find('.', start);
    const std::size_t end = dot == std::string_view::npos ? value.size() : dot;
    if (!IsSemanticSegment(value.substr(start, end - start))) {
      return false;
    }
    ++segments;
    if (dot == std::string_view::npos) {
      break;
    }
    start = dot + 1U;
  }
  return segments >= 3U;
}

[[nodiscard]] bool IsHlslSymbol(const std::string_view value) noexcept {
  if (value.empty()) {
    return false;
  }
  const auto first = value.front();
  if (!((first >= 'A' && first <= 'Z')
        || (first >= 'a' && first <= 'z') || first == '_')) {
    return false;
  }
  return std::all_of(value.begin() + 1, value.end(), [](const char current) {
    return (current >= 'A' && current <= 'Z')
        || (current >= 'a' && current <= 'z')
        || (current >= '0' && current <= '9') || current == '_';
  });
}

[[nodiscard]] bool IsUiText(const std::string_view value) noexcept {
  if (value.empty() || value.front() == ' ' || value.back() == ' '
      || ContainsInvalidTextByte(value)) {
    return false;
  }
  return std::all_of(value.begin(), value.end(), [](const unsigned char current) {
    return current >= 0x20U && current != 0x7FU && current != '"'
        && current != '\\';
  });
}

[[nodiscard]] std::optional<ParameterType> ParseType(
    const std::string_view value) noexcept {
  if (value == "bool") return ParameterType::boolean;
  if (value == "int") return ParameterType::integer;
  if (value == "float") return ParameterType::scalar;
  if (value == "color3") return ParameterType::color3;
  return std::nullopt;
}

[[nodiscard]] std::optional<ParameterUnit> ParseUnit(
    const std::string_view value) noexcept {
  if (value == "unitless") return ParameterUnit::unitless;
  if (value == "ev") return ParameterUnit::ev;
  if (value == "kelvin") return ParameterUnit::kelvin;
  if (value == "seconds") return ParameterUnit::seconds;
  if (value == "percent") return ParameterUnit::percent;
  if (value == "ratio") return ParameterUnit::ratio;
  return std::nullopt;
}

[[nodiscard]] std::optional<UiWidget> ParseWidget(
    const std::string_view value) noexcept {
  if (value == "checkbox") return UiWidget::checkbox;
  if (value == "spinner") return UiWidget::spinner;
  if (value == "color") return UiWidget::color;
  return std::nullopt;
}

[[nodiscard]] std::optional<LayerPolicy> ParseLayerPolicy(
    const std::string_view value) noexcept {
  if (value == "replace") return LayerPolicy::replace;
  if (value == "add") return LayerPolicy::add;
  if (value == "multiply") return LayerPolicy::multiply;
  return std::nullopt;
}

[[nodiscard]] std::string_view TypeName(const ParameterType value) noexcept {
  switch (value) {
    case ParameterType::boolean: return "bool";
    case ParameterType::integer: return "int";
    case ParameterType::scalar: return "float";
    case ParameterType::color3: return "color3";
  }
  return "invalid";
}

[[nodiscard]] std::string_view UnitName(const ParameterUnit value) noexcept {
  switch (value) {
    case ParameterUnit::unitless: return "unitless";
    case ParameterUnit::ev: return "ev";
    case ParameterUnit::kelvin: return "kelvin";
    case ParameterUnit::seconds: return "seconds";
    case ParameterUnit::percent: return "percent";
    case ParameterUnit::ratio: return "ratio";
  }
  return "invalid";
}

[[nodiscard]] std::string_view WidgetName(const UiWidget value) noexcept {
  switch (value) {
    case UiWidget::checkbox: return "checkbox";
    case UiWidget::spinner: return "spinner";
    case UiWidget::color: return "color";
  }
  return "invalid";
}

[[nodiscard]] std::string_view LayerPolicyName(const LayerPolicy value) noexcept {
  switch (value) {
    case LayerPolicy::replace: return "replace";
    case LayerPolicy::add: return "add";
    case LayerPolicy::multiply: return "multiply";
  }
  return "invalid";
}

[[nodiscard]] bool ParseValue(
    const std::string_view text,
    const ParameterType type,
    ParameterValue& output) noexcept {
  ParameterValue candidate{};
  const std::uint8_t expected = type == ParameterType::color3 ? 3U : 1U;
  candidate.count = expected;
  std::size_t start = 0U;
  for (std::uint8_t component = 0U; component < expected; ++component) {
    const std::size_t separator = text.find('|', start);
    if ((component + 1U < expected && separator == std::string_view::npos)
        || (component + 1U == expected && separator != std::string_view::npos)) {
      return false;
    }
    const std::size_t end = separator == std::string_view::npos
        ? text.size()
        : separator;
    double value{};
    if (!ParseNumber(text.substr(start, end - start), value)) {
      return false;
    }
    candidate.components[component] = value;
    start = end + 1U;
  }
  if (type == ParameterType::boolean
      && candidate.components[0] != 0.0 && candidate.components[0] != 1.0) {
    return false;
  }
  if (type == ParameterType::integer && !IsIntegral(candidate.components[0])) {
    return false;
  }
  output = candidate;
  return true;
}

[[nodiscard]] bool IsKnown(const ParameterType value) noexcept {
  switch (value) {
    case ParameterType::boolean:
    case ParameterType::integer:
    case ParameterType::scalar:
    case ParameterType::color3:
      return true;
  }
  return false;
}

[[nodiscard]] bool IsKnown(const ParameterUnit value) noexcept {
  switch (value) {
    case ParameterUnit::unitless:
    case ParameterUnit::ev:
    case ParameterUnit::kelvin:
    case ParameterUnit::seconds:
    case ParameterUnit::percent:
    case ParameterUnit::ratio:
      return true;
  }
  return false;
}

[[nodiscard]] bool IsKnown(const UiWidget value) noexcept {
  switch (value) {
    case UiWidget::checkbox:
    case UiWidget::spinner:
    case UiWidget::color:
      return true;
  }
  return false;
}

[[nodiscard]] bool IsKnown(const LayerPolicy value) noexcept {
  switch (value) {
    case LayerPolicy::replace:
    case LayerPolicy::add:
    case LayerPolicy::multiply:
      return true;
  }
  return false;
}

[[nodiscard]] bool IsStepAligned(
    const double value,
    const double minimum,
    const double step) noexcept {
  if (!std::isfinite(value) || !std::isfinite(minimum)
      || !std::isfinite(step) || step <= 0.0) {
    return false;
  }
  const double quotient = (value - minimum) / step;
  const double nearest = std::round(quotient);
  const double tolerance = 1.0e-9 * std::max(1.0, std::fabs(quotient));
  return std::fabs(quotient - nearest) <= tolerance;
}

[[nodiscard]] bool ValueWithinDefinition(
    const ParameterDefinition& definition,
    const ParameterValue& value,
    const bool layer_operand = false,
    const bool require_step = true) noexcept {
  const std::uint8_t expected =
      definition.type == ParameterType::color3 ? 3U : 1U;
  if (value.count != expected) {
    return false;
  }
  const double minimum = layer_operand
      ? definition.layer_minimum
      : definition.minimum;
  const double maximum = layer_operand
      ? definition.layer_maximum
      : definition.maximum;
  for (std::uint8_t index = 0U; index < expected; ++index) {
    const double component = value.components[index];
    if (!std::isfinite(component) || component < minimum
        || component > maximum
        || (require_step && !IsStepAligned(component, minimum, definition.step))) {
      return false;
    }
  }
  if (definition.type == ParameterType::boolean) {
    return value.components[0] == 0.0 || value.components[0] == 1.0;
  }
  if (definition.type == ParameterType::integer) {
    return IsIntegral(value.components[0]);
  }
  return true;
}

[[nodiscard]] SchemaResult ValidateSchema(
    const NativeParameterSchema& schema,
    const bool require_fingerprint = true) {
  if (schema.schema_id != kNativeParameterSchemaId) {
    return SchemaFailure(
        SchemaDiagnostic::wrong_schema_id, 0U, "schema ID is not supported");
  }
  if (schema.parameters.empty()) {
    return SchemaFailure(
        SchemaDiagnostic::empty_schema, 0U, "schema has no parameters");
  }

  std::unordered_map<std::string_view, std::size_t> by_id;
  std::set<std::string_view> symbols;
  by_id.reserve(schema.parameters.size());
  for (std::size_t index = 0U; index < schema.parameters.size(); ++index) {
    const auto& parameter = schema.parameters[index];
    const std::size_t line = index + 2U;
    if (!IsKnown(parameter.type) || !IsKnown(parameter.unit)
        || !IsKnown(parameter.widget) || !IsKnown(parameter.layer_policy)) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_enum, line,
          "parameter contains an invalid enum value");
    }
    if (parameter.ordinal != index + 1U) {
      return SchemaFailure(
          SchemaDiagnostic::noncontiguous_ordinal, line,
          "ordinals must be contiguous and start at one");
    }
    if (!IsSemanticId(parameter.semantic_id)) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_semantic_id, line,
          "semantic ID must be a lowercase elder.* identifier");
    }
    if (!by_id.emplace(parameter.semantic_id, index).second) {
      return SchemaFailure(
          SchemaDiagnostic::duplicate_semantic_id, line,
          "semantic ID is duplicated");
    }
    if (!IsHlslSymbol(parameter.symbol)) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_symbol, line, "HLSL symbol is invalid");
    }
    if (!symbols.emplace(parameter.symbol).second) {
      return SchemaFailure(
          SchemaDiagnostic::duplicate_symbol, line, "HLSL symbol is duplicated");
    }
    if (!IsUiText(parameter.ui_group) || !IsUiText(parameter.ui_label)) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_text, line,
          "UI group and label must be nonempty injection-safe text");
    }
    if (!std::isfinite(parameter.minimum) || !std::isfinite(parameter.maximum)
        || !std::isfinite(parameter.step) || parameter.minimum >= parameter.maximum
        || parameter.step <= 0.0) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_range, line,
          "range must be finite, increasing, and have a positive step");
    }
    if (!ValueWithinDefinition(parameter, parameter.default_value)) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_default, line,
          "default does not match the declared type and range");
    }
    if (!std::isfinite(parameter.layer_minimum)
        || !std::isfinite(parameter.layer_maximum)
        || parameter.layer_minimum >= parameter.layer_maximum) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_range, line,
          "layer operand bounds must be finite and increasing");
    }
    if (!ValueWithinDefinition(
            parameter, parameter.layer_identity, true, true)) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_default, line,
          "layer identity does not match the operand type and range");
    }
    const std::uint8_t component_count =
        parameter.type == ParameterType::color3 ? 3U : 1U;
    for (std::uint8_t component = 0U; component < component_count; ++component) {
      const double identity = parameter.layer_identity.components[component];
      if ((parameter.layer_policy == LayerPolicy::add && identity != 0.0)
          || (parameter.layer_policy == LayerPolicy::multiply && identity != 1.0)) {
        return SchemaFailure(
            SchemaDiagnostic::incompatible_metadata, line,
            "add/multiply layer identities must be zero/one respectively");
      }
    }
    if (parameter.type == ParameterType::boolean) {
      if (parameter.unit != ParameterUnit::unitless
          || parameter.widget != UiWidget::checkbox
          || parameter.layer_policy != LayerPolicy::replace
          || parameter.minimum != 0.0 || parameter.maximum != 1.0
          || parameter.step != 1.0) {
        return SchemaFailure(
            SchemaDiagnostic::incompatible_metadata, line,
            "boolean metadata must be unitless checkbox/replace over 0..1");
      }
    } else if (parameter.type == ParameterType::integer) {
      if (parameter.unit != ParameterUnit::unitless
          || parameter.widget != UiWidget::spinner
          || parameter.layer_policy != LayerPolicy::replace
          || !IsIntegral(parameter.minimum) || !IsIntegral(parameter.maximum)
          || !IsIntegral(parameter.step)) {
        return SchemaFailure(
            SchemaDiagnostic::incompatible_metadata, line,
            "integer metadata must be integral unitless spinner/replace");
      }
    } else if (parameter.type == ParameterType::scalar) {
      if (parameter.widget != UiWidget::spinner) {
        return SchemaFailure(
            SchemaDiagnostic::incompatible_metadata, line,
            "scalar metadata requires a spinner widget");
      }
    } else if (parameter.type == ParameterType::color3) {
      if (parameter.unit != ParameterUnit::unitless
          || parameter.widget != UiWidget::color) {
        return SchemaFailure(
            SchemaDiagnostic::incompatible_metadata, line,
            "color3 metadata requires a unitless color widget");
      }
    } else {
      return SchemaFailure(
          SchemaDiagnostic::invalid_type, line, "parameter type is invalid");
    }
  }

  std::vector<std::optional<std::size_t>> dependency_edges(
      schema.parameters.size());
  for (std::size_t index = 0U; index < schema.parameters.size(); ++index) {
    const auto& parameter = schema.parameters[index];
    if (parameter.dependency.operation == DependencyOperator::always) {
      if (!parameter.dependency.semantic_id.empty()) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_dependency, index + 2U,
            "always dependencies cannot name a target");
      }
      continue;
    }
    if (parameter.dependency.operation != DependencyOperator::equals
        && parameter.dependency.operation != DependencyOperator::not_equals) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_dependency, index + 2U,
          "dependency operator is invalid");
    }
    const auto found = by_id.find(parameter.dependency.semantic_id);
    if (found == by_id.end()) {
      return SchemaFailure(
          SchemaDiagnostic::unknown_dependency, index + 2U,
          "dependency target is unknown");
    }
    const auto& target = schema.parameters[found->second];
    if (target.type == ParameterType::color3
        || !ValueWithinDefinition(
            target, parameter.dependency.comparison, false, true)) {
      return SchemaFailure(
          SchemaDiagnostic::invalid_dependency, index + 2U,
          "dependency comparison does not match its target");
    }
    dependency_edges[index] = found->second;
  }

  std::vector<std::uint8_t> states(schema.parameters.size(), 0U);
  std::function<bool(std::size_t)> has_cycle = [&](const std::size_t index) {
    if (states[index] == 1U) return true;
    if (states[index] == 2U) return false;
    states[index] = 1U;
    if (dependency_edges[index].has_value()
        && has_cycle(*dependency_edges[index])) {
      return true;
    }
    states[index] = 2U;
    return false;
  };
  for (std::size_t index = 0U; index < schema.parameters.size(); ++index) {
    if (has_cycle(index)) {
      return SchemaFailure(
          SchemaDiagnostic::dependency_cycle, index + 2U,
          "dependency graph contains a cycle");
    }
  }
  if (require_fingerprint
      && schema.abi_sha256 != ComputeFingerprintUnchecked(schema)) {
    return SchemaFailure(
        SchemaDiagnostic::schema_fingerprint_mismatch, 0U,
        "schema ABI SHA-256 does not match its canonical semantics");
  }
  return {};
}

[[nodiscard]] std::string FormatNumber(const double value) {
  if (value == 0.0) {
    return "0";
  }
  std::array<char, 64> buffer{};
  const auto result = std::to_chars(
      buffer.data(), buffer.data() + buffer.size(), value,
      std::chars_format::general);
  if (result.ec != std::errc{}) {
    return "0";
  }
  return std::string{buffer.data(), result.ptr};
}

[[nodiscard]] std::string FormatHlslNumber(const double value) {
  std::string output = FormatNumber(value);
  if (output.find_first_of(".eE") == std::string::npos) {
    output += ".0";
  }
  return output;
}

class Sha256 final {
 public:
  Sha256() noexcept
      : state_{0x6A09E667U, 0xBB67AE85U, 0x3C6EF372U, 0xA54FF53AU,
               0x510E527FU, 0x9B05688CU, 0x1F83D9ABU, 0x5BE0CD19U} {}

  void update(const std::string_view bytes) noexcept {
    for (const unsigned char value : bytes) {
      buffer_[buffer_size_++] = value;
      ++byte_count_;
      if (buffer_size_ == buffer_.size()) {
        transform(buffer_);
        buffer_size_ = 0U;
      }
    }
  }

  [[nodiscard]] std::array<std::uint8_t, 32> finish() noexcept {
    const std::uint64_t bit_count = byte_count_ * 8U;
    buffer_[buffer_size_++] = 0x80U;
    if (buffer_size_ > 56U) {
      while (buffer_size_ < buffer_.size()) buffer_[buffer_size_++] = 0U;
      transform(buffer_);
      buffer_size_ = 0U;
    }
    while (buffer_size_ < 56U) buffer_[buffer_size_++] = 0U;
    for (int shift = 56; shift >= 0; shift -= 8) {
      buffer_[buffer_size_++] = static_cast<std::uint8_t>(
          bit_count >> static_cast<std::uint32_t>(shift));
    }
    transform(buffer_);

    std::array<std::uint8_t, 32> digest{};
    for (std::size_t index = 0U; index < state_.size(); ++index) {
      digest[(4U * index) + 0U] = static_cast<std::uint8_t>(state_[index] >> 24U);
      digest[(4U * index) + 1U] = static_cast<std::uint8_t>(state_[index] >> 16U);
      digest[(4U * index) + 2U] = static_cast<std::uint8_t>(state_[index] >> 8U);
      digest[(4U * index) + 3U] = static_cast<std::uint8_t>(state_[index]);
    }
    return digest;
  }

 private:
  [[nodiscard]] static constexpr std::uint32_t RotateRight(
      const std::uint32_t value,
      const std::uint32_t count) noexcept {
    return (value >> count) | (value << (32U - count));
  }

  void transform(const std::array<std::uint8_t, 64>& block) noexcept {
    static constexpr std::array<std::uint32_t, 64> constants{
        0x428A2F98U, 0x71374491U, 0xB5C0FBCFU, 0xE9B5DBA5U,
        0x3956C25BU, 0x59F111F1U, 0x923F82A4U, 0xAB1C5ED5U,
        0xD807AA98U, 0x12835B01U, 0x243185BEU, 0x550C7DC3U,
        0x72BE5D74U, 0x80DEB1FEU, 0x9BDC06A7U, 0xC19BF174U,
        0xE49B69C1U, 0xEFBE4786U, 0x0FC19DC6U, 0x240CA1CCU,
        0x2DE92C6FU, 0x4A7484AAU, 0x5CB0A9DCU, 0x76F988DAU,
        0x983E5152U, 0xA831C66DU, 0xB00327C8U, 0xBF597FC7U,
        0xC6E00BF3U, 0xD5A79147U, 0x06CA6351U, 0x14292967U,
        0x27B70A85U, 0x2E1B2138U, 0x4D2C6DFCU, 0x53380D13U,
        0x650A7354U, 0x766A0ABBU, 0x81C2C92EU, 0x92722C85U,
        0xA2BFE8A1U, 0xA81A664BU, 0xC24B8B70U, 0xC76C51A3U,
        0xD192E819U, 0xD6990624U, 0xF40E3585U, 0x106AA070U,
        0x19A4C116U, 0x1E376C08U, 0x2748774CU, 0x34B0BCB5U,
        0x391C0CB3U, 0x4ED8AA4AU, 0x5B9CCA4FU, 0x682E6FF3U,
        0x748F82EEU, 0x78A5636FU, 0x84C87814U, 0x8CC70208U,
        0x90BEFFFAU, 0xA4506CEBU, 0xBEF9A3F7U, 0xC67178F2U,
    };
    std::array<std::uint32_t, 64> words{};
    for (std::size_t index = 0U; index < 16U; ++index) {
      words[index] = (static_cast<std::uint32_t>(block[4U * index]) << 24U)
          | (static_cast<std::uint32_t>(block[(4U * index) + 1U]) << 16U)
          | (static_cast<std::uint32_t>(block[(4U * index) + 2U]) << 8U)
          | static_cast<std::uint32_t>(block[(4U * index) + 3U]);
    }
    for (std::size_t index = 16U; index < words.size(); ++index) {
      const std::uint32_t s0 = RotateRight(words[index - 15U], 7U)
          ^ RotateRight(words[index - 15U], 18U)
          ^ (words[index - 15U] >> 3U);
      const std::uint32_t s1 = RotateRight(words[index - 2U], 17U)
          ^ RotateRight(words[index - 2U], 19U)
          ^ (words[index - 2U] >> 10U);
      words[index] = words[index - 16U] + s0 + words[index - 7U] + s1;
    }
    std::uint32_t a = state_[0];
    std::uint32_t b = state_[1];
    std::uint32_t c = state_[2];
    std::uint32_t d = state_[3];
    std::uint32_t e = state_[4];
    std::uint32_t f = state_[5];
    std::uint32_t g = state_[6];
    std::uint32_t h = state_[7];
    for (std::size_t index = 0U; index < words.size(); ++index) {
      const std::uint32_t sum1 = RotateRight(e, 6U) ^ RotateRight(e, 11U)
          ^ RotateRight(e, 25U);
      const std::uint32_t choice = (e & f) ^ ((~e) & g);
      const std::uint32_t temp1 = h + sum1 + choice + constants[index]
          + words[index];
      const std::uint32_t sum0 = RotateRight(a, 2U) ^ RotateRight(a, 13U)
          ^ RotateRight(a, 22U);
      const std::uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
      const std::uint32_t temp2 = sum0 + majority;
      h = g;
      g = f;
      f = e;
      e = d + temp1;
      d = c;
      c = b;
      b = a;
      a = temp1 + temp2;
    }
    state_[0] += a;
    state_[1] += b;
    state_[2] += c;
    state_[3] += d;
    state_[4] += e;
    state_[5] += f;
    state_[6] += g;
    state_[7] += h;
  }

  std::array<std::uint32_t, 8> state_{};
  std::array<std::uint8_t, 64> buffer_{};
  std::size_t buffer_size_{};
  std::uint64_t byte_count_{};
};

void AppendCanonicalField(std::string& output, const std::string_view value) {
  output += std::to_string(value.size());
  output.push_back(':');
  output.append(value);
  output.push_back(';');
}

void AppendCanonicalValue(
    std::string& output,
    const ParameterValue& value) {
  AppendCanonicalField(output, std::to_string(value.count));
  for (std::uint8_t index = 0U; index < value.count && index < 3U; ++index) {
    AppendCanonicalField(output, FormatNumber(value.components[index]));
  }
}

[[nodiscard]] std::string ComputeFingerprintUnchecked(
    const NativeParameterSchema& schema) {
  std::string canonical = "ELDER_NATIVE_SCHEMA_ABI_V1;";
  AppendCanonicalField(canonical, schema.schema_id);
  AppendCanonicalField(canonical, std::to_string(schema.parameters.size()));
  for (const auto& parameter : schema.parameters) {
    AppendCanonicalField(canonical, std::to_string(parameter.ordinal));
    AppendCanonicalField(canonical, parameter.semantic_id);
    AppendCanonicalField(canonical, parameter.symbol);
    AppendCanonicalField(canonical, std::to_string(static_cast<unsigned>(parameter.type)));
    AppendCanonicalField(canonical, std::to_string(static_cast<unsigned>(parameter.unit)));
    AppendCanonicalField(canonical, FormatNumber(parameter.minimum));
    AppendCanonicalField(canonical, FormatNumber(parameter.maximum));
    AppendCanonicalField(canonical, FormatNumber(parameter.step));
    AppendCanonicalValue(canonical, parameter.default_value);
    AppendCanonicalField(canonical, FormatNumber(parameter.layer_minimum));
    AppendCanonicalField(canonical, FormatNumber(parameter.layer_maximum));
    AppendCanonicalValue(canonical, parameter.layer_identity);
    AppendCanonicalField(canonical, parameter.ui_group);
    AppendCanonicalField(canonical, parameter.ui_label);
    AppendCanonicalField(canonical, std::to_string(static_cast<unsigned>(parameter.widget)));
    AppendCanonicalField(
        canonical, std::to_string(static_cast<unsigned>(parameter.layer_policy)));
    AppendCanonicalField(
        canonical, std::to_string(static_cast<unsigned>(parameter.dependency.operation)));
    AppendCanonicalField(canonical, parameter.dependency.semantic_id);
    AppendCanonicalValue(canonical, parameter.dependency.comparison);
  }
  Sha256 sha;
  sha.update(canonical);
  const auto digest = sha.finish();
  constexpr char hex[] = "0123456789abcdef";
  std::string output;
  output.reserve(64U);
  for (const std::uint8_t value : digest) {
    output.push_back(hex[value >> 4U]);
    output.push_back(hex[value & 0x0FU]);
  }
  return output;
}

[[nodiscard]] std::string FormatValue(
    const ParameterDefinition& definition,
    const ParameterValue& value,
    const bool hlsl) {
  if (definition.type == ParameterType::boolean) {
    return value.components[0] == 0.0 ? "false" : "true";
  }
  if (definition.type == ParameterType::integer) {
    return FormatNumber(value.components[0]);
  }
  const std::uint8_t count =
      definition.type == ParameterType::color3 ? 3U : 1U;
  std::string output;
  for (std::uint8_t index = 0U; index < count; ++index) {
    if (index != 0U) output += hlsl ? ", " : "|";
    output += hlsl
        ? FormatHlslNumber(value.components[index])
        : FormatNumber(value.components[index]);
  }
  return output;
}

[[nodiscard]] std::string EscapeJson(const std::string_view text) {
  std::string output;
  output.reserve(text.size());
  for (const unsigned char value : text) {
    switch (value) {
      case '"': output += "\\\""; break;
      case '\\': output += "\\\\"; break;
      case '\b': output += "\\b"; break;
      case '\f': output += "\\f"; break;
      case '\n': output += "\\n"; break;
      case '\r': output += "\\r"; break;
      case '\t': output += "\\t"; break;
      default: output.push_back(static_cast<char>(value)); break;
    }
  }
  return output;
}

[[nodiscard]] std::string DependencyText(
    const ParameterDefinition& parameter) {
  if (parameter.dependency.operation == DependencyOperator::always) {
    return "always";
  }
  return parameter.dependency.semantic_id
      + (parameter.dependency.operation == DependencyOperator::equals
             ? "=="
             : "!=")
      + FormatNumber(parameter.dependency.comparison.components[0]);
}

[[nodiscard]] const ParameterDefinition* FindDefinition(
    const NativeParameterSchema& schema,
    const std::string_view id) noexcept {
  const auto found = std::find_if(
      schema.parameters.begin(), schema.parameters.end(),
      [&](const ParameterDefinition& parameter) {
        return parameter.semantic_id == id;
      });
  return found == schema.parameters.end() ? nullptr : &*found;
}

[[nodiscard]] bool ParseProfileValue(
    const std::string_view text,
    const ParameterDefinition& definition,
    const bool layer_operand,
    ParameterValue& output) noexcept {
  ParameterValue candidate;
  if (definition.type == ParameterType::boolean) {
    if (text == "true") {
      candidate = ParameterValue{{1.0, 0.0, 0.0}, 1U};
    } else if (text == "false") {
      candidate = ParameterValue{{0.0, 0.0, 0.0}, 1U};
    } else {
      return false;
    }
  } else if (!ParseValue(text, definition.type, candidate)) {
    return false;
  }
  if (!ValueWithinDefinition(definition, candidate, layer_operand, true)) {
    return false;
  }
  output = candidate;
  return true;
}

[[nodiscard]] ProfileResult ValidateProfile(
    const NativeParameterSchema& schema,
    const NativeProfile& profile,
    const bool require_complete,
    const bool require_base_opacity,
    const bool layer_operand) {
  if (profile.parameter_schema_id != schema.schema_id) {
    return ProfileFailure(
        ProfileDiagnostic::wrong_schema_id, 0U,
        "profile parameter schema ID does not match");
  }
  if (profile.parameter_schema_sha256 != schema.abi_sha256) {
    return ProfileFailure(
        ProfileDiagnostic::wrong_schema_fingerprint, 0U,
        "profile parameter schema SHA-256 does not match");
  }
  if (!std::isfinite(profile.opacity) || profile.opacity < 0.0
      || profile.opacity > 1.0
      || (require_base_opacity && profile.opacity != 1.0)) {
    return ProfileFailure(
        require_base_opacity
            ? ProfileDiagnostic::invalid_base_profile
            : ProfileDiagnostic::invalid_opacity,
        0U, "profile opacity is invalid");
  }
  for (const auto& [id, value] : profile.values) {
    const ParameterDefinition* definition = FindDefinition(schema, id);
    if (definition == nullptr) {
      return ProfileFailure(
          ProfileDiagnostic::unknown_parameter, 0U,
          "profile contains an unknown parameter");
    }
    if (!ValueWithinDefinition(*definition, value, layer_operand, true)) {
      return ProfileFailure(
          ProfileDiagnostic::invalid_value, 0U,
          "profile value does not match its definition");
    }
  }
  if (require_complete && profile.values.size() != schema.parameters.size()) {
    return ProfileFailure(
        ProfileDiagnostic::missing_parameter, 0U,
        "profile is missing one or more parameters");
  }
  if (require_complete) {
    for (const auto& parameter : schema.parameters) {
      if (!profile.values.contains(parameter.semantic_id)) {
        return ProfileFailure(
            ProfileDiagnostic::missing_parameter, 0U,
            "profile is missing a required parameter");
      }
    }
  }
  return {};
}

}  // namespace

SchemaResult ParseNativeParameterSchema(
    const std::string_view csv,
    NativeParameterSchema& output) noexcept {
  try {
    if (csv.empty()) {
      return SchemaFailure(
          SchemaDiagnostic::empty_input, 0U, "schema input is empty");
    }
    if (csv.size() > kMaximumSchemaBytes) {
      return SchemaFailure(
          SchemaDiagnostic::malformed_csv, 0U,
          "schema exceeds the maximum supported size");
    }
    if (ContainsInvalidTextByte(csv.substr(0U, csv.find('\n')))) {
      return SchemaFailure(
          SchemaDiagnostic::malformed_csv, 1U, "header contains an invalid byte");
    }
    const auto lines = Lines(csv);
    if (lines.size() > kMaximumRows + 1U) {
      return SchemaFailure(
          SchemaDiagnostic::malformed_csv, 0U,
          "schema exceeds the maximum supported row count");
    }
    if (lines.empty() || lines.front() != kHeader) {
      return SchemaFailure(
          SchemaDiagnostic::wrong_header, 1U, "schema header is not exact");
    }

    NativeParameterSchema candidate;
    candidate.schema_id = std::string{kNativeParameterSchemaId};
    std::vector<std::string> raw_dependencies;
    std::vector<std::string> fields;
    for (std::size_t line_index = 1U; line_index < lines.size(); ++line_index) {
      const std::size_t line_number = line_index + 1U;
      if (lines[line_index].empty()) {
        continue;
      }
      if (lines[line_index].size() > kMaximumFieldBytes * kColumnCount) {
        return SchemaFailure(
            SchemaDiagnostic::malformed_csv, line_number,
            "CSV row exceeds the maximum supported size");
      }
      if (!ParseCsvRow(lines[line_index], fields)) {
        return SchemaFailure(
            SchemaDiagnostic::malformed_csv, line_number,
            "CSV row has invalid quoting");
      }
      if (fields.size() != kColumnCount) {
        return SchemaFailure(
            SchemaDiagnostic::wrong_column_count, line_number,
            "CSV row does not contain 18 columns");
      }
      if (std::any_of(fields.begin(), fields.end(), [](const std::string& field) {
            return field.size() > kMaximumFieldBytes;
          })) {
        return SchemaFailure(
            SchemaDiagnostic::malformed_csv, line_number,
            "CSV field exceeds the maximum supported size");
      }
      if (fields[0] != kNativeParameterSchemaId) {
        return SchemaFailure(
            SchemaDiagnostic::wrong_schema_id, line_number,
            "row schema ID is not supported");
      }

      ParameterDefinition parameter;
      if (!ParseUnsigned(fields[1], parameter.ordinal) || parameter.ordinal == 0U) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_ordinal, line_number,
            "ordinal is not a positive integer");
      }
      parameter.semantic_id = fields[2];
      parameter.symbol = fields[3];
      const auto type = ParseType(fields[4]);
      if (!type.has_value()) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_type, line_number,
            "parameter type is unknown");
      }
      parameter.type = *type;
      const auto unit = ParseUnit(fields[5]);
      if (!unit.has_value()) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_unit, line_number,
            "parameter unit is unknown");
      }
      parameter.unit = *unit;
      if (!ParseNumber(fields[6], parameter.minimum)
          || !ParseNumber(fields[7], parameter.maximum)
          || !ParseNumber(fields[8], parameter.step)) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_numeric, line_number,
            "range contains an invalid number");
      }
      if (!ParseValue(fields[9], parameter.type, parameter.default_value)) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_default, line_number,
            "default does not match the declared type");
      }
      if (!ParseNumber(fields[10], parameter.layer_minimum)
          || !ParseNumber(fields[11], parameter.layer_maximum)) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_numeric, line_number,
            "layer operand range contains an invalid number");
      }
      if (!ParseValue(fields[12], parameter.type, parameter.layer_identity)) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_default, line_number,
            "layer identity does not match the declared type");
      }
      parameter.ui_group = fields[13];
      parameter.ui_label = fields[14];
      const auto widget = ParseWidget(fields[15]);
      if (!widget.has_value()) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_widget, line_number,
            "UI widget is unknown");
      }
      parameter.widget = *widget;
      const auto policy = ParseLayerPolicy(fields[16]);
      if (!policy.has_value()) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_layer_policy, line_number,
            "layer policy is unknown");
      }
      parameter.layer_policy = *policy;
      raw_dependencies.push_back(fields[17]);
      candidate.parameters.push_back(std::move(parameter));
    }
    if (candidate.parameters.empty()) {
      return SchemaFailure(
          SchemaDiagnostic::empty_schema, 0U, "schema has no parameter rows");
    }

    std::unordered_map<std::string_view, const ParameterDefinition*> definitions;
    definitions.reserve(candidate.parameters.size());
    for (const auto& parameter : candidate.parameters) {
      definitions.emplace(parameter.semantic_id, &parameter);
    }
    for (std::size_t index = 0U; index < candidate.parameters.size(); ++index) {
      auto& dependency = candidate.parameters[index].dependency;
      const std::string_view raw = raw_dependencies[index];
      if (raw == "always") {
        dependency.operation = DependencyOperator::always;
        continue;
      }
      std::size_t operator_position = raw.find("==");
      std::size_t operator_size = 2U;
      if (operator_position == std::string_view::npos) {
        operator_position = raw.find("!=");
      }
      if (operator_position == std::string_view::npos
          || raw.find("==", operator_position + operator_size)
              != std::string_view::npos
          || raw.find("!=", operator_position + operator_size)
              != std::string_view::npos) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_dependency, index + 2U,
            "dependency must be always, id==value, or id!=value");
      }
      dependency.operation = raw.substr(operator_position, operator_size) == "=="
          ? DependencyOperator::equals
          : DependencyOperator::not_equals;
      dependency.semantic_id = std::string{raw.substr(0U, operator_position)};
      if (!IsSemanticId(dependency.semantic_id)) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_dependency, index + 2U,
            "dependency target ID is malformed");
      }
      const auto target = definitions.find(dependency.semantic_id);
      if (target == definitions.end()) {
        return SchemaFailure(
            SchemaDiagnostic::unknown_dependency, index + 2U,
            "dependency target is unknown");
      }
      if (target->second->type == ParameterType::color3
          || !ParseValue(raw.substr(operator_position + operator_size),
                         target->second->type,
                         dependency.comparison)) {
        return SchemaFailure(
            SchemaDiagnostic::invalid_dependency, index + 2U,
            "dependency comparison has the wrong type");
      }
    }

    const SchemaResult semantic_validation = ValidateSchema(candidate, false);
    if (!semantic_validation.ok()) {
      return semantic_validation;
    }
    candidate.abi_sha256 = ComputeFingerprintUnchecked(candidate);
    const SchemaResult validated = ValidateSchema(candidate, true);
    if (!validated.ok()) {
      return validated;
    }
    output = std::move(candidate);
    return {};
  } catch (const std::exception& error) {
    return SchemaFailure(
        SchemaDiagnostic::malformed_csv, 0U,
        std::string{"schema parser exception: "} + error.what());
  } catch (...) {
    return SchemaFailure(
        SchemaDiagnostic::malformed_csv, 0U, "schema parser exception");
  }
}

SchemaResult CompileNativeParameterArtifacts(
    const NativeParameterSchema& schema,
    NativeArtifacts& output) noexcept {
  try {
    const SchemaResult validated = ValidateSchema(schema);
    if (!validated.ok()) {
      return validated;
    }
    NativeArtifacts candidate;
    candidate.hlsl_ui =
        "#ifndef ELDER_NATIVE_PARAMETERS_FXH\n"
        "#define ELDER_NATIVE_PARAMETERS_FXH\n\n"
        "// Generated from stable Elder semantic IDs. Do not hand-edit.\n"
        "// schema_sha256=" + schema.abi_sha256 + "\n"
        "#define ELDER_NATIVE_PARAMETER_SCHEMA_SHA256 \""
        + schema.abi_sha256 + "\"\n\n"
        "bool ElderNativeFinite(float value)\n"
        "{\n"
        "    return (asuint(value) & 0x7f800000u) != 0x7f800000u;\n"
        "}\n\n"
        "bool ElderNativeFinite3(float3 value)\n"
        "{\n"
        "    uint3 exponent = asuint(value) & 0x7f800000u;\n"
        "    return all(exponent != 0x7f800000u.xxx);\n"
        "}\n\n";
    candidate.cpp_defaults =
        "#pragma once\n\n"
        "#include <array>\n"
        "#include <string_view>\n\n"
        "namespace elder::shaders::generated {\n\n"
        "inline constexpr std::string_view kNativeParameterSchemaSha256 = \""
        + schema.abi_sha256 + "\";\n\n";
    candidate.manifest_json = "{\"schema\":\""
        + EscapeJson(schema.schema_id) + "\",\"schema_sha256\":\""
        + schema.abi_sha256 + "\",\"parameters\":[";
    candidate.default_profile =
        "profile=ELDER_NATIVE_PROFILE_V1\n"
        "parameter_schema=" + schema.schema_id + "\n"
        "parameter_schema_sha256=" + schema.abi_sha256 + "\n"
        "opacity=1\n"
        "[parameters]\n";

    for (std::size_t index = 0U; index < schema.parameters.size(); ++index) {
      const auto& parameter = schema.parameters[index];
      candidate.hlsl_ui += "// semantic_id=" + parameter.semantic_id
          + " layer=" + std::string{LayerPolicyName(parameter.layer_policy)}
          + " dependency=" + DependencyText(parameter) + "\n";
      const std::string type = parameter.type == ParameterType::color3
          ? "float3"
          : std::string{TypeName(parameter.type)};
      candidate.hlsl_ui += type + " " + parameter.symbol + "\n<\n"
          "    string UIName = \"" + parameter.ui_group + " | "
          + parameter.ui_label + "\";\n";
      candidate.hlsl_ui += "    string UIWidget = \""
          + std::string{
              parameter.widget == UiWidget::color
                  ? "Color"
                  : parameter.widget == UiWidget::checkbox ? "Checkbox" : "Spinner"}
          + "\";\n";
      if (parameter.type != ParameterType::boolean) {
        const bool integer = parameter.type == ParameterType::integer;
        const std::string annotation_type = integer ? "int" : "float";
        const auto number = [&](const double value) {
          return integer ? FormatNumber(value) : FormatHlslNumber(value);
        };
        candidate.hlsl_ui += "    " + annotation_type + " UIMin = "
            + number(parameter.minimum) + ";\n"
            "    " + annotation_type + " UIMax = "
            + number(parameter.maximum) + ";\n"
            "    " + annotation_type + " UIStep = "
            + number(parameter.step) + ";\n";
      }
      candidate.hlsl_ui += "> = {";
      candidate.hlsl_ui += FormatValue(parameter, parameter.default_value, true);
      candidate.hlsl_ui += "};\n\n";
      candidate.hlsl_ui += type + " ElderNativeSanitize_" + parameter.symbol
          + "()\n{\n";
      if (parameter.type == ParameterType::boolean) {
        candidate.hlsl_ui += "    return " + parameter.symbol + ";\n";
      } else if (parameter.type == ParameterType::integer) {
        candidate.hlsl_ui += "    return clamp(" + parameter.symbol + ", "
            + FormatNumber(parameter.minimum) + ", "
            + FormatNumber(parameter.maximum) + ");\n";
      } else {
        const std::string fallback = parameter.type == ParameterType::color3
            ? "float3(" + FormatValue(
                parameter, parameter.default_value, true) + ")"
            : FormatHlslNumber(parameter.default_value.components[0]);
        const std::string minimum = parameter.type == ParameterType::color3
            ? FormatHlslNumber(parameter.minimum) + ".xxx"
            : FormatHlslNumber(parameter.minimum);
        const std::string maximum = parameter.type == ParameterType::color3
            ? FormatHlslNumber(parameter.maximum) + ".xxx"
            : FormatHlslNumber(parameter.maximum);
        const std::string finite = parameter.type == ParameterType::color3
            ? "ElderNativeFinite3(" + parameter.symbol + ")"
            : "ElderNativeFinite(" + parameter.symbol + ")";
        candidate.hlsl_ui += "    return " + finite + "\n"
            "        ? clamp(" + parameter.symbol + ", " + minimum + ", "
            + maximum + ")\n"
            "        : " + fallback + ";\n";
      }
      candidate.hlsl_ui += "}\n\n";

      candidate.cpp_defaults += "inline constexpr std::string_view "
          + parameter.symbol + "SemanticId = \"" + parameter.semantic_id
          + "\";\n";
      if (parameter.type == ParameterType::color3) {
        candidate.cpp_defaults += "inline constexpr std::array<double, 3> "
            + parameter.symbol + "Default{"
            + FormatValue(parameter, parameter.default_value, true) + "};\n"
            "inline constexpr std::array<double, 3> " + parameter.symbol
            + "LayerIdentity{"
            + FormatValue(parameter, parameter.layer_identity, true) + "};\n";
      } else {
        const std::string cpp_type = parameter.type == ParameterType::boolean
            ? "bool"
            : parameter.type == ParameterType::integer ? "int" : "double";
        candidate.cpp_defaults += "inline constexpr " + cpp_type + " "
            + parameter.symbol + "Default = "
            + FormatValue(parameter, parameter.default_value, false) + ";\n"
            "inline constexpr " + cpp_type + " " + parameter.symbol
            + "LayerIdentity = "
            + FormatValue(parameter, parameter.layer_identity, false) + ";\n";
      }
      candidate.cpp_defaults += "inline constexpr double " + parameter.symbol
          + "Minimum = " + FormatNumber(parameter.minimum) + ";\n"
          "inline constexpr double " + parameter.symbol + "Maximum = "
          + FormatNumber(parameter.maximum) + ";\n"
          "inline constexpr double " + parameter.symbol + "Step = "
          + FormatNumber(parameter.step) + ";\n"
          "inline constexpr double " + parameter.symbol + "LayerMinimum = "
          + FormatNumber(parameter.layer_minimum) + ";\n"
          "inline constexpr double " + parameter.symbol + "LayerMaximum = "
          + FormatNumber(parameter.layer_maximum) + ";\n\n";

      if (index != 0U) candidate.manifest_json += ',';
      candidate.manifest_json +=
          "{\"ordinal\":" + std::to_string(parameter.ordinal)
          + ",\"semantic_id\":\"" + EscapeJson(parameter.semantic_id)
          + "\",\"symbol\":\"" + EscapeJson(parameter.symbol)
          + "\",\"type\":\"" + std::string{TypeName(parameter.type)}
          + "\",\"unit\":\"" + std::string{UnitName(parameter.unit)}
          + "\",\"minimum\":" + FormatNumber(parameter.minimum)
          + ",\"maximum\":" + FormatNumber(parameter.maximum)
           + ",\"step\":" + FormatNumber(parameter.step)
           + ",\"default\":\""
           + EscapeJson(FormatValue(parameter, parameter.default_value, false))
           + "\",\"layer_minimum\":" + FormatNumber(parameter.layer_minimum)
           + ",\"layer_maximum\":" + FormatNumber(parameter.layer_maximum)
           + ",\"layer_identity\":\""
           + EscapeJson(FormatValue(parameter, parameter.layer_identity, false))
           + "\",\"ui_group\":\"" + EscapeJson(parameter.ui_group)
          + "\",\"ui_label\":\"" + EscapeJson(parameter.ui_label)
          + "\",\"widget\":\"" + std::string{WidgetName(parameter.widget)}
          + "\",\"layer_policy\":\""
          + std::string{LayerPolicyName(parameter.layer_policy)}
          + "\",\"dependency\":\"" + EscapeJson(DependencyText(parameter))
          + "\"}";
      candidate.default_profile += parameter.semantic_id + "="
          + FormatValue(parameter, parameter.default_value, false) + "\n";
    }

    std::unordered_map<std::string_view, const ParameterDefinition*> by_id;
    by_id.reserve(schema.parameters.size());
    for (const auto& parameter : schema.parameters) {
      by_id.emplace(parameter.semantic_id, &parameter);
    }
    std::function<std::string(const ParameterDefinition&)> activity_expression =
        [&](const ParameterDefinition& parameter) -> std::string {
      if (parameter.dependency.operation == DependencyOperator::always) {
        return "true";
      }
      const auto target = by_id.find(parameter.dependency.semantic_id);
      if (target == by_id.end()) {
        return "false";
      }
      const std::string comparison = FormatValue(
          *target->second, parameter.dependency.comparison, true);
      const std::string operation =
          parameter.dependency.operation == DependencyOperator::equals
              ? " == "
              : " != ";
      return "(" + activity_expression(*target->second) + " && ("
          "ElderNativeSanitize_" + target->second->symbol + "()"
          + operation + comparison + "))";
    };
    for (const auto& parameter : schema.parameters) {
      candidate.hlsl_ui += "bool ElderNativeActive_" + parameter.symbol
          + "()\n{\n    return " + activity_expression(parameter) + ";\n}\n\n";
    }
    candidate.hlsl_ui += "#endif\n";
    candidate.cpp_defaults += "}  // namespace elder::shaders::generated\n";
    candidate.manifest_json += "]}\n";
    output = std::move(candidate);
    return {};
  } catch (const std::exception& error) {
    return SchemaFailure(
        SchemaDiagnostic::invalid_text, 0U,
        std::string{"artifact compiler exception: "} + error.what());
  } catch (...) {
    return SchemaFailure(
        SchemaDiagnostic::invalid_text, 0U, "artifact compiler exception");
  }
}

ProfileResult ParseNativeProfile(
    const std::string_view text,
    const NativeParameterSchema& schema,
    const bool require_complete,
    NativeProfile& output) noexcept {
  try {
    if (text.empty()) {
      return ProfileFailure(
          ProfileDiagnostic::empty_input, 0U, "profile input is empty");
    }
    if (text.size() > kMaximumProfileBytes) {
      return ProfileFailure(
          ProfileDiagnostic::malformed_line, 0U,
          "profile exceeds the maximum supported size");
    }
    const SchemaResult schema_result = ValidateSchema(schema);
    if (!schema_result.ok()) {
      return ProfileFailure(
          ProfileDiagnostic::wrong_schema_id, 0U,
          "parameter schema is invalid");
    }
    const auto lines = Lines(text);
    if (lines.size() < 5U) {
      return ProfileFailure(
          ProfileDiagnostic::malformed_line, 0U,
          "profile header is incomplete");
    }
    if (lines[0] != "profile=ELDER_NATIVE_PROFILE_V1") {
      return ProfileFailure(
          ProfileDiagnostic::wrong_profile_id, 1U,
          "profile ID is not supported");
    }
    const std::string schema_line = "parameter_schema=" + schema.schema_id;
    if (lines[1] != schema_line) {
      return ProfileFailure(
          ProfileDiagnostic::wrong_schema_id, 2U,
          "profile parameter schema ID does not match");
    }
    const std::string fingerprint_line =
        "parameter_schema_sha256=" + schema.abi_sha256;
    if (lines[2] != fingerprint_line) {
      return ProfileFailure(
          ProfileDiagnostic::wrong_schema_fingerprint, 3U,
          "profile parameter schema SHA-256 does not match");
    }
    constexpr std::string_view opacity_prefix = "opacity=";
    if (!lines[3].starts_with(opacity_prefix)) {
      return ProfileFailure(
          ProfileDiagnostic::malformed_line, 4U,
          "profile opacity line is missing");
    }
    double opacity{};
    if (!ParseNumber(lines[3].substr(opacity_prefix.size()), opacity)
        || opacity < 0.0 || opacity > 1.0) {
      return ProfileFailure(
          ProfileDiagnostic::invalid_opacity, 4U,
          "profile opacity must be in [0,1]");
    }
    if (lines[4] != "[parameters]") {
      return ProfileFailure(
          ProfileDiagnostic::missing_parameters_section, 5U,
          "profile parameters section is missing");
    }

    NativeProfile candidate;
    candidate.parameter_schema_id = schema.schema_id;
    candidate.parameter_schema_sha256 = schema.abi_sha256;
    candidate.opacity = opacity;
    for (std::size_t index = 5U; index < lines.size(); ++index) {
      const auto line = lines[index];
      if (line.empty()) continue;
      if (line.size() > kMaximumFieldBytes * 2U) {
        return ProfileFailure(
            ProfileDiagnostic::malformed_line, index + 1U,
            "profile parameter line exceeds the maximum supported size");
      }
      const std::size_t equals = line.find('=');
      if (equals == std::string_view::npos || equals == 0U
          || equals + 1U >= line.size()
          || line.find('=', equals + 1U) != std::string_view::npos) {
        return ProfileFailure(
            ProfileDiagnostic::malformed_line, index + 1U,
            "profile parameter line must be id=value");
      }
      const std::string_view id = line.substr(0U, equals);
      const ParameterDefinition* definition = FindDefinition(schema, id);
      if (definition == nullptr) {
        return ProfileFailure(
            ProfileDiagnostic::unknown_parameter, index + 1U,
            "profile parameter is unknown");
      }
      ParameterValue value;
      if (!ParseProfileValue(
              line.substr(equals + 1U),
              *definition,
              !require_complete,
              value)) {
        return ProfileFailure(
            ProfileDiagnostic::invalid_value, index + 1U,
            "profile value has the wrong type or range");
      }
      if (!candidate.values.emplace(std::string{id}, value).second) {
        return ProfileFailure(
            ProfileDiagnostic::duplicate_parameter, index + 1U,
            "profile parameter is duplicated");
      }
    }
    const ProfileResult validated = ValidateProfile(
        schema, candidate, require_complete, false, !require_complete);
    if (!validated.ok()) {
      return validated;
    }
    output = std::move(candidate);
    return {};
  } catch (const std::exception& error) {
    return ProfileFailure(
        ProfileDiagnostic::malformed_line, 0U,
        std::string{"profile parser exception: "} + error.what());
  } catch (...) {
    return ProfileFailure(
        ProfileDiagnostic::malformed_line, 0U, "profile parser exception");
  }
}

ProfileResult ComposeNativeProfileStack(
    const NativeParameterSchema& schema,
    const NativeProfile& base,
    const std::vector<NativeProfile>& layers,
    NativeProfile& output) noexcept {
  try {
    if (!ValidateSchema(schema).ok()) {
      return ProfileFailure(
          ProfileDiagnostic::invalid_base_profile, 0U,
          "parameter schema is invalid");
    }
    const ProfileResult base_result = ValidateProfile(
        schema, base, true, true, false);
    if (!base_result.ok()) {
      return ProfileFailure(
          ProfileDiagnostic::invalid_base_profile, 0U,
          "base profile is not complete and valid");
    }
    NativeProfile candidate = base;
    candidate.opacity = 1.0;

    std::unordered_map<std::string_view, std::size_t> parameter_indexes;
    parameter_indexes.reserve(schema.parameters.size());
    for (std::size_t index = 0U; index < schema.parameters.size(); ++index) {
      parameter_indexes.emplace(schema.parameters[index].semantic_id, index);
    }
    std::vector<std::size_t> composition_order;
    composition_order.reserve(schema.parameters.size());
    std::vector<bool> scheduled(schema.parameters.size(), false);
    while (composition_order.size() < schema.parameters.size()) {
      bool progressed = false;
      for (std::size_t index = 0U; index < schema.parameters.size(); ++index) {
        if (scheduled[index]) continue;
        const auto& dependency = schema.parameters[index].dependency;
        bool ready = dependency.operation == DependencyOperator::always;
        if (!ready) {
          const auto target = parameter_indexes.find(dependency.semantic_id);
          ready = target != parameter_indexes.end() && scheduled[target->second];
        }
        if (ready) {
          composition_order.push_back(index);
          scheduled[index] = true;
          progressed = true;
        }
      }
      if (!progressed) {
        return ProfileFailure(
            ProfileDiagnostic::invalid_base_profile, 0U,
            "parameter dependency order could not be resolved");
      }
    }

    for (std::size_t layer_index = 0U; layer_index < layers.size(); ++layer_index) {
      const NativeProfile& layer = layers[layer_index];
      const ProfileResult layer_result = ValidateProfile(
          schema, layer, false, false, true);
      if (!layer_result.ok()) {
        return layer_result;
      }
      for (const std::size_t parameter_index : composition_order) {
        const ParameterDefinition& definition = schema.parameters[parameter_index];
        const auto incoming_value = layer.values.find(definition.semantic_id);
        if (incoming_value == layer.values.end()) continue;
        if ((definition.type == ParameterType::boolean
             || definition.type == ParameterType::integer)
            && layer.opacity != 0.0 && layer.opacity != 1.0) {
          return ProfileFailure(
              ProfileDiagnostic::discrete_partial_opacity, layer_index + 1U,
              "discrete replacement requires opacity zero or one");
        }

        std::map<std::string, bool, std::less<>> activity;
        const ProfileResult activity_result = EvaluateNativeProfileActivity(
            schema, candidate, activity);
        if (!activity_result.ok()) {
          return activity_result;
        }
        const auto active = activity.find(definition.semantic_id);
        if (active == activity.end() || !active->second) {
          continue;
        }

        auto& destination = candidate.values.at(definition.semantic_id);
        const ParameterValue& layer_value = incoming_value->second;
        for (std::uint8_t component = 0U;
             component < destination.count;
             ++component) {
          const double original = destination.components[component];
          const double incoming = layer_value.components[component];
          double composed{};
          switch (definition.layer_policy) {
            case LayerPolicy::replace:
              composed = original + ((incoming - original) * layer.opacity);
              break;
            case LayerPolicy::add:
              composed = original + (incoming * layer.opacity);
              break;
            case LayerPolicy::multiply:
              composed = original
                  * (1.0 + ((incoming - 1.0) * layer.opacity));
              break;
            default:
              return ProfileFailure(
                  ProfileDiagnostic::invalid_base_profile, layer_index + 1U,
                  "layer policy is invalid");
          }
          if (!std::isfinite(composed)) {
            return ProfileFailure(
                ProfileDiagnostic::calculation_non_finite, layer_index + 1U,
                "layer composition produced a non-finite value");
          }
          destination.components[component] = std::clamp(
              composed, definition.minimum, definition.maximum);
        }
      }
    }
    output = std::move(candidate);
    return {};
  } catch (const std::exception& error) {
    return ProfileFailure(
        ProfileDiagnostic::invalid_base_profile, 0U,
        std::string{"profile composition exception: "} + error.what());
  } catch (...) {
    return ProfileFailure(
        ProfileDiagnostic::invalid_base_profile, 0U,
        "profile composition exception");
  }
}

ProfileResult EvaluateNativeProfileActivity(
    const NativeParameterSchema& schema,
    const NativeProfile& profile,
    std::map<std::string, bool, std::less<>>& output) noexcept {
  try {
    if (!ValidateSchema(schema).ok()) {
      return ProfileFailure(
          ProfileDiagnostic::wrong_schema_id, 0U,
          "parameter schema is invalid");
    }
    if (profile.parameter_schema_id != schema.schema_id) {
      return ProfileFailure(
          ProfileDiagnostic::wrong_schema_id, 0U,
          "profile parameter schema ID does not match");
    }
    if (profile.parameter_schema_sha256 != schema.abi_sha256) {
      return ProfileFailure(
          ProfileDiagnostic::wrong_schema_fingerprint, 0U,
          "profile parameter schema SHA-256 does not match");
    }
    if (profile.values.size() != schema.parameters.size()) {
      return ProfileFailure(
          ProfileDiagnostic::missing_parameter, 0U,
          "activity evaluation requires a complete profile");
    }

    std::unordered_map<std::string_view, std::size_t> by_id;
    by_id.reserve(schema.parameters.size());
    for (std::size_t index = 0U; index < schema.parameters.size(); ++index) {
      const auto& parameter = schema.parameters[index];
      by_id.emplace(parameter.semantic_id, index);
      const auto value = profile.values.find(parameter.semantic_id);
      if (value == profile.values.end()) {
        return ProfileFailure(
            ProfileDiagnostic::missing_parameter, 0U,
            "activity evaluation profile is missing a parameter");
      }
      if (!ValueWithinDefinition(parameter, value->second, false, false)) {
        return ProfileFailure(
            ProfileDiagnostic::invalid_value, 0U,
            "activity evaluation profile contains an invalid value");
      }
    }

    std::vector<std::uint8_t> states(schema.parameters.size(), 0U);
    std::vector<bool> active(schema.parameters.size(), false);
    std::function<bool(std::size_t)> evaluate =
        [&](const std::size_t index) -> bool {
      if (states[index] == 2U) return static_cast<bool>(active[index]);
      if (states[index] == 1U) return false;
      states[index] = 1U;
      const auto& parameter = schema.parameters[index];
      bool result = parameter.dependency.operation == DependencyOperator::always;
      if (!result) {
        const auto target = by_id.find(parameter.dependency.semantic_id);
        if (target != by_id.end() && evaluate(target->second)) {
          const ParameterValue& current =
              profile.values.at(parameter.dependency.semantic_id);
          bool equal = current.count == parameter.dependency.comparison.count;
          for (std::uint8_t component = 0U;
               equal && component < current.count;
               ++component) {
            equal = current.components[component]
                == parameter.dependency.comparison.components[component];
          }
          result = parameter.dependency.operation == DependencyOperator::equals
              ? equal
              : !equal;
        }
      }
      active[index] = result;
      states[index] = 2U;
      return result;
    };

    std::map<std::string, bool, std::less<>> candidate;
    for (std::size_t index = 0U; index < schema.parameters.size(); ++index) {
      candidate.emplace(schema.parameters[index].semantic_id, evaluate(index));
    }
    output = std::move(candidate);
    return {};
  } catch (const std::exception& error) {
    return ProfileFailure(
        ProfileDiagnostic::invalid_base_profile, 0U,
        std::string{"profile activity exception: "} + error.what());
  } catch (...) {
    return ProfileFailure(
        ProfileDiagnostic::invalid_base_profile, 0U,
        "profile activity exception");
  }
}

std::string ComputeNativeSchemaFingerprint(
    const NativeParameterSchema& schema) noexcept {
  try {
    return ComputeFingerprintUnchecked(schema);
  } catch (...) {
    return {};
  }
}

std::string ComputeSha256(const std::string_view bytes) noexcept {
  try {
    Sha256 sha;
    sha.update(bytes);
    const auto digest = sha.finish();
    constexpr char hex[] = "0123456789abcdef";
    std::string output;
    output.reserve(64U);
    for (const std::uint8_t value : digest) {
      output.push_back(hex[value >> 4U]);
      output.push_back(hex[value & 0x0FU]);
    }
    return output;
  } catch (...) {
    return {};
  }
}

bool SameValueBits(
    const ParameterValue& lhs,
    const ParameterValue& rhs) noexcept {
  if (lhs.count != rhs.count || lhs.count == 0U || lhs.count > 3U) {
    return false;
  }
  for (std::uint8_t index = 0U; index < lhs.count; ++index) {
    if (std::bit_cast<std::uint64_t>(lhs.components[index])
        != std::bit_cast<std::uint64_t>(rhs.components[index])) {
      return false;
    }
  }
  return true;
}

}  // namespace elder::shaders
