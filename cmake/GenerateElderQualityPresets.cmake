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
        "ELDER_QUALITY_TIER=${elder_tier}\n"
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

    foreach(elder_stage IN LISTS elder_stages)
        string(CONCAT elder_stage_content
            "; Elder ENB quality preset\n"
            "; Tier: ${elder_label} (${elder_tier})\n"
            "[${elder_stage}]\n"
            "Enable=true\n"
            "Intensity=1.000\n"
            "IntensityMin=0.000\n"
            "IntensityMax=2.000\n"
            "Shape=1.000\n"
            "ShapeMin=0.000\n"
            "ShapeMax=2.000\n")
        file(WRITE "${elder_tier_dir}/${elder_stage}.ini" "${elder_stage_content}")
    endforeach()
endforeach()
