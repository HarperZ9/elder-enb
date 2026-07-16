# Elder's native runtime: the ENB-facing plugin layer that consumes the
# neutral enb-runtime-core as a pinned static source package. The pin is
# fail-closed: the sibling checkout must sit at the admitted revision with a
# clean tracked worktree, and the tracked lock file must agree with the
# admitted revision, or configuration stops.

set(
  ELDER_ENB_RUNTIME_CORE_ROOT
  "${CMAKE_CURRENT_SOURCE_DIR}/../../../enb-runtime-core"
  CACHE PATH
  "Absolute build-time path to the enb-runtime-core sibling"
)

set(
  ELDER_ENB_RUNTIME_CORE_REVISION
  "cfe7c0810adc0c34028a3d727b85dd1e6e51d407"
)

file(STRINGS
  "${CMAKE_CURRENT_SOURCE_DIR}/enb-runtime-core.lock"
  elder_runtime_core_lock_revision_line
  REGEX "^revision=[0-9a-f]+$"
)
list(LENGTH elder_runtime_core_lock_revision_line elder_runtime_core_lock_count)
if(NOT elder_runtime_core_lock_count EQUAL 1)
  message(FATAL_ERROR "enb-runtime-core.lock must contain one full revision")
endif()
list(GET elder_runtime_core_lock_revision_line 0 elder_runtime_core_lock_revision)
string(REGEX REPLACE "^revision=" "" elder_runtime_core_lock_revision
  "${elder_runtime_core_lock_revision}")
string(LENGTH "${elder_runtime_core_lock_revision}" elder_runtime_core_lock_length)
if(NOT elder_runtime_core_lock_length EQUAL 40)
  message(FATAL_ERROR "enb-runtime-core.lock revision must contain 40 hex digits")
endif()
if(NOT elder_runtime_core_lock_revision STREQUAL ELDER_ENB_RUNTIME_CORE_REVISION)
  message(FATAL_ERROR
    "enb-runtime-core.lock does not match the admitted runtime revision"
  )
endif()

cmake_path(
  ABSOLUTE_PATH ELDER_ENB_RUNTIME_CORE_ROOT
  NORMALIZE
  OUTPUT_VARIABLE elder_runtime_core_root_normalized
)
set(ELDER_ENB_RUNTIME_CORE_ROOT "${elder_runtime_core_root_normalized}")

cmake_path(IS_ABSOLUTE ELDER_ENB_RUNTIME_CORE_ROOT elder_runtime_core_is_absolute)
if(NOT elder_runtime_core_is_absolute)
  message(FATAL_ERROR "ELDER_ENB_RUNTIME_CORE_ROOT must be absolute")
endif()
if(NOT EXISTS "${ELDER_ENB_RUNTIME_CORE_ROOT}/CMakeLists.txt")
  message(FATAL_ERROR "ELDER_ENB_RUNTIME_CORE_ROOT does not contain enb-runtime-core")
endif()

find_package(Git REQUIRED)
execute_process(
  COMMAND "${GIT_EXECUTABLE}" -C "${ELDER_ENB_RUNTIME_CORE_ROOT}" rev-parse HEAD
  RESULT_VARIABLE elder_runtime_core_revision_result
  OUTPUT_VARIABLE elder_runtime_core_revision
  ERROR_VARIABLE elder_runtime_core_revision_error
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(NOT elder_runtime_core_revision_result EQUAL 0)
  message(FATAL_ERROR
    "Could not verify the pinned enb-runtime-core revision: "
    "${elder_runtime_core_revision_error}"
  )
endif()
if(NOT elder_runtime_core_revision STREQUAL ELDER_ENB_RUNTIME_CORE_REVISION)
  message(FATAL_ERROR
    "enb-runtime-core revision mismatch: expected "
    "${ELDER_ENB_RUNTIME_CORE_REVISION}, found ${elder_runtime_core_revision}"
  )
endif()
execute_process(
  COMMAND "${GIT_EXECUTABLE}" -C "${ELDER_ENB_RUNTIME_CORE_ROOT}"
    status --porcelain --untracked-files=no
  RESULT_VARIABLE elder_runtime_core_status_result
  OUTPUT_VARIABLE elder_runtime_core_status
  ERROR_VARIABLE elder_runtime_core_status_error
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(NOT elder_runtime_core_status_result EQUAL 0)
  message(FATAL_ERROR
    "Could not verify the pinned enb-runtime-core worktree: "
    "${elder_runtime_core_status_error}"
  )
endif()
if(NOT elder_runtime_core_status STREQUAL "")
  message(FATAL_ERROR
    "Pinned enb-runtime-core contains tracked local changes; use a clean "
    "checkout of ${ELDER_ENB_RUNTIME_CORE_REVISION}"
  )
endif()

set(elder_parent_build_testing "${BUILD_TESTING}")
set(BUILD_TESTING OFF)
add_subdirectory(
  "${ELDER_ENB_RUNTIME_CORE_ROOT}"
  "${CMAKE_CURRENT_BINARY_DIR}/enb-runtime-core"
  EXCLUDE_FROM_ALL
)
set(BUILD_TESTING "${elder_parent_build_testing}")

if(MSVC)
  # enb_runtime_core object code will link into the shipped Elder plugin, so
  # its compiler outputs are part of the reproducibility boundary as well.
  target_compile_options(enb_runtime_core PRIVATE /Brepro)
endif()

add_library(elder_runtime STATIC
  src/PulsePublication.cpp
)
target_compile_features(elder_runtime PUBLIC cxx_std_23)
target_include_directories(
  elder_runtime
  PUBLIC
    include
    "${ELDER_ENB_RUNTIME_CORE_ROOT}/include"
)
target_link_libraries(elder_runtime PRIVATE enb_runtime_core)

if(MSVC)
  target_compile_options(
    elder_runtime
    PRIVATE /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8 /Brepro
  )
endif()

# The loadable Elder ENB runtime plugin: ENBSeries loads this .dllplugin from
# the game-root enbseries\ folder. Its object graph includes the neutral core,
# so the core's compiler outputs are part of the reproducibility boundary.
if(WIN32)
  add_library(elder_enb_runtime_plugin SHARED
    src/windows/PluginMain.cpp
  )
  target_compile_features(elder_enb_runtime_plugin PRIVATE cxx_std_23)
  target_include_directories(
    elder_enb_runtime_plugin
    PRIVATE
      include
      "${ELDER_ENB_RUNTIME_CORE_ROOT}/include"
  )
  target_link_libraries(
    elder_enb_runtime_plugin
    PRIVATE
      elder_runtime
      enb_runtime_core
      Psapi
      Version
  )
  set_target_properties(
    elder_enb_runtime_plugin
    PROPERTIES
      OUTPUT_NAME "ElderENBRuntime"
      PREFIX ""
      SUFFIX ".dllplugin"
      WINDOWS_EXPORT_ALL_SYMBOLS OFF
  )
  if(MSVC)
    target_compile_options(
      elder_enb_runtime_plugin
      PRIVATE /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8 /guard:cf /Brepro
    )
    target_link_options(
      elder_enb_runtime_plugin
      PRIVATE /DYNAMICBASE /NXCOMPAT /GUARD:CF /CETCOMPAT /Brepro
    )
  endif()
endif()

if(BUILD_TESTING)
  add_executable(elder_runtime_pulse_publication_tests
    tests/PulsePublicationTests.cpp
  )
  target_compile_features(
    elder_runtime_pulse_publication_tests PRIVATE cxx_std_23
  )
  target_link_libraries(elder_runtime_pulse_publication_tests PRIVATE
    elder_runtime
    enb_runtime_core
  )

  if(MSVC)
    target_compile_options(elder_runtime_pulse_publication_tests PRIVATE
      /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
    )
  endif()

  add_test(
    NAME elder_runtime_pulse_publication
    COMMAND elder_runtime_pulse_publication_tests
  )
endif()
