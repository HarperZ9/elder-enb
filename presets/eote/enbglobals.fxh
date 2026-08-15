//----------------------------------------------------------------------------------------------//
//  enbglobals.fxh — Shared globals for ENB of the Elders
//
//  Included by all 9 .fx shader files. Declares the theme selector UI and
//  pulls in the theme system. Does NOT redeclare ENB native variables
//  (Timer, ScreenSize, etc.) — each shader declares its own.
//
//  Zain Dana Harper - March 2026
//----------------------------------------------------------------------------------------------//

#ifndef ENBGLOBALS_FXH
#define ENBGLOBALS_FXH


// =============================================================================
//  THEME SYSTEM — Visual preset selector
// =============================================================================
//
//  0 = Manual (no override, all params use their individual UI values)
//  1 = Cinematic     — ACES, warm film, halation
//  2 = Fantasy       — AgX, vibrant, diffused, cool shadows
//  3 = Photorealistic— AgX, neutral, minimal FX
//  4 = Film Noir     — Reinhard, high contrast, desaturated, strong vignette
//  5 = Vintage Film  — Reinhard, warm stock, grain, halation
//  6 = Horror        — Lottes, cold, desaturated, narrow adaptation
//  7 = Ethereal      — Linear, soft, bloomy, pastel
// =============================================================================

int ui_EotE_Theme
<
    string UIName = "THEME | Preset (0=Manual 1=Cine 2=Fantasy 3=Photo 4=Noir 5=Vintage 6=Horror 7=Ethereal)";
    string UIWidget = "Spinner";
    int UIMin = 0;
    int UIMax = 7;
> = {0};

// Optional SkyrimBridge sync — C++ reads theme from enbeffect.fx and pushes to all shaders
extern float4 SB_Theme_Config
<
    string UIName = "SB_Theme_Config";
    int UIHidden = 1;
>;


// =============================================================================
//  THEME SYSTEM IMPLEMENTATION
// =============================================================================

#include "Helper/EotE_ThemeSystem.fxh"


// =============================================================================
//  QUALITY TIER — Compile-time sample count control
// =============================================================================
//  Change QUALITY_TIER and relaunch to adjust performance/quality trade-off:
//    0 = Low    (minimum samples, max performance)
//    1 = Medium (balanced — default)
//    2 = High   (maximum quality, more samples)
//
//  Referenced by: enbeffectprepass.fx (AO/GI slices/steps),
//                 enbdepthoffield.fx (ring count), enbbloom.fx (Gaussian loop).
// =============================================================================

#ifndef QUALITY_TIER
#define QUALITY_TIER  1
#endif

// Per-tier sample counts (shaders use these instead of hardcoded values)
#if QUALITY_TIER == 0
    #define QT_AO_DIRS      8
    #define QT_AO_STEPS     4
    #define QT_VOL_STEPS   16
    #define QT_DOF_RINGS    3
#elif QUALITY_TIER == 2
    #define QT_AO_DIRS     16
    #define QT_AO_STEPS     8
    #define QT_VOL_STEPS   48
    #define QT_DOF_RINGS    5
#else  // QUALITY_TIER == 1 (default)
    #define QT_AO_DIRS     12
    #define QT_AO_STEPS     6
    #define QT_VOL_STEPS   32
    #define QT_DOF_RINGS    4
#endif


#endif // ENBGLOBALS_FXH
