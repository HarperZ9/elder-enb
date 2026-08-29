cmake_minimum_required(VERSION 4.0)

if(NOT DEFINED ELDER_SOURCE_DIR OR ELDER_SOURCE_DIR STREQUAL "")
    message(FATAL_ERROR "ELDER_SOURCE_DIR is required")
endif()
if(NOT DEFINED ELDER_BINARY_DIR OR ELDER_BINARY_DIR STREQUAL "")
    message(FATAL_ERROR "ELDER_BINARY_DIR is required")
endif()

cmake_path(ABSOLUTE_PATH ELDER_SOURCE_DIR NORMALIZE OUTPUT_VARIABLE elder_source_dir)
cmake_path(ABSOLUTE_PATH ELDER_BINARY_DIR NORMALIZE OUTPUT_VARIABLE elder_binary_dir)

set(elder_optical_modules
    shaders/elder/ElderTier.fxh
    shaders/elder/ElderDepthOfField.fxh
    shaders/elder/ElderBloom.fxh
    shaders/elder/ElderAdaptation.fxh
    shaders/elder/ElderLens.fxh)
set(elder_optical_stages
    shaders/enbdepthoffield.fx
    shaders/enbbloom.fx
    shaders/enbadaptation.fx
    shaders/enblens.fx)

foreach(elder_required_file IN LISTS elder_optical_modules elder_optical_stages)
    if(NOT EXISTS "${elder_source_dir}/${elder_required_file}")
        message(FATAL_ERROR "Task 4 optical contract requires ${elder_required_file}")
    endif()
endforeach()

set(elder_quality_include "${elder_source_dir}/shaders/elder/ElderQuality.fxh")
if(NOT EXISTS "${elder_quality_include}")
    message(FATAL_ERROR "Task 4 optical contract requires ElderQuality.fxh")
endif()
file(READ "${elder_source_dir}/shaders/elder/ElderTier.fxh" elder_tier_include_source)
file(READ "${elder_quality_include}" elder_quality_include_source)
foreach(elder_tier_token IN ITEMS
    "#ifndef ELDER_TIER_FXH"
    "#ifndef ELDER_QUALITY_TIER"
    "#define ELDER_QUALITY_TIER 1"
    "#endif")
    string(FIND "${elder_tier_include_source}" "${elder_tier_token}" elder_tier_token_position)
    if(elder_tier_token_position EQUAL -1)
        message(FATAL_ERROR "Base ElderTier.fxh is missing public default-tier token ${elder_tier_token}")
    endif()
endforeach()
string(FIND "${elder_quality_include_source}" "#include \"elder/ElderTier.fxh\"" elder_quality_tier_include_position)
if(elder_quality_tier_include_position EQUAL -1)
    message(FATAL_ERROR "ElderQuality.fxh must include the overridable public elder/ElderTier.fxh tier contract")
endif()
string(FIND "${elder_quality_include_source}" "#define ELDER_QUALITY_TIER 1" elder_quality_inline_default_position)
if(NOT elder_quality_inline_default_position EQUAL -1)
    message(FATAL_ERROR "ElderQuality.fxh must not inline the default tier macro; ElderTier.fxh owns it")
endif()

set(elder_stage_parameters "${elder_source_dir}/shaders/elder/ElderStageParameters.fxh")
if(NOT EXISTS "${elder_stage_parameters}")
    message(FATAL_ERROR "Task 4 optical contract requires ElderStageParameters.fxh")
endif()
file(READ "${elder_stage_parameters}" elder_stage_parameter_source)

set(elder_forbidden_placeholder_parameters
    ElderDepthOfFieldFocusShape
    ElderBloomThresholdShape
    ElderAdaptationResponseShape
    ElderLensApertureShape)
foreach(elder_placeholder IN LISTS elder_forbidden_placeholder_parameters)
    string(FIND "${elder_stage_parameter_source}" "${elder_placeholder}" elder_placeholder_position)
    if(NOT elder_placeholder_position EQUAL -1)
        message(FATAL_ERROR "Optical stage parameters still expose generic placeholder ${elder_placeholder}")
    endif()
endforeach()

set(elder_dof_keys
    ElderDepthOfFieldEnabled
    ElderDepthOfFieldAutofocus
    ElderDepthOfFieldIntensity
    ElderDepthOfFieldFocusDepth
    ElderDepthOfFieldFocusRange
    ElderDepthOfFieldForegroundStrength
    ElderDepthOfFieldBackgroundStrength
    ElderDepthOfFieldMaxBlur)
set(elder_bloom_keys
    ElderBloomEnabled
    ElderBloomIntensity
    ElderBloomThreshold
    ElderBloomSoftKnee
    ElderBloomRadiusScale)
set(elder_adaptation_keys
    ElderAdaptationEnabled
    ElderAdaptationIntensity
    ElderAdaptationBrightenRate
    ElderAdaptationDarkenRate
    ElderAdaptationMinLuminance
    ElderAdaptationMaxLuminance)
set(elder_lens_keys
    ElderLensEnabled
    ElderLensIntensity
    ElderLensGhostStrength
    ElderLensHaloStrength
    ElderLensEnergyCap)
set(elder_all_optical_keys
    ${elder_dof_keys}
    ${elder_bloom_keys}
    ${elder_adaptation_keys}
    ${elder_lens_keys})
foreach(elder_key IN LISTS elder_all_optical_keys)
    string(FIND "${elder_stage_parameter_source}" "${elder_key}" elder_key_position)
    if(elder_key_position EQUAL -1)
        message(FATAL_ERROR "Optical stage parameter is missing real ENB variable ${elder_key}")
    endif()
endforeach()

function(require_elder_optical_tokens source_file contract_name)
    file(READ "${source_file}" elder_optical_source)
    foreach(elder_required_token IN LISTS ARGN)
        string(FIND "${elder_optical_source}" "${elder_required_token}" elder_required_token_position)
        if(elder_required_token_position EQUAL -1)
            message(FATAL_ERROR
                "${contract_name} is missing required optical contract token: ${elder_required_token}")
        endif()
    endforeach()
    foreach(elder_forbidden_token IN ITEMS
        "random"
        "rand"
        "jitter"
        "motion vector"
        "MotionVector"
        "frame history"
        "TexturePrevious"
        "tex2D")
        if("${contract_name}" STREQUAL "Elder adaptation module"
           OR "${contract_name}" STREQUAL "Elder adaptation stage")
            if(elder_forbidden_token STREQUAL "TexturePrevious")
                continue()
            endif()
        endif()
        string(FIND "${elder_optical_source}" "${elder_forbidden_token}" elder_forbidden_token_position)
        if(NOT elder_forbidden_token_position EQUAL -1)
            message(FATAL_ERROR
                "${contract_name} contains forbidden optical token: ${elder_forbidden_token}")
        endif()
    endforeach()
endfunction()

function(forbid_elder_optical_tokens source_file contract_name)
    file(READ "${source_file}" elder_optical_source)
    foreach(elder_forbidden_token IN LISTS ARGN)
        if(elder_forbidden_token STREQUAL "")
            continue()
        endif()
        string(FIND "${elder_optical_source}" "${elder_forbidden_token}" elder_forbidden_token_position)
        if(NOT elder_forbidden_token_position EQUAL -1)
            message(FATAL_ERROR
                "${contract_name} contains forbidden Task 4 review token: ${elder_forbidden_token}")
        endif()
    endforeach()
endfunction()

require_elder_optical_tokens(
    "${elder_source_dir}/shaders/elder/ElderDepthOfField.fxh"
    "Elder depth-of-field module"
    "ElderApplyDepthOfField"
    "ElderDOFRings"
    "#if ELDER_DOF_RINGS_VALUE == 0"
    "ElderDepthOfFieldMaxBlur"
    "ElderFiniteOrBlack"
    "ElderStageOpticalIdentityWhenDisabled"
    "ElderActiveDofRings"
    "clamp(radius_rings, 1u, ElderDOFRings)"
    "for (uint ring_index = 0u; ring_index < active_rings; ++ring_index)")
require_elder_optical_tokens(
    "${elder_source_dir}/shaders/elder/ElderBloom.fxh"
    "Elder bloom module"
    "ElderApplyBloom"
    "ElderBloomRadius"
    "ElderBloomThreshold"
    "ElderBloomSoftKnee"
    "ElderExtractBloomHighlight"
    "ElderNeutralBloomScratch"
    "ElderBloomContribution"
    "ElderBloomOctaveWeight"
    "ElderBloomDownsampleOctave"
    "for (uint octave_index = 1u; octave_index <= 6u; ++octave_index)")
forbid_elder_optical_tokens(
    "${elder_source_dir}/shaders/elder/ElderBloom.fxh"
    "Elder bloom module"
    "return source"
    "source.rgb +"
    "ElderStageOpticalIdentityWhenDisabled")
require_elder_optical_tokens(
    "${elder_source_dir}/shaders/elder/ElderAdaptation.fxh"
    "Elder adaptation module"
    "ElderUpdateAdaptedLuminance"
    "ElderAdaptationDeltaSeconds"
    "timer_value.w"
    "1.0 / 60.0"
    "ElderSeedAdaptationHistory"
    "ElderAdaptationBrightenRate"
    "ElderAdaptationDarkenRate"
    "ElderAdaptationMinLuminance"
    "ElderAdaptationMaxLuminance")
forbid_elder_optical_tokens(
    "${elder_source_dir}/shaders/elder/ElderAdaptation.fxh"
    "Elder adaptation module"
    "return previous_luminance"
    "ElderStageOpticalIdentityWhenDisabled")
require_elder_optical_tokens(
    "${elder_source_dir}/shaders/elder/ElderLens.fxh"
    "Elder lens module"
    "ElderApplyLens"
    "ElderLensGhosts"
    "TextureBloom"
    "ElderLensEnergyCap"
    "ElderNeutralLensScratch"
    "ElderLensContribution"
    "#if ELDER_LENS_GHOSTS_VALUE >= 1"
    "#if ELDER_LENS_GHOSTS_VALUE >= 2"
    "#if ELDER_LENS_GHOSTS_VALUE >= 3")
forbid_elder_optical_tokens(
    "${elder_source_dir}/shaders/elder/ElderLens.fxh"
    "Elder lens module"
    "return bloom_source"
    "bloom_source.rgb +"
    "ElderStageOpticalIdentityWhenDisabled")

require_elder_optical_tokens(
    "${elder_source_dir}/shaders/enbdepthoffield.fx"
    "Elder depth-of-field stage"
    "#include \"elder/ElderDepthOfField.fxh\""
    "Texture2D TextureColor"
    "Texture2D TextureDepth"
    "ElderApplyDepthOfField")
require_elder_optical_tokens(
    "${elder_source_dir}/shaders/enbbloom.fx"
    "Elder bloom stage"
    "#include \"elder/ElderBloom.fxh\""
    "Texture2D TextureDownsampled"
    "string RenderTarget = \"RenderTarget512\";"
    "string RenderTarget = \"RenderTarget16\";"
    "technique11 Draw6"
    "return ElderApplyBloom")
forbid_elder_optical_tokens(
    "${elder_source_dir}/shaders/enbbloom.fx"
    "Elder bloom stage"
    "ElderStageIdentity("
    "Texture2D TextureColor")
require_elder_optical_tokens(
    "${elder_source_dir}/shaders/enbadaptation.fx"
    "Elder adaptation stage"
    "#include \"elder/ElderAdaptation.fxh\""
    "Texture2D TextureCurrent"
    "Texture2D TexturePrevious"
    "ElderAdaptationDeltaSeconds(Timer)"
    "ElderUpdateAdaptedLuminance")
forbid_elder_optical_tokens(
    "${elder_source_dir}/shaders/enbadaptation.fx"
    "Elder adaptation stage"
    "Timer.x")
require_elder_optical_tokens(
    "${elder_source_dir}/shaders/enblens.fx"
    "Elder lens stage"
    "#include \"elder/ElderLens.fxh\""
    "Texture2D TextureBloom"
    "return ElderApplyLens")
forbid_elder_optical_tokens(
    "${elder_source_dir}/shaders/enblens.fx"
    "Elder lens stage"
    "ElderStageIdentity(")

file(READ "${elder_source_dir}/shaders/enblens.fx" elder_lens_stage_source)
string(FIND "${elder_lens_stage_source}" "Texture2D TextureColor" elder_lens_raw_scene_position)
if(NOT elder_lens_raw_scene_position EQUAL -1)
    message(FATAL_ERROR "Lens stage must consume TextureBloom rather than raw TextureColor")
endif()

set(elder_generator "${elder_source_dir}/cmake/GenerateElderQualityPresets.cmake")
set(elder_contract_preset_root "${elder_binary_dir}/quality-presets-optical-contract")
execute_process(
    COMMAND "${CMAKE_COMMAND}"
        "-DELDER_SOURCE_DIR=${elder_source_dir}"
        "-DELDER_OUTPUT_DIR=${elder_contract_preset_root}"
        -P "${elder_generator}"
    RESULT_VARIABLE elder_generate_result)
if(NOT elder_generate_result EQUAL 0)
    message(FATAL_ERROR "Optical contract preset generation failed")
endif()

set(elder_expected_tiers performance balanced quality ultra cinematic)
set(elder_expected_tier_values 0 1 2 3 4)
set(elder_dof_ui_keys
    "TECHNIQUE"
    "Elder 20 | Depth of Field | Enabled"
    "Elder 20 | Depth of Field | Autofocus"
    "Elder 20 | Depth of Field | Intensity"
    "Elder 20 | Depth of Field | Focus Depth"
    "Elder 20 | Depth of Field | Focus Range"
    "Elder 20 | Depth of Field | Foreground Strength"
    "Elder 20 | Depth of Field | Background Strength"
    "Elder 20 | Depth of Field | Max Blur")
set(elder_bloom_ui_keys
    "TECHNIQUE"
    "Elder 30 | Bloom | Enabled"
    "Elder 30 | Bloom | Intensity"
    "Elder 30 | Bloom | Highlight Threshold"
    "Elder 30 | Bloom | Soft Knee"
    "Elder 30 | Bloom | Radius Scale")
set(elder_adaptation_ui_keys
    "TECHNIQUE"
    "Elder 40 | Adaptation | Enabled"
    "Elder 40 | Adaptation | Intensity"
    "Elder 40 | Adaptation | Brighten Rate"
    "Elder 40 | Adaptation | Darken Rate"
    "Elder 40 | Adaptation | Min Luminance"
    "Elder 40 | Adaptation | Max Luminance")
set(elder_lens_ui_keys
    "TECHNIQUE"
    "Elder 50 | Lens | Enabled"
    "Elder 50 | Lens | Intensity"
    "Elder 50 | Lens | Ghost Strength"
    "Elder 50 | Lens | Halo Strength"
    "Elder 50 | Lens | Energy Cap")
set(elder_optical_preset_files
    enbdepthoffield.fx.ini
    enbbloom.fx.ini
    enbadaptation.fx.ini
    enblens.fx.ini)

function(elder_expected_optical_preset_keys preset_file out_keys out_section)
    if(preset_file STREQUAL "enbdepthoffield.fx.ini")
        set(keys ${elder_dof_ui_keys})
        set(section "[ENBDEPTHOFFIELD.FX]")
    elseif(preset_file STREQUAL "enbbloom.fx.ini")
        set(keys ${elder_bloom_ui_keys})
        set(section "[ENBBLOOM.FX]")
    elseif(preset_file STREQUAL "enbadaptation.fx.ini")
        set(keys ${elder_adaptation_ui_keys})
        set(section "[ENBADAPTATION.FX]")
    elseif(preset_file STREQUAL "enblens.fx.ini")
        set(keys ${elder_lens_ui_keys})
        set(section "[ENBLENS.FX]")
    else()
        message(FATAL_ERROR "Unknown optical preset file ${preset_file}")
    endif()
    set(${out_keys} ${keys} PARENT_SCOPE)
    set(${out_section} "${section}" PARENT_SCOPE)
endfunction()
file(GLOB_RECURSE elder_contract_files LIST_DIRECTORIES false RELATIVE "${elder_contract_preset_root}" "${elder_contract_preset_root}/*")
list(LENGTH elder_contract_files elder_contract_file_count)
if(NOT elder_contract_file_count EQUAL 55)
    message(FATAL_ERROR "Expected fifty-five generated preset files including one ElderTier.fxh override per tier")
endif()
foreach(elder_tier_index RANGE 0 4)
    list(GET elder_expected_tiers ${elder_tier_index} elder_tier)
    list(GET elder_expected_tier_values ${elder_tier_index} elder_tier_value)
    set(elder_generated_tier_include "${elder_contract_preset_root}/${elder_tier}/enbseries/elder/ElderTier.fxh")
    if(NOT EXISTS "${elder_generated_tier_include}")
        message(FATAL_ERROR "Missing generated tier override: ${elder_tier}/enbseries/elder/ElderTier.fxh")
    endif()
    file(READ "${elder_generated_tier_include}" elder_generated_tier_source)
    string(FIND "${elder_generated_tier_source}" ";" elder_generated_ini_comment_position)
    if(NOT elder_generated_ini_comment_position EQUAL -1)
        message(FATAL_ERROR "Generated ElderTier.fxh for ${elder_tier} must use HLSL comments, not INI comments")
    endif()
    file(STRINGS "${elder_generated_tier_include}" elder_generated_tier_lines)
    set(elder_generated_tier_define_count 0)
    foreach(elder_generated_tier_line IN LISTS elder_generated_tier_lines)
        if(elder_generated_tier_line MATCHES "^#define[ \t]+ELDER_QUALITY_TIER[ \t]+([0-4])$")
            math(EXPR elder_generated_tier_define_count "${elder_generated_tier_define_count} + 1")
            if(NOT CMAKE_MATCH_1 STREQUAL "${elder_tier_value}")
                message(FATAL_ERROR "Generated tier override for ${elder_tier} defines ${CMAKE_MATCH_1}, expected ${elder_tier_value}")
            endif()
        elseif(elder_generated_tier_line MATCHES "^#define[ \t]+")
            message(FATAL_ERROR "Generated tier override for ${elder_tier} contains an extra define: ${elder_generated_tier_line}")
        endif()
    endforeach()
    if(NOT elder_generated_tier_define_count EQUAL 1)
        message(FATAL_ERROR "Generated tier override for ${elder_tier} must contain exactly one ELDER_QUALITY_TIER define")
    endif()
    foreach(elder_preset_file IN LISTS elder_optical_preset_files)
        elder_expected_optical_preset_keys(
            "${elder_preset_file}" elder_expected_keys elder_expected_section)
        set(elder_preset_path "${elder_contract_preset_root}/${elder_tier}/${elder_preset_file}")
        if(NOT EXISTS "${elder_preset_path}")
            message(FATAL_ERROR "Missing optical generated preset ${elder_tier}/${elder_preset_file}")
        endif()
        file(READ "${elder_preset_path}" elder_preset_source)
        string(FIND "${elder_preset_source}" "${elder_expected_section}" elder_section_position)
        if(elder_section_position EQUAL -1)
            message(FATAL_ERROR "Optical preset must use uppercase stage section ${elder_expected_section}: ${elder_tier}/${elder_preset_file}")
        endif()
        file(STRINGS "${elder_preset_path}" elder_preset_lines)
        set(elder_seen_keys "")
        foreach(elder_line IN LISTS elder_preset_lines)
            if(elder_line STREQUAL "" OR elder_line MATCHES "^;")
                continue()
            endif()
            # INI readers classify any line opening with '[' as a section
            # header, so only the expected stage section may start with one.
            if(elder_line MATCHES "^[ \t]*\\[")
                if(NOT elder_line STREQUAL "${elder_expected_section}")
                    message(FATAL_ERROR "Line would read back as an INI section header: ${elder_tier}/${elder_preset_file}: ${elder_line}")
                endif()
                continue()
            endif()
            if(NOT elder_line MATCHES "^(.+)=([^;]+)$")
                message(FATAL_ERROR "Malformed optical preset line in ${elder_tier}/${elder_preset_file}: ${elder_line}")
            endif()
            set(elder_key "${CMAKE_MATCH_1}")
            set(elder_value "${CMAKE_MATCH_2}")
            if(elder_key MATCHES "^(Enable|Intensity|IntensityMin|IntensityMax|Shape|ShapeMin|ShapeMax)$")
                message(FATAL_ERROR "Optical preset still uses generic placeholder key ${elder_key}: ${elder_tier}/${elder_preset_file}")
            endif()
            list(FIND elder_expected_keys "${elder_key}" elder_allowed_key_position)
            if(elder_allowed_key_position EQUAL -1)
                message(FATAL_ERROR "Unknown optical preset key ${elder_key}: ${elder_tier}/${elder_preset_file}")
            endif()
            list(FIND elder_seen_keys "${elder_key}" elder_duplicate_key_position)
            if(NOT elder_duplicate_key_position EQUAL -1)
                message(FATAL_ERROR "Duplicate optical preset key ${elder_key}: ${elder_tier}/${elder_preset_file}")
            endif()
            list(APPEND elder_seen_keys "${elder_key}")
            if(elder_key MATCHES "\\| (Enabled|Autofocus)$")
                if(NOT elder_value MATCHES "^(true|false)$")
                    message(FATAL_ERROR "Boolean optical preset key has non-boolean value ${elder_value}: ${elder_key}")
                endif()
            elseif(NOT elder_value MATCHES "^-?[0-9]+(\\.[0-9]+)?$")
                message(FATAL_ERROR "Numeric optical preset key has non-numeric value ${elder_value}: ${elder_key}")
            endif()
        endforeach()
        foreach(elder_required_key IN LISTS elder_expected_keys)
            list(FIND elder_seen_keys "${elder_required_key}" elder_seen_key_position)
            if(elder_seen_key_position EQUAL -1)
                message(FATAL_ERROR "Missing optical preset key ${elder_required_key}: ${elder_tier}/${elder_preset_file}")
            endif()
        endforeach()
    endforeach()
endforeach()

message(STATUS "Elder optical contracts verified public modules, stage wiring, and generated preset keys")
