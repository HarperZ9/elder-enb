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
set(
    ELDER_SH2_SOURCE_ROOT
    ""
    CACHE PATH
    "Optional absolute path to the read-only recovered Silent Horizons Layer3 shader source"
)
set(
    ELDER_SH2_EVIDENCE_SIDECAR
    ""
    CACHE FILEPATH
    "Optional protected external semantic-evidence sidecar paired with ELDER_SH2_SOURCE_ROOT"
)

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_library(elder_profiles STATIC
    src/audit/LegacyPresetAudit.cpp
    src/bindings/LegacyKreateBindings.cpp
    src/improvement/ProfileBundleCompiler.cpp
    src/profiles/TransactionalProfile.cpp
    src/weather/OwnedOutputTransaction.cpp
    src/weather/WeatherThemeCompiler.cpp
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

add_executable(elder_preset_auditor
    src/tools/LegacyPresetAuditMain.cpp
)

target_link_libraries(elder_preset_auditor PRIVATE elder_profiles)

if(MSVC)
    target_compile_options(elder_preset_auditor PRIVATE /W4 /WX /permissive- /utf-8)
endif()

add_executable(elder_profile_bundle_compiler
    src/tools/ProfileBundleCompilerMain.cpp
)

target_link_libraries(elder_profile_bundle_compiler PRIVATE elder_profiles)

if(MSVC)
    target_compile_options(
        elder_profile_bundle_compiler
        PRIVATE /W4 /WX /permissive- /utf-8
    )
endif()

add_executable(elder_weather_theme_compiler
    src/tools/WeatherThemeCompilerMain.cpp
)

target_link_libraries(elder_weather_theme_compiler PRIVATE elder_profiles)

if(MSVC)
    target_compile_options(
        elder_weather_theme_compiler
        PRIVATE /W4 /WX /permissive- /utf-8
    )
endif()

find_program(
    ELDER_FXC_EXECUTABLE
    NAMES fxc.exe fxc
    HINTS
        "C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64"
    DOC "Absolute path to Microsoft FXC used for Elder shader validation"
)
set(
    ELDER_FXC_EXECUTABLE
    "${ELDER_FXC_EXECUTABLE}"
    CACHE FILEPATH "Absolute path to Microsoft FXC used for Elder shader validation"
    FORCE
)

include(CTest)

find_package(Python3 3.10 REQUIRED COMPONENTS Interpreter)

set(
    ELDER_PUBLIC_NATIVE_PARAMETERS
    "${CMAKE_CURRENT_SOURCE_DIR}/out/native-schema/vs18-x64-static/generated/Release/shaders/ElderNativeParameters.fxh"
    CACHE FILEPATH
    "Generated ElderNativeParameters.fxh admitted to the public archive"
)
set(
    ELDER_PUBLIC_RUNTIME_PLUGIN
    "${CMAKE_CURRENT_SOURCE_DIR}/out/native-schema/vs18-x64-static/runtime/Release/ElderENBRuntime.dllplugin"
    CACHE FILEPATH
    "Elder-owned ElderENBRuntime.dllplugin admitted to the public archive"
)
set(
    ELDER_PUBLIC_RUNTIME_RECEIPT
    "${CMAKE_CURRENT_SOURCE_DIR}/out/native-schema/vs18-x64-static/runtime/Release/ElderENBRuntime.dllplugin.receipt"
    CACHE FILEPATH
    "Build receipt binding ElderENBRuntime.dllplugin to its source revisions"
)
set(elder_public_runtime_core_default "${CMAKE_CURRENT_SOURCE_DIR}/../enb-runtime-core")
if(
    NOT EXISTS "${elder_public_runtime_core_default}/LICENSE"
    AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../enb-runtime-core/LICENSE"
)
    set(elder_public_runtime_core_default "${CMAKE_CURRENT_SOURCE_DIR}/../../enb-runtime-core")
endif()
set(
    ELDER_PUBLIC_RUNTIME_CORE_ROOT
    "${elder_public_runtime_core_default}"
    CACHE PATH
    "Pinned enb-runtime-core checkout used for the public runtime license"
)
set(
    ELDER_PUBLIC_PACKAGE_OUTPUT_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/dist"
    CACHE PATH
    "Output directory for the strict Elder public archive"
)
add_custom_target(
    elder_public_release_package
    COMMAND "${CMAKE_COMMAND}" -E env PYTHONDONTWRITEBYTECODE=1
        "${Python3_EXECUTABLE}"
        "${CMAKE_CURRENT_SOURCE_DIR}/scripts/package.py"
        build
        --source-root "${CMAKE_CURRENT_SOURCE_DIR}"
        --output-dir "${ELDER_PUBLIC_PACKAGE_OUTPUT_DIR}"
        --work-dir "${CMAKE_CURRENT_BINARY_DIR}/public-package/target"
        --native-parameters "${ELDER_PUBLIC_NATIVE_PARAMETERS}"
        --runtime-plugin "${ELDER_PUBLIC_RUNTIME_PLUGIN}"
        --runtime-receipt "${ELDER_PUBLIC_RUNTIME_RECEIPT}"
        --runtime-core-root "${ELDER_PUBLIC_RUNTIME_CORE_ROOT}"
    BYPRODUCTS
        "${ELDER_PUBLIC_PACKAGE_OUTPUT_DIR}/Elder-ENB-1.0.0-win64.zip"
        "${ELDER_PUBLIC_PACKAGE_OUTPUT_DIR}/Elder-ENB-1.0.0-win64.zip.sha256"
    COMMENT "Building the strict runtime-complete Elder public archive"
    VERBATIM
)

if(BUILD_TESTING)
    add_test(
        NAME elder_public_release_package
        COMMAND "${CMAKE_COMMAND}"
            "-DELDER_PYTHON=${Python3_EXECUTABLE}"
            "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
            "-DELDER_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
            "-DELDER_NATIVE_PARAMETERS=${ELDER_PUBLIC_NATIVE_PARAMETERS}"
            "-DELDER_RUNTIME_PLUGIN=${ELDER_PUBLIC_RUNTIME_PLUGIN}"
            "-DELDER_RUNTIME_RECEIPT=${ELDER_PUBLIC_RUNTIME_RECEIPT}"
            "-DELDER_RUNTIME_CORE_ROOT=${ELDER_PUBLIC_RUNTIME_CORE_ROOT}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderPublicReleasePackage.cmake"
    )
    set_tests_properties(
        elder_public_release_package
        PROPERTIES
            CONFIGURATIONS Release
            LABELS "release;package;manifest;determinism;security"
            TIMEOUT 180
    )

    add_test(
        NAME elder_stage_compile_matrix
        COMMAND "${CMAKE_COMMAND}"
            "-DELDER_FXC=${ELDER_FXC_EXECUTABLE}"
            "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
            "-DELDER_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderStageMatrix.cmake"
    )
    set_tests_properties(
        elder_stage_compile_matrix
        PROPERTIES LABELS "shader;fxc;quality;matrix"
    )

    add_test(
        NAME elder_host_include_layout_contract
        COMMAND "${CMAKE_COMMAND}"
            "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderHostIncludeLayout.cmake"
    )
    set_tests_properties(
        elder_host_include_layout_contract
        PROPERTIES LABELS "shader;host;include;package"
    )

    add_test(
        NAME elder_prepass_contract
        COMMAND "${CMAKE_COMMAND}"
            "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderPrepassContracts.cmake"
    )
    set_tests_properties(
        elder_prepass_contract
        PROPERTIES LABELS "shader;prepass;contract"
    )

    add_test(
        NAME elder_quality_presets
        COMMAND "${CMAKE_COMMAND}"
            "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
            "-DELDER_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderQualityPresets.cmake"
    )
    set_tests_properties(
        elder_quality_presets
        PROPERTIES LABELS "shader;quality;presets;determinism"
    )

    add_test(
        NAME elder_optical_contracts
        COMMAND "${CMAKE_COMMAND}"
            "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
            "-DELDER_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderOpticalContracts.cmake"
    )
    set_tests_properties(
        elder_optical_contracts
        PROPERTIES LABELS "shader;optical;contract"
    )

    add_test(
        NAME elder_composition_contracts
        COMMAND "${CMAKE_COMMAND}"
            "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderCompositionContracts.cmake"
    )
    set_tests_properties(
        elder_composition_contracts
        PROPERTIES LABELS "shader;composition;contract"
    )

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

    add_executable(elder_preset_audit_tests
        tests/LegacyPresetAuditTests.cpp
    )

    target_link_libraries(elder_preset_audit_tests PRIVATE elder_profiles)

    if(MSVC)
        target_compile_options(elder_preset_audit_tests PRIVATE /W4 /WX /permissive- /utf-8)
    endif()

    add_test(NAME legacy_kreate_preset_audit_tests COMMAND elder_preset_audit_tests)
    set_tests_properties(legacy_kreate_preset_audit_tests PROPERTIES TIMEOUT 30)

    add_executable(elder_profile_bundle_tests
        tests/ProfileBundleCompilerTests.cpp
    )

    target_link_libraries(elder_profile_bundle_tests PRIVATE elder_profiles)

    if(MSVC)
        target_compile_options(elder_profile_bundle_tests PRIVATE /W4 /WX /permissive- /utf-8)
    endif()

    add_test(NAME elder_profile_bundle_tests COMMAND elder_profile_bundle_tests)
    set_tests_properties(elder_profile_bundle_tests PROPERTIES TIMEOUT 60)

    add_executable(elder_weather_theme_tests
        tests/WeatherThemeCompilerTests.cpp
    )

    target_link_libraries(elder_weather_theme_tests PRIVATE elder_profiles)

    target_compile_definitions(
        elder_weather_theme_tests
        PRIVATE ELDER_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
    )

    if(MSVC)
        target_compile_options(elder_weather_theme_tests PRIVATE /W4 /WX /permissive- /utf-8)
    endif()

    add_test(NAME elder_weather_theme_tests COMMAND elder_weather_theme_tests)
    set_tests_properties(elder_weather_theme_tests PROPERTIES TIMEOUT 90)

    if(WIN32)
        add_executable(elder_room_light_cpp_tests
            native/tests/RoomLightTests.cpp
            native/src/RoomLight.cpp
        )
        target_compile_features(elder_room_light_cpp_tests PRIVATE cxx_std_23)
        target_include_directories(elder_room_light_cpp_tests PRIVATE
            "${CMAKE_CURRENT_SOURCE_DIR}/native/include"
        )
        if(MSVC)
            target_compile_options(
                elder_room_light_cpp_tests
                PRIVATE /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
            )
        endif()
        add_test(
            NAME elder_room_light_cpp
            COMMAND elder_room_light_cpp_tests
        )
        set_tests_properties(
            elder_room_light_cpp
            PROPERTIES LABELS "shader;room-light;prepass;cpp"
        )

        add_executable(elder_room_light_warp_tests
            native/tests/RoomLightWarpTests.cpp
            native/src/RoomLight.cpp
        )
        target_compile_features(elder_room_light_warp_tests PRIVATE cxx_std_23)
        target_include_directories(elder_room_light_warp_tests PRIVATE
            "${CMAKE_CURRENT_SOURCE_DIR}/native/include"
        )
        target_link_libraries(elder_room_light_warp_tests PRIVATE
            d3d11
            d3dcompiler
        )
        if(MSVC)
            target_compile_options(
                elder_room_light_warp_tests
                PRIVATE /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
            )
        endif()
        add_test(
            NAME elder_room_light_warp
            COMMAND elder_room_light_warp_tests
                "${CMAKE_CURRENT_SOURCE_DIR}/native/shaders/ElderRoomLightWarpProbe.hlsl"
                "${CMAKE_CURRENT_SOURCE_DIR}/shaders/elder/ElderPrepassWarpProbe.hlsl"
        )
        set_tests_properties(
            elder_room_light_warp
            PROPERTIES LABELS "shader;warp;room-light;prepass"
        )

        add_executable(elder_capability_warp_tests
            tests/ElderCapabilityWarpTests.cpp
        )
        target_compile_features(elder_capability_warp_tests PRIVATE cxx_std_23)
        target_link_libraries(elder_capability_warp_tests PRIVATE
            d3d11
            d3dcompiler
        )
        if(MSVC)
            target_compile_options(
                elder_capability_warp_tests
                PRIVATE /W4 /WX /permissive- /EHsc /Zc:__cplusplus /utf-8
            )
        endif()
        add_test(
            NAME elder_capability_warp
            COMMAND elder_capability_warp_tests
                "${CMAKE_CURRENT_SOURCE_DIR}/shaders/elder/ElderCapabilityWarpProbe.hlsl"
        )
        set_tests_properties(
            elder_capability_warp
            PROPERTIES LABELS "shader;warp;capability;matrix"
        )
    endif()

    add_test(
        NAME elder_weather_structural_validation
        COMMAND "${CMAKE_COMMAND}"
            -DCOMPILER=$<TARGET_FILE:elder_weather_theme_compiler>
            -DSOURCE_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DOUTPUT_ROOT=${CMAKE_CURRENT_BINARY_DIR}/artifacts/weather-structural-output
            -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/VerifyWeatherStructuralOnly.cmake
    )
    set_tests_properties(elder_weather_structural_validation PROPERTIES TIMEOUT 30)

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

        add_test(
            NAME legacy_kreate_record_audit_integration
            COMMAND elder_preset_auditor
                --preset-root "${ELDER_LEGACY_PRESET_ROOT}"
                --catalog "${CMAKE_CURRENT_SOURCE_DIR}/config/legacy-kreate-bindings.csv"
                --manifest "${CMAKE_CURRENT_BINARY_DIR}/artifacts/task-03/legacy-preset-audit.csv"
                --report "${CMAKE_CURRENT_BINARY_DIR}/artifacts/task-03/legacy-preset-audit.txt"
                --expect-presets 37
                --expect-ini-files 49358
                --require-preset "Arrival of Autumn"
            CONFIGURATIONS Release
        )
        set_tests_properties(
            legacy_kreate_record_audit_integration
            PROPERTIES
                TIMEOUT 600
        )

        add_test(
            NAME elder_first_five_bundle_integration
            COMMAND elder_profile_bundle_compiler
                --overlay-root "${ELDER_LEGACY_OVERLAY_ROOT}"
                --preset-root "${ELDER_LEGACY_PRESET_ROOT}"
                --catalog "${CMAKE_CURRENT_SOURCE_DIR}/config/legacy-kreate-bindings.csv"
                --improvement-manifest
                    "${CMAKE_CURRENT_SOURCE_DIR}/config/first-five-improvements.csv"
                --output-root
                    "${CMAKE_CURRENT_BINARY_DIR}/artifacts/task-04/$<CONFIG>/first-five-bundles"
                --expect-profiles 5
                --expect-repairs 1077
        )
        set_tests_properties(
            elder_first_five_bundle_integration
            PROPERTIES
                TIMEOUT 600
        )

        if(
            (ELDER_SH2_SOURCE_ROOT STREQUAL ""
             AND NOT ELDER_SH2_EVIDENCE_SIDECAR STREQUAL "")
            OR
            (NOT ELDER_SH2_SOURCE_ROOT STREQUAL ""
             AND ELDER_SH2_EVIDENCE_SIDECAR STREQUAL "")
        )
            message(FATAL_ERROR
                "ELDER_SH2_SOURCE_ROOT and ELDER_SH2_EVIDENCE_SIDECAR must be supplied together"
            )
        endif()

        if(
            NOT ELDER_SH2_SOURCE_ROOT STREQUAL ""
            AND NOT ELDER_SH2_EVIDENCE_SIDECAR STREQUAL ""
        )
            cmake_path(IS_ABSOLUTE ELDER_SH2_SOURCE_ROOT elder_sh2_root_is_absolute)
            cmake_path(
                IS_ABSOLUTE
                ELDER_SH2_EVIDENCE_SIDECAR
                elder_sh2_sidecar_is_absolute
            )
            if(NOT elder_sh2_root_is_absolute OR NOT elder_sh2_sidecar_is_absolute)
                message(FATAL_ERROR
                    "Protected semantic-evidence integration paths must be absolute"
                )
            endif()

            add_test(
                NAME elder_five_profile_weather_theme_integration
                COMMAND elder_weather_theme_compiler
                    --overlay-root "${ELDER_LEGACY_OVERLAY_ROOT}"
                    --preset-root "${ELDER_LEGACY_PRESET_ROOT}"
                    --catalog
                        "${CMAKE_CURRENT_SOURCE_DIR}/config/legacy-kreate-bindings.csv"
                    --improvement-manifest
                        "${CMAKE_CURRENT_SOURCE_DIR}/config/first-five-improvements.csv"
                    --theme-config
                        "${CMAKE_CURRENT_SOURCE_DIR}/config/five-profile-weather-themes.csv"
                    --semantic-registry
                        "${CMAKE_CURRENT_SOURCE_DIR}/config/shader-semantic-registry.csv"
                    --shader-root "${ELDER_SH2_SOURCE_ROOT}"
                    --semantic-evidence-sidecar "${ELDER_SH2_EVIDENCE_SIDECAR}"
                    --output-root
                        "${CMAKE_CURRENT_BINARY_DIR}/artifacts/task-05/$<CONFIG>/weather-theme-bundles"
                    --expect-profiles 5
                    --expect-weather-records 3555
                    --expect-fields 583020
                    --expect-semantic-verified 15
                    --expect-semantic-unresolved 1
            )
            set_tests_properties(
                elder_five_profile_weather_theme_integration
                PROPERTIES
                    TIMEOUT 1200
            )
        endif()
    endif()
endif()
