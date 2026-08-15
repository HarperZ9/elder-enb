//----------------------------------------------------------------------------------------------//
//                      ENB of the Elders - HDR Compositor                                      //
//----------------------------------------------------------------------------------------------//
//                                                                                              //
//  Main post-processing pass: bloom/lens mixing, adaptation, tonemapping, color grading.       //
//                                                                                              //
//  Pipeline (18 stages):                                                                       //
//    1-4:   Scene input, bloom/lens, fade, adaptation, brightness        (existing)            //
//    5-7:   FILM — characteristic curves, subtractive density, interimage (new)                //
//    8:     Contrast fallback (when FILM disabled)                        (existing)            //
//    9-10:  Tonemapping, AgX Punchy look                                  (existing + new)     //
//    11-16: GRADE — highlight desat, printer lights, color temp,          (new)                //
//                    split-toning, ASC-CDL, bleach bypass                                      //
//    17-18: Saturation, dither                                            (existing)            //
//                                                                                              //
//  All new features default to OFF — backward-compatible with previous output.                 //
//                                                                                              //
//  Base: the "ENB of the Elders" (EotE) preset shader stack. The stages marked                 //
//  (existing) above are its work; the FILM and GRADE stages, the tonemapper                    //
//  selector and the AgX look are additions.                                                    //
//  Framework: Boris Vorontsov / ENBSeries. TextureColor and TextureDepth are                   //
//  his host inputs, and the pass contract is his.                                              //
//                                                                                              //
//  Per-technique references live with the code that uses them:                                 //
//    Film color science: EotE_FilmScience.fxh  (Ottosson, ASC-CDL, H&D curves)                 //
//    Tonemapper library: EotE_Tonemappers.fxh  (Hill, Sobotka, Lottes, GT)                     //
//    Color grading:      Addons/Effect_ColorGrading.fxh                                        //
//                                                                                              //
//  Not credited here on purpose: the adaptation auto-exposure algorithm is                     //
//  kingeric1992's, and it lives in enbadaptation.fx where it is credited. This                 //
//  shader only samples the 1x1 result that shader produces.                                    //
//                                                                                              //
//  Adapted for ENB of the Elders by Zain Dana Harper - March 2026                              //
//                                                                                              //
//----------------------------------------------------------------------------------------------//


//=== ENB EXTERNAL VARIABLES ===//

float4  Timer;

//  Published by the Elder ENB runtime plugin each BeginFrame.
//    x  frame counter, 1-based, wrapped at 2^24; exactly 0 when not live
//    y  frame delta in seconds
//    z  output width      w  output height
//  All zero when the plugin is absent, which every read below tolerates.
float4  ElderRuntimeFramePulse
<
    string UIName = "Elder Runtime | Frame Pulse";
    string UIWidget = "Ignore";
> = {0.0, 0.0, 0.0, 0.0};
float4  ScreenSize;
float   AdaptiveQuality;
float4  Weather;
float4  TimeOfDay1;
float4  TimeOfDay2;
float   ENightDayFactor;
float   EInteriorFactor;
float   FieldOfView;
float4  tempF1;
float4  tempF2;
float4  tempF3;
float4  tempInfo1;
float4  tempInfo2;


//=== GAME PARAMETERS ===//

float4  Params01[7];    // Skyrim SE parameters
float4  ENBParams01;    // x = bloom amount, y = lens amount


//=== TEXTURES ===//

Texture2D   TextureColor;       // HDR scene color (full-res)
Texture2D   TextureBloom;       // Bloom texture from enbbloom.fx
Texture2D   TextureLens;        // Lens effects from enblens.fx
Texture2D   TextureDepth;       // Scene depth
Texture2D   TextureAdaptation;  // 1x1 adaptation value from enbadaptation.fx
Texture2D   TextureAperture;    // 1x1 DOF aperture from enbdepthoffield.fx


//=== SAMPLERS ===//

SamplerState smpPoint
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

SamplerState smpLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};


//=== GLOBALS ===//

#include "enbglobals.fxh"


//=== LIBRARIES ===//

#include "Helper/EotE_Tonemappers.fxh"
#include "Helper/EotE_FilmScience.fxh"
#include "Addons/Effect_ColorGrading.fxh"


//=== UI PARAMETERS ===//

// =============================================================================
//  PIPELINE MODE — Meta-selector for effect chain
// =============================================================================
//
//  0 = Digital   — Clean digital path (no FILM, no GRADE)
//  1 = Film      — Photochemical emulation (FILM on, no GRADE)
//  2 = Hybrid    — Film negative + digital grading (FILM + partial GRADE)
//  3 = Full      — All stages active (FILM + GRADE)
//  4 = Custom    — Individual per-stage bool toggles (existing behavior)
// =============================================================================

int ui_PipelineMode
<
    string UIName = "PIPELINE | Mode (0=Digital 1=Film 2=Hybrid 3=Full 4=Custom)";
    string UIWidget = "Spinner";
    int UIMin = 0;
    int UIMax = 4;
> = {4};

// =============================================================================
//  SCENE
// =============================================================================

bool ui_EnableFade
<
    string UIName = "SCENE | Enable Fade Transition";
> = {true};

// =============================================================================
//  TONEMAP
// =============================================================================

int ui_TonemapMode
<
    string UIName = "TONEMAP | Operator (0=Lin 1=Reinhard 2=Hejl 3=Hable 4=ACES 5=AgX 6=Lottes 7=GT)";
    string UIWidget = "Spinner";
    int UIMin = 0;
    int UIMax = 7;
> = {1};

bool ui_AllowCurveStacking
<
    string UIName = "TONEMAP | Expert - Allow FILM + Tonemap stacking";
> = {false};

float ui_TonemapCurveDay
<
    string UIName = "TONEMAP | Day - Curve";
    string UIWidget = "Spinner";
    float UIMin = 0.01;
    float UIMax = 5.0;
> = {0.5};

float ui_TonemapCurveNight
<
    string UIName = "TONEMAP | Night - Curve";
    string UIWidget = "Spinner";
    float UIMin = 0.01;
    float UIMax = 5.0;
> = {0.5};

float ui_TonemapCurveInterior
<
    string UIName = "TONEMAP | Interior - Curve";
    string UIWidget = "Spinner";
    float UIMin = 0.01;
    float UIMax = 5.0;
> = {0.5};

float ui_WhitePointDay
<
    string UIName = "TONEMAP | Day - White Point";
    string UIWidget = "Spinner";
    float UIMin = 1.0;
    float UIMax = 200.0;
> = {60.0};

float ui_WhitePointNight
<
    string UIName = "TONEMAP | Night - White Point";
    string UIWidget = "Spinner";
    float UIMin = 1.0;
    float UIMax = 200.0;
> = {50.0};

float ui_WhitePointInterior
<
    string UIName = "TONEMAP | Interior - White Point";
    string UIWidget = "Spinner";
    float UIMin = 1.0;
    float UIMax = 200.0;
> = {30.0};

float ui_AgXPunchyDay
<
    string UIName = "TONEMAP | Day - AgX Punchy Look";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.0};

float ui_AgXPunchyNight
<
    string UIName = "TONEMAP | Night - AgX Punchy Look";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.0};

float ui_AgXPunchyInterior
<
    string UIName = "TONEMAP | Interior - AgX Punchy Look";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.0};

float ui_HuntEffect
<
    string UIName = "TONEMAP | Hunt Effect (bright area saturation)";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.5;
    float UIStep = 0.01;
> = {0.0};

float ui_StevensEffect
<
    string UIName = "TONEMAP | Stevens Effect (bright area contrast)";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.01;
> = {0.0};

float ui_PurkinjeStrength
<
    string UIName = "COLOR | Purkinje Shift (mesopic night vision)";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.01;
> = {0.0};

// =============================================================================
//  ADAPT
// =============================================================================

float ui_AdaptMaxDay
<
    string UIName = "ADAPT | Day - Max";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 10.0;
> = {1.0};

float ui_AdaptMaxNight
<
    string UIName = "ADAPT | Night - Max";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 10.0;
> = {1.0};

float ui_AdaptMaxInterior
<
    string UIName = "ADAPT | Interior - Max";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 10.0;
> = {1.0};

float ui_AdaptMinDay
<
    string UIName = "ADAPT | Day - Min";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.001;
> = {0.05};

float ui_AdaptMinNight
<
    string UIName = "ADAPT | Night - Min";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.001;
> = {0.05};

float ui_AdaptMinInterior
<
    string UIName = "ADAPT | Interior - Min";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.001;
> = {0.05};

float ui_FilmicAdaptStr
<
    string UIName = "ADAPT | Filmic Adapt Strength (WP modulation)";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.01;
> = {0.0};

// =============================================================================
//  COLOR (Brightness / Contrast / Saturation)
// =============================================================================

float ui_BrightnessDay
<
    string UIName = "COLOR | Day - Brightness";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 5.0;
> = {1.0};

float ui_BrightnessNight
<
    string UIName = "COLOR | Night - Brightness";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 5.0;
> = {0.75};

float ui_BrightnessInterior
<
    string UIName = "COLOR | Interior - Brightness";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 5.0;
> = {1.0};

float ui_ContrastDay
<
    string UIName = "COLOR | Day - Contrast";
    string UIWidget = "Spinner";
    float UIMin = 0.1;
    float UIMax = 3.0;
> = {1.0};

float ui_ContrastNight
<
    string UIName = "COLOR | Night - Contrast";
    string UIWidget = "Spinner";
    float UIMin = 0.1;
    float UIMax = 3.0;
> = {1.0};

float ui_ContrastInterior
<
    string UIName = "COLOR | Interior - Contrast";
    string UIWidget = "Spinner";
    float UIMin = 0.1;
    float UIMax = 3.0;
> = {1.0};

float ui_SaturationDay
<
    string UIName = "COLOR | Day - Saturation";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 5.0;
> = {1.0};

float ui_SaturationNight
<
    string UIName = "COLOR | Night - Saturation";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 5.0;
> = {0.9};

float ui_SaturationInterior
<
    string UIName = "COLOR | Interior - Saturation";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 5.0;
> = {1.0};

// =============================================================================
//  FILM (Photochemical Emulation Pipeline)
// =============================================================================

bool ui_FilmEnable
<
    string UIName = "FILM | Enable Film Pipeline";
> = {false};

int ui_FilmNegStock
<
    string UIName = "FILM | Negative Stock (0=500T 1=250D 2=Eterna 3=Custom)";
    string UIWidget = "Spinner";
    int UIMin = 0;
    int UIMax = 3;
> = {0};

float ui_FilmNegIntensity
<
    string UIName = "FILM | Negative Curve Intensity";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {1.0};

float ui_FilmPrintIntensity
<
    string UIName = "FILM | Print Curve Intensity";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.5};

float ui_FilmToeR
<
    string UIName = "FILM | Custom Toe R";
    string UIWidget = "Spinner";
    float UIMin = 0.01;
    float UIMax = 0.5;
> = {0.12};

float ui_FilmToeG
<
    string UIName = "FILM | Custom Toe G";
    string UIWidget = "Spinner";
    float UIMin = 0.01;
    float UIMax = 0.5;
> = {0.10};

float ui_FilmToeB
<
    string UIName = "FILM | Custom Toe B";
    string UIWidget = "Spinner";
    float UIMin = 0.01;
    float UIMax = 0.5;
> = {0.14};

float ui_FilmGammaR
<
    string UIName = "FILM | Custom Gamma R";
    string UIWidget = "Spinner";
    float UIMin = 0.2;
    float UIMax = 1.0;
> = {0.58};

float ui_FilmGammaG
<
    string UIName = "FILM | Custom Gamma G";
    string UIWidget = "Spinner";
    float UIMin = 0.2;
    float UIMax = 1.0;
> = {0.55};

float ui_FilmGammaB
<
    string UIName = "FILM | Custom Gamma B";
    string UIWidget = "Spinner";
    float UIMin = 0.2;
    float UIMax = 1.0;
> = {0.52};

float ui_FilmShoulderR
<
    string UIName = "FILM | Custom Shoulder R";
    string UIWidget = "Spinner";
    float UIMin = 1.0;
    float UIMax = 5.0;
> = {2.2};

float ui_FilmShoulderG
<
    string UIName = "FILM | Custom Shoulder G";
    string UIWidget = "Spinner";
    float UIMin = 1.0;
    float UIMax = 5.0;
> = {2.4};

float ui_FilmShoulderB
<
    string UIName = "FILM | Custom Shoulder B";
    string UIWidget = "Spinner";
    float UIMin = 1.0;
    float UIMax = 5.0;
> = {2.8};

float ui_FilmDensity
<
    string UIName = "FILM | Subtractive Density";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 2.0;
> = {0.0};

float ui_FilmInterimage
<
    string UIName = "FILM | Interimage Effect (Dev Inhibition)";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 2.0;
> = {0.0};

// =============================================================================
//  GRADE (Professional Color Grading)
// =============================================================================

bool ui_GradeEnable
<
    string UIName = "GRADE | Enable Color Grading";
> = {false};

// --- Highlight Desaturation (Oklab Path-to-White) ---

bool ui_HighlightDesatEnable
<
    string UIName = "GRADE | Enable Highlight Desaturation";
> = {true};

float ui_HighlightDesatStart
<
    string UIName = "GRADE | Highlight Desat Start Lightness";
    string UIWidget = "Spinner";
    float UIMin = 0.3;
    float UIMax = 0.95;
> = {0.65};

float ui_HighlightDesatStrength
<
    string UIName = "GRADE | Highlight Desat Strength";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.7};

// --- Printer Lights (Per-Channel Exposure, 1-50 scale, 25 = neutral) ---

float ui_PrinterR_Day
<
    string UIName = "GRADE | Day - Printer Light R";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

float ui_PrinterG_Day
<
    string UIName = "GRADE | Day - Printer Light G";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

float ui_PrinterB_Day
<
    string UIName = "GRADE | Day - Printer Light B";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

float ui_PrinterR_Night
<
    string UIName = "GRADE | Night - Printer Light R";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

float ui_PrinterG_Night
<
    string UIName = "GRADE | Night - Printer Light G";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

float ui_PrinterB_Night
<
    string UIName = "GRADE | Night - Printer Light B";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

float ui_PrinterR_Interior
<
    string UIName = "GRADE | Interior - Printer Light R";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

float ui_PrinterG_Interior
<
    string UIName = "GRADE | Interior - Printer Light G";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

float ui_PrinterB_Interior
<
    string UIName = "GRADE | Interior - Printer Light B";
    string UIWidget = "Spinner";
    float UIMin = 15.0;
    float UIMax = 35.0;
> = {25.0};

// --- Color Temperature ---

float ui_ColorTempDay
<
    string UIName = "GRADE | Day - Color Temp (K)";
    string UIWidget = "Spinner";
    float UIMin = 3000.0;
    float UIMax = 12000.0;
> = {6500.0};

float ui_ColorTempNight
<
    string UIName = "GRADE | Night - Color Temp (K)";
    string UIWidget = "Spinner";
    float UIMin = 3000.0;
    float UIMax = 12000.0;
> = {6500.0};

float ui_ColorTempInterior
<
    string UIName = "GRADE | Interior - Color Temp (K)";
    string UIWidget = "Spinner";
    float UIMin = 3000.0;
    float UIMax = 12000.0;
> = {6500.0};

// --- Split-Toning (Oklab-Based) ---

bool ui_SplitToneEnable
<
    string UIName = "GRADE | Enable Split-Toning";
> = {false};

float3 ui_SplitShadowTint
<
    string UIName = "GRADE | Shadow Tint (RGB)";
    string UIWidget = "Color";
> = {0.5, 0.5, 0.6};

float3 ui_SplitHighlightTint
<
    string UIName = "GRADE | Highlight Tint (RGB)";
    string UIWidget = "Color";
> = {0.6, 0.55, 0.5};

float ui_SplitBalance
<
    string UIName = "GRADE | Split-Tone Balance";
    string UIWidget = "Spinner";
    float UIMin = 0.2;
    float UIMax = 0.8;
> = {0.5};

float ui_SplitIntensity
<
    string UIName = "GRADE | Split-Tone Intensity";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.3};

// --- ASC-CDL ---

float ui_CDLSlopeR
<
    string UIName = "GRADE | CDL Slope R";
    string UIWidget = "Spinner";
    float UIMin = 0.5;
    float UIMax = 2.0;
> = {1.0};

float ui_CDLSlopeG
<
    string UIName = "GRADE | CDL Slope G";
    string UIWidget = "Spinner";
    float UIMin = 0.5;
    float UIMax = 2.0;
> = {1.0};

float ui_CDLSlopeB
<
    string UIName = "GRADE | CDL Slope B";
    string UIWidget = "Spinner";
    float UIMin = 0.5;
    float UIMax = 2.0;
> = {1.0};

float ui_CDLOffsetR
<
    string UIName = "GRADE | CDL Offset R";
    string UIWidget = "Spinner";
    float UIMin = -0.2;
    float UIMax = 0.2;
> = {0.0};

float ui_CDLOffsetG
<
    string UIName = "GRADE | CDL Offset G";
    string UIWidget = "Spinner";
    float UIMin = -0.2;
    float UIMax = 0.2;
> = {0.0};

float ui_CDLOffsetB
<
    string UIName = "GRADE | CDL Offset B";
    string UIWidget = "Spinner";
    float UIMin = -0.2;
    float UIMax = 0.2;
> = {0.0};

float ui_CDLPowerR
<
    string UIName = "GRADE | CDL Power R";
    string UIWidget = "Spinner";
    float UIMin = 0.5;
    float UIMax = 3.0;
> = {1.0};

float ui_CDLPowerG
<
    string UIName = "GRADE | CDL Power G";
    string UIWidget = "Spinner";
    float UIMin = 0.5;
    float UIMax = 3.0;
> = {1.0};

float ui_CDLPowerB
<
    string UIName = "GRADE | CDL Power B";
    string UIWidget = "Spinner";
    float UIMin = 0.5;
    float UIMax = 3.0;
> = {1.0};

float ui_CDLSaturation
<
    string UIName = "GRADE | CDL Saturation";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 2.0;
> = {1.0};

// --- Bleach Bypass ---

float ui_BleachBypassDay
<
    string UIName = "GRADE | Day - Bleach Bypass";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.0};

float ui_BleachBypassNight
<
    string UIName = "GRADE | Night - Bleach Bypass";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.0};

float ui_BleachBypassInterior
<
    string UIName = "GRADE | Interior - Bleach Bypass";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
> = {0.0};

// =============================================================================
//  LOCAL TONE MAP (from bloom buffer — zero additional passes)
// =============================================================================

bool ui_LocalToneEnable
<
    string UIName = "LOCAL | Enable Local Tone Mapping";
> = {false};

float ui_LocalToneStrength
<
    string UIName = "LOCAL | Strength";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 2.0;
    float UIStep = 0.01;
> = {0.3};

float ui_LocalToneMipLevel
<
    string UIName = "LOCAL | Mip Level (radius control)";
    string UIWidget = "Spinner";
    float UIMin = 3.0;
    float UIMax = 9.0;
    float UIStep = 0.5;
> = {6.0};


//=== CONSTANTS ===//

static const float3 LUM = float3(0.2126, 0.7152, 0.0722);


//=== VERTEX SHADER ===//

void VS_Draw(inout float4 pos : SV_POSITION, inout float2 txcoord : TEXCOORD0)
{
    pos.w = 1.0;
}


//=== PIXEL SHADER ===//

float4 PS_Draw(float4 pos : SV_POSITION, float2 txcoord : TEXCOORD0) : SV_Target
{
    // =================================================================
    //  Pipeline routing — resolve which stage groups are active
    //  Mode 4 (Custom) = both true, individual stage bools control.
    // =================================================================

    int pipeMode = ui_PipelineMode;
    bool filmOn  = (pipeMode == 1 || pipeMode == 2 || pipeMode >= 3);
    bool gradeOn = (pipeMode == 2 || pipeMode >= 3);

    // =================================================================
    //  Stage 1: Sample scene + bloom + lens
    // =================================================================

    float4 color = TextureColor.SampleLevel(smpPoint, txcoord, 0);

    float3 lens = TextureLens.SampleLevel(smpLinear, txcoord, 0).rgb;
    color.rgb += lens * ENBParams01.y;

    float3 bloom = TextureBloom.SampleLevel(smpLinear, txcoord, 0).rgb;
    bloom = max(bloom - color.rgb, 0.0);
    color.rgb += bloom * ENBParams01.x;

    // =================================================================
    //  Stage 2: Fade transition
    // =================================================================

    if (ui_EnableFade)
    {
        float3 fadeColor = Params01[5].xyz;
        float fadeWeight = Params01[5].w;
        color.rgb = lerp(color.rgb, fadeColor, fadeWeight);
    }

    // =================================================================
    //  Stage 3: Adaptation + DNI interpolation
    // =================================================================

    float adaptation = TextureAdaptation.SampleLevel(smpPoint, 0.5, 0).x;
    adaptation = clamp(adaptation, 0.001, 50.0);

    float adaptMax = lerp(lerp(ui_AdaptMaxNight, ui_AdaptMaxDay, ENightDayFactor),
                          ui_AdaptMaxInterior, EInteriorFactor);
    float adaptMin = lerp(lerp(ui_AdaptMinNight, ui_AdaptMinDay, ENightDayFactor),
                          ui_AdaptMinInterior, EInteriorFactor);
    float brightness = lerp(lerp(ui_BrightnessNight, ui_BrightnessDay, ENightDayFactor),
                            ui_BrightnessInterior, EInteriorFactor);
    float contrast = lerp(lerp(ui_ContrastNight, ui_ContrastDay, ENightDayFactor),
                          ui_ContrastInterior, EInteriorFactor);
    float saturation = lerp(lerp(ui_SaturationNight, ui_SaturationDay, ENightDayFactor),
                            ui_SaturationInterior, EInteriorFactor);
    float curve = lerp(lerp(ui_TonemapCurveNight, ui_TonemapCurveDay, ENightDayFactor),
                       ui_TonemapCurveInterior, EInteriorFactor);
    float whitePoint = lerp(lerp(ui_WhitePointNight, ui_WhitePointDay, ENightDayFactor),
                            ui_WhitePointInterior, EInteriorFactor);

    // Theme overrides (when active, replaces DNI-interpolated values with preset)
    brightness  = TF(brightness,  GetTheme().brightness);
    contrast    = TF(contrast,    GetTheme().contrast);
    saturation  = TF(saturation,  GetTheme().saturation);
    curve       = TF(curve,       GetTheme().curve);
    whitePoint  = TF(whitePoint,  GetTheme().whitePoint);

    // =================================================================
    //  Stage 4: Adaptation (exposure normalization) + Brightness
    // =================================================================

    color.rgb = color.rgb / max(adaptation * adaptMax + adaptMin, 1e-4);
    color.rgb *= brightness;

    // =================================================================
    //  Stage 4a: Purkinje Shift (mesopic vision — physics-based night vision)
    //  Replaces artistic night desaturation with spectral sensitivity
    //  redistribution: rods peak at 507nm (blue-green), not 555nm (green).
    //  Desaturation is hue-dependent (reds darken, blues persist).
    // =================================================================

    [branch] if (ui_PurkinjeStrength > 0.001)
    {
        static const float3 SCOTOPIC_W = float3(0.062, 0.681, 0.257);
        static const float3 PHOTOPIC_W = float3(0.2126, 0.7152, 0.0722);

        // Mesopic blend: 1.0 = photopic (day), 0.0 = scotopic (night)
        float logL = log2(max(adaptation, 1e-6));
        float tanhX = (logL + 3.32) * 0.8;
        float tanhX2 = tanhX * tanhX;
        float tanhApprox = tanhX * (27.0 + tanhX2) / (27.0 + 9.0 * tanhX2);
        float mesoBlend = saturate(0.5 + 0.5 * tanhApprox);

        // Weighted luminance shifts as rod sensitivity dominates
        float3 mesoWeights = lerp(SCOTOPIC_W, PHOTOPIC_W, mesoBlend);
        float mesoLuma = dot(color.rgb, mesoWeights);

        // Hue-dependent desaturation (R desaturates fully, B retains)
        float photoLuma = dot(color.rgb, PHOTOPIC_W);
        float3 pChroma = color.rgb - photoLuma;
        float3 desatRate = float3(1.0, 0.9, 0.6);
        float3 desaturated = mesoLuma + pChroma * mesoBlend * desatRate;

        // Scotopic blue-green tint (rhodopsin peak at 507nm)
        float3 scotopicTint = float3(0.45, 0.78, 1.0);
        float3 fullScotopic = mesoLuma * scotopicTint;

        // Blend photopic <-> scotopic
        float3 purkinjeResult = lerp(fullScotopic, desaturated, mesoBlend);

        // Energy conservation
        float pResultLuma = dot(purkinjeResult, mesoWeights);
        purkinjeResult *= mesoLuma / max(pResultLuma, 1e-6);

        color.rgb = lerp(color.rgb, max(purkinjeResult, 0.0), ui_PurkinjeStrength);
    }

    // =================================================================
    //  Stage 4b: Local Tone Mapping (from bloom buffer — zero extra passes)
    //  Samples bloom at high mip level as local average luminance,
    //  applies Reinhard-style local operator to compress dynamic range.
    //  Preserves local detail while controlling global exposure.
    // =================================================================

    [branch] if (TB(ui_LocalToneEnable, GetTheme().localToneEnable))
    {
        float localStr = TF(ui_LocalToneStrength, GetTheme().localToneStr);
        // Sample bloom at configurable mip level for local average
        // mip 6 of 1024 = 16x16 avg, mip 8 = 4x4 avg
        float3 localAvg = TextureBloom.SampleLevel(smpLinear, txcoord, ui_LocalToneMipLevel).rgb;
        float localLuma = max(dot(localAvg, LUM), 1e-4);

        // Reinhard local operator: compress bright areas, expand dark areas
        // scale = 1/(1 + localLuma*strength) — localLuma high → darken, low → brighten
        float localScale = 1.0 / (1.0 + localLuma * localStr);

        // Also boost dark areas slightly (local tone mapping should work both ways)
        float sceneLuma = dot(color.rgb, LUM);
        float darkBoost = saturate(1.0 - sceneLuma * 4.0) * localLuma * localStr * 0.3;

        color.rgb = color.rgb * localScale + color.rgb * darkBoost;
    }

    // =================================================================
    //  Stages 5-7: FILM Pipeline (replaces contrast when enabled)
    // =================================================================

    bool filmCurvesApplied = false;

    [branch] if (filmOn && TB(ui_FilmEnable, GetTheme().filmEnable))
    {
        color.rgb = max(color.rgb, 1e-6);

        // --- Stage 5: Film characteristic curves (neg → print) ---

        int filmStock = TI(ui_FilmNegStock, GetTheme().filmNegStock);
        float filmNegStr = TF(ui_FilmNegIntensity, GetTheme().filmNegIntensity);
        float filmPrintStr = TF(ui_FilmPrintIntensity, GetTheme().filmPrintIntensity);
        float filmDens = TF(ui_FilmDensity, GetTheme().filmDensity);
        float filmInter = TF(ui_FilmInterimage, GetTheme().filmInterimage);

        // The characteristic curves are a complete display transform;
        // stage 9 must know they ran.
        filmCurvesApplied = (filmNegStr > 0.001) || (filmPrintStr > 0.001);

        float3 negToe, negGamma, negShoulder, negWP;

        [branch] if (filmStock < 3)
        {
            int idx = filmStock;
            negToe      = NEG_TOE[idx];
            negGamma    = NEG_GAMMA[idx];
            negShoulder = NEG_SHOULDER[idx];
            negWP       = NEG_WP[idx];
        }
        else
        {
            negToe      = float3(ui_FilmToeR, ui_FilmToeG, ui_FilmToeB);
            negGamma    = float3(ui_FilmGammaR, ui_FilmGammaG, ui_FilmGammaB);
            negShoulder = float3(ui_FilmShoulderR, ui_FilmShoulderG, ui_FilmShoulderB);
            negWP       = float3(16.0, 14.0, 12.0);
        }

        // Apply negative characteristic curve
        float3 negResult = ApplyFilmCurves(color.rgb, negToe, negGamma,
                                           negShoulder, negWP);
        negResult = lerp(color.rgb, negResult, filmNegStr);

        // Apply print characteristic curve (Kodak 2383)
        if (filmPrintStr > 0.001)
        {
            float3 printResult = ApplyFilmCurves(negResult, PRINT_TOE, PRINT_GAMMA,
                                                  PRINT_SHOULDER, PRINT_WP);
            printResult = max(printResult, 0.0);   // clamp deferred to Stage 18 encode
            color.rgb = lerp(negResult, printResult, filmPrintStr);
        }
        else
        {
            color.rgb = negResult;
        }

        // --- Stage 6: Beer-Lambert subtractive density ---

        if (filmDens > 0.001)
            color.rgb = ApplySubtractiveDensity(color.rgb, filmDens);

        // --- Stage 7: Interimage effect ---
        // (floored below: the inhibition matrix can push channels negative)

        if (filmInter > 0.001)
            color.rgb = max(ApplyInterimageEffect(color.rgb, filmInter), 0.0);
    }
    else
    {
        // =================================================================
        //  Stage 8: Log-domain contrast (when FILM disabled)
        //  Preserves photographic midpoint (0.18 gray). Mathematically equivalent
        //  to pow(x/m,c)*m but more numerically stable for HDR values.
        // =================================================================

        color.rgb = max(color.rgb, 1e-6);
        float3 logC = log2(color.rgb);
        float logMid = log2(0.18);
        color.rgb = exp2((logC - logMid) * contrast + logMid);
    }

    // =================================================================
    //  Stage 8b: UC2 Filmic Adaptation (white point follows scene brightness)
    //  Brighter adaptation → higher white point → more headroom → less compression.
    //  Creates the "film look" where bright scenes feel more open.
    // =================================================================

    // Only Reinhard (1) and GT (7) brighten with a higher white point;
    // Hejl (2) DIVIDES by it, inverting the intent, and the rest ignore it.
    int tonemapModePre = TI(ui_TonemapMode, GetTheme().tonemapMode);
    if (ui_FilmicAdaptStr > 0.001 && (tonemapModePre == 1 || tonemapModePre == 7))
        whitePoint *= lerp(1.0, adaptation * 2.0, ui_FilmicAdaptStr);

    // =================================================================
    //  Stage 8c: Unified Color Appearance Model (Hunt + Stevens)
    //  Hunt: colorfulness scales with luminance^0.25 (CIECAM02 F_L term)
    //  Stevens: perceived contrast scales with luminance^0.15 (Krawczyk 2005)
    //  Together these replace manual per-weather saturation/contrast with
    //  physics-derived corrections driven by adapted luminance.
    // =================================================================

    if (ui_HuntEffect > 0.001 || ui_StevensEffect > 0.001)
    {
        float refLuma = 0.18;
        float lumaRatio = max(adaptation / max(refLuma, 0.001), 0.01);

        // Hunt: colorfulness ∝ luminance^0.25
        float camLuma = dot(color.rgb, LUM);
        float3 camChroma = color.rgb - camLuma;
        float huntScale = lerp(1.0, pow(lumaRatio, 0.25), ui_HuntEffect);
        color.rgb = camLuma + camChroma * huntScale;

        // Stevens: contrast ∝ luminance^0.15 (pivot around adapted luminance)
        if (ui_StevensEffect > 0.001)
        {
            float stevensScale = lerp(1.0, pow(lumaRatio, 0.15), ui_StevensEffect);
            color.rgb = adaptation + (color.rgb - adaptation) * stevensScale;
        }

        color.rgb = max(color.rgb, 0.0);
    }

    // =================================================================
    //  Stage 9: Tonemapping
    // =================================================================

    int tonemapMode = TI(ui_TonemapMode, GetTheme().tonemapMode);

    // Single display-transform authority: when the FILM curves ran this
    // frame the signal is already display-shaped (and ~[0,1]); stacking a
    // second operator crushes shadows and skews hue, and the whitePoint
    // scale is meaningless for that input. Film output therefore passes
    // through linearly unless stacking is explicitly allowed.
    [branch] if (filmCurvesApplied && !ui_AllowCurveStacking)
        tonemapMode = 0;

    color.rgb = ApplyTonemap(color.rgb, tonemapMode, curve, whitePoint, 1.0);

    // =================================================================
    //  Stage 10: AgX Punchy look (only when AgX selected)
    // =================================================================

    [branch] if (tonemapMode == 5)
    {
        float agxPunchy = lerp(lerp(ui_AgXPunchyNight, ui_AgXPunchyDay, ENightDayFactor),
                               ui_AgXPunchyInterior, EInteriorFactor);
        if (agxPunchy > 0.001)
        {
            float pLuma = dot(color.rgb, LUM);
            float3 pSaturated = pLuma + 1.35 * (color.rgb - pLuma);
            color.rgb = saturate(lerp(color.rgb, pSaturated, agxPunchy));
        }
    }

    // =================================================================
    //  Stages 11-16: GRADE Pipeline
    // =================================================================

    [branch] if (gradeOn && TB(ui_GradeEnable, GetTheme().gradeEnable))
    {
        // --- Stage 11: Highlight desaturation (Oklab path-to-white) ---

        [branch] if (ui_HighlightDesatEnable)
        {
            float hlDesatStr = TF(ui_HighlightDesatStrength, GetTheme().highlightDesatStr);
            float3 lab = SRGBToOklab(saturate(color.rgb));
            float L = lab.x;
            float desat = 1.0 - smoothstep(ui_HighlightDesatStart, 1.0, L);
            desat = lerp(1.0, desat, hlDesatStr);
            lab.yz *= desat;
            color.rgb = OklabToSRGB(lab);
        }

        // --- Stage 12: Printer lights (per-channel exposure) ---
        {
            float pR = lerp(lerp(ui_PrinterR_Night, ui_PrinterR_Day, ENightDayFactor),
                            ui_PrinterR_Interior, EInteriorFactor);
            float pG = lerp(lerp(ui_PrinterG_Night, ui_PrinterG_Day, ENightDayFactor),
                            ui_PrinterG_Interior, EInteriorFactor);
            float pB = lerp(lerp(ui_PrinterB_Night, ui_PrinterB_Day, ENightDayFactor),
                            ui_PrinterB_Interior, EInteriorFactor);

            // Convert 1-50 printer point scale to log exposure multiplier
            // Point 25 = neutral (1.0x), each point = 1/12 stop
            float3 printerMul = pow(2.0, (float3(pR, pG, pB) - 25.0) / 12.0);
            color.rgb = saturate(color.rgb * printerMul);
        }

        // --- Stage 13: Color temperature ---
        {
            float tempK = lerp(lerp(ui_ColorTempNight, ui_ColorTempDay, ENightDayFactor),
                               ui_ColorTempInterior, EInteriorFactor);
            tempK = TF(tempK, GetTheme().colorTemp);
            if (abs(tempK - 6500.0) > 1.0)
                color.rgb = saturate(ApplyWhiteBalance(color.rgb, tempK));
        }

        // --- Stage 14: Split-toning (Oklab-based) ---

        float splitStr = TF(ui_SplitIntensity, GetTheme().splitIntensity);
        [branch] if (TB(ui_SplitToneEnable, GetTheme().splitToneEnable) && splitStr > 0.001)
        {
            float3 splitShadow = ThemeActive()
                ? float3(GetTheme().splitShadowR, GetTheme().splitShadowG, GetTheme().splitShadowB)
                : ui_SplitShadowTint;
            float3 splitHighlight = ThemeActive()
                ? float3(GetTheme().splitHighlightR, GetTheme().splitHighlightG, GetTheme().splitHighlightB)
                : ui_SplitHighlightTint;

            float3 lab = SRGBToOklab(saturate(color.rgb));
            float L = lab.x;

            // Get chrominance offsets from tint colors
            float3 shadowLab = SRGBToOklab(splitShadow);
            float3 highlightLab = SRGBToOklab(splitHighlight);

            // Blend tint chrominance based on lightness zone
            float shadowW = smoothstep(ui_SplitBalance, ui_SplitBalance - 0.3, L);
            float highlightW = smoothstep(ui_SplitBalance, ui_SplitBalance + 0.3, L);

            lab.yz += shadowLab.yz * shadowW * splitStr;
            lab.yz += highlightLab.yz * highlightW * splitStr;

            color.rgb = OklabToSRGB(lab);
        }

        // --- Stage 15: ASC-CDL ---
        {
            float3 cdlSlope  = float3(ui_CDLSlopeR,  ui_CDLSlopeG,  ui_CDLSlopeB);
            float3 cdlOffset = float3(ui_CDLOffsetR, ui_CDLOffsetG, ui_CDLOffsetB);
            float3 cdlPower  = float3(ui_CDLPowerR,  ui_CDLPowerG,  ui_CDLPowerB);

            bool cdlActive = any(cdlSlope != 1.0) || any(cdlOffset != 0.0)
                          || any(cdlPower != 1.0) || ui_CDLSaturation != 1.0;

            if (cdlActive)
                color.rgb = saturate(ApplyASCCDL(color.rgb, cdlSlope, cdlOffset,
                                                 cdlPower, ui_CDLSaturation));
        }

        // --- Stage 16: Bleach bypass ---
        {
            float bleach = lerp(lerp(ui_BleachBypassNight, ui_BleachBypassDay, ENightDayFactor),
                                ui_BleachBypassInterior, EInteriorFactor);
            bleach = TF(bleach, GetTheme().bleachBypass);
            if (bleach > 0.001)
                color.rgb = ApplyBleachBypass(color.rgb, bleach);
        }
    }

    // =================================================================
    //  Stage 16b: Extended Color Grading (Addon)
    // =================================================================

    // The extended suite obeys the pipeline mode: in Digital and Film
    // modes it stays off even when its individual enables are set, so two
    // grading systems never fight over the same image.
    [branch] if (gradeOn)
    {
        if (ui_LGGEnable)      color.rgb = CG_LiftGammaGain(color.rgb);
        if (ui_CMixEnable)     color.rgb = CG_ChannelMixer(color.rgb);
        if (ui_HvSEnable)      color.rgb = CG_HueVsSat(color.rgb);
        if (ui_VibranceEnable) color.rgb = CG_Vibrance(color.rgb);
        if (ui_SCurveEnable)   color.rgb = CG_SCurve(color.rgb);
        if (ui_CBEnable)       color.rgb = CG_ColorBalance(color.rgb);
        if (ui_ClarityEnable)  color.rgb = CG_Clarity(color.rgb, txcoord);
    }

    // =================================================================
    //  Stage 17: Saturation (luminance-preserving)
    // =================================================================

    float luma = dot(color.rgb, LUM);
    color.rgb = max(luma + saturation * (color.rgb - luma), 0.0);

    // =================================================================
    //  Stage 18: Dither + output
    // =================================================================

    //  Interleaved gradient noise, per channel. Static on its own: the pattern
    //  is a function of position only, so it sits in the same place every frame
    //  and reads as a fixed grain over a smooth gradient.
    //
    //  When the Elder runtime is live, its frame counter advances the sample
    //  position so the pattern moves. The eye then integrates it away and the
    //  gradient reads smooth, without the spatial cost of averaging across a
    //  block. 5.588238 per frame over a 64-frame cycle is the published IGN
    //  advance; the cycle keeps the value small enough to stay exact however
    //  long the session runs.
    //
    //  Without the plugin the offset is zero and this is bit-for-bit the
    //  original static dither.
    float ditherCycle = (ElderRuntimeFramePulse.x >= 1.0)
        ? fmod(ElderRuntimeFramePulse.x, 64.0)
        : 0.0;
    float2 ditherPos = pos.xy + (5.588238 * ditherCycle).xx;

    float3 noise = float3(
        frac(52.9829189 * frac(dot(ditherPos, float2(0.06711056, 0.00583715)))),
        frac(52.9829189 * frac(dot(ditherPos + 72.0, float2(0.06711056, 0.00583715)))),
        frac(52.9829189 * frac(dot(ditherPos + 144.0, float2(0.06711056, 0.00583715))))
    );
    color.rgb += (noise - 0.5) / 255.0;

    // NaN sanitization: one NaN cascades through all weighted averaging
    // Can originate from divide-by-zero in adaptation, log of negative in film, etc.
    color.rgb = (any(isnan(color.rgb)) || any(isinf(color.rgb))) ? 0.0 : saturate(color.rgb);

    return color;
}


//=== TECHNIQUES ===//

technique11 EotE_Draw <string UIName = "EotE: HDR Compositor";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, VS_Draw()));
        SetPixelShader(CompileShader(ps_5_0, PS_Draw()));
    }
}
