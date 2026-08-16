cmake_minimum_required(VERSION 4.0)

foreach(required_variable IN ITEMS
    ELDER_PYTHON
    ELDER_SOURCE_DIR
    ELDER_BINARY_DIR
    ELDER_REQUIRE_RUNTIME
    ELDER_NATIVE_PARAMETERS
    ELDER_RUNTIME_PLUGIN
    ELDER_RUNTIME_CORE_ROOT)
    if(NOT DEFINED ${required_variable} OR "${${required_variable}}" STREQUAL "")
        message(FATAL_ERROR "Missing required variable: ${required_variable}")
    endif()
endforeach()

if(NOT EXISTS "${ELDER_PYTHON}")
    message(FATAL_ERROR "Python interpreter is absent: ${ELDER_PYTHON}")
endif()
if(NOT IS_DIRECTORY "${ELDER_SOURCE_DIR}")
    message(FATAL_ERROR "Elder source directory is absent: ${ELDER_SOURCE_DIR}")
endif()
if(NOT IS_DIRECTORY "${ELDER_BINARY_DIR}")
    message(FATAL_ERROR "Elder binary directory is absent: ${ELDER_BINARY_DIR}")
endif()

file(REAL_PATH "${ELDER_SOURCE_DIR}" elder_source_dir)
file(REAL_PATH "${ELDER_BINARY_DIR}" elder_binary_dir)
set(elder_package_script "${elder_source_dir}/scripts/package.py")
set(elder_package_tests "${elder_source_dir}/tests/test_public_package.py")
foreach(required_file IN ITEMS "${elder_package_script}" "${elder_package_tests}")
    if(NOT EXISTS "${required_file}")
        message(FATAL_ERROR "Public package gate requires: ${required_file}")
    endif()
endforeach()

set(elder_work_root "${elder_binary_dir}/public-package-check")
cmake_path(
    IS_PREFIX elder_binary_dir "${elder_work_root}"
    NORMALIZE elder_work_is_contained)
if(NOT elder_work_is_contained)
    message(FATAL_ERROR "Public package work path escapes the build directory")
endif()
file(REMOVE_RECURSE "${elder_work_root}")
file(MAKE_DIRECTORY "${elder_work_root}")

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env PYTHONDONTWRITEBYTECODE=1
        "${ELDER_PYTHON}" -m unittest discover
        -s "${elder_source_dir}/tests"
        -p test_public_package.py
    WORKING_DIRECTORY "${elder_source_dir}"
    RESULT_VARIABLE elder_unit_result
    OUTPUT_VARIABLE elder_unit_stdout
    ERROR_VARIABLE elder_unit_stderr)
if(NOT elder_unit_result EQUAL 0)
    message(FATAL_ERROR
        "Focused public-package validator cases failed.\n"
        "stdout:\n${elder_unit_stdout}\n"
        "stderr:\n${elder_unit_stderr}")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env PYTHONDONTWRITEBYTECODE=1
        "${ELDER_PYTHON}" "${elder_package_script}"
        check-source
        --source-root "${elder_source_dir}"
        --work-dir "${elder_work_root}/source"
    WORKING_DIRECTORY "${elder_source_dir}"
    RESULT_VARIABLE elder_source_result
    OUTPUT_VARIABLE elder_source_stdout
    ERROR_VARIABLE elder_source_stderr)
if(NOT elder_source_result EQUAL 0)
    message(FATAL_ERROR
        "Deterministic shader/docs/media package boundary failed.\n"
        "stdout:\n${elder_source_stdout}\n"
        "stderr:\n${elder_source_stderr}")
endif()

if(NOT ELDER_REQUIRE_RUNTIME)
    string(STRIP "${elder_source_stdout}" elder_source_summary)
    message(STATUS "${elder_source_summary}")
    message(STATUS
        "Runtime-complete archive verification is deferred until "
        "ELDER_PUBLIC_PACKAGE_REQUIRE_RUNTIME=ON and the Elder runtime is built")
    return()
endif()

foreach(runtime_input IN ITEMS
    "${ELDER_NATIVE_PARAMETERS}"
    "${ELDER_RUNTIME_PLUGIN}"
    "${ELDER_RUNTIME_CORE_ROOT}/LICENSE")
    if(NOT EXISTS "${runtime_input}")
        message(FATAL_ERROR
            "Runtime-complete public package input is absent: ${runtime_input}")
    endif()
endforeach()

set(elder_reference_archive "")
set(elder_reference_checksum "")
foreach(elder_run IN ITEMS first second)
    set(elder_run_root "${elder_work_root}/${elder_run}")
    set(elder_output_root "${elder_run_root}/dist")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env PYTHONDONTWRITEBYTECODE=1
            "${ELDER_PYTHON}" "${elder_package_script}"
            build
            --source-root "${elder_source_dir}"
            --output-dir "${elder_output_root}"
            --work-dir "${elder_run_root}/work"
            --native-parameters "${ELDER_NATIVE_PARAMETERS}"
            --runtime-plugin "${ELDER_RUNTIME_PLUGIN}"
            --runtime-core-root "${ELDER_RUNTIME_CORE_ROOT}"
        WORKING_DIRECTORY "${elder_source_dir}"
        RESULT_VARIABLE elder_build_result
        OUTPUT_VARIABLE elder_build_stdout
        ERROR_VARIABLE elder_build_stderr)
    if(NOT elder_build_result EQUAL 0)
        message(FATAL_ERROR
            "Runtime-complete public package run ${elder_run} failed.\n"
            "stdout:\n${elder_build_stdout}\n"
            "stderr:\n${elder_build_stderr}")
    endif()

    set(elder_archive "${elder_output_root}/Elder-ENB-1.0.0-win64.zip")
    set(elder_checksum "${elder_archive}.sha256")
    foreach(elder_artifact IN ITEMS "${elder_archive}" "${elder_checksum}")
        if(NOT EXISTS "${elder_artifact}")
            message(FATAL_ERROR
                "Public package run ${elder_run} omitted ${elder_artifact}")
        endif()
    endforeach()

    execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env PYTHONDONTWRITEBYTECODE=1
            "${ELDER_PYTHON}" "${elder_package_script}"
            verify "${elder_archive}" --require-runtime
        WORKING_DIRECTORY "${elder_source_dir}"
        RESULT_VARIABLE elder_verify_result
        OUTPUT_VARIABLE elder_verify_stdout
        ERROR_VARIABLE elder_verify_stderr)
    if(NOT elder_verify_result EQUAL 0)
        message(FATAL_ERROR
            "Runtime-complete public package run ${elder_run} did not verify.\n"
            "stdout:\n${elder_verify_stdout}\n"
            "stderr:\n${elder_verify_stderr}")
    endif()

    if(elder_run STREQUAL "first")
        set(elder_reference_archive "${elder_archive}")
        set(elder_reference_checksum "${elder_checksum}")
    else()
        execute_process(
            COMMAND "${CMAKE_COMMAND}" -E compare_files
                "${elder_reference_archive}" "${elder_archive}"
            RESULT_VARIABLE elder_archive_compare)
        if(NOT elder_archive_compare EQUAL 0)
            message(FATAL_ERROR
                "Two independent public package builds produced different ZIP bytes")
        endif()
        execute_process(
            COMMAND "${CMAKE_COMMAND}" -E compare_files
                "${elder_reference_checksum}" "${elder_checksum}"
            RESULT_VARIABLE elder_checksum_compare)
        if(NOT elder_checksum_compare EQUAL 0)
            message(FATAL_ERROR
                "Two independent public package builds produced different checksum bytes")
        endif()
    endif()
endforeach()

file(SHA256 "${elder_reference_archive}" elder_archive_sha256)
file(SIZE "${elder_reference_archive}" elder_archive_size)
message(STATUS
    "Verified runtime-complete Elder public package twice: "
    "${elder_archive_size} bytes, SHA-256 ${elder_archive_sha256}")
