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
set(elder_quality_include "${elder_source_dir}/shaders/elder/ElderQuality.fxh")
set(elder_tier_include "${elder_source_dir}/shaders/elder/ElderTier.fxh")
foreach(elder_required_source IN ITEMS
    "${elder_generator}"
    "${elder_quality_include}"
    "${elder_tier_include}")
    if(NOT EXISTS "${elder_required_source}")
        message(FATAL_ERROR "Quality-preset contract is missing source: ${elder_required_source}")
    endif()
endforeach()

file(READ "${elder_tier_include}" elder_tier_hlsl)
foreach(elder_required_tier_token IN ITEMS
    "#ifndef ELDER_TIER_FXH"
    "#ifndef ELDER_QUALITY_TIER"
    "#define ELDER_QUALITY_TIER 1"
    "#endif")
    string(FIND "${elder_tier_hlsl}" "${elder_required_tier_token}" elder_required_tier_position)
    if(elder_required_tier_position EQUAL -1)
        message(FATAL_ERROR "Base ElderTier.fxh lacks its guarded default tier contract")
    endif()
endforeach()

file(READ "${elder_quality_include}" elder_quality_hlsl)
foreach(elder_required_hlsl IN ITEMS
    "#include \"elder/ElderTier.fxh\""
    "#if ELDER_QUALITY_TIER < 0 || ELDER_QUALITY_TIER > 4"
    "#error ELDER_QUALITY_TIER must be in [0,4]"
    "static const uint ElderQualityTier = ELDER_QUALITY_TIER;"
    "static const uint ElderAODirections = ELDER_AO_DIRECTIONS_VALUE;"
    "static const uint ElderAOSteps = ELDER_AO_STEPS_VALUE;"
    "static const uint ElderSSRSteps = ELDER_SSR_STEPS_VALUE;"
    "static const uint ElderDOFRings = ELDER_DOF_RINGS_VALUE;"
    "static const uint ElderBloomRadius = ELDER_BLOOM_RADIUS_VALUE;"
    "static const uint ElderLensGhosts = ELDER_LENS_GHOSTS_VALUE;"
    "static const uint ElderRoomLightRefinement = ELDER_ROOM_LIGHT_REFINEMENT_VALUE;")
    string(FIND "${elder_quality_hlsl}" "${elder_required_hlsl}" elder_required_hlsl_index)
    if(elder_required_hlsl_index EQUAL -1)
        message(FATAL_ERROR "Quality include lacks the tier-override or budget-static contract")
    endif()
endforeach()
string(FIND "${elder_quality_hlsl}" "#define ELDER_QUALITY_TIER 1" elder_inline_default_position)
if(NOT elder_inline_default_position EQUAL -1)
    message(FATAL_ERROR "ElderQuality.fxh must not inline the default tier macro")
endif()

set(elder_hlsl_branch_prefixes
    "#if ELDER_QUALITY_TIER == 0"
    "#elif ELDER_QUALITY_TIER == 1"
    "#elif ELDER_QUALITY_TIER == 2"
    "#elif ELDER_QUALITY_TIER == 3"
    "#else")
set(elder_hlsl_budget_macro_names
    ELDER_AO_DIRECTIONS_VALUE
    ELDER_AO_STEPS_VALUE
    ELDER_SSR_STEPS_VALUE
    ELDER_DOF_RINGS_VALUE
    ELDER_BLOOM_RADIUS_VALUE
    ELDER_LENS_GHOSTS_VALUE
    ELDER_ROOM_LIGHT_REFINEMENT_VALUE)
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
    foreach(elder_budget_name IN LISTS elder_hlsl_budget_macro_names)
        list(GET elder_budget_values ${elder_budget_index} elder_budget_value)
        string(APPEND elder_expected_hlsl_branch
            "#define ${elder_budget_name} ${elder_budget_value}\n")
        math(EXPR elder_budget_index "${elder_budget_index} + 1")
    endforeach()
    string(FIND "${elder_quality_hlsl}" "${elder_expected_hlsl_branch}" elder_hlsl_branch_index)
    if(elder_hlsl_branch_index EQUAL -1)
        message(FATAL_ERROR "Quality include budget macros drift from canonical tier ${elder_index}")
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
set(elder_expected_labels Performance Balanced Quality Ultra Cinematic)
set(elder_expected_budget_values
    "4|2|0|0|2|0|0"
    "6|3|0|2|3|1|1"
    "8|4|8|3|4|2|1"
    "12|5|12|4|5|2|2"
    "16|6|16|5|6|3|2")
set(elder_expected_ini_files
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

set(elder_dof_ui_keys
    "[Elder 20] Depth of Field | Enabled"
    "[Elder 20] Depth of Field | Intensity"
    "[Elder 20] Depth of Field | Focus Depth"
    "[Elder 20] Depth of Field | Focus Range"
    "[Elder 20] Depth of Field | Foreground Strength"
    "[Elder 20] Depth of Field | Background Strength"
    "[Elder 20] Depth of Field | Max Blur")
set(elder_bloom_ui_keys
    "[Elder 30] Bloom | Enabled"
    "[Elder 30] Bloom | Intensity"
    "[Elder 30] Bloom | Highlight Threshold"
    "[Elder 30] Bloom | Soft Knee"
    "[Elder 30] Bloom | Radius Scale")
set(elder_adaptation_ui_keys
    "[Elder 40] Adaptation | Enabled"
    "[Elder 40] Adaptation | Intensity"
    "[Elder 40] Adaptation | Brighten Rate"
    "[Elder 40] Adaptation | Darken Rate"
    "[Elder 40] Adaptation | Min Luminance"
    "[Elder 40] Adaptation | Max Luminance")
set(elder_lens_ui_keys
    "[Elder 50] Lens | Enabled"
    "[Elder 50] Lens | Intensity"
    "[Elder 50] Lens | Ghost Strength"
    "[Elder 50] Lens | Halo Strength"
    "[Elder 50] Lens | Energy Cap")
set(elder_optical_ini_files
    enbdepthoffield.fx.ini
    enbbloom.fx.ini
    enbadaptation.fx.ini
    enblens.fx.ini)
set(elder_prepass_ui_keys
    "[Elder 10] Prepass | Enabled"
    "[Elder 10] Prepass | Intensity"
    "[Elder 10] Prepass | Depth Shape")
set(elder_main_ui_keys
    "[Elder 60] Main Effect | Enabled"
    "[Elder 60] Main Effect | Color-Core Intensity"
    "[Elder 60] Main Effect | Optical Shape")
set(elder_postpass_ui_keys
    "[Elder 70] Postpass | Enabled"
    "[Elder 70] Postpass | Intensity"
    "[Elder 70] Postpass | Vignette Strength"
    "[Elder 70] Postpass | Grain Shape")
set(elder_sunsprite_ui_keys
    "[Elder 80] Sun Sprite | Enabled"
    "[Elder 80] Sun Sprite | Intensity"
    "[Elder 80] Sun Sprite | Disc Shape")
set(elder_underwater_ui_keys
    "[Elder 90] Underwater | Enabled"
    "[Elder 90] Underwater | Intensity"
    "[Elder 90] Underwater | Density Shape")
set(elder_non_optical_ini_files
    enbeffectprepass.fx.ini
    enbeffect.fx.ini
    enbeffectpostpass.fx.ini
    enbsunsprite.fx.ini
    enbunderwater.fx.ini)

function(elder_expected_optical_keys ini_file out_keys out_section)
    if(ini_file STREQUAL "enbdepthoffield.fx.ini")
        set(keys ${elder_dof_ui_keys})
        set(section "[ENBDEPTHOFFIELD.FX]")
    elseif(ini_file STREQUAL "enbbloom.fx.ini")
        set(keys ${elder_bloom_ui_keys})
        set(section "[ENBBLOOM.FX]")
    elseif(ini_file STREQUAL "enbadaptation.fx.ini")
        set(keys ${elder_adaptation_ui_keys})
        set(section "[ENBADAPTATION.FX]")
    elseif(ini_file STREQUAL "enblens.fx.ini")
        set(keys ${elder_lens_ui_keys})
        set(section "[ENBLENS.FX]")
    else()
        message(FATAL_ERROR "No optical-key contract exists for ${ini_file}")
    endif()
    set(${out_keys} ${keys} PARENT_SCOPE)
    set(${out_section} "${section}" PARENT_SCOPE)
endfunction()

function(elder_optical_numeric_range key out_min out_max)
    if(key STREQUAL "[Elder 20] Depth of Field | Intensity")
        set(minimum 0.0)
        set(maximum 0.45)
    elseif(key STREQUAL "[Elder 20] Depth of Field | Focus Depth")
        set(minimum 0.01)
        set(maximum 0.99)
    elseif(key STREQUAL "[Elder 20] Depth of Field | Focus Range")
        set(minimum 0.03)
        set(maximum 0.60)
    elseif(key STREQUAL "[Elder 20] Depth of Field | Foreground Strength")
        set(minimum 0.0)
        set(maximum 0.60)
    elseif(key STREQUAL "[Elder 20] Depth of Field | Background Strength")
        set(minimum 0.0)
        set(maximum 0.80)
    elseif(key STREQUAL "[Elder 20] Depth of Field | Max Blur")
        set(minimum 0.0)
        set(maximum 1.00)
    elseif(key STREQUAL "[Elder 30] Bloom | Intensity")
        set(minimum 0.0)
        set(maximum 0.45)
    elseif(key STREQUAL "[Elder 30] Bloom | Highlight Threshold")
        set(minimum 0.70)
        set(maximum 4.00)
    elseif(key STREQUAL "[Elder 30] Bloom | Soft Knee")
        set(minimum 0.01)
        set(maximum 1.00)
    elseif(key STREQUAL "[Elder 30] Bloom | Radius Scale")
        set(minimum 0.25)
        set(maximum 1.50)
    elseif(key STREQUAL "[Elder 40] Adaptation | Intensity")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 40] Adaptation | Brighten Rate")
        set(minimum 0.05)
        set(maximum 4.00)
    elseif(key STREQUAL "[Elder 40] Adaptation | Darken Rate")
        set(minimum 0.05)
        set(maximum 4.00)
    elseif(key STREQUAL "[Elder 40] Adaptation | Min Luminance")
        set(minimum 0.001)
        set(maximum 1.00)
    elseif(key STREQUAL "[Elder 40] Adaptation | Max Luminance")
        set(minimum 1.00)
        set(maximum 32.00)
    elseif(key STREQUAL "[Elder 50] Lens | Intensity")
        set(minimum 0.0)
        set(maximum 0.30)
    elseif(key STREQUAL "[Elder 50] Lens | Ghost Strength")
        set(minimum 0.0)
        set(maximum 0.35)
    elseif(key STREQUAL "[Elder 50] Lens | Halo Strength")
        set(minimum 0.0)
        set(maximum 0.30)
    elseif(key STREQUAL "[Elder 50] Lens | Energy Cap")
        set(minimum 0.0)
        set(maximum 0.50)
    else()
        message(FATAL_ERROR "No numeric range exists for optical key ${key}")
    endif()
    set(${out_min} "${minimum}" PARENT_SCOPE)
    set(${out_max} "${maximum}" PARENT_SCOPE)
endfunction()

function(elder_validate_optical_ini root tier ini_file)
    elder_expected_optical_keys("${ini_file}" expected_keys expected_section)
    set(candidate "${root}/${tier}/${ini_file}")
    file(READ "${candidate}" content)
    string(FIND "${content}" "${expected_section}" section_position)
    if(section_position EQUAL -1)
        message(FATAL_ERROR "Optical preset must use uppercase stage section ${expected_section}: ${tier}/${ini_file}")
    endif()
    file(STRINGS "${candidate}" lines)
    set(seen_keys "")
    foreach(line IN LISTS lines)
        if(line STREQUAL "" OR line MATCHES "^;" OR line MATCHES "^\\[[A-Z0-9.]+\\]$")
            continue()
        endif()
        if(NOT line MATCHES "^(.+)=([^;]+)$")
            message(FATAL_ERROR "Malformed optical preset line in ${tier}/${ini_file}: ${line}")
        endif()
        set(key "${CMAKE_MATCH_1}")
        set(value "${CMAKE_MATCH_2}")
        if(key MATCHES "^(Enable|Intensity|IntensityMin|IntensityMax|Shape|ShapeMin|ShapeMax)$")
            message(FATAL_ERROR "Optical preset uses generic placeholder key ${key}: ${tier}/${ini_file}")
        endif()
        list(FIND expected_keys "${key}" allowed_key_position)
        if(allowed_key_position EQUAL -1)
            message(FATAL_ERROR "Unknown optical preset key ${key}: ${tier}/${ini_file}")
        endif()
        list(FIND seen_keys "${key}" duplicate_position)
        if(NOT duplicate_position EQUAL -1)
            message(FATAL_ERROR "Duplicate optical preset key ${key}: ${tier}/${ini_file}")
        endif()
        list(APPEND seen_keys "${key}")
        if(key MATCHES "\\| Enabled$")
            if(NOT value MATCHES "^(true|false)$")
                message(FATAL_ERROR "Boolean optical preset key has non-boolean value ${value}: ${key}")
            endif()
        else()
            if(NOT value MATCHES "^-?[0-9]+(\\.[0-9]+)?$")
                message(FATAL_ERROR "Numeric optical preset key has non-numeric value ${value}: ${key}")
            endif()
            elder_optical_numeric_range("${key}" minimum maximum)
            if(value LESS minimum OR value GREATER maximum)
                message(FATAL_ERROR "Optical preset key out of range ${key}=${value}; allowed ${minimum}..${maximum}")
            endif()
        endif()
    endforeach()
    foreach(required_key IN LISTS expected_keys)
        list(FIND seen_keys "${required_key}" required_key_position)
        if(required_key_position EQUAL -1)
            message(FATAL_ERROR "Missing optical preset key ${required_key}: ${tier}/${ini_file}")
        endif()
    endforeach()
endfunction()

function(elder_expected_non_optical_keys ini_file out_keys out_section)
    if(ini_file STREQUAL "enbeffectprepass.fx.ini")
        set(keys ${elder_prepass_ui_keys})
        set(section "[ENBEFFECTPREPASS.FX]")
    elseif(ini_file STREQUAL "enbeffect.fx.ini")
        set(keys ${elder_main_ui_keys})
        set(section "[ENBEFFECT.FX]")
    elseif(ini_file STREQUAL "enbeffectpostpass.fx.ini")
        set(keys ${elder_postpass_ui_keys})
        set(section "[ENBEFFECTPOSTPASS.FX]")
    elseif(ini_file STREQUAL "enbsunsprite.fx.ini")
        set(keys ${elder_sunsprite_ui_keys})
        set(section "[ENBSUNSPRITE.FX]")
    elseif(ini_file STREQUAL "enbunderwater.fx.ini")
        set(keys ${elder_underwater_ui_keys})
        set(section "[ENBUNDERWATER.FX]")
    else()
        message(FATAL_ERROR "No non-optical-key contract exists for ${ini_file}")
    endif()
    set(${out_keys} ${keys} PARENT_SCOPE)
    set(${out_section} "${section}" PARENT_SCOPE)
endfunction()

function(elder_non_optical_numeric_range key out_min out_max)
    if(key STREQUAL "[Elder 10] Prepass | Intensity")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 10] Prepass | Depth Shape")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 60] Main Effect | Color-Core Intensity")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 60] Main Effect | Optical Shape")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 70] Postpass | Intensity")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 70] Postpass | Vignette Strength")
        set(minimum 0.0)
        set(maximum 0.35)
    elseif(key STREQUAL "[Elder 70] Postpass | Grain Shape")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 80] Sun Sprite | Intensity")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 80] Sun Sprite | Disc Shape")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 90] Underwater | Intensity")
        set(minimum 0.0)
        set(maximum 1.0)
    elseif(key STREQUAL "[Elder 90] Underwater | Density Shape")
        set(minimum 0.0)
        set(maximum 1.0)
    else()
        message(FATAL_ERROR "No numeric range exists for non-optical key ${key}")
    endif()
    set(${out_min} "${minimum}" PARENT_SCOPE)
    set(${out_max} "${maximum}" PARENT_SCOPE)
endfunction()

function(elder_validate_non_optical_ini root tier ini_file)
    elder_expected_non_optical_keys("${ini_file}" expected_keys expected_section)
    set(candidate "${root}/${tier}/${ini_file}")
    file(READ "${candidate}" content)
    string(FIND "${content}" "${expected_section}" section_position)
    if(section_position EQUAL -1)
        message(FATAL_ERROR "Non-optical preset must use uppercase stage section ${expected_section}: ${tier}/${ini_file}")
    endif()
    file(STRINGS "${candidate}" lines)
    set(seen_keys "")
    foreach(line IN LISTS lines)
        if(line STREQUAL "" OR line MATCHES "^;" OR line MATCHES "^\\[[A-Z0-9.]+\\]$")
            continue()
        endif()
        if(NOT line MATCHES "^(.+)=([^;]+)$")
            message(FATAL_ERROR "Malformed non-optical preset line in ${tier}/${ini_file}: ${line}")
        endif()
        set(key "${CMAKE_MATCH_1}")
        set(value "${CMAKE_MATCH_2}")
        if(key MATCHES "^(Enable|Intensity|IntensityMin|IntensityMax|Shape|ShapeMin|ShapeMax)$")
            message(FATAL_ERROR "Non-optical preset uses generic placeholder key ${key}: ${tier}/${ini_file}")
        endif()
        list(FIND expected_keys "${key}" allowed_key_position)
        if(allowed_key_position EQUAL -1)
            message(FATAL_ERROR "Unknown non-optical preset key ${key}: ${tier}/${ini_file}")
        endif()
        list(FIND seen_keys "${key}" duplicate_position)
        if(NOT duplicate_position EQUAL -1)
            message(FATAL_ERROR "Duplicate non-optical preset key ${key}: ${tier}/${ini_file}")
        endif()
        list(APPEND seen_keys "${key}")
        if(key MATCHES "\\| Enabled$")
            if(NOT value MATCHES "^(true|false)$")
                message(FATAL_ERROR "Boolean non-optical preset key has non-boolean value ${value}: ${key}")
            endif()
        else()
            if(NOT value MATCHES "^-?[0-9]+(\\.[0-9]+)?$")
                message(FATAL_ERROR "Numeric non-optical preset key has non-numeric value ${value}: ${key}")
            endif()
            elder_non_optical_numeric_range("${key}" minimum maximum)
            if(value LESS minimum OR value GREATER maximum)
                message(FATAL_ERROR "Non-optical preset key out of range ${key}=${value}; allowed ${minimum}..${maximum}")
            endif()
        endif()
    endforeach()
    foreach(required_key IN LISTS expected_keys)
        list(FIND seen_keys "${required_key}" required_key_position)
        if(required_key_position EQUAL -1)
            message(FATAL_ERROR "Missing non-optical preset key ${required_key}: ${tier}/${ini_file}")
        endif()
    endforeach()
endfunction()

function(elder_validate_tier_include root tier tier_value)
    set(generated_tier_include "${root}/${tier}/enbseries/elder/ElderTier.fxh")
    if(NOT EXISTS "${generated_tier_include}")
        message(FATAL_ERROR "Missing generated tier override: ${tier}/enbseries/elder/ElderTier.fxh")
    endif()
    file(READ "${generated_tier_include}" generated_tier_source)
    string(FIND "${generated_tier_source}" ";" ini_comment_position)
    if(NOT ini_comment_position EQUAL -1)
        message(FATAL_ERROR "Generated ElderTier.fxh must use HLSL comments, not INI comments: ${tier}")
    endif()
    file(STRINGS "${generated_tier_include}" generated_tier_lines)
    set(define_count 0)
    foreach(generated_tier_line IN LISTS generated_tier_lines)
        if(generated_tier_line MATCHES "^#define[ \t]+ELDER_QUALITY_TIER[ \t]+([0-4])$")
            math(EXPR define_count "${define_count} + 1")
            if(NOT CMAKE_MATCH_1 STREQUAL "${tier_value}")
                message(FATAL_ERROR "Generated tier override for ${tier} defines ${CMAKE_MATCH_1}, expected ${tier_value}")
            endif()
        elseif(generated_tier_line MATCHES "^#define[ \t]+")
            message(FATAL_ERROR "Generated tier override for ${tier} contains an extra define: ${generated_tier_line}")
        endif()
    endforeach()
    if(NOT define_count EQUAL 1)
        message(FATAL_ERROR "Generated tier override for ${tier} must contain exactly one ELDER_QUALITY_TIER define")
    endif()
endfunction()

foreach(elder_root IN ITEMS "${elder_first_root}" "${elder_second_root}")
    file(GLOB elder_children RELATIVE "${elder_root}" "${elder_root}/*")
    list(SORT elder_children)
    list(LENGTH elder_children elder_directory_count)
    if(NOT elder_directory_count EQUAL 5)
        message(FATAL_ERROR "Expected exactly five quality-tier directories")
    endif()
    file(GLOB_RECURSE elder_all_files LIST_DIRECTORIES false RELATIVE "${elder_root}" "${elder_root}/*")
    list(SORT elder_all_files)
    list(LENGTH elder_all_files elder_all_file_count)
    if(NOT elder_all_file_count EQUAL 55)
        message(FATAL_ERROR "Expected exactly fifty-five generated preset files")
    endif()
    file(GLOB_RECURSE elder_ini_files LIST_DIRECTORIES false RELATIVE "${elder_root}" "${elder_root}/*.ini")
    list(SORT elder_ini_files)
    list(LENGTH elder_ini_files elder_ini_count)
    if(NOT elder_ini_count EQUAL 50)
        message(FATAL_ERROR "Expected exactly fifty generated INI files")
    endif()

    foreach(elder_index RANGE 0 4)
        list(GET elder_expected_tiers ${elder_index} elder_tier)
        list(GET elder_expected_labels ${elder_index} elder_label)
        list(GET elder_expected_budget_values ${elder_index} elder_budget_values)
        if(NOT IS_DIRECTORY "${elder_root}/${elder_tier}")
            message(FATAL_ERROR "Missing quality-tier directory: ${elder_tier}")
        endif()
        elder_validate_tier_include("${elder_root}" "${elder_tier}" "${elder_index}")

        foreach(elder_file IN LISTS elder_expected_ini_files)
            set(elder_candidate "${elder_root}/${elder_tier}/${elder_file}")
            if(NOT EXISTS "${elder_candidate}")
                message(FATAL_ERROR "Missing generated preset: ${elder_tier}/${elder_file}")
            endif()
            file(READ "${elder_candidate}" elder_content)
            string(REGEX MATCH "^; Elder ENB quality preset" elder_product_marker "${elder_content}")
            string(REGEX MATCH "; Tier: ${elder_label} \\(${elder_index}\\)" elder_tier_marker "${elder_content}")
            if(elder_product_marker STREQUAL "" OR elder_tier_marker STREQUAL "")
                message(FATAL_ERROR "Preset lacks Elder/tier provenance: ${elder_tier}/${elder_file}")
            endif()
            if(NOT elder_file STREQUAL "elder-quality.ini")
                string(REGEX REPLACE "\\.ini$" "" elder_stage_name "${elder_file}")
                string(TOUPPER "${elder_stage_name}" elder_expected_section)
                string(FIND "${elder_content}" "[${elder_expected_section}]" elder_stage_section_position)
                if(elder_stage_section_position EQUAL -1)
                    message(FATAL_ERROR "Stage preset lacks uppercase ENB stage section: ${elder_tier}/${elder_file}")
                endif()
            endif()
        endforeach()

        set(elder_quality_file "${elder_root}/${elder_tier}/elder-quality.ini")
        file(READ "${elder_quality_file}" elder_quality_content)
        if(elder_quality_content MATCHES "ELDER_QUALITY_TIER[ \t]*=")
            message(FATAL_ERROR "INI metadata must not pretend to select ELDER_QUALITY_TIER: ${elder_tier}/elder-quality.ini")
        endif()
        string(REPLACE "|" ";" elder_budget_values "${elder_budget_values}")
        list(GET elder_budget_values 0 elder_ao_directions)
        list(GET elder_budget_values 1 elder_ao_steps)
        list(GET elder_budget_values 2 elder_ssr_steps)
        list(GET elder_budget_values 3 elder_dof_rings)
        list(GET elder_budget_values 4 elder_bloom_radius)
        list(GET elder_budget_values 5 elder_lens_ghosts)
        list(GET elder_budget_values 6 elder_room_light_refinement)
        foreach(expected_quality_line IN ITEMS
            "QualityTier=${elder_index}"
            "TierId=${elder_tier}"
            "TierLabel=${elder_label}"
            "AODirections=${elder_ao_directions}"
            "AOSteps=${elder_ao_steps}"
            "SSRSteps=${elder_ssr_steps}"
            "DOFRings=${elder_dof_rings}"
            "BloomRadius=${elder_bloom_radius}"
            "LensGhosts=${elder_lens_ghosts}"
            "RoomLightRefinement=${elder_room_light_refinement}")
            string(FIND "${elder_quality_content}" "${expected_quality_line}" expected_quality_position)
            if(expected_quality_position EQUAL -1)
                message(FATAL_ERROR "elder-quality.ini is missing expected line ${expected_quality_line} for ${elder_tier}")
            endif()
        endforeach()

        foreach(elder_optical_file IN LISTS elder_optical_ini_files)
            elder_validate_optical_ini("${elder_root}" "${elder_tier}" "${elder_optical_file}")
        endforeach()

        foreach(elder_non_optical_file IN LISTS elder_non_optical_ini_files)
            elder_validate_non_optical_ini(
                "${elder_root}" "${elder_tier}" "${elder_non_optical_file}")
        endforeach()
    endforeach()
endforeach()

file(GLOB_RECURSE elder_first_files LIST_DIRECTORIES false RELATIVE "${elder_first_root}" "${elder_first_root}/*")
file(GLOB_RECURSE elder_second_files LIST_DIRECTORIES false RELATIVE "${elder_second_root}" "${elder_second_root}/*")
list(SORT elder_first_files)
list(SORT elder_second_files)
if(NOT elder_first_files STREQUAL elder_second_files)
    message(FATAL_ERROR "Quality-preset generation is not path deterministic")
endif()
foreach(elder_file IN LISTS elder_first_files)
    file(SHA256 "${elder_first_root}/${elder_file}" elder_first_hash)
    file(SHA256 "${elder_second_root}/${elder_file}" elder_second_hash)
    if(NOT elder_first_hash STREQUAL elder_second_hash)
        message(FATAL_ERROR "Quality-preset generation is not byte deterministic: ${elder_file}")
    endif()
endforeach()

message(STATUS "Elder quality presets generated deterministic 55-file tier overlays with real stage UIName keys")
