cmake_minimum_required(VERSION 4.0)

project(elder_native_shader_schema LANGUAGES CXX)

include(CTest)

option(
  ELDER_ALLOW_PARSER_ONLY
  "Developer-only: permit configuration without strict FXC shader validation"
  OFF
)

add_library(elder_native_parameter_schema STATIC
  src/ParameterSchema.cpp
  src/ArtifactPublication.cpp
  src/NativeFileIO.cpp
)
target_compile_features(elder_native_parameter_schema PUBLIC cxx_std_23)
  target_include_directories(elder_native_parameter_schema PUBLIC include)

add_executable(elder_native_schema_compiler
  tools/NativeSchemaCompilerMain.cpp
)
target_compile_features(elder_native_schema_compiler PRIVATE cxx_std_23)
target_link_libraries(elder_native_schema_compiler PRIVATE
  elder_native_parameter_schema
)

add_executable(elder_native_artifact_publisher
  tools/ArtifactPublisherMain.cpp
)
target_compile_features(elder_native_artifact_publisher PRIVATE cxx_std_23)
target_link_libraries(elder_native_artifact_publisher PRIVATE
  elder_native_parameter_schema
)

if(MSVC)
  foreach(target IN ITEMS
      elder_native_parameter_schema
      elder_native_schema_compiler
      elder_native_artifact_publisher)
    target_compile_options(${target} PRIVATE
      /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
    )
  endforeach()
endif()

set(ELDER_NATIVE_SCHEMA
  "${CMAKE_CURRENT_SOURCE_DIR}/schema/elder-native-parameters.csv"
)
set(ELDER_GENERATED_ROOT
  "${CMAKE_CURRENT_BINARY_DIR}/generated/$<CONFIG>"
)
set(ELDER_GENERATED_HLSL
  "${ELDER_GENERATED_ROOT}/shaders/ElderNativeParameters.fxh"
)
set(ELDER_GENERATED_CPP
  "${ELDER_GENERATED_ROOT}/include/elder/shaders/generated/ElderNativeParameterDefaults.hpp"
)
set(ELDER_GENERATED_MANIFEST
  "${ELDER_GENERATED_ROOT}/manifest/elder-native-parameters.json"
)
set(ELDER_GENERATED_PROFILE
  "${ELDER_GENERATED_ROOT}/profiles/elder-native-default.profile"
)

add_custom_command(
  OUTPUT
    "${ELDER_GENERATED_HLSL}"
    "${ELDER_GENERATED_CPP}"
    "${ELDER_GENERATED_MANIFEST}"
    "${ELDER_GENERATED_PROFILE}"
  COMMAND "$<TARGET_FILE:elder_native_schema_compiler>"
    "${ELDER_NATIVE_SCHEMA}"
    "${ELDER_GENERATED_HLSL}"
    "${ELDER_GENERATED_CPP}"
    "${ELDER_GENERATED_MANIFEST}"
    "${ELDER_GENERATED_PROFILE}"
  DEPENDS
    elder_native_schema_compiler
    "${ELDER_NATIVE_SCHEMA}"
  COMMENT "Generating the Elder native parameter ABI"
  VERBATIM
)
add_custom_target(elder_native_generated_artifacts ALL
  DEPENDS
    "${ELDER_GENERATED_HLSL}"
    "${ELDER_GENERATED_CPP}"
    "${ELDER_GENERATED_MANIFEST}"
    "${ELDER_GENERATED_PROFILE}"
)

add_library(elder_native_room_light STATIC
  src/RoomLight.cpp
)
target_compile_features(elder_native_room_light PUBLIC cxx_std_23)
target_include_directories(elder_native_room_light PUBLIC include)

add_library(elder_native_temporal_dither STATIC
  src/TemporalDither.cpp
)
target_compile_features(elder_native_temporal_dither PUBLIC cxx_std_23)
target_include_directories(elder_native_temporal_dither PUBLIC include)

add_library(elder_native_color_core STATIC
  src/ColorCore.cpp
  src/ColorProfileBinding.cpp
  "${ELDER_GENERATED_CPP}"
)
add_dependencies(elder_native_color_core elder_native_generated_artifacts)
target_compile_features(elder_native_color_core PUBLIC cxx_std_23)
target_include_directories(elder_native_color_core PUBLIC
  include
  "${ELDER_GENERATED_ROOT}/include"
)
target_link_libraries(elder_native_color_core PUBLIC
  elder_native_parameter_schema
)
if(MSVC)
  target_compile_options(elder_native_color_core PRIVATE
    /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
  )
endif()

find_program(
  ELDER_FXC_EXECUTABLE
  NAMES fxc.exe fxc
  HINTS
    "C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64"
  DOC "Absolute path to Microsoft FXC used for release shader validation"
)
set(ELDER_FXC_EXECUTABLE "${ELDER_FXC_EXECUTABLE}"
  CACHE FILEPATH "Absolute path to Microsoft FXC used for release shader validation"
  FORCE
)
if(NOT EXISTS "${ELDER_FXC_EXECUTABLE}" AND NOT ELDER_ALLOW_PARSER_ONLY)
  message(FATAL_ERROR
    "FXC is required for Elder release validation. Set ELDER_FXC_EXECUTABLE "
    "to fxc.exe, or explicitly opt into the non-release parser-only mode with "
    "-DELDER_ALLOW_PARSER_ONLY=ON."
  )
endif()

if(EXISTS "${ELDER_FXC_EXECUTABLE}")
  set(ELDER_COMPILED_ROOT
    "${CMAKE_CURRENT_BINARY_DIR}/compiled/$<CONFIG>"
  )
  set(ELDER_COMPILED_CSO
    "${ELDER_COMPILED_ROOT}/ElderColorReference.cso"
  )
  set(ELDER_COMPILED_ASM
    "${ELDER_COMPILED_ROOT}/ElderColorReference.asm"
  )
  add_custom_command(
    OUTPUT "${ELDER_COMPILED_CSO}" "${ELDER_COMPILED_ASM}"
    COMMAND "${CMAKE_COMMAND}"
      "-DELDER_FXC=${ELDER_FXC_EXECUTABLE}"
      "-DELDER_PUBLISHER=$<TARGET_FILE:elder_native_artifact_publisher>"
      "-DELDER_SHADER=${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderColorReference.hlsl"
      "-DELDER_INCLUDE=${CMAKE_CURRENT_SOURCE_DIR}/shaders"
      "-DELDER_GENERATED_INCLUDE=${ELDER_GENERATED_ROOT}/shaders"
      "-DELDER_OUTPUT=${ELDER_COMPILED_CSO}"
      "-DELDER_LISTING=${ELDER_COMPILED_ASM}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CompileElderColorCore.cmake"
    DEPENDS
      elder_native_artifact_publisher
      elder_native_generated_artifacts
      "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CompileElderColorCore.cmake"
      "${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderColorCore.fxh"
      "${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderColorReference.hlsl"
      "${ELDER_GENERATED_HLSL}"
    COMMENT "Compiling the Elder production color shader"
    VERBATIM
  )
  add_custom_target(elder_native_compiled_shaders ALL
    DEPENDS "${ELDER_COMPILED_CSO}" "${ELDER_COMPILED_ASM}"
  )

  set(ELDER_NATIVE_INSTALL_ROOT "Elder ENB/Native")
  install(FILES "${ELDER_GENERATED_HLSL}"
    DESTINATION "${ELDER_NATIVE_INSTALL_ROOT}/Shaders"
    COMPONENT NativeRelease)
  install(FILES "${ELDER_COMPILED_CSO}" "${ELDER_COMPILED_ASM}"
    DESTINATION "${ELDER_NATIVE_INSTALL_ROOT}/Shaders"
    COMPONENT NativeRelease)
  install(FILES "${ELDER_GENERATED_CPP}"
    DESTINATION
      "${ELDER_NATIVE_INSTALL_ROOT}/Include/elder/shaders/generated"
    COMPONENT NativeRelease)
  install(FILES "${ELDER_GENERATED_MANIFEST}"
    DESTINATION "${ELDER_NATIVE_INSTALL_ROOT}/Manifest"
    COMPONENT NativeRelease)
  install(FILES "${ELDER_GENERATED_PROFILE}"
    DESTINATION "${ELDER_NATIVE_INSTALL_ROOT}/Profiles"
    COMPONENT NativeRelease)
  install(FILES README.md NOTICE.md
    DESTINATION "${ELDER_NATIVE_INSTALL_ROOT}/Documentation"
    COMPONENT NativeRelease)

  set(CPACK_GENERATOR "ZIP")
  set(CPACK_PACKAGE_NAME "Elder ENB Native")
  set(CPACK_PACKAGE_VENDOR "Elder ENB")
  set(CPACK_PACKAGE_DESCRIPTION_SUMMARY
    "Elder ENB native parameter ABI and production color shader")
  set(CPACK_PACKAGE_VERSION "0.0.0")
  set(CPACK_PACKAGE_FILE_NAME "Elder-ENB-Native-RC-win64")
  set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)
  set(CPACK_COMPONENTS_ALL NativeRelease)
  set(CPACK_THREADS 1)
  set(CPACK_PACKAGE_CHECKSUM SHA256)
  include(CPack)
  add_custom_target(elder_native_release_package
    COMMAND "${CMAKE_COMMAND}" -E make_directory
      "${CMAKE_CURRENT_BINARY_DIR}/packages/$<CONFIG>"
    COMMAND "${CMAKE_COMMAND}" -E env SOURCE_DATE_EPOCH=946684800
      "${CMAKE_CPACK_COMMAND}"
      --config "${CMAKE_CURRENT_BINARY_DIR}/CPackConfig.cmake"
      -C "$<CONFIG>"
      -G ZIP
      -B "${CMAKE_CURRENT_BINARY_DIR}/packages/$<CONFIG>"
    DEPENDS
      elder_native_generated_artifacts
      elder_native_compiled_shaders
    COMMENT "Packaging the deterministic Elder native release archive"
    VERBATIM
  )
endif()

if(BUILD_TESTING)
  add_executable(elder_native_shader_schema_tests
    tests/ParameterSchemaTests.cpp
  )
  target_compile_features(elder_native_shader_schema_tests PRIVATE cxx_std_23)
  target_link_libraries(elder_native_shader_schema_tests PRIVATE
    elder_native_parameter_schema
  )

  add_executable(elder_native_color_core_tests
    tests/ColorCoreTests.cpp
  )
  target_compile_features(elder_native_color_core_tests PRIVATE cxx_std_23)
  target_link_libraries(elder_native_color_core_tests PRIVATE
    elder_native_color_core
  )

  add_executable(elder_native_temporal_dither_tests
    tests/TemporalDitherTests.cpp
  )
  target_compile_features(elder_native_temporal_dither_tests PRIVATE cxx_std_23)
  target_link_libraries(elder_native_temporal_dither_tests PRIVATE
    elder_native_temporal_dither
  )
  add_test(
    NAME elder_native_temporal_dither
    COMMAND elder_native_temporal_dither_tests
  )

  add_executable(elder_native_room_light_tests
    tests/RoomLightTests.cpp
  )
  target_compile_features(elder_native_room_light_tests PRIVATE cxx_std_23)
  target_link_libraries(elder_native_room_light_tests PRIVATE
    elder_native_room_light
  )

  if(MSVC)
    foreach(target IN ITEMS
        elder_native_shader_schema_tests
        elder_native_color_core_tests
        elder_native_room_light_tests)
      target_compile_options(${target} PRIVATE
        /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
      )
    endforeach()
  endif()

  add_test(NAME elder_native_room_light COMMAND elder_native_room_light_tests)

  add_test(
    NAME elder_native_shader_schema
    COMMAND elder_native_shader_schema_tests "${ELDER_NATIVE_SCHEMA}"
  )

  add_executable(elder_native_artifact_publication_tests
    tests/ArtifactPublicationTests.cpp
  )
  target_compile_features(
    elder_native_artifact_publication_tests PRIVATE cxx_std_23
  )
  target_link_libraries(elder_native_artifact_publication_tests PRIVATE
    elder_native_parameter_schema
  )
  target_include_directories(elder_native_artifact_publication_tests PRIVATE
    src
  )
  if(MSVC)
    target_compile_options(elder_native_artifact_publication_tests PRIVATE
      /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
    )
  endif()
  add_test(
    NAME elder_native_artifact_publication
    COMMAND elder_native_artifact_publication_tests
  )
  set_tests_properties(elder_native_artifact_publication PROPERTIES
    LABELS "artifact;transaction;rollback;release"
  )
  add_test(
    NAME elder_native_artifact_determinism
    COMMAND "${CMAKE_COMMAND}"
      "-DELDER_COMPILER=$<TARGET_FILE:elder_native_schema_compiler>"
      "-DELDER_SCHEMA=${ELDER_NATIVE_SCHEMA}"
      "-DELDER_WORK_ROOT=${CMAKE_CURRENT_BINARY_DIR}/determinism/$<CONFIG>"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckDeterministicNativeArtifacts.cmake"
  )
  set_tests_properties(elder_native_artifact_determinism PROPERTIES
    DEPENDS elder_native_artifact_publication
    LABELS "artifact;determinism;release"
  )

  if(WIN32)
    add_executable(elder_native_tool_cli_tests
      tests/NativeToolCliTests.cpp
    )
    add_dependencies(elder_native_tool_cli_tests
      elder_native_artifact_publisher
      elder_native_schema_compiler
    )
    target_compile_features(elder_native_tool_cli_tests PRIVATE cxx_std_23)
    if(MSVC)
      target_compile_options(elder_native_tool_cli_tests PRIVATE
        /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
      )
    endif()
    add_test(
      NAME elder_native_tool_cli_paths
      COMMAND elder_native_tool_cli_tests
        "$<TARGET_FILE:elder_native_artifact_publisher>"
        "$<TARGET_FILE:elder_native_schema_compiler>"
        "${ELDER_NATIVE_SCHEMA}"
    )
    set_tests_properties(elder_native_tool_cli_paths PROPERTIES
      LABELS "artifact;cli;long-path;unicode;release"
    )
  endif()
  add_test(NAME elder_native_color_core COMMAND elder_native_color_core_tests)

  add_executable(elder_native_color_profile_binding_tests
    tests/ColorProfileBindingTests.cpp
  )
  target_compile_features(
    elder_native_color_profile_binding_tests PRIVATE cxx_std_23
  )
  target_link_libraries(elder_native_color_profile_binding_tests PRIVATE
    elder_native_color_core
  )
  if(MSVC)
    target_compile_options(elder_native_color_profile_binding_tests PRIVATE
      /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
    )
  endif()
  add_test(
    NAME elder_native_color_profile_binding
    COMMAND elder_native_color_profile_binding_tests "${ELDER_NATIVE_SCHEMA}"
  )
  set_tests_properties(elder_native_color_profile_binding PROPERTIES
    LABELS "profile;color-core;binding;release"
  )

  if(EXISTS "${ELDER_FXC_EXECUTABLE}")
    add_test(
      NAME elder_native_color_core_fxc
      COMMAND "${CMAKE_COMMAND}"
        "-DELDER_FXC=${ELDER_FXC_EXECUTABLE}"
        "-DELDER_PUBLISHER=$<TARGET_FILE:elder_native_artifact_publisher>"
        "-DELDER_SHADER=${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderColorReference.hlsl"
        "-DELDER_INCLUDE=${CMAKE_CURRENT_SOURCE_DIR}/shaders"
        "-DELDER_GENERATED_INCLUDE=${ELDER_GENERATED_ROOT}/shaders"
        "-DELDER_OUTPUT=${ELDER_COMPILED_CSO}"
        "-DELDER_LISTING=${ELDER_COMPILED_ASM}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CompileElderColorCore.cmake"
    )
    set_tests_properties(elder_native_color_core_fxc PROPERTIES
      DEPENDS elder_native_shader_schema
      LABELS "shader;fxc;color-core;release"
    )

    add_test(
      NAME elder_native_room_light_fxc
      COMMAND "${CMAKE_COMMAND}"
        "-DELDER_FXC=${ELDER_FXC_EXECUTABLE}"
        "-DELDER_SHADER=${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderRoomLightReference.hlsl"
        "-DELDER_REQUIRED_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderRoomLight.fxh"
        "-DELDER_INCLUDE=${CMAKE_CURRENT_SOURCE_DIR}/shaders"
        "-DELDER_TARGET=ps_5_0"
        "-DELDER_ENTRY=ElderRoomLightReferencePixelMain"
        "-DELDER_OUTPUT=${CMAKE_CURRENT_BINARY_DIR}/shaders/$<CONFIG>/ElderRoomLight.cso"
        "-DELDER_LISTING=${CMAKE_CURRENT_BINARY_DIR}/shaders/$<CONFIG>/ElderRoomLight.asm"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CompileElderShader.cmake"
    )
    set_tests_properties(elder_native_room_light_fxc PROPERTIES
      LABELS "shader;fxc;room-light;release"
    )

    add_executable(elder_native_room_light_warp_tests
      tests/RoomLightWarpTests.cpp
    )
    target_compile_features(
      elder_native_room_light_warp_tests PRIVATE cxx_std_23
    )
    target_link_libraries(elder_native_room_light_warp_tests PRIVATE
      elder_native_room_light
      d3d11
      d3dcompiler
    )
    if(MSVC)
      target_compile_options(elder_native_room_light_warp_tests PRIVATE
        /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
      )
    endif()
    add_test(
      NAME elder_native_room_light_warp
      COMMAND elder_native_room_light_warp_tests
        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderRoomLightWarpProbe.hlsl"
    )
    set_tests_properties(elder_native_room_light_warp PROPERTIES
      LABELS "shader;warp;room-light;parity;release"
    )

    add_test(
      NAME elder_native_release_package_manifest
      COMMAND "${CMAKE_COMMAND}"
        "-DELDER_BUILD_ROOT=${CMAKE_CURRENT_BINARY_DIR}"
        "-DELDER_CONFIGURATION=$<CONFIG>"
        "-DELDER_WORK_ROOT=${CMAKE_CURRENT_BINARY_DIR}/package-validation/$<CONFIG>"
        "-DELDER_GENERATED_ROOT=${ELDER_GENERATED_ROOT}"
        "-DELDER_COMPILED_ROOT=${ELDER_COMPILED_ROOT}"
        "-DELDER_SOURCE_ROOT=${CMAKE_CURRENT_SOURCE_DIR}"
        "-DELDER_CPACK=${CMAKE_CPACK_COMMAND}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckNativePackage.cmake"
    )
    set_tests_properties(elder_native_release_package_manifest PROPERTIES
      DEPENDS "elder_native_artifact_determinism;elder_native_color_core_fxc"
      LABELS "install;package;manifest;determinism;release"
    )
  endif()

  if(WIN32)
    add_executable(elder_native_temporal_dither_warp_tests
      tests/TemporalDitherWarpTests.cpp
    )
    target_compile_features(
      elder_native_temporal_dither_warp_tests PRIVATE cxx_std_23
    )
    target_link_libraries(elder_native_temporal_dither_warp_tests PRIVATE
      elder_native_temporal_dither
      d3d11
      d3dcompiler
    )
    if(MSVC)
      target_compile_options(elder_native_temporal_dither_warp_tests PRIVATE
        /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
      )
    endif()
    add_test(
      NAME elder_native_temporal_dither_warp
      COMMAND elder_native_temporal_dither_warp_tests
        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderTemporalDitherWarpProbe.hlsl"
    )
    set_tests_properties(elder_native_temporal_dither_warp PROPERTIES
      LABELS "shader;warp;dither;parity;release"
    )

    add_executable(elder_native_color_core_warp_tests
      tests/ColorCoreWarpTests.cpp
    )
    add_dependencies(
      elder_native_color_core_warp_tests
      elder_native_generated_artifacts
    )
    target_compile_features(
      elder_native_color_core_warp_tests PRIVATE cxx_std_23
    )
    target_link_libraries(elder_native_color_core_warp_tests PRIVATE
      elder_native_color_core
      d3d11
      d3dcompiler
    )
    if(MSVC)
      target_compile_options(elder_native_color_core_warp_tests PRIVATE
        /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
      )
    endif()
    add_test(
      NAME elder_native_color_core_warp
      COMMAND elder_native_color_core_warp_tests
        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderColorWarpProbe.hlsl"
        "${ELDER_GENERATED_ROOT}/shaders"
    )
    set_tests_properties(elder_native_color_core_warp PROPERTIES
      DEPENDS elder_native_shader_schema
      LABELS "shader;warp;color-core;parity;release"
    )

    add_executable(elder_native_color_reference_warp_tests
      tests/ColorReferenceWarpTests.cpp
    )
    add_dependencies(
      elder_native_color_reference_warp_tests
      elder_native_generated_artifacts
    )
    target_compile_features(
      elder_native_color_reference_warp_tests PRIVATE cxx_std_23
    )
    target_link_libraries(elder_native_color_reference_warp_tests PRIVATE
      elder_native_color_core
      d3d11
      d3dcompiler
    )
    if(MSVC)
      target_compile_options(elder_native_color_reference_warp_tests PRIVATE
        /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
      )
    endif()
    add_test(
      NAME elder_native_color_reference_warp
      COMMAND elder_native_color_reference_warp_tests
        "${CMAKE_CURRENT_SOURCE_DIR}/shaders/ElderColorReference.hlsl"
        "${ELDER_GENERATED_ROOT}/shaders"
    )
    set_tests_properties(elder_native_color_reference_warp PROPERTIES
      DEPENDS elder_native_color_core_fxc
      LABELS "shader;warp;color-core;production;nan;release"
    )
  endif()
endif()

# The ENB-facing Elder runtime, built on the pinned neutral enb-runtime-core.
add_subdirectory(runtime)
