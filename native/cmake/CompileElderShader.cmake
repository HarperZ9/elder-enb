cmake_minimum_required(VERSION 3.28)

# Generic strict FXC compile witness for an Elder shader. Fails on a missing
# input, a missing required include, a nonzero compiler result, or an
# absent/empty output. Kept separate from the color-core-specific script so any
# Elder shader module can register a compile gate.

foreach(required_variable IN ITEMS
    ELDER_FXC
    ELDER_SHADER
    ELDER_REQUIRED_SOURCE
    ELDER_INCLUDE
    ELDER_TARGET
    ELDER_ENTRY
    ELDER_OUTPUT
    ELDER_LISTING)
  if(NOT DEFINED ${required_variable} OR "${${required_variable}}" STREQUAL "")
    message(FATAL_ERROR "Missing required variable: ${required_variable}")
  endif()
endforeach()

if(NOT EXISTS "${ELDER_FXC}")
  message(FATAL_ERROR "Exact FXC executable is absent: ${ELDER_FXC}")
endif()
if(NOT EXISTS "${ELDER_SHADER}")
  message(FATAL_ERROR "Elder shader source is absent: ${ELDER_SHADER}")
endif()
if(NOT EXISTS "${ELDER_REQUIRED_SOURCE}")
  message(FATAL_ERROR "Required Elder shader source is absent: ${ELDER_REQUIRED_SOURCE}")
endif()
if(NOT IS_DIRECTORY "${ELDER_INCLUDE}")
  message(FATAL_ERROR "Elder shader include directory is absent: ${ELDER_INCLUDE}")
endif()

cmake_path(GET ELDER_OUTPUT PARENT_PATH elder_output_directory)
file(MAKE_DIRECTORY "${elder_output_directory}")
file(REMOVE "${ELDER_OUTPUT}" "${ELDER_LISTING}")

execute_process(
  COMMAND
    "${ELDER_FXC}"
    /nologo
    /T "${ELDER_TARGET}"
    /E "${ELDER_ENTRY}"
    /WX
    /Ges
    /O3
    /I "${ELDER_INCLUDE}"
    /Fo "${ELDER_OUTPUT}"
    /Fc "${ELDER_LISTING}"
    "${ELDER_SHADER}"
  RESULT_VARIABLE elder_fxc_result
  OUTPUT_VARIABLE elder_fxc_stdout
  ERROR_VARIABLE elder_fxc_stderr
)

if(NOT elder_fxc_result EQUAL 0)
  message(FATAL_ERROR
    "FXC failed with exit code ${elder_fxc_result}\n"
    "stdout:\n${elder_fxc_stdout}\n"
    "stderr:\n${elder_fxc_stderr}"
  )
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

message(STATUS "Elder FXC compiled ${ELDER_ENTRY} (${ELDER_TARGET}) -> ${ELDER_OUTPUT}")
