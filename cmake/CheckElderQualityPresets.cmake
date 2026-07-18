cmake_minimum_required(VERSION 4.0)

if(NOT DEFINED ELDER_SOURCE_DIR OR ELDER_SOURCE_DIR STREQUAL "")
    message(FATAL_ERROR "ELDER_SOURCE_DIR is required")
endif()
if(NOT DEFINED ELDER_BINARY_DIR OR ELDER_BINARY_DIR STREQUAL "")
    message(FATAL_ERROR "ELDER_BINARY_DIR is required")
endif()

cmake_path(ABSOLUTE_PATH ELDER_SOURCE_DIR NORMALIZE OUTPUT_VARIABLE elder_source_dir)
cmake_path(ABSOLUTE_PATH ELDER_BINARY_DIR NORMALIZE OUTPUT_VARIABLE elder_binary_dir)

set(elder_generator "${elder_source_dir}/cmake/GenerateElderQualityPresets.cmake")
if(NOT EXISTS "${elder_generator}")
    message(FATAL_ERROR "Quality-preset generator is missing: ${elder_generator}")
endif()
set(elder_quality_include "${elder_source_dir}/shaders/elder/ElderQuality.fxh")
if(NOT EXISTS "${elder_quality_include}")
    message(FATAL_ERROR "Quality include is missing: ${elder_quality_include}")
endif()
file(READ "${elder_quality_include}" elder_quality_hlsl)
foreach(elder_required_hlsl IN ITEMS
    "#ifndef ELDER_QUALITY_TIER"
    "#define ELDER_QUALITY_TIER 1"
    "#if ELDER_QUALITY_TIER < 0 || ELDER_QUALITY_TIER > 4"
    "#error ELDER_QUALITY_TIER must be in [0,4]"
    "static const uint ElderQualityTier = ELDER_QUALITY_TIER;")
    string(FIND "${elder_quality_hlsl}" "${elder_required_hlsl}" elder_required_hlsl_index)
    if(elder_required_hlsl_index EQUAL -1)
        message(FATAL_ERROR "Quality include lacks its required default or invalid-tier contract")
    endif()
endforeach()

set(elder_hlsl_branch_prefixes
    "#if ELDER_QUALITY_TIER == 0"
    "#elif ELDER_QUALITY_TIER == 1"
    "#elif ELDER_QUALITY_TIER == 2"
    "#elif ELDER_QUALITY_TIER == 3"
    "#else")
set(elder_hlsl_budget_names
    ElderAODirections
    ElderAOSteps
    ElderSSRSteps
    ElderDOFRings
    ElderBloomRadius
    ElderLensGhosts
    ElderRoomLightRefinement)
set(elder_hlsl_budget_values
    "4|2|0|0|2|0|0"
    "6|3|0|2|3|1|1"
    "8|4|8|3|4|2|1"
    "12|5|12|4|5|2|2"
    "16|6|16|5|6|3|2")
foreach(elder_index RANGE 0 4)
    list(GET elder_hlsl_branch_prefixes ${elder_index} elder_branch_prefix)
    list(GET elder_hlsl_budget_values ${elder_index} elder_budget_values)
    string(REPLACE "|" ";" elder_budget_values "${elder_budget_values}")
    string(CONCAT elder_expected_hlsl_branch "${elder_branch_prefix}\n")
    set(elder_budget_index 0)
    foreach(elder_budget_name IN LISTS elder_hlsl_budget_names)
        list(GET elder_budget_values ${elder_budget_index} elder_budget_value)
        string(APPEND elder_expected_hlsl_branch
            "static const uint ${elder_budget_name} = ${elder_budget_value};\n")
        math(EXPR elder_budget_index "${elder_budget_index} + 1")
    endforeach()
    string(FIND "${elder_quality_hlsl}" "${elder_expected_hlsl_branch}" elder_hlsl_branch_index)
    if(elder_hlsl_branch_index EQUAL -1)
        message(FATAL_ERROR "Quality include budgets drift from the canonical tier ${elder_index}")
    endif()
endforeach()

set(elder_first_root "${elder_binary_dir}/quality-presets-first")
set(elder_second_root "${elder_binary_dir}/quality-presets-second")
foreach(elder_root IN ITEMS "${elder_first_root}" "${elder_second_root}")
    cmake_path(IS_PREFIX elder_binary_dir "${elder_root}" NORMALIZE elder_root_is_contained)
    if(NOT elder_root_is_contained)
        message(FATAL_ERROR "Quality-preset output escapes ELDER_BINARY_DIR")
    endif()
    execute_process(
        COMMAND "${CMAKE_COMMAND}"
            "-DELDER_SOURCE_DIR=${elder_source_dir}"
            "-DELDER_OUTPUT_DIR=${elder_root}"
            -P "${elder_generator}"
        RESULT_VARIABLE elder_generate_result
    )
    if(NOT elder_generate_result EQUAL 0)
        message(FATAL_ERROR "Quality-preset generation failed")
    endif()
endforeach()

set(elder_expected_tiers performance balanced quality ultra cinematic)
set(elder_expected_files
    elder-quality.ini
    enbeffectprepass.fx.ini
    enbdepthoffield.fx.ini
    enbbloom.fx.ini
    enbadaptation.fx.ini
    enblens.fx.ini
    enbeffect.fx.ini
    enbeffectpostpass.fx.ini
    enbsunsprite.fx.ini
    enbunderwater.fx.ini)
foreach(elder_root IN ITEMS "${elder_first_root}" "${elder_second_root}")
    file(GLOB elder_children RELATIVE "${elder_root}" "${elder_root}/*")
    list(SORT elder_children)
    list(LENGTH elder_children elder_directory_count)
    if(NOT elder_directory_count EQUAL 5)
        message(FATAL_ERROR "Expected exactly five quality-tier directories")
    endif()
    foreach(elder_tier IN LISTS elder_expected_tiers)
        if(NOT IS_DIRECTORY "${elder_root}/${elder_tier}")
            message(FATAL_ERROR "Missing quality-tier directory: ${elder_tier}")
        endif()
    endforeach()
    file(GLOB_RECURSE elder_ini_files RELATIVE "${elder_root}" "${elder_root}/*.ini")
    list(SORT elder_ini_files)
    list(LENGTH elder_ini_files elder_ini_count)
    if(NOT elder_ini_count EQUAL 50)
        message(FATAL_ERROR "Expected exactly fifty generated INI files")
    endif()
    foreach(elder_tier IN LISTS elder_expected_tiers)
        foreach(elder_file IN LISTS elder_expected_files)
            set(elder_candidate "${elder_root}/${elder_tier}/${elder_file}")
            if(NOT EXISTS "${elder_candidate}")
                message(FATAL_ERROR "Missing generated preset: ${elder_tier}/${elder_file}")
            endif()
            file(READ "${elder_candidate}" elder_content)
            string(REGEX MATCH "^; Elder ENB quality preset" elder_product_marker "${elder_content}")
            string(REGEX MATCH "; Tier: [^\r\n]+" elder_tier_marker "${elder_content}")
            if(elder_product_marker STREQUAL "" OR elder_tier_marker STREQUAL "")
                message(FATAL_ERROR "Preset lacks Elder/tier provenance: ${elder_tier}/${elder_file}")
            endif()
            if(NOT elder_file STREQUAL "elder-quality.ini"
               AND (NOT elder_content MATCHES "Enable=true"
                    OR NOT elder_content MATCHES "Intensity=1\\.000"
                    OR NOT elder_content MATCHES "IntensityMin=0\\.000"
                    OR NOT elder_content MATCHES "IntensityMax=2\\.000"
                    OR NOT elder_content MATCHES "Shape=1\\.000"
                    OR NOT elder_content MATCHES "ShapeMin=0\\.000"
                    OR NOT elder_content MATCHES "ShapeMax=2\\.000"))
                message(FATAL_ERROR "Stage preset is missing bounded master/intensity/shape controls: ${elder_tier}/${elder_file}")
            endif()
        endforeach()
    endforeach()
endforeach()

file(GLOB_RECURSE elder_first_files RELATIVE "${elder_first_root}" "${elder_first_root}/*")
file(GLOB_RECURSE elder_second_files RELATIVE "${elder_second_root}" "${elder_second_root}/*")
list(SORT elder_first_files)
list(SORT elder_second_files)
if(NOT elder_first_files STREQUAL elder_second_files)
    message(FATAL_ERROR "Quality-preset generation is not path deterministic")
endif()
foreach(elder_file IN LISTS elder_first_files)
    if(IS_DIRECTORY "${elder_first_root}/${elder_file}")
        continue()
    endif()
    file(SHA256 "${elder_first_root}/${elder_file}" elder_first_hash)
    file(SHA256 "${elder_second_root}/${elder_file}" elder_second_hash)
    if(NOT elder_first_hash STREQUAL elder_second_hash)
        message(FATAL_ERROR "Quality-preset generation is not byte deterministic: ${elder_file}")
    endif()
endforeach()
