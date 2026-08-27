cmake_minimum_required(VERSION 4.0)

if(NOT DEFINED ELDER_SOURCE_DIR OR ELDER_SOURCE_DIR STREQUAL "")
    message(FATAL_ERROR "ELDER_SOURCE_DIR is required")
endif()
if(DEFINED ELDER_OUTPUT_DIR AND NOT ELDER_OUTPUT_DIR STREQUAL "")
    set(elder_output_dir "${ELDER_OUTPUT_DIR}")
elseif(DEFINED OUTPUT_ROOT AND NOT OUTPUT_ROOT STREQUAL "")
    set(elder_output_dir "${OUTPUT_ROOT}")
else()
    message(FATAL_ERROR "ELDER_OUTPUT_DIR is required")
endif()

cmake_path(ABSOLUTE_PATH ELDER_SOURCE_DIR NORMALIZE OUTPUT_VARIABLE elder_source_dir)
cmake_path(ABSOLUTE_PATH elder_output_dir NORMALIZE OUTPUT_VARIABLE elder_output_dir)

set(elder_manifest "${elder_source_dir}/config/quality-tiers.csv")
if(NOT EXISTS "${elder_manifest}")
    message(FATAL_ERROR "Quality-tier manifest is missing: ${elder_manifest}")
endif()
file(STRINGS "${elder_manifest}" elder_rows)
list(LENGTH elder_rows elder_row_count)
if(NOT elder_row_count EQUAL 6)
    message(FATAL_ERROR "Quality-tier manifest must contain one header and five rows")
endif()
list(GET elder_rows 0 elder_header)
if(NOT elder_header STREQUAL "tier,id,label,ao_directions,ao_steps,ssr_steps,dof_rings,bloom_radius,lens_ghosts,room_light_refinement")
    message(FATAL_ERROR "Quality-tier manifest header is not canonical")
endif()

set(elder_expected_ids performance balanced quality ultra cinematic)
set(elder_expected_labels Performance Balanced Quality Ultra Cinematic)
set(elder_expected_values
    "4,2,0,0,2,0,0"
    "6,3,0,2,3,1,1"
    "8,4,8,3,4,2,1"
    "12,5,12,4,5,2,2"
    "16,6,16,5,6,3,2")
set(elder_stages
    enbeffectprepass.fx
    enbdepthoffield.fx
    enbbloom.fx
    enbadaptation.fx
    enblens.fx
    enbeffect.fx
    enbeffectpostpass.fx
    enbsunsprite.fx
    enbunderwater.fx)

file(REMOVE_RECURSE "${elder_output_dir}")
file(MAKE_DIRECTORY "${elder_output_dir}")

foreach(elder_index RANGE 0 4)
    math(EXPR elder_row_index "${elder_index} + 1")
    list(GET elder_rows ${elder_row_index} elder_row)
    string(REPLACE "," ";" elder_fields "${elder_row}")
    list(LENGTH elder_fields elder_field_count)
    if(NOT elder_field_count EQUAL 10)
        message(FATAL_ERROR "Quality-tier row ${elder_row_index} must contain ten fields")
    endif()
    list(GET elder_fields 0 elder_tier)
    list(GET elder_fields 1 elder_id)
    list(GET elder_fields 2 elder_label)
    list(REMOVE_AT elder_fields 0 1 2)
    string(JOIN "," elder_values ${elder_fields})
    list(GET elder_expected_ids ${elder_index} elder_expected_id)
    list(GET elder_expected_labels ${elder_index} elder_expected_label)
    list(GET elder_expected_values ${elder_index} elder_expected_value)
    if(NOT elder_tier STREQUAL "${elder_index}" OR NOT elder_id STREQUAL "${elder_expected_id}" OR NOT elder_label STREQUAL "${elder_expected_label}" OR NOT elder_values STREQUAL "${elder_expected_value}")
        message(FATAL_ERROR "Quality-tier row ${elder_row_index} is not canonical")
    endif()

    set(elder_tier_dir "${elder_output_dir}/${elder_id}")
    cmake_path(IS_PREFIX elder_output_dir "${elder_tier_dir}" NORMALIZE elder_tier_is_contained)
    if(NOT elder_tier_is_contained)
        message(FATAL_ERROR "Generated tier path escapes ELDER_OUTPUT_DIR")
    endif()
    file(MAKE_DIRECTORY "${elder_tier_dir}")

    string(REPLACE "," ";" elder_values_list "${elder_values}")
    list(GET elder_values_list 0 elder_ao_directions)
    list(GET elder_values_list 1 elder_ao_steps)
    list(GET elder_values_list 2 elder_ssr_steps)
    list(GET elder_values_list 3 elder_dof_rings)
    list(GET elder_values_list 4 elder_bloom_radius)
    list(GET elder_values_list 5 elder_lens_ghosts)
    list(GET elder_values_list 6 elder_room_light_refinement)
    string(CONCAT elder_quality_content
        "; Elder ENB quality preset\n"
        "; Tier: ${elder_label} (${elder_tier})\n"
        "[ElderQuality]\n"
        "QualityTier=${elder_tier}\n"
        "TierId=${elder_id}\n"
        "TierLabel=${elder_label}\n"
        "AODirections=${elder_ao_directions}\n"
        "AOSteps=${elder_ao_steps}\n"
        "SSRSteps=${elder_ssr_steps}\n"
        "DOFRings=${elder_dof_rings}\n"
        "BloomRadius=${elder_bloom_radius}\n"
        "LensGhosts=${elder_lens_ghosts}\n"
        "RoomLightRefinement=${elder_room_light_refinement}\n")
    file(WRITE "${elder_tier_dir}/elder-quality.ini" "${elder_quality_content}")

    set(elder_tier_include_dir "${elder_tier_dir}/enbseries/elder")
    cmake_path(IS_PREFIX elder_tier_dir "${elder_tier_include_dir}" NORMALIZE elder_tier_include_is_contained)
    if(NOT elder_tier_include_is_contained)
        message(FATAL_ERROR "Generated tier include path escapes its quality tier directory")
    endif()
    file(MAKE_DIRECTORY "${elder_tier_include_dir}")
    string(CONCAT elder_tier_include_content
        "// Elder ENB generated tier override\n"
        "// Tier: ${elder_label} (${elder_tier})\n"
        "#ifndef ELDER_QUALITY_TIER\n"
        "#define ELDER_QUALITY_TIER ${elder_tier}\n"
        "#endif\n")
    file(WRITE "${elder_tier_include_dir}/ElderTier.fxh" "${elder_tier_include_content}")

    if(elder_id STREQUAL "performance")
        set(elder_dof_enabled false)
        set(elder_dof_intensity 0.000)
        set(elder_dof_focus_depth 0.55)
        set(elder_dof_focus_range 0.24)
        set(elder_dof_foreground_strength 0.00)
        set(elder_dof_background_strength 0.00)
        set(elder_dof_max_blur 0.00)
        set(elder_bloom_enabled true)
        set(elder_bloom_intensity 0.080)
        set(elder_bloom_threshold 1.65)
        set(elder_bloom_soft_knee 0.18)
        set(elder_bloom_radius_scale 0.70)
        set(elder_adaptation_enabled true)
        set(elder_adaptation_intensity 0.45)
        set(elder_adaptation_brighten_rate 0.55)
        set(elder_adaptation_darken_rate 0.35)
        set(elder_adaptation_min_luminance 0.080)
        set(elder_adaptation_max_luminance 7.00)
        set(elder_lens_enabled false)
        set(elder_lens_intensity 0.000)
        set(elder_lens_ghost_strength 0.00)
        set(elder_lens_halo_strength 0.00)
        set(elder_lens_energy_cap 0.00)
        set(elder_prepass_enabled true)
        set(elder_prepass_intensity 0.900)
        set(elder_prepass_depth_shape 0.40)
        set(elder_main_enabled true)
        set(elder_main_intensity 1.000)
        set(elder_main_optical_shape 0.35)
        set(elder_postpass_enabled true)
        set(elder_postpass_intensity 1.000)
        set(elder_postpass_vignette_strength 0.10)
        set(elder_postpass_grain_shape 0.00)
        set(elder_sunsprite_enabled false)
        set(elder_sunsprite_intensity 0.000)
        set(elder_sunsprite_disc_shape 0.45)
        set(elder_underwater_enabled true)
        set(elder_underwater_intensity 0.45)
        set(elder_underwater_density_shape 0.18)
    elseif(elder_id STREQUAL "balanced")
        set(elder_dof_enabled true)
        set(elder_dof_intensity 0.180)
        set(elder_dof_focus_depth 0.55)
        set(elder_dof_focus_range 0.22)
        set(elder_dof_foreground_strength 0.20)
        set(elder_dof_background_strength 0.35)
        set(elder_dof_max_blur 0.45)
        set(elder_bloom_enabled true)
        set(elder_bloom_intensity 0.120)
        set(elder_bloom_threshold 1.45)
        set(elder_bloom_soft_knee 0.25)
        set(elder_bloom_radius_scale 0.80)
        set(elder_adaptation_enabled true)
        set(elder_adaptation_intensity 0.55)
        set(elder_adaptation_brighten_rate 0.70)
        set(elder_adaptation_darken_rate 0.45)
        set(elder_adaptation_min_luminance 0.080)
        set(elder_adaptation_max_luminance 8.00)
        set(elder_lens_enabled true)
        set(elder_lens_intensity 0.070)
        set(elder_lens_ghost_strength 0.05)
        set(elder_lens_halo_strength 0.04)
        set(elder_lens_energy_cap 0.08)
        set(elder_prepass_enabled true)
        set(elder_prepass_intensity 1.000)
        set(elder_prepass_depth_shape 0.50)
        set(elder_main_enabled true)
        set(elder_main_intensity 1.000)
        set(elder_main_optical_shape 0.50)
        set(elder_postpass_enabled true)
        set(elder_postpass_intensity 1.000)
        set(elder_postpass_vignette_strength 0.18)
        set(elder_postpass_grain_shape 0.00)
        set(elder_sunsprite_enabled true)
        set(elder_sunsprite_intensity 0.180)
        set(elder_sunsprite_disc_shape 0.50)
        set(elder_underwater_enabled true)
        set(elder_underwater_intensity 0.55)
        set(elder_underwater_density_shape 0.25)
    elseif(elder_id STREQUAL "quality")
        set(elder_dof_enabled true)
        set(elder_dof_intensity 0.220)
        set(elder_dof_focus_depth 0.54)
        set(elder_dof_focus_range 0.20)
        set(elder_dof_foreground_strength 0.25)
        set(elder_dof_background_strength 0.42)
        set(elder_dof_max_blur 0.52)
        set(elder_bloom_enabled true)
        set(elder_bloom_intensity 0.150)
        set(elder_bloom_threshold 1.35)
        set(elder_bloom_soft_knee 0.30)
        set(elder_bloom_radius_scale 0.90)
        set(elder_adaptation_enabled true)
        set(elder_adaptation_intensity 0.62)
        set(elder_adaptation_brighten_rate 0.85)
        set(elder_adaptation_darken_rate 0.55)
        set(elder_adaptation_min_luminance 0.070)
        set(elder_adaptation_max_luminance 9.00)
        set(elder_lens_enabled true)
        set(elder_lens_intensity 0.090)
        set(elder_lens_ghost_strength 0.07)
        set(elder_lens_halo_strength 0.05)
        set(elder_lens_energy_cap 0.10)
        set(elder_prepass_enabled true)
        set(elder_prepass_intensity 1.000)
        set(elder_prepass_depth_shape 0.55)
        set(elder_main_enabled true)
        set(elder_main_intensity 1.000)
        set(elder_main_optical_shape 0.58)
        set(elder_postpass_enabled true)
        set(elder_postpass_intensity 1.000)
        set(elder_postpass_vignette_strength 0.20)
        set(elder_postpass_grain_shape 0.05)
        set(elder_sunsprite_enabled true)
        set(elder_sunsprite_intensity 0.220)
        set(elder_sunsprite_disc_shape 0.55)
        set(elder_underwater_enabled true)
        set(elder_underwater_intensity 0.60)
        set(elder_underwater_density_shape 0.30)
    elseif(elder_id STREQUAL "ultra")
        set(elder_dof_enabled true)
        set(elder_dof_intensity 0.260)
        set(elder_dof_focus_depth 0.53)
        set(elder_dof_focus_range 0.18)
        set(elder_dof_foreground_strength 0.30)
        set(elder_dof_background_strength 0.48)
        set(elder_dof_max_blur 0.62)
        set(elder_bloom_enabled true)
        set(elder_bloom_intensity 0.180)
        set(elder_bloom_threshold 1.25)
        set(elder_bloom_soft_knee 0.35)
        set(elder_bloom_radius_scale 1.00)
        set(elder_adaptation_enabled true)
        set(elder_adaptation_intensity 0.68)
        set(elder_adaptation_brighten_rate 1.00)
        set(elder_adaptation_darken_rate 0.65)
        set(elder_adaptation_min_luminance 0.060)
        set(elder_adaptation_max_luminance 10.00)
        set(elder_lens_enabled true)
        set(elder_lens_intensity 0.100)
        set(elder_lens_ghost_strength 0.08)
        set(elder_lens_halo_strength 0.06)
        set(elder_lens_energy_cap 0.12)
        set(elder_prepass_enabled true)
        set(elder_prepass_intensity 1.000)
        set(elder_prepass_depth_shape 0.62)
        set(elder_main_enabled true)
        set(elder_main_intensity 1.000)
        set(elder_main_optical_shape 0.64)
        set(elder_postpass_enabled true)
        set(elder_postpass_intensity 1.000)
        set(elder_postpass_vignette_strength 0.22)
        set(elder_postpass_grain_shape 0.08)
        set(elder_sunsprite_enabled true)
        set(elder_sunsprite_intensity 0.250)
        set(elder_sunsprite_disc_shape 0.60)
        set(elder_underwater_enabled true)
        set(elder_underwater_intensity 0.65)
        set(elder_underwater_density_shape 0.34)
    else()
        set(elder_dof_enabled true)
        set(elder_dof_intensity 0.300)
        set(elder_dof_focus_depth 0.52)
        set(elder_dof_focus_range 0.16)
        set(elder_dof_foreground_strength 0.34)
        set(elder_dof_background_strength 0.55)
        set(elder_dof_max_blur 0.72)
        set(elder_bloom_enabled true)
        set(elder_bloom_intensity 0.210)
        set(elder_bloom_threshold 1.15)
        set(elder_bloom_soft_knee 0.40)
        set(elder_bloom_radius_scale 1.10)
        set(elder_adaptation_enabled true)
        set(elder_adaptation_intensity 0.72)
        set(elder_adaptation_brighten_rate 1.15)
        set(elder_adaptation_darken_rate 0.75)
        set(elder_adaptation_min_luminance 0.050)
        set(elder_adaptation_max_luminance 11.00)
        set(elder_lens_enabled true)
        set(elder_lens_intensity 0.120)
        set(elder_lens_ghost_strength 0.10)
        set(elder_lens_halo_strength 0.07)
        set(elder_lens_energy_cap 0.14)
        set(elder_prepass_enabled true)
        set(elder_prepass_intensity 1.000)
        set(elder_prepass_depth_shape 0.70)
        set(elder_main_enabled true)
        set(elder_main_intensity 1.000)
        set(elder_main_optical_shape 0.70)
        set(elder_postpass_enabled true)
        set(elder_postpass_intensity 1.000)
        set(elder_postpass_vignette_strength 0.24)
        set(elder_postpass_grain_shape 0.10)
        set(elder_sunsprite_enabled true)
        set(elder_sunsprite_intensity 0.300)
        set(elder_sunsprite_disc_shape 0.65)
        set(elder_underwater_enabled true)
        set(elder_underwater_intensity 0.70)
        set(elder_underwater_density_shape 0.38)
    endif()

    # ENB's per-stage technique dropdown defaults to index 0, its internal
    # DEFAULT shader; index 1 is the first technique11 declared in the stage
    # file. Without TECHNIQUE=1 an installed preset renders ENB's built-in
    # path instead of Elder.
    foreach(elder_stage IN LISTS elder_stages)
        string(TOUPPER "${elder_stage}" elder_stage_section)
        if(elder_stage STREQUAL "enbdepthoffield.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 20] Depth of Field | Enabled=${elder_dof_enabled}\n"
                "[Elder 20] Depth of Field | Intensity=${elder_dof_intensity}\n"
                "[Elder 20] Depth of Field | Focus Depth=${elder_dof_focus_depth}\n"
                "[Elder 20] Depth of Field | Focus Range=${elder_dof_focus_range}\n"
                "[Elder 20] Depth of Field | Foreground Strength=${elder_dof_foreground_strength}\n"
                "[Elder 20] Depth of Field | Background Strength=${elder_dof_background_strength}\n"
                "[Elder 20] Depth of Field | Max Blur=${elder_dof_max_blur}\n")
        elseif(elder_stage STREQUAL "enbbloom.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 30] Bloom | Enabled=${elder_bloom_enabled}\n"
                "[Elder 30] Bloom | Intensity=${elder_bloom_intensity}\n"
                "[Elder 30] Bloom | Highlight Threshold=${elder_bloom_threshold}\n"
                "[Elder 30] Bloom | Soft Knee=${elder_bloom_soft_knee}\n"
                "[Elder 30] Bloom | Radius Scale=${elder_bloom_radius_scale}\n")
        elseif(elder_stage STREQUAL "enbadaptation.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 40] Adaptation | Enabled=${elder_adaptation_enabled}\n"
                "[Elder 40] Adaptation | Intensity=${elder_adaptation_intensity}\n"
                "[Elder 40] Adaptation | Brighten Rate=${elder_adaptation_brighten_rate}\n"
                "[Elder 40] Adaptation | Darken Rate=${elder_adaptation_darken_rate}\n"
                "[Elder 40] Adaptation | Min Luminance=${elder_adaptation_min_luminance}\n"
                "[Elder 40] Adaptation | Max Luminance=${elder_adaptation_max_luminance}\n")
        elseif(elder_stage STREQUAL "enblens.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 50] Lens | Enabled=${elder_lens_enabled}\n"
                "[Elder 50] Lens | Intensity=${elder_lens_intensity}\n"
                "[Elder 50] Lens | Ghost Strength=${elder_lens_ghost_strength}\n"
                "[Elder 50] Lens | Halo Strength=${elder_lens_halo_strength}\n"
                "[Elder 50] Lens | Energy Cap=${elder_lens_energy_cap}\n")
        elseif(elder_stage STREQUAL "enbeffectprepass.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 10] Prepass | Enabled=${elder_prepass_enabled}\n"
                "[Elder 10] Prepass | Intensity=${elder_prepass_intensity}\n"
                "[Elder 10] Prepass | Depth Shape=${elder_prepass_depth_shape}\n")
        elseif(elder_stage STREQUAL "enbeffect.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 60] Main Effect | Enabled=${elder_main_enabled}\n"
                "[Elder 60] Main Effect | Color-Core Intensity=${elder_main_intensity}\n"
                "[Elder 60] Main Effect | Optical Shape=${elder_main_optical_shape}\n")
        elseif(elder_stage STREQUAL "enbeffectpostpass.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 70] Postpass | Enabled=${elder_postpass_enabled}\n"
                "[Elder 70] Postpass | Intensity=${elder_postpass_intensity}\n"
                "[Elder 70] Postpass | Vignette Strength=${elder_postpass_vignette_strength}\n"
                "[Elder 70] Postpass | Grain Shape=${elder_postpass_grain_shape}\n")
        elseif(elder_stage STREQUAL "enbsunsprite.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 80] Sun Sprite | Enabled=${elder_sunsprite_enabled}\n"
                "[Elder 80] Sun Sprite | Intensity=${elder_sunsprite_intensity}\n"
                "[Elder 80] Sun Sprite | Disc Shape=${elder_sunsprite_disc_shape}\n")
        elseif(elder_stage STREQUAL "enbunderwater.fx")
            string(CONCAT elder_stage_content
                "; Elder ENB quality preset\n"
                "; Tier: ${elder_label} (${elder_tier})\n"
                "[${elder_stage_section}]\n"
                "TECHNIQUE=1\n"
                "[Elder 90] Underwater | Enabled=${elder_underwater_enabled}\n"
                "[Elder 90] Underwater | Intensity=${elder_underwater_intensity}\n"
                "[Elder 90] Underwater | Density Shape=${elder_underwater_density_shape}\n")
        else()
            message(FATAL_ERROR "Unhandled Elder stage preset: ${elder_stage}")
        endif()
        file(WRITE "${elder_tier_dir}/${elder_stage}.ini" "${elder_stage_content}")
    endforeach()
endforeach()
