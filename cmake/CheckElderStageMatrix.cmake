cmake_minimum_required(VERSION 3.30)

foreach(required_variable IN ITEMS ELDER_FXC ELDER_SOURCE_DIR ELDER_BINARY_DIR)
  if(NOT DEFINED ${required_variable} OR "${${required_variable}}" STREQUAL "")
    message(FATAL_ERROR "Missing required variable: ${required_variable}")
  endif()
endforeach()

if(NOT EXISTS "${ELDER_FXC}")
  message(FATAL_ERROR "Exact x64 FXC executable is absent: ${ELDER_FXC}")
endif()
if(NOT IS_DIRECTORY "${ELDER_SOURCE_DIR}")
  message(FATAL_ERROR "Elder source directory is absent: ${ELDER_SOURCE_DIR}")
endif()
if(NOT IS_DIRECTORY "${ELDER_BINARY_DIR}")
  message(FATAL_ERROR "Elder binary directory is absent: ${ELDER_BINARY_DIR}")
endif()

file(REAL_PATH "${ELDER_SOURCE_DIR}" elder_source_dir)
file(REAL_PATH "${ELDER_BINARY_DIR}" elder_binary_dir)
set(elder_matrix_root "${elder_binary_dir}/shader-matrix")
set(elder_generated_native_root "${elder_matrix_root}/generated-native")

# Stock FXC searches the including file's directory before /I roots, while
# ENBSeries resolves nested public includes from the installed enbseries root.
# Enforce the host layout before compiling so sibling-relative includes cannot
# make the offline matrix greener than the installed shader tree.
include("${elder_source_dir}/cmake/CheckElderHostIncludeLayout.cmake")

set(elder_stage_sources
  shaders/enbeffectprepass.fx
  shaders/enbdepthoffield.fx
  shaders/enbbloom.fx
  shaders/enbadaptation.fx
  shaders/enblens.fx
  shaders/enbeffect.fx
  shaders/enbeffectpostpass.fx
  shaders/enbsunsprite.fx
  shaders/enbunderwater.fx)

foreach(stage_source IN LISTS elder_stage_sources)
  if(NOT EXISTS "${elder_source_dir}/${stage_source}")
    message(FATAL_ERROR "Elder stage is absent: ${stage_source}")
  endif()
endforeach()

set(elder_compile_script "${elder_source_dir}/cmake/CompileElderStage.cmake")
set(elder_common "${elder_source_dir}/shaders/elder/ElderPipelineCommon.fxh")
set(elder_capabilities "${elder_source_dir}/shaders/elder/ElderHostCapabilities.fxh")
set(elder_parameters "${elder_source_dir}/shaders/elder/ElderStageParameters.fxh")
set(elder_quality "${elder_source_dir}/shaders/elder/ElderQuality.fxh")
set(elder_tier "${elder_source_dir}/shaders/elder/ElderTier.fxh")
set(elder_native_schema "${elder_source_dir}/native/schema/elder-native-parameters.csv")
set(elder_color_core "${elder_source_dir}/native/shaders/ElderColorCore.fxh")
set(elder_preset_generator "${elder_source_dir}/cmake/GenerateElderQualityPresets.cmake")

foreach(required_file IN ITEMS
    "${elder_compile_script}"
    "${elder_common}"
    "${elder_capabilities}"
    "${elder_parameters}"
    "${elder_quality}"
    "${elder_tier}"
    "${elder_native_schema}"
    "${elder_color_core}"
    "${elder_preset_generator}")
  if(NOT EXISTS "${required_file}")
    message(FATAL_ERROR "Elder stage matrix requires source: ${required_file}")
  endif()
endforeach()

function(require_elder_contract_tokens source_file contract_name)
  file(READ "${source_file}" contract_source)
  foreach(required_token IN LISTS ARGN)
    string(FIND "${contract_source}" "${required_token}" token_position)
    if(token_position EQUAL -1)
      message(FATAL_ERROR
        "${contract_name} is missing required contract token: ${required_token}")
    endif()
  endforeach()
endfunction()

function(require_elder_source_order source_file earlier_token later_token contract_name)
  file(READ "${source_file}" source_contents)
  string(FIND "${source_contents}" "${earlier_token}" earlier_position)
  string(FIND "${source_contents}" "${later_token}" later_position)
  if(earlier_position EQUAL -1 OR later_position EQUAL -1
      OR earlier_position GREATER_EQUAL later_position)
    message(FATAL_ERROR
      "${contract_name} must preserve ${earlier_token} before ${later_token}")
  endif()
endfunction()

file(READ "${elder_native_schema}" elder_native_schema_source)
foreach(required_native_symbol IN ITEMS
    "ELDER_NATIVE_PARAMETERS_V1"
    "ElderMasterEnabled"
    "ElderExposureCompensationEv"
    "ElderTonemapToe"
    "ElderTonemapShoulder"
    "ElderTonemapMidGray"
    "ElderTonemapWhitePoint"
    "ElderColorSaturation"
    "ElderHighlightTint")
  string(FIND "${elder_native_schema_source}" "${required_native_symbol}" native_symbol_position)
  if(native_symbol_position EQUAL -1)
    message(FATAL_ERROR
      "Native parameter ABI schema is missing required symbol: ${required_native_symbol}")
  endif()
endforeach()

set(elder_main_effect "${elder_source_dir}/shaders/enbeffect.fx")
require_elder_source_order("${elder_main_effect}"
  "#include \"ElderNativeParameters.fxh\""
  "#include \"elder/ElderStageParameters.fxh\""
  "Main effect native ABI")
require_elder_source_order("${elder_main_effect}"
  "#include \"elder/ElderStageParameters.fxh\""
  "#include \"elder/ElderPipelineCommon.fxh\""
  "Main effect stage contract")

require_elder_contract_tokens("${elder_common}" "Elder pipeline common"
  "ElderFinite1"
  "ElderFiniteOrBlack"
  "ElderDepthMask"
  "ELDER_DEPTH_CONVENTION_DEVICE_Z_SKY_AT_ONE"
  "ElderIdentityColor"
  "ElderNativeCapability(ElderCapabilityValue value)"
  "ElderBridgeCapability(ElderCapabilityValue value)"
  "ElderSpatialCapability(ElderCapabilityValue value)"
  "ElderIdentityCapability(ElderCapabilityValue value)"
  "ElderResolveCapability("
  "ElderResolveCapabilityColor(")
require_elder_contract_tokens("${elder_capabilities}" "Elder host capabilities"
  "#define ELDER_CAPABILITY_IDENTITY 0"
  "#define ELDER_CAPABILITY_SPATIAL  1"
  "#define ELDER_CAPABILITY_BRIDGE   2"
  "#define ELDER_CAPABILITY_NATIVE   3"
  "ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE"
  "ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE"
  "ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE"
  "ELDER_STAGE_OWNS_BRIDGE_VALUE"
  "Full-frame history is unavailable"
  "Object motion vectors are unavailable"
  "Current-frame scratch cannot be treated as persistent history"
  "Cross-effect alpha packing requires an explicit round-trip contract")
require_elder_contract_tokens("${elder_parameters}" "Elder stage parameters"
  "Elder 00 |"
  "Elder 10 |"
  "Elder 20 |"
  "Elder 30 |"
  "Elder 40 |"
  "Elder 50 |"
  "Elder 60 |"
  "Elder 70 |"
  "Elder 80 |"
  "Elder 90 |"
  "Balanced"
  "= true;"
  "= 1.0;")
file(READ "${elder_parameters}" elder_stage_parameter_source)
foreach(forbidden_main_parameter IN ITEMS
    "bool ElderMasterEnabled"
    "float ElderMasterIntensity")
  string(FIND "${elder_stage_parameter_source}" "${forbidden_main_parameter}"
    forbidden_main_parameter_position)
  if(NOT forbidden_main_parameter_position EQUAL -1)
    message(FATAL_ERROR
      "Stage parameters must not redefine native ABI control: ${forbidden_main_parameter}")
  endif()
endforeach()

# ENB persists every annotated knob to the stage .fx.ini keyed by its UIName.
# A label that opens with '[' reads back as a section header and an embedded
# '=' or ';' splits or comments the saved line, so such a value can never
# round-trip through ENB's own save format.
string(REGEX MATCHALL "UIName = \"[^\"]*\"" elder_stage_ui_annotations
  "${elder_stage_parameter_source}")
list(LENGTH elder_stage_ui_annotations elder_stage_ui_annotation_count)
if(elder_stage_ui_annotation_count EQUAL 0)
  message(FATAL_ERROR "Stage parameters declare no UIName annotations")
endif()
foreach(elder_stage_ui_annotation IN LISTS elder_stage_ui_annotations)
  string(REGEX REPLACE "^UIName = \"(.*)\"$" "\\1" elder_stage_ui_label
    "${elder_stage_ui_annotation}")
  if(NOT elder_stage_ui_label MATCHES "^[A-Za-z0-9]")
    message(FATAL_ERROR
      "UIName must open with an alphanumeric character to survive as an INI key: ${elder_stage_ui_label}")
  endif()
  if(elder_stage_ui_label MATCHES "(\\[|\\]|=|;)")
    message(FATAL_ERROR
      "UIName cannot round-trip as an INI key with '[', ']', '=', or ';': ${elder_stage_ui_label}")
  endif()
endforeach()

file(READ "${elder_compile_script}" elder_compile_script_source)
string(FIND "${elder_compile_script_source}" "/DELDER_QUALITY_TIER" elder_compile_defines_tier_position)
if(NOT elder_compile_defines_tier_position EQUAL -1)
  message(FATAL_ERROR
    "Stage compiler must consume generated ElderTier.fxh overlays, not /D ELDER_QUALITY_TIER")
endif()

set(elder_stage_rows
  "enbeffectprepass.fx|Draw"
  "enbdepthoffield.fx|Draw"
  "enbbloom.fx|Draw"
  "enbadaptation.fx|Draw"
  "enblens.fx|Draw"
  "enbeffect.fx|Draw"
  "enbeffectpostpass.fx|Draw"
  "enbsunsprite.fx|Draw"
  "enbunderwater.fx|Draw")

file(REMOVE_RECURSE "${elder_matrix_root}")
file(MAKE_DIRECTORY "${elder_matrix_root}/negative" "${elder_generated_native_root}")
file(WRITE "${elder_generated_native_root}/ElderNativeParameters.fxh" [=[
#ifndef ELDER_NATIVE_PARAMETERS_FXH
#define ELDER_NATIVE_PARAMETERS_FXH

bool ElderMasterEnabled
<
    string UIName = "Master | Enabled";
> = true;
float ElderExposureCompensationEv = 0.0;
float ElderColorWarmCool = 0.0;
float ElderColorTint = 0.0;
float ElderTonemapToe = 0.22;
float ElderTonemapShoulder = 0.58;
float ElderTonemapMidGray = 0.18;
float ElderTonemapWhitePoint = 11.2;
float ElderTonemapLocalContrast = 0.34;
float ElderColorSaturation = 1.0;
float ElderColorVibrance = 0.0;
float ElderHighlightDesaturation = 0.0;
float ElderHighlightGamutPreservation = 1.0;
float ElderShadowHueStability = 1.0;
float3 ElderShadowTint = {1.0, 1.0, 1.0};
float3 ElderHighlightTint = {1.0, 1.0, 1.0};

bool ElderNativeSanitize_ElderMasterEnabled() { return ElderMasterEnabled; }
bool ElderNativeActive_ElderMasterEnabled() { return true; }
float ElderNativeSanitize_ElderExposureCompensationEv() { return clamp(ElderExposureCompensationEv, -8.0, 8.0); }
float ElderNativeSanitize_ElderColorWarmCool() { return clamp(ElderColorWarmCool, -1.0, 1.0); }
float ElderNativeSanitize_ElderColorTint() { return clamp(ElderColorTint, -1.0, 1.0); }
float ElderNativeSanitize_ElderTonemapToe() { return clamp(ElderTonemapToe, 0.0, 1.0); }
float ElderNativeSanitize_ElderTonemapShoulder() { return clamp(ElderTonemapShoulder, 0.0, 1.0); }
float ElderNativeSanitize_ElderTonemapMidGray() { return clamp(ElderTonemapMidGray, 0.05, 0.5); }
float ElderNativeSanitize_ElderTonemapWhitePoint() { return clamp(ElderTonemapWhitePoint, 1.0, 32.0); }
float ElderNativeSanitize_ElderTonemapLocalContrast() { return clamp(ElderTonemapLocalContrast, 0.0, 2.0); }
float ElderNativeSanitize_ElderColorSaturation() { return clamp(ElderColorSaturation, 0.0, 2.0); }
float ElderNativeSanitize_ElderColorVibrance() { return clamp(ElderColorVibrance, 0.0, 2.0); }
float ElderNativeSanitize_ElderHighlightDesaturation() { return clamp(ElderHighlightDesaturation, 0.0, 1.0); }
float ElderNativeSanitize_ElderHighlightGamutPreservation() { return clamp(ElderHighlightGamutPreservation, 0.0, 1.0); }
float ElderNativeSanitize_ElderShadowHueStability() { return clamp(ElderShadowHueStability, 0.0, 1.0); }
float3 ElderNativeSanitize_ElderShadowTint() { return saturate(ElderShadowTint); }
float3 ElderNativeSanitize_ElderHighlightTint() { return saturate(ElderHighlightTint); }

#endif
]=])

function(expect_elder_stage_rejection case_name source_name source_token replacement)
  set(source_path "${elder_source_dir}/shaders/${source_name}")
  file(READ "${source_path}" source_contents)
  string(FIND "${source_contents}" "${source_token}" source_token_position)
  if(source_token_position EQUAL -1)
    message(FATAL_ERROR
      "Negative matrix fixture ${case_name} cannot locate: ${source_token}")
  endif()
  string(REPLACE "${source_token}" "${replacement}" rejected_contents
    "${source_contents}")
  set(rejected_source "${elder_matrix_root}/negative/${case_name}.fx")
  file(WRITE "${rejected_source}" "${rejected_contents}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}"
      "-DELDER_FXC=${ELDER_FXC}"
      "-DELDER_SOURCE_DIR=${elder_source_dir}"
      "-DELDER_STAGE_SOURCE=${rejected_source}"
      "-DELDER_STAGE_TECHNIQUE=Draw"
      "-DELDER_QUALITY_TIER=1"
      "-DELDER_GENERATED_INCLUDE=${elder_generated_native_root}"
      "-DELDER_OUTPUT=${elder_matrix_root}/negative/${case_name}.fxo"
      "-DELDER_LISTING=${elder_matrix_root}/negative/${case_name}.asm"
      -P "${elder_compile_script}"
    RESULT_VARIABLE rejected_result
    OUTPUT_VARIABLE rejected_stdout
    ERROR_VARIABLE rejected_stderr)
  if(rejected_result EQUAL 0)
    message(FATAL_ERROR
      "Negative matrix fixture was accepted: ${case_name}\n${rejected_stdout}${rejected_stderr}")
  endif()
endfunction()

function(expect_elder_synthesized_vertex_rejection)
  set(source_path "${elder_source_dir}/shaders/enbbloom.fx")
  file(READ "${source_path}" source_contents)
  string(REPLACE
    "ElderFullscreenVertex()"
    "ElderSynthesizedFullscreenVertex()"
    rejected_contents "${source_contents}")
  set(synthesized_vertex [=[
ElderStageVSOutput ElderSynthesizedFullscreenVertex(uint vertex_id : SV_VertexID)
{
    ElderStageVSOutput output;
    float2 triangle_position = vertex_id == 0u
        ? float2(-1.0, -1.0)
        : (vertex_id == 1u ? float2(-1.0, 3.0) : float2(3.0, -1.0));
    output.position = float4(triangle_position, 0.0, 1.0);
    output.texcoord = triangle_position * float2(0.5, -0.5) + 0.5;
    return output;
}

]=])
  string(REPLACE "technique11 Draw"
    "${synthesized_vertex}technique11 Draw"
    rejected_contents "${rejected_contents}")
  set(rejected_source
    "${elder_matrix_root}/negative/synthesized-host-vertex.fx")
  file(WRITE "${rejected_source}" "${rejected_contents}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}"
      "-DELDER_FXC=${ELDER_FXC}"
      "-DELDER_SOURCE_DIR=${elder_source_dir}"
      "-DELDER_STAGE_SOURCE=${rejected_source}"
      "-DELDER_STAGE_TECHNIQUE=Draw"
      "-DELDER_QUALITY_TIER=1"
      "-DELDER_GENERATED_INCLUDE=${elder_generated_native_root}"
      "-DELDER_OUTPUT=${elder_matrix_root}/negative/synthesized-host-vertex.fxo"
      "-DELDER_LISTING=${elder_matrix_root}/negative/synthesized-host-vertex.asm"
      -P "${elder_compile_script}"
    RESULT_VARIABLE rejected_result
    OUTPUT_VARIABLE rejected_stdout
    ERROR_VARIABLE rejected_stderr)
  if(rejected_result EQUAL 0)
    message(FATAL_ERROR
      "Reflected host signature accepted synthesized SV_VertexID geometry")
  endif()
endfunction()

expect_elder_synthesized_vertex_rejection()

expect_elder_stage_rejection("full-frame-history"
  "enbeffectprepass.fx"
  "#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0"
  "#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 1")
expect_elder_stage_rejection("object-motion"
  "enbeffectprepass.fx"
  "#define ELDER_STAGE_OWNS_OBJECT_MOTION 0"
  "#define ELDER_STAGE_OWNS_OBJECT_MOTION 1")
expect_elder_stage_rejection("foreign-scratch-read"
  "enbeffectprepass.fx"
  "#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE"
  "#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_ADAPTATION")
expect_elder_stage_rejection("scratch-as-history"
  "enbeffectprepass.fx"
  "#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0"
  "#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 1")
expect_elder_stage_rejection("cross-effect-alpha-packing"
  "enbeffectprepass.fx"
  "#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0"
  "#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 1")
expect_elder_stage_rejection("non-adaptation-texture-previous"
  "enbeffectprepass.fx"
  "Texture2D TextureColor;"
  "Texture2D TexturePrevious;")
expect_elder_stage_rejection("false-resource-declaration"
  "enbbloom.fx"
  "Texture2D TextureColor;"
  "Texture2D TextureColor;\nTexture2D TextureDepth;")

set(elder_capability_probe "${elder_matrix_root}/ElderCapabilityProbe.hlsl")
file(WRITE "${elder_capability_probe}" [=[
#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_NATIVE
#define ELDER_STAGE_OWNS_COLOR 0
#define ELDER_STAGE_OWNS_DEPTH ELDER_PROBE_SPATIAL_AVAILABLE
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW ELDER_PROBE_NATIVE_AVAILABLE
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE ELDER_PROBE_BRIDGE_AVAILABLE
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE ELDER_PROBE_NATIVE_AVAILABLE
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE ELDER_PROBE_BRIDGE_AVAILABLE
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE ELDER_PROBE_SPATIAL_AVAILABLE
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_NONE
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderPipelineCommon.fxh"

#if ELDER_PROBE_NATIVE_AVAILABLE
#define ELDER_PROBE_COMPILED_ROUTE ELDER_CAPABILITY_NATIVE
#elif ELDER_PROBE_BRIDGE_AVAILABLE
#define ELDER_PROBE_COMPILED_ROUTE ELDER_CAPABILITY_BRIDGE
#elif ELDER_PROBE_SPATIAL_AVAILABLE
#define ELDER_PROBE_COMPILED_ROUTE ELDER_CAPABILITY_SPATIAL
#else
#define ELDER_PROBE_COMPILED_ROUTE ELDER_CAPABILITY_IDENTITY
#endif

#if ELDER_PROBE_COMPILED_ROUTE != ELDER_PROBE_EXPECTED_ROUTE
#error Elder capability probe did not select the expected ordered route
#endif

uint ElderCapabilityProbeMain() : SV_Target
{
    ElderCapabilityValue selected = ElderResolveCapability(
        ElderMakeCapability(float4(0.1, 0.2, 0.3, 1.0), 1.0),
        ElderMakeCapability(float4(0.2, 0.3, 0.4, 1.0), 1.0),
        ElderMakeCapability(float4(0.3, 0.4, 0.5, 1.0), 1.0),
        ElderMakeCapability(float4(0.4, 0.5, 0.6, 1.0), 1.0));
    return selected.route;
}
]=])

function(run_elder_capability_probe probe_name native_available bridge_available spatial_available expected_route)
  execute_process(
    COMMAND "${ELDER_FXC}"
      /nologo
      /T ps_5_0
      /E ElderCapabilityProbeMain
      /WX
      /Ges
      /O3
      /I "${elder_source_dir}/shaders"
      "/DELDER_PROBE_NATIVE_AVAILABLE=${native_available}"
      "/DELDER_PROBE_BRIDGE_AVAILABLE=${bridge_available}"
      "/DELDER_PROBE_SPATIAL_AVAILABLE=${spatial_available}"
      "/DELDER_PROBE_EXPECTED_ROUTE=${expected_route}"
      /Fo "${elder_matrix_root}/${probe_name}.cso"
      "${elder_capability_probe}"
    RESULT_VARIABLE probe_result
    OUTPUT_VARIABLE probe_stdout
    ERROR_VARIABLE probe_stderr)
  if(NOT probe_result EQUAL 0)
    message(FATAL_ERROR
      "Capability probe ${probe_name} failed.\nstdout:\n${probe_stdout}\nstderr:\n${probe_stderr}")
  endif()
endfunction()

run_elder_capability_probe("capability-native" 1 1 1 3)
run_elder_capability_probe("capability-bridge" 0 1 1 2)
run_elder_capability_probe("capability-spatial" 0 0 1 1)
run_elder_capability_probe("capability-identity" 0 0 0 0)

set(elder_matrix_preset_root "${elder_matrix_root}/quality-presets")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    "-DELDER_SOURCE_DIR=${elder_source_dir}"
    "-DELDER_OUTPUT_DIR=${elder_matrix_preset_root}"
    -P "${elder_preset_generator}"
  RESULT_VARIABLE elder_matrix_preset_result
  OUTPUT_VARIABLE elder_matrix_preset_stdout
  ERROR_VARIABLE elder_matrix_preset_stderr)
if(NOT elder_matrix_preset_result EQUAL 0)
  message(FATAL_ERROR
    "Stage matrix could not generate tier overlays.\n"
    "stdout:\n${elder_matrix_preset_stdout}\n"
    "stderr:\n${elder_matrix_preset_stderr}")
endif()

set(elder_expected_tier_names performance balanced quality ultra cinematic)
set(elder_expected_tier_budgets
  "4|2|0|0|2|0|0"
  "6|3|0|2|3|1|1"
  "8|4|8|3|4|2|1"
  "12|5|12|4|5|2|2"
  "16|6|16|5|6|3|2")

set(elder_tier_budget_probe "${elder_matrix_root}/ElderTierBudgetProbe.hlsl")
file(WRITE "${elder_tier_budget_probe}" [=[
#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_IDENTITY
#define ELDER_STAGE_OWNS_COLOR 0
#define ELDER_STAGE_OWNS_DEPTH 0
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 0
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 0
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_NONE
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderPipelineCommon.fxh"

#if ELDER_QUALITY_TIER != ELDER_PROBE_QUALITY_TIER
#error Generated ElderTier.fxh overlay did not select the expected quality tier
#endif
#if ELDER_AO_DIRECTIONS_VALUE != ELDER_PROBE_AO_DIRECTIONS
#error Generated tier overlay did not select the expected AO direction budget
#endif
#if ELDER_AO_STEPS_VALUE != ELDER_PROBE_AO_STEPS
#error Generated tier overlay did not select the expected AO step budget
#endif
#if ELDER_SSR_STEPS_VALUE != ELDER_PROBE_SSR_STEPS
#error Generated tier overlay did not select the expected SSR budget
#endif
#if ELDER_DOF_RINGS_VALUE != ELDER_PROBE_DOF_RINGS
#error Generated tier overlay did not select the expected DOF budget
#endif
#if ELDER_BLOOM_RADIUS_VALUE != ELDER_PROBE_BLOOM_RADIUS
#error Generated tier overlay did not select the expected bloom budget
#endif
#if ELDER_LENS_GHOSTS_VALUE != ELDER_PROBE_LENS_GHOSTS
#error Generated tier overlay did not select the expected lens budget
#endif
#if ELDER_ROOM_LIGHT_REFINEMENT_VALUE != ELDER_PROBE_ROOM_LIGHT_REFINEMENT
#error Generated tier overlay did not select the expected room-light budget
#endif

float4 ElderTierBudgetProbeMain() : SV_Target
{
    return float4(
        float(ElderDOFRings),
        float(ElderBloomRadius),
        float(ElderLensGhosts),
        float(ElderQualityTier));
}
]=])

function(run_elder_tier_budget_probe tier_index tier_name budget_row)
  string(REPLACE "|" ";" budget_values "${budget_row}")
  list(GET budget_values 0 ao_directions)
  list(GET budget_values 1 ao_steps)
  list(GET budget_values 2 ssr_steps)
  list(GET budget_values 3 dof_rings)
  list(GET budget_values 4 bloom_radius)
  list(GET budget_values 5 lens_ghosts)
  list(GET budget_values 6 room_light_refinement)
  set(tier_override "${elder_matrix_preset_root}/${tier_name}/enbseries/elder/ElderTier.fxh")
  if(NOT EXISTS "${tier_override}")
    message(FATAL_ERROR "Generated tier include override is absent: ${tier_override}")
  endif()
  set(installed_shader_root "${elder_matrix_root}/installed-tier-${tier_name}")
  file(REMOVE_RECURSE "${installed_shader_root}")
  file(MAKE_DIRECTORY "${installed_shader_root}")
  file(COPY "${elder_source_dir}/shaders/elder" DESTINATION "${installed_shader_root}")
  file(COPY "${tier_override}" DESTINATION "${installed_shader_root}/elder")
  execute_process(
    COMMAND "${ELDER_FXC}"
      /nologo
      /T ps_5_0
      /E ElderTierBudgetProbeMain
      /WX
      /Ges
      /O3
      /I "${installed_shader_root}"
      "/DELDER_PROBE_QUALITY_TIER=${tier_index}"
      "/DELDER_PROBE_AO_DIRECTIONS=${ao_directions}"
      "/DELDER_PROBE_AO_STEPS=${ao_steps}"
      "/DELDER_PROBE_SSR_STEPS=${ssr_steps}"
      "/DELDER_PROBE_DOF_RINGS=${dof_rings}"
      "/DELDER_PROBE_BLOOM_RADIUS=${bloom_radius}"
      "/DELDER_PROBE_LENS_GHOSTS=${lens_ghosts}"
      "/DELDER_PROBE_ROOM_LIGHT_REFINEMENT=${room_light_refinement}"
      /Fo "${elder_matrix_root}/tier-budget-${tier_name}.cso"
      "${elder_tier_budget_probe}"
    RESULT_VARIABLE tier_probe_result
    OUTPUT_VARIABLE tier_probe_stdout
    ERROR_VARIABLE tier_probe_stderr)
  if(NOT tier_probe_result EQUAL 0)
    message(FATAL_ERROR
      "Generated tier budget probe failed for ${tier_name}.\n"
      "stdout:\n${tier_probe_stdout}\n"
      "stderr:\n${tier_probe_stderr}")
  endif()
endfunction()

foreach(tier RANGE 0 4)
  list(GET elder_expected_tier_names ${tier} tier_name)
  list(GET elder_expected_tier_budgets ${tier} tier_budget_row)
  run_elder_tier_budget_probe(${tier} "${tier_name}" "${tier_budget_row}")
endforeach()

foreach(tier RANGE 0 4)
  list(GET elder_expected_tier_names ${tier} tier_name)
  set(elder_tier_include_root "${elder_matrix_preset_root}/${tier_name}/enbseries")
  set(elder_tier_root "${elder_matrix_root}/${tier}")
  file(MAKE_DIRECTORY "${elder_tier_root}")
  foreach(stage_row IN LISTS elder_stage_rows)
    string(REPLACE "|" ";" stage_fields "${stage_row}")
    list(GET stage_fields 0 stage_name)
    list(GET stage_fields 1 stage_technique)
    set(stage_source "${elder_source_dir}/shaders/${stage_name}")
    get_filename_component(stage_stem "${stage_name}" NAME_WE)
    execute_process(
      COMMAND "${CMAKE_COMMAND}"
        "-DELDER_FXC=${ELDER_FXC}"
        "-DELDER_SOURCE_DIR=${elder_source_dir}"
        "-DELDER_STAGE_SOURCE=${stage_source}"
        "-DELDER_STAGE_TECHNIQUE=${stage_technique}"
        "-DELDER_QUALITY_TIER=${tier}"
        "-DELDER_TIER_INCLUDE_ROOT=${elder_tier_include_root}"
        "-DELDER_GENERATED_INCLUDE=${elder_generated_native_root}"
        "-DELDER_OUTPUT=${elder_tier_root}/${stage_stem}.fxo"
        "-DELDER_LISTING=${elder_tier_root}/${stage_stem}.asm"
        -P "${elder_compile_script}"
      RESULT_VARIABLE stage_result
      OUTPUT_VARIABLE stage_stdout
      ERROR_VARIABLE stage_stderr)
    if(NOT stage_result EQUAL 0)
      message(FATAL_ERROR
        "Elder stage matrix failed for ${stage_name}, tier ${tier}.\n"
        "stdout:\n${stage_stdout}\n"
        "stderr:\n${stage_stderr}")
    endif()
  endforeach()
endforeach()

message(STATUS "Elder stage matrix compiled 45 strict FXC permutations")
