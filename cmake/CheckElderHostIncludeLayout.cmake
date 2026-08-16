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

message(STATUS
  "Elder public nested .fxh includes resolve from the packaged ENB root")
