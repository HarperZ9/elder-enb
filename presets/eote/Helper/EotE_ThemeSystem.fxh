//----------------------------------------------------------------------------------------------//
//  EotE_ThemeSystem.fxh — Theme preset system for ENB of the Elders
//
//  Provides 7 curated visual presets that override key parameters across all shaders.
//  Theme 0 (Manual) = no override, all params use their manual UI values.
//
//  Usage in shader code:
//    float val = TF(manualValue, GetTheme().fieldName);
//    bool  on  = TB(ui_BoolParam, GetTheme().boolField);
//    int   idx = TI(ui_IntParam,  GetTheme().intField);
//
//  Requires: ui_EotE_Theme declared in enbglobals.fxh before this include.
//----------------------------------------------------------------------------------------------//

#ifndef EOTE_THEME_SYSTEM_FXH
#define EOTE_THEME_SYSTEM_FXH


//=== THEME PARAMETER STRUCT ===//
// All fields are float for static const array compatibility.
// Bools are 0.0/1.0, ints are truncated at point of use.

struct ThemeParams
{
    // --- enbeffect.fx: Tonemap ---
    float tonemapMode;          // 0=Lin 1=Reinhard 2=Hejl 3=Hable 4=ACES 5=AgX 6=Lottes
    float curve;                // Tonemap curve strength
    float whitePoint;           // Tonemap white point
    float brightness;           // Scene brightness multiplier
    float contrast;             // Log-domain contrast
    float saturation;           // Final saturation

    // --- enbeffect.fx: Film Pipeline ---
    float filmEnable;           // 0/1
    float filmNegStock;         // 0=500T 1=250D 2=Eterna 3=Custom
    float filmNegIntensity;     // Negative curve blend
    float filmPrintIntensity;   // Print curve blend
    float filmDensity;          // Beer-Lambert density
    float filmInterimage;       // Interimage effect

    // --- enbeffect.fx: Grade Pipeline ---
    float gradeEnable;          // 0/1
    float highlightDesatStr;    // Highlight desaturation strength
    float colorTemp;            // Kelvin (6500 = neutral)
    float splitToneEnable;      // 0/1
    float splitShadowR;         // Shadow tint RGB
    float splitShadowG;
    float splitShadowB;
    float splitHighlightR;      // Highlight tint RGB
    float splitHighlightG;
    float splitHighlightB;
    float splitIntensity;       // Split-tone mix strength
    float bleachBypass;         // Bleach bypass strength

    // --- enbeffect.fx: Local Tone ---
    float localToneEnable;      // 0/1
    float localToneStr;         // Local tone mapping strength

    // --- enbbloom.fx ---
    float bloomIntensity;       // Bloom intensity multiplier
    float bloomSpectralTint;    // Warm-near / cool-far tinting

    // --- enbadaptation.fx ---
    float adaptBias;            // Exposure bias (log2 stops)

    // --- enbeffectpostpass.fx ---
    float diffusionEnable;      // 0/1
    float diffusionStr;         // Lens diffusion strength
    float halationEnable;       // 0/1
    float halationStr;          // Film halation strength
    float vignetteEnable;       // 0/1
    float vignetteStr;          // Optical vignette strength
    float grainIntensity;       // Film grain intensity
    float sharpenStr;           // CAS sharpening intensity

    // --- enbsunsprite.fx ---
    float sunspriteIntensity;   // Sun sprite global intensity
};


//=== PRESET DEFINITIONS ===//

static const ThemeParams THEME_PRESETS[8] =
{
    // -----------------------------------------------------------------------
    // 0: Manual — values are never read (ThemeActive() = false)
    // -----------------------------------------------------------------------
    {
        1, 0.5, 60.0, 1.0, 1.0, 1.0,          // tonemap
        0, 0, 1.0, 0.5, 0.0, 0.0,              // film (off)
        0, 0.7, 6500.0,                         // grade (off)
        0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.3, 0.0,  // split + bleach
        0, 0.0,                                 // local tone (off)
        1.0, 0.0,                               // bloom
        0.0,                                    // adapt bias
        0, 0.25, 0, 0.20, 0, 0.5, 0.0, 0.5,   // postpass (all off)
        1.0                                     // sunsprite
    },

    // -----------------------------------------------------------------------
    // 1: Cinematic — ACES, warm film, halation, understated color
    //    Emulates high-budget digital cinema with a warm, filmic falloff.
    // -----------------------------------------------------------------------
    {
        4, 0.5, 60.0, 1.0, 1.15, 0.95,         // ACES, slightly elevated contrast
        1, 0, 0.8, 0.5, 0.0, 0.0,              // film: 500T neg, moderate
        1, 0.7, 5500.0,                         // grade on, warm temp
        1, 0.50, 0.45, 0.40,                    // warm shadows
           0.60, 0.55, 0.50, 0.25, 0.0,         // warm highlights, no bleach
        0, 0.0,                                 // local tone off
        1.2, 0.15,                              // slightly boosted bloom, gentle spectral
        0.0,                                    // neutral adapt
        0, 0.0, 1, 0.30, 0, 0.0, 0.0, 0.5,    // halation on
        1.0                                     // normal sunsprite
    },

    // -----------------------------------------------------------------------
    // 2: Fantasy — AgX, vibrant, diffused, cool shadows, warm highlights
    //    Lush and dreamlike, ideal for verdant landscapes and magic.
    // -----------------------------------------------------------------------
    {
        5, 0.5, 60.0, 1.05, 0.90, 1.30,        // AgX, low contrast, high sat
        0, 0, 1.0, 0.5, 0.0, 0.0,              // film off
        1, 0.5, 6500.0,                         // grade on, neutral temp
        1, 0.40, 0.45, 0.60,                    // cool blue-ish shadows
           0.60, 0.55, 0.45, 0.30, 0.0,         // warm highlights
        0, 0.0,                                 // local tone off
        1.5, 0.20,                              // generous bloom, spectral tint
        0.0,                                    // neutral adapt
        1, 0.35, 0, 0.0, 0, 0.0, 0.0, 0.4,    // diffusion on, soft look
        1.2                                     // slightly boosted sunsprite
    },

    // -----------------------------------------------------------------------
    // 3: Photorealistic — AgX, neutral, minimal processing
    //    Clean and accurate, lets the game's lighting speak for itself.
    // -----------------------------------------------------------------------
    {
        5, 0.5, 60.0, 1.0, 1.0, 1.0,           // AgX, all neutral
        0, 0, 1.0, 0.5, 0.0, 0.0,              // film off
        0, 0.7, 6500.0,                         // grade off, neutral
        0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.0, 0.0,  // no split, no bleach
        0, 0.0,                                 // local tone off
        0.8, 0.0,                               // restrained bloom, no spectral
        0.0,                                    // neutral adapt
        0, 0.0, 0, 0.0, 0, 0.0, 0.0, 0.6,     // no FX, slightly stronger sharpen
        0.8                                     // subtle sunsprite
    },

    // -----------------------------------------------------------------------
    // 4: Film Noir — Reinhard, high contrast, desaturated, strong vignette
    //    Hard shadows, bleached tones, heavy vignetting.
    // -----------------------------------------------------------------------
    {
        1, 0.5, 40.0, 0.95, 1.40, 0.30,        // Reinhard, heavy contrast, very low sat
        0, 0, 1.0, 0.5, 0.0, 0.0,              // film off
        1, 0.9, 7500.0,                         // grade on, cool highlight desat
        0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.0, 0.70,  // strong bleach bypass
        0, 0.0,                                 // local tone off
        0.6, 0.0,                               // reduced bloom
        0.0,                                    // neutral adapt
        0, 0.0, 0, 0.0, 1, 0.80, 0.0, 0.5,    // strong vignette
        0.5                                     // dim sunsprite
    },

    // -----------------------------------------------------------------------
    // 5: Vintage Film — Reinhard, warm stock, grain, halation
    //    Nostalgic analog look: heavy grain, warm halation, faded blacks.
    // -----------------------------------------------------------------------
    {
        1, 0.5, 50.0, 1.0, 1.10, 0.85,         // Reinhard, moderate contrast, slightly desat
        1, 0, 1.0, 0.7, 0.3, 0.2,              // film: 500T, full neg, strong print, density+interimage
        1, 0.6, 5000.0,                         // grade on, warm temp
        0, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.0, 0.0,  // no split, no bleach
        0, 0.0,                                 // local tone off
        1.0, 0.10,                              // normal bloom, gentle spectral
        0.0,                                    // neutral adapt
        0, 0.0, 1, 0.40, 0, 0.0, 0.50, 0.3,   // halation on, visible grain
        1.0                                     // normal sunsprite
    },

    // -----------------------------------------------------------------------
    // 6: Horror — Lottes, cold, desaturated, narrow adaptation
    //    Oppressive atmosphere: crushed darks, cold tones, claustrophobic.
    // -----------------------------------------------------------------------
    {
        6, 0.6, 30.0, 0.90, 1.30, 0.50,        // Lottes, high contrast, low sat
        0, 0, 1.0, 0.5, 0.0, 0.0,              // film off
        1, 0.8, 8000.0,                         // grade on, cold temp, heavy highlight desat
        1, 0.45, 0.48, 0.55,                    // cold shadows
           0.48, 0.50, 0.55, 0.15, 0.0,         // cold highlights
        0, 0.0,                                 // local tone off
        0.5, 0.0,                               // dim bloom
        -0.5,                                   // darker adapt bias
        0, 0.0, 0, 0.0, 1, 0.40, 0.15, 0.4,   // light vignette, subtle grain
        0.3                                     // very dim sunsprite
    },

    // -----------------------------------------------------------------------
    // 7: Ethereal — Linear (no tonemap curve), soft, diffused, bloomy
    //    Otherworldly glow: blown highlights, heavy diffusion, pastel tones.
    // -----------------------------------------------------------------------
    {
        0, 0.3, 80.0, 1.10, 0.70, 0.70,        // Linear, low contrast, low sat
        0, 0, 1.0, 0.5, 0.0, 0.0,              // film off
        1, 0.5, 7000.0,                         // grade on, slightly cool
        1, 0.55, 0.50, 0.60,                    // lavender shadows
           0.55, 0.55, 0.50, 0.20, 0.0,         // pastel highlights
        0, 0.0,                                 // local tone off
        2.0, 0.25,                              // heavy bloom, strong spectral
        0.3,                                    // brighter adapt bias
        1, 0.50, 0, 0.0, 0, 0.0, 0.0, 0.3,    // heavy diffusion, light sharpen
        1.5                                     // boosted sunsprite
    }
};


//=== THEME HELPERS ===//

// Returns true when a theme preset is active (index > 0)
bool ThemeActive()
{
    return ui_EotE_Theme > 0;
}

// Look up the current theme preset (clamped to valid range)
ThemeParams GetTheme()
{
    return THEME_PRESETS[clamp(ui_EotE_Theme, 0, 7)];
}

// Theme-or-manual selectors: return themed value when active, manual value otherwise.
// GPU evaluates both sides (ternary = conditional move), but the uniform branch
// is coherent across all pixels so cost is negligible.

float TF(float manual, float themed)
{
    return ThemeActive() ? themed : manual;
}

int TI(int manual, float themed)
{
    return ThemeActive() ? (int)themed : manual;
}

bool TB(bool manual, float themed)
{
    return ThemeActive() ? (themed > 0.5) : manual;
}


#endif // EOTE_THEME_SYSTEM_FXH
