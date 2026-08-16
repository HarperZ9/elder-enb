cmake_minimum_required(VERSION 4.0)

foreach(required_variable IN ITEMS
    ELDER_RUNTIME_PLUGIN
    ELDER_RUNTIME_RECEIPT
    ELDER_SOURCE_ROOT
    ELDER_RUNTIME_CORE_ROOT
    ELDER_RUNTIME_CORE_LOCK)
  if(NOT DEFINED ${required_variable} OR "${${required_variable}}" STREQUAL "")
    message(FATAL_ERROR "Missing required variable: ${required_variable}")
  endif()
endforeach()

foreach(required_file IN ITEMS
    "${ELDER_RUNTIME_PLUGIN}"
    "${ELDER_RUNTIME_CORE_LOCK}"
    "${ELDER_RUNTIME_CORE_ROOT}/CMakeLists.txt"
    "${ELDER_RUNTIME_CORE_ROOT}/LICENSE")
  if(NOT EXISTS "${required_file}")
    message(FATAL_ERROR "Runtime receipt input is absent: ${required_file}")
  endif()
endforeach()

find_package(Git REQUIRED)

function(elder_git_output output_variable checkout)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${checkout}" ${ARGN}
    RESULT_VARIABLE command_result
    OUTPUT_VARIABLE command_output
    ERROR_VARIABLE command_error
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT command_result EQUAL 0)
    message(FATAL_ERROR
      "git ${ARGN} failed for ${checkout}: ${command_error}")
  endif()
  set(${output_variable} "${command_output}" PARENT_SCOPE)
endfunction()

function(elder_normalize_repository output_variable repository)
  string(STRIP "${repository}" normalized)
  string(REPLACE "\\" "/" normalized "${normalized}")
  string(REGEX REPLACE "/+$" "" normalized "${normalized}")
  string(REGEX REPLACE "\\.git$" "" normalized "${normalized}")
  string(TOLOWER "${normalized}" normalized)
  set(${output_variable} "${normalized}" PARENT_SCOPE)
endfunction()

file(STRINGS "${ELDER_RUNTIME_CORE_LOCK}" lock_repository_lines
  REGEX "^repository=[^ ]+$")
file(STRINGS "${ELDER_RUNTIME_CORE_LOCK}" lock_revision_lines
  REGEX "^revision=[0-9a-f]{40}$")
list(LENGTH lock_repository_lines repository_count)
list(LENGTH lock_revision_lines revision_count)
if(NOT repository_count EQUAL 1 OR NOT revision_count EQUAL 1)
  message(FATAL_ERROR
    "enb-runtime-core.lock must contain one repository and one full revision")
endif()
list(GET lock_repository_lines 0 lock_repository)
list(GET lock_revision_lines 0 lock_revision)
string(REGEX REPLACE "^repository=" "" lock_repository "${lock_repository}")
string(REGEX REPLACE "^revision=" "" lock_revision "${lock_revision}")

elder_git_output(elder_revision "${ELDER_SOURCE_ROOT}" rev-parse HEAD)
elder_git_output(elder_runtime_tree "${ELDER_SOURCE_ROOT}"
  rev-parse HEAD:native/runtime)
elder_git_output(elder_runtime_status "${ELDER_SOURCE_ROOT}"
  status --porcelain --untracked-files=no -- native/runtime native/schema)
if(NOT elder_runtime_status STREQUAL "")
  message(FATAL_ERROR
    "Elder runtime/schema sources contain tracked changes; commit them before release")
endif()

elder_git_output(core_revision "${ELDER_RUNTIME_CORE_ROOT}" rev-parse HEAD)
if(NOT core_revision STREQUAL lock_revision)
  message(FATAL_ERROR
    "enb-runtime-core revision mismatch: expected ${lock_revision}, found ${core_revision}")
endif()
elder_git_output(core_repository "${ELDER_RUNTIME_CORE_ROOT}"
  remote get-url origin)
elder_normalize_repository(expected_repository "${lock_repository}")
elder_normalize_repository(actual_repository "${core_repository}")
if(NOT actual_repository STREQUAL expected_repository)
  message(FATAL_ERROR
    "enb-runtime-core repository mismatch: expected ${lock_repository}, found ${core_repository}")
endif()
elder_git_output(core_status "${ELDER_RUNTIME_CORE_ROOT}"
  status --porcelain --untracked-files=no)
if(NOT core_status STREQUAL "")
  message(FATAL_ERROR
    "enb-runtime-core contains tracked changes; use the clean pinned checkout")
endif()

file(SHA256 "${ELDER_RUNTIME_PLUGIN}" runtime_sha256)
cmake_path(GET ELDER_RUNTIME_RECEIPT PARENT_PATH receipt_directory)
file(MAKE_DIRECTORY "${receipt_directory}")
file(WRITE "${ELDER_RUNTIME_RECEIPT}"
  "schema=ELDER_RUNTIME_RECEIPT_V1\n"
  "runtime_file=ElderENBRuntime.dllplugin\n"
  "runtime_sha256=${runtime_sha256}\n"
  "elder_revision=${elder_revision}\n"
  "elder_runtime_tree=${elder_runtime_tree}\n"
  "runtime_core_repository=${lock_repository}\n"
  "runtime_core_revision=${lock_revision}\n")
