cmake_minimum_required(VERSION 3.30)

foreach(required_variable IN ITEMS
    ELDER_FXC
    ELDER_SOURCE_DIR
    ELDER_STAGE_SOURCE
    ELDER_STAGE_TECHNIQUE
    ELDER_QUALITY_TIER
    ELDER_GENERATED_INCLUDE
    ELDER_OUTPUT
    ELDER_LISTING)
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
if(NOT EXISTS "${ELDER_STAGE_SOURCE}")
  message(FATAL_ERROR "Elder stage source is absent: ${ELDER_STAGE_SOURCE}")
endif()
if(NOT IS_DIRECTORY "${ELDER_GENERATED_INCLUDE}")
  message(FATAL_ERROR "Generated native parameter include directory is absent: ${ELDER_GENERATED_INCLUDE}")
endif()
if(NOT "${ELDER_QUALITY_TIER}" MATCHES "^[0-4]$")
  message(FATAL_ERROR "ELDER_QUALITY_TIER must be an integer in [0,4]")
endif()
set(elder_tier_include_args "")
if(DEFINED ELDER_TIER_INCLUDE_ROOT AND NOT "${ELDER_TIER_INCLUDE_ROOT}" STREQUAL "")
  if(NOT IS_DIRECTORY "${ELDER_TIER_INCLUDE_ROOT}")
    message(FATAL_ERROR
      "Generated Elder tier include root is absent: ${ELDER_TIER_INCLUDE_ROOT}")
  endif()
  list(APPEND elder_tier_include_args /I "${ELDER_TIER_INCLUDE_ROOT}")
endif()

function(elder_fxc_diagnostics_allowed diagnostics result_variable)
  string(REPLACE "\r\n" "\n" normalized_diagnostics "${diagnostics}")
  string(REPLACE "\r" "\n" normalized_diagnostics "${normalized_diagnostics}")
  string(REPLACE "\n" ";" diagnostic_lines "${normalized_diagnostics}")
  set(diagnostics_allowed TRUE)
  foreach(diagnostic_line IN LISTS diagnostic_lines)
    if(diagnostic_line STREQUAL "")
      continue()
    endif()
    if(diagnostic_line STREQUAL
        "warning X4717: Effects deprecated for D3DCompiler_47")
      continue()
    endif()
    if(diagnostic_line MATCHES
        "^.+\\([0-9]+,[0-9]+(-[0-9]+,[0-9]+)?\\): warning X4717: Effects deprecated for D3DCompiler_47$")
      continue()
    endif()
    string(TOLOWER "${diagnostic_line}" normalized_line)
    if(normalized_line MATCHES "warning")
      set(diagnostics_allowed FALSE)
    endif()
  endforeach()
  set(${result_variable} ${diagnostics_allowed} PARENT_SCOPE)
endfunction()

# Keep the effect-profile exception exact. These embedded negatives prevent a
# broad substring filter from accepting unrelated shader-source warnings.
elder_fxc_diagnostics_allowed(
  "warning X4717: Effects deprecated for D3DCompiler_47\n"
  elder_x4717_bare_allowed)
if(NOT elder_x4717_bare_allowed)
  message(FATAL_ERROR "The exact FXC X4717 effect-profile diagnostic must be accepted")
endif()
elder_fxc_diagnostics_allowed(
  "C:/stage.fx(1,1): warning X4717: Effects deprecated for D3DCompiler_47\n"
  elder_x4717_source_allowed)
if(NOT elder_x4717_source_allowed)
  message(FATAL_ERROR "The exact source-attributed FXC X4717 diagnostic must be accepted")
endif()
elder_fxc_diagnostics_allowed(
  "warning X4717: Effects deprecated for D3DCompiler_47 extended\n"
  elder_x4717_extended_allowed)
if(elder_x4717_extended_allowed)
  message(FATAL_ERROR "The FXC X4717 whitelist accepted an extended warning")
endif()
elder_fxc_diagnostics_allowed("warning X3206: implicit truncation\n"
  elder_source_warning_allowed)
if(elder_source_warning_allowed)
  message(FATAL_ERROR "The FXC diagnostic filter accepted a source warning")
endif()

get_filename_component(elder_stage_name "${ELDER_STAGE_SOURCE}" NAME)
file(READ "${ELDER_STAGE_SOURCE}" elder_stage_contents)
foreach(required_token IN ITEMS
    "#define ELDER_STAGE_CAPABILITY"
    "#define ELDER_STAGE_OWNS_COLOR"
    "#define ELDER_STAGE_OWNS_DEPTH"
    "#define ELDER_STAGE_OWNS_NORMAL"
    "#define ELDER_STAGE_OWNS_MASK"
    "#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW"
    "#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION"
    "#define ELDER_STAGE_OWNS_BRIDGE_VALUE"
    "#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE"
    "#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE"
    "#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE"
    "#define ELDER_STAGE_SCRATCH_OWNER"
    "#define ELDER_STAGE_SCRATCH_READ"
    "#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0"
    "#define ELDER_STAGE_OWNS_OBJECT_MOTION 0"
    "#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0"
    "#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0"
    "#include \"elder/ElderHostCapabilities.fxh\""
    "#include \"elder/ElderStageParameters.fxh\""
    "#include \"elder/ElderPipelineCommon.fxh\""
    "technique11 ${ELDER_STAGE_TECHNIQUE}")
  string(FIND "${elder_stage_contents}" "${required_token}" token_position)
  if(token_position EQUAL -1)
    message(FATAL_ERROR
      "Elder stage ${ELDER_STAGE_SOURCE} is missing required contract token: ${required_token}")
  endif()
endforeach()

if(elder_stage_name STREQUAL "enbeffect.fx")
  foreach(required_main_token IN ITEMS
      "#include \"ElderNativeParameters.fxh\""
      "#include \"ElderColorCore.fxh\""
      "ElderEvaluateColorCore"
      "ElderNativeSanitize_ElderMasterEnabled"
      "ElderResolveCapabilityColor")
    string(FIND "${elder_stage_contents}" "${required_main_token}" main_token_position)
    if(main_token_position EQUAL -1)
      message(FATAL_ERROR
        "Main effect ${ELDER_STAGE_SOURCE} is missing required native/color token: ${required_main_token}")
    endif()
  endforeach()
else()
  string(FIND "${elder_stage_contents}"
    "#define ELDER_STAGE_PARAMETER_SLOT"
    stage_slot_position)
  if(stage_slot_position EQUAL -1)
    message(FATAL_ERROR
      "Identity stage ${ELDER_STAGE_SOURCE} is missing its parameter slot")
  endif()
endif()

string(FIND "${elder_stage_contents}" "#define ELDER_STAGE_OWNS_BRIDGE_VALUE 1"
  elder_bridge_stage_position)
if(NOT elder_bridge_stage_position EQUAL -1)
  if(elder_stage_name STREQUAL "enbsunsprite.fx")
    foreach(required_sun_bridge_token IN ITEMS
        "ElderBridgeSunDirection"
        "ElderBridgeRenderFrame"
        "ElderSunSpriteBridgeAvailable")
      string(FIND "${elder_stage_contents}" "${required_sun_bridge_token}"
        elder_sun_bridge_token_position)
      if(elder_sun_bridge_token_position EQUAL -1)
        message(FATAL_ERROR
          "Sun sprite Bridge path is missing required token: ${required_sun_bridge_token}")
      endif()
    endforeach()
  else()
    string(FIND "${elder_stage_contents}" "SB_Retain" elder_retain_position)
    if(elder_retain_position EQUAL -1)
      message(FATAL_ERROR
        "Bridge-consuming stage ${elder_stage_name} must preserve the SB_Retain call")
    endif()
  endif()
endif()

if(elder_stage_name STREQUAL "enbdepthoffield.fx")
  string(FIND "${elder_stage_contents}" "ElderStageIdentity" identity_position)
  if(identity_position EQUAL -1)
    message(FATAL_ERROR
      "Identity stage ${elder_stage_name} must use the exact ElderStageIdentity output")
  endif()
elseif(elder_stage_name STREQUAL "enbeffectpostpass.fx")
  foreach(required_post_token IN ITEMS
      "ElderFinishLdr"
      "return float4(finished, 1.0)")
    string(FIND "${elder_stage_contents}" "${required_post_token}"
      post_token_position)
    if(post_token_position EQUAL -1)
      message(FATAL_ERROR
        "Postpass display stage ${elder_stage_name} is missing required finish token: ${required_post_token}")
    endif()
  endforeach()
elseif(elder_stage_name STREQUAL "enbsunsprite.fx")
  string(FIND "${elder_stage_contents}" "ElderEvaluateSunSprite"
    sun_token_position)
  if(sun_token_position EQUAL -1)
    message(FATAL_ERROR
      "Sun sprite stage must call ElderEvaluateSunSprite")
  endif()
elseif(elder_stage_name STREQUAL "enbunderwater.fx")
  string(FIND "${elder_stage_contents}" "ElderEvaluateUnderwater"
    underwater_token_position)
  if(underwater_token_position EQUAL -1)
    message(FATAL_ERROR
      "Underwater stage must call ElderEvaluateUnderwater")
  endif()
endif()
if(elder_stage_name STREQUAL "enbbloom.fx"
    OR elder_stage_name STREQUAL "enblens.fx")
  string(FIND "${elder_stage_contents}" "ElderStageIdentity" additive_identity_position)
  if(NOT additive_identity_position EQUAL -1)
    message(FATAL_ERROR
      "Additive scratch stage ${elder_stage_name} must output neutral/contribution scratch directly")
  endif()
endif()
string(FIND "${elder_stage_contents}" "ORIGINALPOSTPROCESS" original_postprocess_position)
if(NOT elder_stage_name STREQUAL "enbeffect.fx" AND NOT original_postprocess_position EQUAL -1)
  message(FATAL_ERROR
    "Only enbeffect.fx may define the ENB-reserved ORIGINALPOSTPROCESS technique")
endif()

string(REGEX MATCHALL "Texture2D[ \t]+[A-Za-z0-9_]+" elder_texture_declarations
  "${elder_stage_contents}")
if(elder_stage_name STREQUAL "enbadaptation.fx")
  list(LENGTH elder_texture_declarations elder_texture_count)
  if(NOT elder_texture_count EQUAL 2)
    message(FATAL_ERROR
      "Adaptation may declare only TextureCurrent and scalar TexturePrevious in this identity release")
  endif()
  foreach(required_texture IN ITEMS "Texture2D TextureCurrent" "Texture2D TexturePrevious")
    list(FIND elder_texture_declarations "${required_texture}" texture_position)
    if(texture_position EQUAL -1)
      message(FATAL_ERROR "Adaptation is missing required scalar-history texture: ${required_texture}")
    endif()
  endforeach()
  string(FIND "${elder_stage_contents}"
    "#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 1"
    elder_scalar_history_owner_position)
  if(elder_scalar_history_owner_position EQUAL -1)
    message(FATAL_ERROR "TexturePrevious requires the adaptation scalar-history owner declaration")
  endif()
elseif(elder_stage_name STREQUAL "enbeffectprepass.fx")
  list(LENGTH elder_texture_declarations elder_texture_count)
  if(NOT elder_texture_count EQUAL 4)
    message(FATAL_ERROR
      "HDR prepass must declare only its current-frame color, depth, normal, and mask inputs")
  endif()
  foreach(required_texture IN ITEMS
      "Texture2D TextureColor"
      "Texture2D TextureDepth"
      "Texture2D TextureNormal"
      "Texture2D TextureMask")
    list(FIND elder_texture_declarations "${required_texture}" texture_position)
    if(texture_position EQUAL -1)
      message(FATAL_ERROR "HDR prepass is missing required current-frame resource: ${required_texture}")
    endif()
  endforeach()
  string(FIND "${elder_stage_contents}" "TexturePrevious" elder_previous_position)
  if(NOT elder_previous_position EQUAL -1)
    message(FATAL_ERROR "HDR prepass may not declare previous-frame history")
  endif()
  string(FIND "${elder_stage_contents}"
    "#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 1"
    elder_prepass_history_owner_position)
  if(NOT elder_prepass_history_owner_position EQUAL -1)
    message(FATAL_ERROR "HDR prepass may not own scalar adaptation history")
  endif()
elseif(elder_stage_name STREQUAL "enbdepthoffield.fx"
    OR elder_stage_name STREQUAL "enbunderwater.fx")
  list(LENGTH elder_texture_declarations elder_texture_count)
  if(NOT elder_texture_count EQUAL 2)
    message(FATAL_ERROR
      "${elder_stage_name} must declare only current-frame color and depth")
  endif()
  foreach(required_texture IN ITEMS "Texture2D TextureColor" "Texture2D TextureDepth")
    list(FIND elder_texture_declarations "${required_texture}" texture_position)
    if(texture_position EQUAL -1)
      message(FATAL_ERROR "${elder_stage_name} is missing required texture: ${required_texture}")
    endif()
  endforeach()
elseif(elder_stage_name STREQUAL "enblens.fx")
  list(LENGTH elder_texture_declarations elder_texture_count)
  if(NOT elder_texture_count EQUAL 1
      OR NOT "${elder_texture_declarations}" STREQUAL "Texture2D TextureBloom")
    message(FATAL_ERROR
      "Lens stage must declare only the TextureBloom source supplied by ENB")
  endif()
  string(FIND "${elder_stage_contents}" "Texture2D TextureColor" elder_lens_texture_color_position)
  if(NOT elder_lens_texture_color_position EQUAL -1)
    message(FATAL_ERROR "Lens stage must not consume raw TextureColor")
  endif()
  string(FIND "${elder_stage_contents}" "TexturePrevious" elder_previous_position)
  if(NOT elder_previous_position EQUAL -1)
    message(FATAL_ERROR "Only adaptation may declare TexturePrevious scalar history")
  endif()
  string(FIND "${elder_stage_contents}"
    "#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 1"
    elder_lens_history_owner_position)
  if(NOT elder_lens_history_owner_position EQUAL -1)
    message(FATAL_ERROR "Only adaptation may own scalar history")
  endif()
elseif(elder_stage_name STREQUAL "enbeffect.fx")
  list(LENGTH elder_texture_declarations elder_texture_count)
  if(NOT elder_texture_count EQUAL 4)
    message(FATAL_ERROR
      "Main effect must declare only TextureColor, TextureBloom, TextureLens, and TextureAdaptation")
  endif()
  foreach(required_texture IN ITEMS
      "Texture2D TextureColor"
      "Texture2D TextureBloom"
      "Texture2D TextureLens"
      "Texture2D TextureAdaptation")
    list(FIND elder_texture_declarations "${required_texture}" texture_position)
    if(texture_position EQUAL -1)
      message(FATAL_ERROR "Main effect is missing required resource: ${required_texture}")
    endif()
  endforeach()
  string(FIND "${elder_stage_contents}" "TexturePrevious" elder_previous_position)
  if(NOT elder_previous_position EQUAL -1)
    message(FATAL_ERROR "Main effect may not declare TexturePrevious")
  endif()
else()
  list(LENGTH elder_texture_declarations elder_texture_count)
  if(NOT elder_texture_count EQUAL 1
      OR NOT "${elder_texture_declarations}" STREQUAL "Texture2D TextureColor")
    message(FATAL_ERROR
      "Identity stage ${elder_stage_name} may declare only the TextureColor source it reads")
  endif()
  string(FIND "${elder_stage_contents}" "TexturePrevious" elder_previous_position)
  if(NOT elder_previous_position EQUAL -1)
    message(FATAL_ERROR "Only adaptation may declare TexturePrevious scalar history")
  endif()
  string(FIND "${elder_stage_contents}"
    "#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 1"
    elder_non_adaptation_history_owner_position)
  if(NOT elder_non_adaptation_history_owner_position EQUAL -1)
    message(FATAL_ERROR "Only adaptation may own scalar history")
  endif()
endif()

cmake_path(GET ELDER_OUTPUT PARENT_PATH elder_output_directory)
cmake_path(GET ELDER_LISTING PARENT_PATH elder_listing_directory)
file(MAKE_DIRECTORY "${elder_output_directory}" "${elder_listing_directory}")
file(REMOVE "${ELDER_OUTPUT}" "${ELDER_LISTING}")

execute_process(
  COMMAND
    "${ELDER_FXC}"
    /nologo
    /T fx_5_0
    /WX
    /Ges
    /O3
    ${elder_tier_include_args}
    /I "${ELDER_SOURCE_DIR}/shaders"
    /I "${ELDER_SOURCE_DIR}/native/shaders"
    /I "${ELDER_GENERATED_INCLUDE}"
    /Fo "${ELDER_OUTPUT}"
    /Fc "${ELDER_LISTING}"
    "${ELDER_STAGE_SOURCE}"
  RESULT_VARIABLE elder_fxc_result
  OUTPUT_VARIABLE elder_fxc_stdout
  ERROR_VARIABLE elder_fxc_stderr)

if(NOT elder_fxc_result EQUAL 0)
  message(FATAL_ERROR
    "FXC failed for ${elder_stage_name}, tier ${ELDER_QUALITY_TIER}, technique ${ELDER_STAGE_TECHNIQUE} with exit code ${elder_fxc_result}\n"
    "stdout:\n${elder_fxc_stdout}\n"
    "stderr:\n${elder_fxc_stderr}")
endif()
elder_fxc_diagnostics_allowed("${elder_fxc_stdout}${elder_fxc_stderr}"
  elder_fxc_diagnostics_are_allowed)
if(NOT elder_fxc_diagnostics_are_allowed)
  message(FATAL_ERROR
    "FXC emitted an unexpected warning for ${elder_stage_name}, tier ${ELDER_QUALITY_TIER}:\n${elder_fxc_stdout}${elder_fxc_stderr}")
endif()

foreach(output_file IN ITEMS "${ELDER_OUTPUT}" "${ELDER_LISTING}")
  if(NOT EXISTS "${output_file}")
    message(FATAL_ERROR "FXC reported success without output: ${output_file}")
  endif()
  file(SIZE "${output_file}" output_size)
  if(output_size EQUAL 0)
    message(FATAL_ERROR "FXC emitted an empty output: ${output_file}")
  endif()
endforeach()

message(STATUS
  "FXC stage: ${elder_stage_name}; tier: ${ELDER_QUALITY_TIER}; technique: ${ELDER_STAGE_TECHNIQUE}")
