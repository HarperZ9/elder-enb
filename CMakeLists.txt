cmake_minimum_required(VERSION 4.0)

cmake_policy(SET CMP0091 NEW)
set(CMAKE_VS_GLOBALS "VcpkgEnabled=false")

project(ElderENB VERSION 0.1.0 LANGUAGES CXX)

set(
    ELDER_LEGACY_OVERLAY_ROOT
    ""
    CACHE PATH
    "Optional absolute path to the read-only legacy ENB preset-overlay directory"
)
set(
    ELDER_LEGACY_PRESET_ROOT
    ""
    CACHE PATH
    "Optional absolute path to the read-only legacy KreatE preset directory"
)

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_library(elder_profiles STATIC
    src/bindings/LegacyKreateBindings.cpp
    src/profiles/TransactionalProfile.cpp
)

target_include_directories(elder_profiles
    PUBLIC
        "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
)

target_compile_features(elder_profiles PUBLIC cxx_std_23)

if(MSVC)
    target_compile_options(elder_profiles PRIVATE /W4 /WX /permissive- /utf-8)
endif()

add_executable(elder_binding_compiler
    src/tools/LegacyKreateCompilerMain.cpp
)

target_link_libraries(elder_binding_compiler PRIVATE elder_profiles)

if(MSVC)
    target_compile_options(elder_binding_compiler PRIVATE /W4 /WX /permissive- /utf-8)
endif()

include(CTest)

if(BUILD_TESTING)
    add_executable(elder_profile_tests
        tests/TransactionalProfileTests.cpp
    )

    target_link_libraries(elder_profile_tests PRIVATE elder_profiles)

    if(MSVC)
        target_compile_options(elder_profile_tests PRIVATE /W4 /WX /permissive- /utf-8)
    endif()

    add_test(NAME transactional_profile_tests COMMAND elder_profile_tests)
    set_tests_properties(transactional_profile_tests PROPERTIES TIMEOUT 30)

    add_executable(elder_binding_tests
        tests/LegacyKreateBindingsTests.cpp
    )

    target_link_libraries(elder_binding_tests PRIVATE elder_profiles)

    if(MSVC)
        target_compile_options(elder_binding_tests PRIVATE /W4 /WX /permissive- /utf-8)
    endif()

    add_test(NAME legacy_kreate_binding_tests COMMAND elder_binding_tests)
    set_tests_properties(legacy_kreate_binding_tests PROPERTIES TIMEOUT 30)

    if(
        (ELDER_LEGACY_OVERLAY_ROOT STREQUAL ""
         AND NOT ELDER_LEGACY_PRESET_ROOT STREQUAL "")
        OR
        (NOT ELDER_LEGACY_OVERLAY_ROOT STREQUAL ""
         AND ELDER_LEGACY_PRESET_ROOT STREQUAL "")
    )
        message(FATAL_ERROR
            "ELDER_LEGACY_OVERLAY_ROOT and ELDER_LEGACY_PRESET_ROOT must be supplied together"
        )
    endif()

    if(
        NOT ELDER_LEGACY_OVERLAY_ROOT STREQUAL ""
        AND NOT ELDER_LEGACY_PRESET_ROOT STREQUAL ""
    )
        cmake_path(IS_ABSOLUTE ELDER_LEGACY_OVERLAY_ROOT elder_overlay_root_is_absolute)
        cmake_path(IS_ABSOLUTE ELDER_LEGACY_PRESET_ROOT elder_preset_root_is_absolute)
        if(NOT elder_overlay_root_is_absolute OR NOT elder_preset_root_is_absolute)
            message(FATAL_ERROR "Legacy integration roots must be absolute paths")
        endif()

        add_test(
            NAME legacy_kreate_readonly_integration
            COMMAND elder_binding_compiler
                --overlay-root "${ELDER_LEGACY_OVERLAY_ROOT}"
                --preset-root "${ELDER_LEGACY_PRESET_ROOT}"
                --catalog "${CMAKE_CURRENT_SOURCE_DIR}/config/legacy-kreate-bindings.csv"
                --manifest "${CMAKE_CURRENT_BINARY_DIR}/artifacts/task-02/legacy-kreate-manifest.csv"
                --report "${CMAKE_CURRENT_BINARY_DIR}/artifacts/task-02/legacy-kreate-report.txt"
                --expect-overlays 55
                --expect-bindings 37
                --expect-retired 18
                --expect-aliases 4
                --require-identity "Arrival of Autumn"
        )
        set_tests_properties(legacy_kreate_readonly_integration PROPERTIES TIMEOUT 120)
    endif()
endif()
