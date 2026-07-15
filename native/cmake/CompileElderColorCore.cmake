foreach(required
    ELDER_FXC
    ELDER_PUBLISHER
    ELDER_SHADER
    ELDER_INCLUDE
    ELDER_GENERATED_INCLUDE
    ELDER_OUTPUT
    ELDER_LISTING)
  if(NOT DEFINED ${required} OR "${${required}}" STREQUAL "")
    message(FATAL_ERROR "${required} is required")
  endif()
endforeach()

if(NOT EXISTS "${ELDER_FXC}")
  message(FATAL_ERROR "FXC does not exist: ${ELDER_FXC}")
endif()
if(NOT EXISTS "${ELDER_PUBLISHER}")
  message(FATAL_ERROR "Elder artifact publisher does not exist")
endif()
if(NOT EXISTS "${ELDER_SHADER}")
  message(FATAL_ERROR "Elder reference shader does not exist")
endif()

get_filename_component(output_directory "${ELDER_OUTPUT}" DIRECTORY)
get_filename_component(listing_directory "${ELDER_LISTING}" DIRECTORY)
file(MAKE_DIRECTORY "${output_directory}" "${listing_directory}")
string(RANDOM LENGTH 24 ALPHABET 0123456789abcdef transaction_token)
set(staged_output
  "${ELDER_OUTPUT}.elder-fxc-owned-${transaction_token}.stage")
set(staged_listing
  "${ELDER_LISTING}.elder-fxc-owned-${transaction_token}.stage")

execute_process(
  COMMAND "${ELDER_FXC}"
    /nologo /Ges /Gis /WX /O3
    /T ps_5_0
    /E ElderColorReferencePixelMain
    /I "${ELDER_INCLUDE}"
    /I "${ELDER_GENERATED_INCLUDE}"
    /Fo "${staged_output}"
    /Fc "${staged_listing}"
    "${ELDER_SHADER}"
  RESULT_VARIABLE result
  OUTPUT_VARIABLE standard_output
  ERROR_VARIABLE standard_error
)
if(NOT result EQUAL 0)
  file(REMOVE "${staged_output}" "${staged_listing}")
  message(FATAL_ERROR
    "Elder color core failed strict FXC compilation (${result})\n"
    "${standard_output}\n${standard_error}")
endif()

file(SIZE "${staged_output}" output_size)
file(SIZE "${staged_listing}" listing_size)
if(output_size LESS 64 OR listing_size LESS 256)
  file(REMOVE "${staged_output}" "${staged_listing}")
  message(FATAL_ERROR "Elder color core emitted an implausibly small artifact")
endif()

execute_process(
  COMMAND "${ELDER_PUBLISHER}"
    "${staged_output}" "${ELDER_OUTPUT}"
    "${staged_listing}" "${ELDER_LISTING}"
  RESULT_VARIABLE publish_result
  OUTPUT_VARIABLE publish_output
  ERROR_VARIABLE publish_error
)
file(REMOVE "${staged_output}" "${staged_listing}")
if(NOT publish_result EQUAL 0)
  message(FATAL_ERROR
    "Elder FXC artifact transaction failed (${publish_result})\n"
    "${publish_output}\n${publish_error}")
endif()
