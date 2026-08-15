#ifndef EOTE_FILMSCIENCE_FXH
#define EOTE_FILMSCIENCE_FXH
//----------------------------------------------------------------------------------------------//
//                                                                                              //
//         EotE_FilmScience.fxh - Film color science & grading library                          //
//                                                                                              //
//  Pure math functions for photochemical emulation and professional color grading.              //
//  No UI declarations, no extern variables, no PixelSize. Safe for any host .fx.               //
//                                                                                              //
//  Contents:                                                                                   //
//    Section 1: Oklab perceptual color space                                                   //
//    Section 2: Film characteristic curves (H&D) + stock presets                               //
//    Section 3: Beer-Lambert subtractive density                                               //
//    Section 4: Interimage effect (development inhibition)                                     //
//    Section 5: ASC-CDL (Color Decision List)                                                  //
//    Section 6: White balance (Kelvin)                                                         //
//    Section 7: Bleach bypass (silver retention)                                               //
//                                                                                              //
//  References:                                                                                 //
//    - Bjorn Ottosson, "A perceptual color space for image processing" (Oklab)                 //
//    - Kodak Publication H-1, "Sensitometric Properties of Photographic Films"                 //
//    - ASC Technology Committee, "Color Decision List v1.2"                                    //
//    - Tanner Helland, "How to Convert a Temperature in Kelvin to RGB"                         //
//                                                                                              //
//  Author: Zain Dana Harper - March 2026                                                       //
//                                                                                              //
//----------------------------------------------------------------------------------------------//


//=============================================================================//
//  Section 1: Oklab Perceptual Color Space                                    //
//                                                                             //
//  Perceptually uniform color space for hue-preserving operations.            //
//  Input/output: sRGB-gamma [0,1] (post-tonemap, display-referred).           //
//  Internally linearizes for the matrix transforms.                           //
//  Reference: Bjorn Ottosson, 2020                                            //
//=============================================================================//

float3 SRGBToOklab(float3 srgb)
{
    // sRGB EOTF (gamma decode to linear)
    float3 lin = (srgb > 0.04045)
        ? pow(abs((srgb + 0.055) / 1.055), 2.4)
        : srgb / 12.92;

    // Linear sRGB -> LMS (Oklab adapted primaries)
    float l = 0.4122214708 * lin.r + 0.5363325363 * lin.g + 0.0514459929 * lin.b;
    float m = 0.2119034982 * lin.r + 0.6806995451 * lin.g + 0.1073969566 * lin.b;
    float s = 0.0883024619 * lin.r + 0.2817188376 * lin.g + 0.6299787005 * lin.b;

    // Cube root (perceptual nonlinearity)
    l = pow(abs(l), 1.0 / 3.0);
    m = pow(abs(m), 1.0 / 3.0);
    s = pow(abs(s), 1.0 / 3.0);

    // LMS^(1/3) -> Oklab (L, a, b)
    return float3(
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    );
}

float3 OklabToSRGB(float3 lab)
{
    // Oklab -> LMS^(1/3)
    float l = lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z;
    float m = lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z;
    float s = lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z;

    // Cube (inverse of cube root)
    l = l * l * l;
    m = m * m * m;
    s = s * s * s;

    // LMS -> linear sRGB
    float3 lin = float3(
         4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    );

    // sRGB OETF (linear to gamma)
    return (lin > 0.0031308)
        ? 1.055 * pow(abs(lin), 1.0 / 2.4) - 0.055
        : 12.92 * lin;
}


//=============================================================================//
//  Section 2: Film Characteristic Curves (H&D Response)                       //
//                                                                             //
//  Asymmetric sigmoid modeling the density vs. log-exposure response of       //
//  real photographic film. Per-channel application creates the natural        //
//  color shifts that distinguish film from digital.                           //
//                                                                             //
//  Negative film: low gamma (0.5-0.65), compresses dynamic range             //
//  Print film: high gamma (2.6-2.8), expands contrast                        //
//  Together (neg → optical printing → print) = cinema S-curve                //
//=============================================================================//

// Single-channel characteristic curve
// toe:       shadow compression (0.01-0.5, higher = more lifted shadows)
// gamma:     midtone contrast (0.2-1.0 for neg, 1.0-3.5 for print)
// shoulder:  highlight rolloff (1.0-5.0, higher = harder clip)
// whitePoint: input level that maps to near-maximum output
float FilmCurve(float x, float toe, float gamma, float shoulder, float whitePoint)
{
    // Naka-Rushton toe: smooth shadow entry
    float toeResult = x / (x + toe);

    // Apply gamma (contrast)
    toeResult = pow(abs(toeResult), gamma);

    // Shoulder: soft highlight rolloff
    float normX = saturate(x / max(whitePoint, 0.001));
    float shoulderResult = 1.0 - pow(max(1.0 - normX, 0.0), shoulder);

    // Crossfade: toe region in shadows, shoulder in highlights
    float blend = smoothstep(0.0, 1.0, normX);
    return lerp(toeResult, shoulderResult, blend);
}

// Per-channel application
float3 ApplyFilmCurves(float3 color, float3 toe, float3 gamma,
                       float3 shoulder, float3 wp)
{
    return float3(
        FilmCurve(color.r, toe.r, gamma.r, shoulder.r, wp.r),
        FilmCurve(color.g, toe.g, gamma.g, shoulder.g, wp.g),
        FilmCurve(color.b, toe.b, gamma.b, shoulder.b, wp.b)
    );
}

// --- Negative stock presets ---
// Per-channel parameters create the characteristic color shifts of each stock.
// Index 0: Kodak Vision3 500T  - Tungsten, warm, wide latitude, gentle rolloff
// Index 1: Kodak Vision3 250D  - Daylight, neutral-cool, vivid, higher contrast
// Index 2: Fuji Eterna Vivid   - Cool, muted, pastel, subdued highlights

static const float3 NEG_TOE[3] = {
    float3(0.12, 0.10, 0.14),   // 500T: blue toe lifted → warm shadows
    float3(0.10, 0.10, 0.10),   // 250D: neutral toe
    float3(0.10, 0.10, 0.10)    // Eterna: neutral toe
};

static const float3 NEG_GAMMA[3] = {
    float3(0.58, 0.55, 0.52),   // 500T: red steeper → warm midtones
    float3(0.60, 0.58, 0.55),   // 250D: higher contrast, balanced
    float3(0.52, 0.55, 0.56)    // Eterna: low contrast, blue slightly steeper
};

static const float3 NEG_SHOULDER[3] = {
    float3(2.2, 2.4, 2.8),     // 500T: blue rolls off harder → warm highlights
    float3(2.4, 2.4, 2.4),     // 250D: uniform rolloff
    float3(2.6, 2.4, 2.2)      // Eterna: red rolls off harder → cool highlights
};

static const float3 NEG_WP[3] = {
    float3(16.0, 14.0, 12.0),  // 500T: wide exposure latitude
    float3(14.0, 14.0, 14.0),  // 250D: standard
    float3(14.0, 14.0, 15.0)   // Eterna: slightly narrower
};

// --- Print stock: Kodak 2383 ---
// The only color print film still manufactured. Its high gamma
// IS the cinema contrast look.
static const float3 PRINT_TOE      = float3(0.08, 0.08, 0.10);
static const float3 PRINT_GAMMA    = float3(2.80, 2.70, 2.60);
static const float3 PRINT_SHOULDER = float3(1.8, 1.8, 1.8);
static const float3 PRINT_WP       = float3(1.2, 1.2, 1.2);


//=============================================================================//
//  Section 3: Beer-Lambert Subtractive Density                                //
//                                                                             //
//  In real film, saturated colors are DARKER than neutral grays at the        //
//  same exposure. This is because dye layers absorb light — more dye          //
//  (more saturation) = more absorption = darker.                              //
//                                                                             //
//  Digital cameras capture additive light, so saturated colors appear         //
//  brighter. This function corrects that, giving the characteristic           //
//  "rich depth" of film colors.                                               //
//=============================================================================//

float3 ApplySubtractiveDensity(float3 color, float densityAmount)
{
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    float3 delta = color - luma;
    float sat = length(delta);

    // More saturation → more density → darker
    float densityFactor = 1.0 - saturate(sat * densityAmount);
    float3 chroma = (luma > 0.001) ? (color / luma) : 1.0;
    return chroma * (luma * densityFactor);
}


//=============================================================================//
//  Section 4: Interimage Effect (Development Inhibition)                      //
//                                                                             //
//  During film development, byproducts from each emulsion layer inhibit       //
//  the development of neighboring layers. This cross-suppression              //
//  INCREASES apparent color saturation — it's why film colors "pop"           //
//  differently from digital saturation.                                       //
//                                                                             //
//  The inhibition matrix encodes how much each channel suppresses the         //
//  others. Negative values = suppression.                                     //
//=============================================================================//

float3 ApplyInterimageEffect(float3 color, float strength)
{
    // Kodak-type inhibition coefficients:
    // - Green strongly inhibits Red and Blue
    // - Red moderately inhibits Green
    // - Blue weakly inhibits Red and Green
    static const float3x3 INHIBITION = float3x3(
         0.00, -0.08, -0.03,   // R suppressed by G (-0.08) and B (-0.03)
        -0.05,  0.00, -0.05,   // G suppressed by R (-0.05) and B (-0.05)
        -0.02, -0.06,  0.00    // B suppressed by R (-0.02) and G (-0.06)
    );

    float3 inhibition = mul(INHIBITION, color) * strength;
    return color - inhibition;
}


//=============================================================================//
//  Section 5: ASC-CDL (Color Decision List)                                   //
//                                                                             //
//  Industry-standard per-channel color grading: the exact same controls       //
//  used in DaVinci Resolve, Baselight, and on-set DIT stations.              //
//                                                                             //
//  slope:  multiplicative gain (1.0 = neutral)                                //
//  offset: additive shift (0.0 = neutral)                                     //
//  power:  gamma/contrast (1.0 = neutral)                                     //
//  sat:    global saturation (1.0 = neutral)                                  //
//=============================================================================//

float3 ApplyASCCDL(float3 color, float3 slope, float3 offset,
                   float3 power, float sat)
{
    color = pow(max(color * slope + offset, 0.0), power);
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    return max(luma + sat * (color - luma), 0.0);
}


//=============================================================================//
//  Section 6: White Balance (Color Temperature)                               //
//                                                                             //
//  Shift the image white point by multiplying with the ratio of target        //
//  Kelvin temperature to D65 (6500K). Uses Tanner Helland's Planckian        //
//  locus approximation.                                                       //
//                                                                             //
//  6500K = neutral (no change). Lower = warmer. Higher = cooler.             //
//=============================================================================//

float3 KelvinToRGB_Film(float K)
{
    float temp = K * 0.01;
    float3 rgb;

    rgb.r = (temp <= 66.0) ? 1.0
          : saturate(1.292936 * pow(abs(temp - 60.0), -0.1332047));

    rgb.g = (temp <= 66.0)
          ? saturate(0.390082 * log(max(temp, 1.0)) - 0.631889)
          : saturate(1.129891 * pow(abs(temp - 60.0), -0.0755148));

    rgb.b = (temp >= 66.0) ? 1.0
          : (temp <= 19.0) ? 0.0
          : saturate(0.543207 * log(max(temp - 10.0, 1.0)) - 1.19625);

    return rgb;
}

float3 ApplyWhiteBalance(float3 color, float tempK)
{
    float3 target  = KelvinToRGB_Film(tempK);
    float3 neutral = KelvinToRGB_Film(6500.0);
    return color * (target / max(neutral, 0.001));
}


//=============================================================================//
//  Section 7: Bleach Bypass (Silver Retention)                                //
//                                                                             //
//  In traditional film processing, the bleach step removes the silver         //
//  image, leaving only the color dyes. Skipping (or partially skipping)      //
//  this step leaves metallic silver overlaid on the dye image, creating       //
//  a desaturated, high-contrast look.                                         //
//                                                                             //
//  Used in Saving Private Ryan, Minority Report, Se7en.                       //
//=============================================================================//

float3 ApplyBleachBypass(float3 color, float intensity)
{
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    // Silver image: luminance overlay (multiplicative blend)
    float3 silver = color * luma;
    return lerp(color, silver, intensity);
}


#endif // EOTE_FILMSCIENCE_FXH
