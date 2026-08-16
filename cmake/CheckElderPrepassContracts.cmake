cmake_minimum_required(VERSION 3.30)

foreach(required_variable IN ITEMS ELDER_SOURCE_DIR)
  if(NOT DEFINED ${required_variable} OR "${${required_variable}}" STREQUAL "")
    message(FATAL_ERROR "Missing required variable: ${required_variable}")
  endif()
endforeach()

file(REAL_PATH "${ELDER_SOURCE_DIR}" elder_source_dir)
set(elder_prepass "${elder_source_dir}/shaders/enbeffectprepass.fx")
set(elder_prepass_core "${elder_source_dir}/shaders/elder/ElderPrepassCore.fxh")
set(elder_screen_space "${elder_source_dir}/shaders/elder/ElderScreenSpace.fxh")

foreach(required_file IN ITEMS
    "${elder_prepass}"
    "${elder_prepass_core}"
    "${elder_screen_space}")
  if(NOT EXISTS "${required_file}")
    message(FATAL_ERROR "Elder prepass contract requires source: ${required_file}")
  endif()
endforeach()

file(READ "${elder_prepass}" elder_prepass_source)
file(READ "${elder_prepass_core}" elder_prepass_core_source)
file(READ "${elder_screen_space}" elder_screen_space_source)

foreach(public_source IN ITEMS
    "${elder_prepass_source}"
    "${elder_prepass_core_source}"
    "${elder_screen_space_source}")
  string(FIND "${public_source}" "../../native/" native_relative_position)
  if(NOT native_relative_position EQUAL -1)
    message(FATAL_ERROR
      "Public Elder shaders must not include source-tree-only native relative paths")
  endif()
endforeach()

foreach(eager_token IN ITEMS
    "float3 native_scene ="
    "float3 bridge_scene ="
    "float3 spatial_scene ="
    "ElderResolveCapabilityColor(")
  string(FIND "${elder_prepass_source}" "${eager_token}" eager_position)
  if(NOT eager_position EQUAL -1)
    message(FATAL_ERROR
      "HDR prepass must use an ordered lazy capability ladder, found eager token: ${eager_token}")
  endif()
endforeach()

foreach(required_token IN ITEMS
    "if (ElderPrepassNativeAvailable()"
    "else if (ElderPrepassBridgeAvailable()"
    "else if (spatial_available > 0.0)"
    "SB_Retain(input.texcoord)"
    "ElderStageIdentity(")
  string(FIND "${elder_prepass_source}" "${required_token}" token_position)
  if(token_position EQUAL -1)
    message(FATAL_ERROR
      "HDR prepass lazy route ladder is missing required token: ${required_token}")
  endif()
endforeach()

foreach(forbidden_token IN ITEMS
    "ElderApplyGtao"
    "ElderApplyShortSsr"
    "ElderApplyMaterialAwareSss"
    "GTAO"
    "SSR"
    "SSS"
    "frac("
    "scene + scene"
    "step_index < ElderSSRSteps")
  string(FIND "${elder_screen_space_source}" "${forbidden_token}" forbidden_position)
  if(NOT forbidden_position EQUAL -1)
    message(FATAL_ERROR
      "ElderScreenSpace must not claim unsupported effects or use pseudo-random/self-brightening logic: ${forbidden_token}")
  endif()
endforeach()

foreach(required_token IN ITEMS
    "ElderGatherScreenNeighborhood"
    "ElderApplyDepthNormalContactOcclusion"
    "ElderApplyUnsupportedReflectionIdentity"
    "ElderApplyUnsupportedSubsurfaceIdentity"
    "ElderApplyWeatherAtmosphere"
    "ElderApplyBoundedScreenSpace")
  string(FIND "${elder_screen_space_source}" "${required_token}" token_position)
  if(token_position EQUAL -1)
    message(FATAL_ERROR
      "ElderScreenSpace is missing required bounded/current-frame contract token: ${required_token}")
  endif()
endforeach()

string(FIND "${elder_prepass_core_source}" "max(finite_scene, candidate)" blanket_floor_position)
if(NOT blanket_floor_position EQUAL -1)
  message(FATAL_ERROR
    "Elder prepass must not blanket-clamp composed scene with max(finite_scene, candidate)")
endif()

message(STATUS "Elder prepass Task 3 contracts passed")
