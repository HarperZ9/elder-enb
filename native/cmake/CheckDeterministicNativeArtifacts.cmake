foreach(required ELDER_COMPILER ELDER_SCHEMA ELDER_WORK_ROOT)
  if(NOT DEFINED ${required} OR "${${required}}" STREQUAL "")
    message(FATAL_ERROR "${required} is required")
  endif()
endforeach()

file(REMOVE_RECURSE "${ELDER_WORK_ROOT}")
set(first "${ELDER_WORK_ROOT}/first")
set(second "${ELDER_WORK_ROOT}/second")

foreach(directory IN ITEMS "${first}" "${second}")
  execute_process(
    COMMAND "${ELDER_COMPILER}" "${ELDER_SCHEMA}"
      "${directory}/shaders/ElderNativeParameters.fxh"
      "${directory}/include/ElderNativeParameterDefaults.hpp"
      "${directory}/manifest/elder-native-parameters.json"
      "${directory}/profiles/elder-native-default.profile"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
  )
  if(NOT result EQUAL 0)
    file(REMOVE_RECURSE "${ELDER_WORK_ROOT}")
    message(FATAL_ERROR
      "deterministic artifact generation failed (${result})\n${output}\n${error}")
  endif()
endforeach()

foreach(relative IN ITEMS
    "shaders/ElderNativeParameters.fxh"
    "include/ElderNativeParameterDefaults.hpp"
    "manifest/elder-native-parameters.json"
    "profiles/elder-native-default.profile")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E compare_files
      "${first}/${relative}" "${second}/${relative}"
    RESULT_VARIABLE different
  )
  if(NOT different EQUAL 0)
    file(REMOVE_RECURSE "${ELDER_WORK_ROOT}")
    message(FATAL_ERROR "generated artifact is nondeterministic: ${relative}")
  endif()
endforeach()

file(GLOB_RECURSE owned_debris
  "${ELDER_WORK_ROOT}/*.elder-owned-*.stage"
  "${ELDER_WORK_ROOT}/*.elder-owned-*.backup")
if(owned_debris)
  file(REMOVE_RECURSE "${ELDER_WORK_ROOT}")
  message(FATAL_ERROR "determinism run left owned transaction debris")
endif()

file(REMOVE_RECURSE "${ELDER_WORK_ROOT}")
