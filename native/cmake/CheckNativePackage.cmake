foreach(required
    ELDER_BUILD_ROOT
    ELDER_CONFIGURATION
    ELDER_WORK_ROOT
    ELDER_GENERATED_ROOT
    ELDER_COMPILED_ROOT
    ELDER_SOURCE_ROOT
    ELDER_CPACK)
  if(NOT DEFINED ${required} OR "${${required}}" STREQUAL "")
    message(FATAL_ERROR "${required} is required")
  endif()
endforeach()

set(expected_files
  "Elder ENB/Native/Documentation/NOTICE.md"
  "Elder ENB/Native/Documentation/README.md"
  "Elder ENB/Native/Include/elder/shaders/generated/ElderNativeParameterDefaults.hpp"
  "Elder ENB/Native/Manifest/elder-native-parameters.json"
  "Elder ENB/Native/Profiles/elder-native-default.profile"
  "Elder ENB/Native/Shaders/ElderColorReference.asm"
  "Elder ENB/Native/Shaders/ElderColorReference.cso"
  "Elder ENB/Native/Shaders/ElderNativeParameters.fxh"
)
list(SORT expected_files)

function(elder_expected_source relative output)
  if(relative STREQUAL "Elder ENB/Native/Documentation/NOTICE.md")
    set(source "${ELDER_SOURCE_ROOT}/NOTICE.md")
  elseif(relative STREQUAL "Elder ENB/Native/Documentation/README.md")
    set(source "${ELDER_SOURCE_ROOT}/README.md")
  elseif(relative STREQUAL "Elder ENB/Native/Include/elder/shaders/generated/ElderNativeParameterDefaults.hpp")
    set(source "${ELDER_GENERATED_ROOT}/include/elder/shaders/generated/ElderNativeParameterDefaults.hpp")
  elseif(relative STREQUAL "Elder ENB/Native/Manifest/elder-native-parameters.json")
    set(source "${ELDER_GENERATED_ROOT}/manifest/elder-native-parameters.json")
  elseif(relative STREQUAL "Elder ENB/Native/Profiles/elder-native-default.profile")
    set(source "${ELDER_GENERATED_ROOT}/profiles/elder-native-default.profile")
  elseif(relative STREQUAL "Elder ENB/Native/Shaders/ElderColorReference.asm")
    set(source "${ELDER_COMPILED_ROOT}/ElderColorReference.asm")
  elseif(relative STREQUAL "Elder ENB/Native/Shaders/ElderColorReference.cso")
    set(source "${ELDER_COMPILED_ROOT}/ElderColorReference.cso")
  elseif(relative STREQUAL "Elder ENB/Native/Shaders/ElderNativeParameters.fxh")
    set(source "${ELDER_GENERATED_ROOT}/shaders/ElderNativeParameters.fxh")
  else()
    message(FATAL_ERROR "package test has no source mapping for ${relative}")
  endif()
  set(${output} "${source}" PARENT_SCOPE)
endfunction()

function(elder_validate_tree root manifest_output)
  file(GLOB_RECURSE actual_files
    RELATIVE "${root}"
    LIST_DIRECTORIES false
    "${root}/*")
  list(SORT actual_files)
  if(NOT actual_files STREQUAL expected_files)
    string(JOIN "\n  " expected_text ${expected_files})
    string(JOIN "\n  " actual_text ${actual_files})
    message(FATAL_ERROR
      "native package manifest mismatch\nExpected:\n  ${expected_text}"
      "\nActual:\n  ${actual_text}")
  endif()

  set(manifest "")
  foreach(relative IN LISTS actual_files)
    set(installed "${root}/${relative}")
    elder_expected_source("${relative}" source)
    if(NOT EXISTS "${source}")
      message(FATAL_ERROR "package source artifact is missing: ${relative}")
    endif()
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E compare_files "${source}" "${installed}"
      RESULT_VARIABLE different)
    if(NOT different EQUAL 0)
      message(FATAL_ERROR "installed artifact changed bytes: ${relative}")
    endif()
    file(SIZE "${installed}" size)
    if(size EQUAL 0)
      message(FATAL_ERROR "installed artifact is empty: ${relative}")
    endif()
    file(SHA256 "${installed}" sha256)
    string(APPEND manifest "${relative},${size},${sha256}\n")
  endforeach()
  file(WRITE "${manifest_output}" "${manifest}")
endfunction()

file(REMOVE_RECURSE "${ELDER_WORK_ROOT}")
file(MAKE_DIRECTORY "${ELDER_WORK_ROOT}")
foreach(run IN ITEMS first second)
  set(install_root "${ELDER_WORK_ROOT}/install-${run}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" --install "${ELDER_BUILD_ROOT}"
      --config "${ELDER_CONFIGURATION}"
      --component NativeRelease
      --prefix "${install_root}"
    RESULT_VARIABLE install_result
    OUTPUT_VARIABLE install_output
    ERROR_VARIABLE install_error)
  if(NOT install_result EQUAL 0)
    message(FATAL_ERROR
      "native release install failed (${install_result})\n"
      "${install_output}\n${install_error}")
  endif()
  elder_validate_tree(
    "${install_root}" "${ELDER_WORK_ROOT}/manifest-${run}.csv")
endforeach()

execute_process(
  COMMAND "${CMAKE_COMMAND}" -E compare_files
    "${ELDER_WORK_ROOT}/manifest-first.csv"
    "${ELDER_WORK_ROOT}/manifest-second.csv"
  RESULT_VARIABLE manifest_changed)
if(NOT manifest_changed EQUAL 0)
  message(FATAL_ERROR "repeated installs produced different content hashes")
endif()

foreach(run IN ITEMS first second)
  set(package_root "${ELDER_WORK_ROOT}/archive-${run}")
  file(MAKE_DIRECTORY "${package_root}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env SOURCE_DATE_EPOCH=946684800
      "${ELDER_CPACK}"
      --config "${ELDER_BUILD_ROOT}/CPackConfig.cmake"
      -C "${ELDER_CONFIGURATION}"
      -G ZIP
      -B "${package_root}"
    WORKING_DIRECTORY "${ELDER_BUILD_ROOT}"
    RESULT_VARIABLE package_result
    OUTPUT_VARIABLE package_output
    ERROR_VARIABLE package_error)
  if(NOT package_result EQUAL 0)
    message(FATAL_ERROR
      "native ZIP package failed (${package_result})\n"
      "${package_output}\n${package_error}")
  endif()

  file(GLOB package_archives
    "${package_root}/Elder-ENB-Native-RC-win64.zip")
  list(LENGTH package_archives package_count)
  if(NOT package_count EQUAL 1)
    message(FATAL_ERROR
      "expected exactly one deterministic native ZIP package")
  endif()
  list(GET package_archives 0 package_archive)
  file(SIZE "${package_archive}" package_size)
  if(package_size LESS 1024)
    message(FATAL_ERROR "native ZIP package is implausibly small")
  endif()
  file(SHA256 "${package_archive}" package_sha256)
  set(checksum_file "${package_archive}.sha256")
  if(NOT EXISTS "${checksum_file}")
    message(FATAL_ERROR "CPack did not emit the native ZIP SHA-256 file")
  endif()
  file(READ "${checksum_file}" checksum_text)
  string(STRIP "${checksum_text}" checksum_text)
  set(expected_checksum
    "${package_sha256}  Elder-ENB-Native-RC-win64.zip")
  if(NOT checksum_text STREQUAL expected_checksum)
    message(FATAL_ERROR "native ZIP SHA-256 sidecar does not match its archive")
  endif()

  if(run STREQUAL "first")
    set(reference_package_sha256 "${package_sha256}")
    set(extracted "${ELDER_WORK_ROOT}/extracted")
    file(MAKE_DIRECTORY "${extracted}")
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E tar xf "${package_archive}"
      WORKING_DIRECTORY "${extracted}"
      RESULT_VARIABLE extract_result
      ERROR_VARIABLE extract_error)
    if(NOT extract_result EQUAL 0)
      message(FATAL_ERROR
        "could not extract native ZIP package: ${extract_error}")
    endif()
    elder_validate_tree(
      "${extracted}" "${ELDER_WORK_ROOT}/manifest-archive.csv")
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E compare_files
        "${ELDER_WORK_ROOT}/manifest-first.csv"
        "${ELDER_WORK_ROOT}/manifest-archive.csv"
      RESULT_VARIABLE archive_changed)
    if(NOT archive_changed EQUAL 0)
      message(FATAL_ERROR
        "ZIP package content differs from the install boundary")
    endif()
  elseif(NOT package_sha256 STREQUAL reference_package_sha256)
    message(FATAL_ERROR
      "repeated native ZIP packages produced different SHA-256 hashes")
  endif()
endforeach()

file(COPY_FILE
  "${ELDER_WORK_ROOT}/manifest-first.csv"
  "${ELDER_WORK_ROOT}/package-content-manifest.csv"
  ONLY_IF_DIFFERENT)
message(STATUS
  "Verified native release package: 2 byte-identical archives, "
  "${package_size} bytes, SHA-256 ${reference_package_sha256}, "
  "8 exact content hashes")
