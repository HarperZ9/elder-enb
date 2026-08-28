cmake_minimum_required(VERSION 3.30)

if(NOT DEFINED ELDER_SOURCE_DIR OR "${ELDER_SOURCE_DIR}" STREQUAL "")
  message(FATAL_ERROR "Missing required variable: ELDER_SOURCE_DIR")
endif()
file(REAL_PATH "${ELDER_SOURCE_DIR}" elder_source_dir)

function(elder_require_file file_path description)
  if(NOT EXISTS "${file_path}")
    message(FATAL_ERROR "Elder composition ${description} is absent: ${file_path}")
  endif()
endfunction()

function(elder_require_token source_text token description)
  string(FIND "${source_text}" "${token}" token_position)
  if(token_position EQUAL -1)
    message(FATAL_ERROR "${description} is missing required token: ${token}")
  endif()
endfunction()

function(elder_forbid_token source_text token description)
  string(FIND "${source_text}" "${token}" token_position)
  if(NOT token_position EQUAL -1)
    message(FATAL_ERROR "${description} contains forbidden token: ${token}")
  endif()
endfunction()

function(elder_count_token source_text token out_count)
  string(REGEX MATCHALL "${token}" token_matches "${source_text}")
  list(LENGTH token_matches token_count)
  set(${out_count} "${token_count}" PARENT_SCOPE)
endfunction()

function(elder_require_order source_text earlier_token later_token description)
  string(FIND "${source_text}" "${earlier_token}" earlier_position)
  string(FIND "${source_text}" "${later_token}" later_position)
  if(earlier_position EQUAL -1
      OR later_position EQUAL -1
      OR earlier_position GREATER_EQUAL later_position)
    message(FATAL_ERROR
      "${description} must preserve order: ${earlier_token} before ${later_token}")
  endif()
endfunction()

set(elder_main "${elder_source_dir}/shaders/enbeffect.fx")
set(elder_post "${elder_source_dir}/shaders/enbeffectpostpass.fx")
set(elder_sun "${elder_source_dir}/shaders/enbsunsprite.fx")
set(elder_underwater "${elder_source_dir}/shaders/enbunderwater.fx")
set(elder_adaptation "${elder_source_dir}/shaders/enbadaptation.fx")
set(elder_bloom_module "${elder_source_dir}/shaders/elder/ElderBloom.fxh")
set(elder_lens_module "${elder_source_dir}/shaders/elder/ElderLens.fxh")
set(elder_adaptation_module "${elder_source_dir}/shaders/elder/ElderAdaptation.fxh")
set(elder_parameters "${elder_source_dir}/shaders/elder/ElderStageParameters.fxh")
set(elder_generator "${elder_source_dir}/cmake/GenerateElderQualityPresets.cmake")
set(elder_modules
  "${elder_source_dir}/shaders/elder/ElderPostFinish.fxh"
  "${elder_source_dir}/shaders/elder/ElderSunSprite.fxh"
  "${elder_source_dir}/shaders/elder/ElderUnderwater.fxh")

foreach(required_source IN ITEMS
    "${elder_main}"
    "${elder_post}"
    "${elder_sun}"
    "${elder_underwater}"
    "${elder_adaptation}"
    "${elder_bloom_module}"
    "${elder_lens_module}"
    "${elder_adaptation_module}"
    "${elder_parameters}"
    "${elder_generator}")
  elder_require_file("${required_source}" "contract source")
endforeach()

file(READ "${elder_bloom_module}" elder_bloom_module_source)
foreach(required_bloom_token IN ITEMS
    "ElderNeutralBloomScratch("
    "return float4(0.0.xxx, ElderBloomScratchAlpha(source_alpha));"
    "return ElderNeutralBloomScratch(source.a);"
    "ElderBloomContribution(")
  elder_require_token("${elder_bloom_module_source}" "${required_bloom_token}"
    "Bloom contribution scratch contract")
endforeach()
foreach(forbidden_bloom_token IN ITEMS
    "source.rgb + bounded_add"
    "ElderStageOpticalIdentityWhenDisabled"
    "ElderStageIdentity(")
  elder_forbid_token("${elder_bloom_module_source}" "${forbidden_bloom_token}"
    "Bloom contribution scratch contract")
endforeach()

file(READ "${elder_lens_module}" elder_lens_module_source)
foreach(required_lens_token IN ITEMS
    "ElderNeutralLensScratch("
    "return float4(0.0.xxx, ElderLensScratchAlpha(source_alpha));"
    "return ElderNeutralLensScratch(bloom_source.a);"
    "ElderLensContribution(")
  elder_require_token("${elder_lens_module_source}" "${required_lens_token}"
    "Lens contribution scratch contract")
endforeach()
foreach(forbidden_lens_token IN ITEMS
    "bloom_source.rgb + capped_lens"
    "ElderStageOpticalIdentityWhenDisabled"
    "ElderStageIdentity(")
  elder_forbid_token("${elder_lens_module_source}" "${forbidden_lens_token}"
    "Lens contribution scratch contract")
endforeach()
foreach(required_module IN LISTS elder_modules)
  elder_require_file("${required_module}" "module")
endforeach()

file(READ "${elder_main}" elder_main_source)
elder_count_token("${elder_main_source}" "ElderEvaluateColorCore[ \t\r\n]*\\("
  elder_color_core_count)
if(NOT elder_color_core_count EQUAL 1)
  message(FATAL_ERROR
    "Main effect must call ElderEvaluateColorCore exactly once; found ${elder_color_core_count}")
endif()
foreach(required_main_token IN ITEMS
    "float3 bloom_add = ElderBoundOpticalContribution(TextureBloom.Sample(Sampler1, texcoord).rgb);"
    "float3 lens_add = ElderBoundOpticalContribution(TextureLens.Sample(Sampler1, texcoord).rgb);"
    "float3 optical_color = ElderBoundHdrDisplay(scene_color + bloom_add + lens_add);"
    "TextureBloom.Sample"
    "TextureLens.Sample")
  elder_require_token("${elder_main_source}" "${required_main_token}"
    "Main effect optical composition")
endforeach()
foreach(forbidden_main_token IN ITEMS
    "ElderPositiveOpticalDelta"
    "bloom_source, scene_color"
    "lens_source, bloom_source"
    "TextureBloom.Sample(Sampler1, texcoord).rgb + TextureLens")
  elder_forbid_token("${elder_main_source}" "${forbidden_main_token}"
    "Main effect optical composition")
endforeach()

file(READ "${elder_post}" elder_post_source)
foreach(required_post_token IN ITEMS
    "#include \"elder/ElderPostFinish.fxh\""
    "ElderFinishLdr("
    "return float4(finished, 1.0)")
  elder_require_token("${elder_post_source}" "${required_post_token}"
    "Postpass LDR finish")
endforeach()
foreach(forbidden_post_token IN ITEMS
    "ElderApplyBloom"
    "ElderApplyLens"
    "ElderEvaluateColorCore"
    "ElderApplyWeatherAtmosphere"
    "ElderEvaluateFog"
    "Fog"
    "GodRay"
    "TextureBloom"
    "TextureLens")
  elder_forbid_token("${elder_post_source}" "${forbidden_post_token}"
    "Postpass LDR finish")
endforeach()

file(READ "${elder_source_dir}/shaders/elder/ElderPostFinish.fxh"
  elder_post_finish_source)
foreach(required_finish_token IN ITEMS
    "ElderApplyLdrVignette("
    "ElderApplyFineGrain("
    "ElderApplyTerminalTriangularDither("
    "return ElderApplyTerminalTriangularDither(uv, finished);")
  elder_require_token("${elder_post_finish_source}" "${required_finish_token}"
    "Elder post finish")
endforeach()
elder_require_order("${elder_post_finish_source}"
  "ElderApplyLdrVignette(" "ElderApplyFineGrain("
  "Elder post finish")
elder_require_order("${elder_post_finish_source}"
  "ElderApplyFineGrain(" "ElderApplyTerminalTriangularDither("
  "Elder post finish")
foreach(forbidden_finish_token IN ITEMS
    "ElderApplyBloom"
    "ElderApplyLens"
    "ElderEvaluateColorCore"
    "ElderApplyWeatherAtmosphere"
    "ElderEvaluateFog"
    "GodRay")
  elder_forbid_token("${elder_post_finish_source}" "${forbidden_finish_token}"
    "Elder post finish")
endforeach()

file(READ "${elder_sun}" elder_sun_source)
foreach(required_sun_token IN ITEMS
    "#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_NATIVE"
    "#define ELDER_STAGE_OWNS_BRIDGE_VALUE 1"
    "#include \"elder/ElderSunSprite.fxh\""
    "LightParameters"
    "ElderSunSpriteBridgeAvailable()"
    "ElderEvaluateSunSprite(")
  elder_require_token("${elder_sun_source}" "${required_sun_token}"
    "Sun sprite stage")
endforeach()
file(READ "${elder_source_dir}/shaders/elder/ElderSunSprite.fxh" elder_sun_module)
foreach(required_sun_module_token IN ITEMS
    "visibility <= 0.0"
    "saturate(ElderSunSpriteIntensity)"
    "min(ElderFiniteOrBlack(sprite), 8.0.xxx)")
  elder_require_token("${elder_sun_module}" "${required_sun_module_token}"
    "Sun sprite module")
endforeach()
foreach(forbidden_sun_token IN ITEMS
    "TextureBloom"
    "TextureLens"
    "ElderApplyBloom"
    "ElderApplyLens"
    "Fog"
    "GodRay")
  elder_forbid_token("${elder_sun_source}" "${forbidden_sun_token}"
    "Sun sprite stage")
  elder_forbid_token("${elder_sun_module}" "${forbidden_sun_token}"
    "Sun sprite module")
endforeach()

file(READ "${elder_underwater}" elder_underwater_source)
foreach(required_underwater_token IN ITEMS
    "#include \"elder/ElderUnderwater.fxh\""
    "ElderEvaluateUnderwater("
    "TextureDepth")
  elder_require_token("${elder_underwater_source}" "${required_underwater_token}"
    "Underwater stage")
endforeach()
file(READ "${elder_source_dir}/shaders/elder/ElderUnderwater.fxh"
  elder_underwater_module)
foreach(required_underwater_module_token IN ITEMS
    "ElderUnderwaterTransmittance("
    "float3 absorption = float3(0.42, 0.16, 0.08);"
    "float3 water_radiance = float3(0.015, 0.075, 0.095);"
    "return ElderFiniteOrBlack(")
  elder_require_token("${elder_underwater_module}" "${required_underwater_module_token}"
    "Underwater medium module")
endforeach()
foreach(forbidden_underwater_token IN ITEMS
    "ElderApplyWeatherAtmosphere"
    "ElderEvaluateFog"
    "Fog"
    "ElderApplyLens"
    "LensDirt"
    "GodRay"
    "ElderEvaluateColorCore")
  elder_forbid_token("${elder_underwater_source}" "${forbidden_underwater_token}"
    "Underwater stage")
  elder_forbid_token("${elder_underwater_module}" "${forbidden_underwater_token}"
    "Underwater medium module")
endforeach()

file(READ "${elder_adaptation}" elder_adaptation_source)
elder_require_token("${elder_adaptation_source}" "ElderAdaptationDeltaSeconds(Timer)"
  "Adaptation frame-delta contract")
elder_forbid_token("${elder_adaptation_source}" "clamp(Timer.x"
  "Adaptation frame-delta contract")
file(READ "${elder_adaptation_module}" elder_adaptation_module_source)
elder_require_token("${elder_adaptation_module_source}" "timer_value.w"
  "Adaptation frame-delta helper contract")
elder_forbid_token("${elder_adaptation_module_source}" "timer_value.x"
  "Adaptation frame-delta helper contract")

file(READ "${elder_parameters}" elder_parameter_source)
foreach(required_parameter_token IN ITEMS
    "[Elder 60] Main Effect | Color-Core Intensity"
    "[Elder 60] Main Effect | Optical Shape"
    "[Elder 70] Postpass | Vignette Strength"
    "[Elder 70] Postpass | Grain Shape"
    "[Elder 80] Sun Sprite | Disc Shape"
    "[Elder 90] Underwater | Density Shape")
  elder_require_token("${elder_parameter_source}" "${required_parameter_token}"
    "Stage parameter UIName contract")
endforeach()

file(READ "${elder_generator}" elder_generator_source)
foreach(forbidden_generator_token IN ITEMS
    "Temporary Task 4 placeholder for Task 5-owned stage controls"
    "Enable=true"
    "IntensityMin=0.000"
    "ShapeMax=2.000")
  elder_forbid_token("${elder_generator_source}" "${forbidden_generator_token}"
    "Quality preset generator")
endforeach()
foreach(required_generator_token IN ITEMS
    "[Elder 10] Prepass | Enabled="
    "[Elder 60] Main Effect | Optical Shape="
    "[Elder 70] Postpass | Vignette Strength="
    "[Elder 80] Sun Sprite | Disc Shape="
    "[Elder 90] Underwater | Density Shape=")
  elder_require_token("${elder_generator_source}" "${required_generator_token}"
    "Quality preset generator")
endforeach()

message(STATUS
  "Elder composition contracts enforce single HDR composition, terminal LDR finish, finite sun/underwater, and Timer.w adaptation")
