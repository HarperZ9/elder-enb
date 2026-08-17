cmake_minimum_required(VERSION 3.30)

if(NOT DEFINED ELDER_SOURCE_DIR OR "${ELDER_SOURCE_DIR}" STREQUAL "")
  message(FATAL_ERROR "Missing required variable: ELDER_SOURCE_DIR")
endif()
if(NOT IS_DIRECTORY "${ELDER_SOURCE_DIR}")
  message(FATAL_ERROR "Elder source directory is absent: ${ELDER_SOURCE_DIR}")
endif()

file(REAL_PATH "${ELDER_SOURCE_DIR}" elder_source_dir)
set(elder_shader_root "${elder_source_dir}/shaders")
set(elder_public_include_root "${elder_shader_root}/elder")
if(NOT IS_DIRECTORY "${elder_public_include_root}")
  message(FATAL_ERROR
    "Elder public include root is absent: ${elder_public_include_root}")
endif()

file(GLOB elder_public_includes
  RELATIVE "${elder_public_include_root}"
  "${elder_public_include_root}/*.fxh")
list(SORT elder_public_includes)
if(NOT elder_public_includes)
  message(FATAL_ERROR "No public Elder .fxh includes were found")
endif()

set(unqualified_elder_includes)
foreach(public_include IN LISTS elder_public_includes)
  set(public_include_path "${elder_public_include_root}/${public_include}")
  file(READ "${public_include_path}" public_include_source)
  string(REGEX MATCHALL "#[ \t]*include[ \t]+\"[^\"]+\""
    include_directives "${public_include_source}")
  foreach(include_directive IN LISTS include_directives)
    string(REGEX REPLACE ".*\"([^\"]+)\".*" "\\1" include_operand
      "${include_directive}")
    if(include_operand MATCHES "(^|/)Elder[^/]*\\.fxh$")
      if(NOT include_operand MATCHES "^elder/Elder[^/]*\\.fxh$")
        list(APPEND unqualified_elder_includes
          "${public_include}: ${include_operand}")
      endif()
    endif()
    if(include_operand MATCHES "^elder/Elder[^/]*\\.fxh$")
      set(host_resolved_source "${elder_shader_root}/${include_operand}")
      if(NOT EXISTS "${host_resolved_source}")
        message(FATAL_ERROR
          "Public nested include does not resolve from packaged ENB root: "
          "${public_include}: ${include_operand}")
      endif()
    endif()
  endforeach()
endforeach()

if(unqualified_elder_includes)
  string(JOIN "\n  " unqualified_text ${unqualified_elder_includes})
  message(FATAL_ERROR
    "Public nested Elder .fxh includes must be root-qualified for the "
    "Root/enbseries package layout:\n  ${unqualified_text}")
endif()

# ENBSeries 0.504 supplies a fullscreen quad through POSITION/TEXCOORD0 and may
# use shared/non-zero vertex indices. Synthesizing a triangle from SV_VertexID
# collapses every id above one onto the same corner and can black out the pass.
set(host_stage_contract_violations)
set(elder_pipeline_common
  "${elder_public_include_root}/ElderPipelineCommon.fxh")
file(READ "${elder_pipeline_common}" elder_pipeline_common_source)
foreach(required_token IN ITEMS
    "ElderStageVSOutput ElderFullscreenVertex(float3 position : POSITION, float2 texcoord : TEXCOORD0)"
    "output.position = float4(position, 1.0);"
    "output.texcoord = texcoord;")
  string(FIND "${elder_pipeline_common_source}" "${required_token}"
    required_token_position)
  if(required_token_position EQUAL -1)
    list(APPEND host_stage_contract_violations
      "ElderPipelineCommon.fxh lacks host quad pass-through: ${required_token}")
  endif()
endforeach()
foreach(forbidden_token IN ITEMS "SV_VertexID" "triangle_position")
  string(FIND "${elder_pipeline_common_source}" "${forbidden_token}"
    forbidden_token_position)
  if(NOT forbidden_token_position EQUAL -1)
    list(APPEND host_stage_contract_violations
      "ElderPipelineCommon.fxh synthesizes unsupported host geometry: ${forbidden_token}")
  endif()
endforeach()

if(host_stage_contract_violations)
  string(JOIN "\n  " host_stage_contract_text ${host_stage_contract_violations})
  message(FATAL_ERROR
    "Elder ENB host stage contract failed:\n  ${host_stage_contract_text}")
endif()

message(STATUS
  "Elder public includes and ENB host stage inputs are compatible")
