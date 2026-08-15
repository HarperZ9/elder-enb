#ifndef EOTE_TONEMAPPERS_FXH
#define EOTE_TONEMAPPERS_FXH
//----------------------------------------------------------------------------------------------//
//                                                                                              //
//         EotE_Tonemappers.fxh - Tonemapping operator library                                  //
//                                                                                              //
//         8 tonemapper implementations with uniform signatures                                 //
//                                                                                              //
//  Operators:                                                                                  //
//    0: Linear (passthrough)                                                                   //
//    1: Reinhard (Boris extended)                                                              //
//    2: Hejl-Burgess (filmic)                                                                  //
//    3: Hable / Uncharted 2 (filmic with toe/shoulder)                                        //
//    4: ACES (Hill RRT+ODT approximation)                                                     //
//    5: AgX (Troy Sobotka display transform)                                                  //
//    6: Lottes (Timothy Lottes adjustable)                                                     //
//    7: Gran Turismo (Uchimura piecewise, SIGGRAPH 2017)                                      //
//                                                                                              //
//----------------------------------------------------------------------------------------------//


//=============================================================================//
//  0: Linear (passthrough with optional exposure)                             //
//=============================================================================//

float3 Tonemap_Linear(float3 color)
{
    return saturate(color);
}


//=============================================================================//
//  1: Boris Extended Reinhard                                                 //
//  Standard ENB tonemapper. Widely used and battle-tested.                    //
//  WhitePoint controls the luminance at which output reaches pure white.      //
//  Curve controls the contrast in midtones.                                   //
//=============================================================================//

float3 Tonemap_Reinhard(float3 color, float whitePoint, float curve)
{
    float3 num = color * (1.0 + color / max(whitePoint * whitePoint, 1e-4));
    return num / (color + max(curve, 1e-4));
}


//=============================================================================//
//  2: Hejl-Burgess Filmic                                                     //
//  Jim Hejl & Richard Burgess-Dawson filmic tonemapper.                       //
//  Built-in gamma correction (outputs sRGB-ready).                            //
//  WhitePoint controls the highlight compression ceiling.                     //
//=============================================================================//

float3 Tonemap_HejlBurgess(float3 color, float whitePoint)
{
    float3 x = max(0.0, color - 0.004);
    float3 mapped = (x * (6.2 * x + 0.5)) / (x * (6.2 * x + 1.7) + 0.06);
    // The Hejl curve already bakes in a gamma-like response
    return mapped * (1.0 / max(whitePoint, 0.01));
}


//=============================================================================//
//  3: Hable / Uncharted 2 Filmic                                             //
//  John Hable's piecewise filmic curve from Uncharted 2.                     //
//  Parameters: A=shoulder, B=linear, C=linear angle, D=toe,                  //
//              E=toe numerator, F=toe denominator                             //
//=============================================================================//

float3 HablePartial(float3 x, float A, float B, float C, float D, float E, float F)
{
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

float3 Tonemap_Hable(float3 color, float exposureBias,
                     float A, float B, float C, float D, float E, float F, float W)
{
    float3 curr = HablePartial(color * exposureBias, A, B, C, D, E, F);
    float3 whiteScale = 1.0 / HablePartial(W.xxx, A, B, C, D, E, F);
    return curr * whiteScale;
}

// Simplified Hable with default parameters
float3 Tonemap_Hable(float3 color, float exposureBias)
{
    // Default Uncharted 2 values: A=0.15, B=0.50, C=0.10, D=0.20, E=0.02, F=0.30, W=11.2
    return Tonemap_Hable(color, exposureBias, 0.15, 0.50, 0.10, 0.20, 0.02, 0.30, 11.2);
}


//=============================================================================//
//  4: ACES (Stephen Hill RRT+ODT fitted approximation)                        //
//  Simple polynomial fit to the full ACES reference rendering transform.      //
//  Excellent for cinematic look with natural highlight rolloff.               //
//  Reference: Stephen Hill, "ACES Fitted", 2016                              //
//=============================================================================//

float3 Tonemap_ACES(float3 color)
{
    // sRGB -> ACES input transform (AP0)
    static const float3x3 ACESInput = float3x3(
        0.59719, 0.35458, 0.04823,
        0.07600, 0.90834, 0.01566,
        0.02840, 0.13383, 0.83777
    );
    // ACES output transform -> sRGB
    static const float3x3 ACESOutput = float3x3(
         1.60475, -0.53108, -0.07367,
        -0.10208,  1.10813, -0.00605,
        -0.00327, -0.07276,  1.07602
    );

    color = mul(ACESInput, color);

    // RRT + ODT fit (Stephen Hill)
    float3 a = color * (color + 0.0245786) - 0.000090537;
    float3 b = color * (0.983729 * color + 0.4329510) + 0.238081;
    color = a / b;

    return saturate(mul(ACESOutput, color));
}


//=============================================================================//
//  5: AgX (Troy Sobotka display transform)                                    //
//  Modern alternative to ACES. Best hue preservation under extreme            //
//  saturation. More natural highlight desaturation.                           //
//  Reference: Troy Sobotka, "AgX", 2023                                      //
//=============================================================================//

float3 AgXDefaultContrastApprox(float3 x)
{
    // 6th order polynomial approximation of AgX default contrast
    float3 x2 = x * x;
    float3 x4 = x2 * x2;
    return + 15.5     * x4 * x2
           - 40.14    * x4 * x
           + 31.96    * x4
           - 6.868    * x2 * x
           + 0.4298   * x2
           + 0.1191   * x
           - 0.00232;
}

float3 Tonemap_AgX(float3 color)
{
    // AgX log2 encoding
    static const float3x3 AgXTransform = float3x3(
        0.842479, 0.0784336, 0.0792237,
        0.0423304, 0.878468, 0.0791661,
        0.0423756, 0.0784336, 0.879142
    );

    static const float AgXMinEV = -12.47393;
    static const float AgXMaxEV = 4.026069;

    color = mul(AgXTransform, color);
    color = clamp(log2(max(color, 1e-10)), AgXMinEV, AgXMaxEV);
    color = (color - AgXMinEV) / (AgXMaxEV - AgXMinEV);

    color = AgXDefaultContrastApprox(color);

    // AgX inverse transform back to display
    static const float3x3 AgXInverse = float3x3(
         1.19687,  -0.0980208, -0.0990297,
        -0.0528968, 1.15190,   -0.0989611,
        -0.0529716, -0.0980434, 1.15107
    );

    return saturate(mul(AgXInverse, color));
}


//=============================================================================//
//  6: Lottes (Timothy Lottes adjustable)                                      //
//  Single-parameter simplicity with configurable toe/shoulder.                //
//  Reference: Timothy Lottes, "Advanced Techniques and Optimization of        //
//  HDR Color Pipelines", GDC 2016                                            //
//=============================================================================//

float3 Tonemap_Lottes(float3 color, float contrast, float shoulder,
                      float hdrMax, float midIn, float midOut)
{
    // Attempt a general curve that gives better shoulder control
    float a = contrast;
    float d = shoulder;
    float b = (-pow(abs(midIn), a) + pow(abs(hdrMax), a) * midOut) /
              ((pow(abs(hdrMax), a * d) - pow(abs(midIn), a * d)) * midOut);
    float c = (pow(abs(hdrMax), a * d) * pow(abs(midIn), a) - pow(abs(hdrMax), a) * pow(abs(midIn), a * d) * midOut) /
              ((pow(abs(hdrMax), a * d) - pow(abs(midIn), a * d)) * midOut);

    float3 cr = pow(abs(color), a);
    return cr / (cr * b + c);
}

// Simplified Lottes with defaults
float3 Tonemap_Lottes(float3 color)
{
    return Tonemap_Lottes(color, 1.6, 0.977, 8.0, 0.18, 0.267);
}


//=============================================================================//
//  7: Gran Turismo / Uchimura (Hajime Uchimura, SIGGRAPH 2017)              //
//  Piecewise curve with toe, linear, and shoulder sections.                  //
//  Designed for maximum artist control: natural highlight rolloff,           //
//  configurable black tightness, and clean linear midtones.                  //
//  Reference: "Practical HDR and Wide Color Techniques in Gran Turismo       //
//  SPORT", SIGGRAPH 2017                                                    //
//=============================================================================//

float3 Tonemap_GranTurismo(float3 x, float P, float c)
{
    // P = max brightness (controls shoulder ceiling)
    // c = black tightness / toe contrast (1.0 = linear toe, 1.5+ = crushed blacks)
    // Fixed artist-friendly defaults for other params
    static const float a = 1.0;    // contrast in linear section
    static const float m = 0.22;   // linear section start
    static const float l = 0.4;    // linear section length
    static const float b = 0.0;    // pedestal (black level lift)

    float l0 = ((P - m) * l) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / max(P - S1, 1e-4);
    float CP = -C2 / max(P, 1e-4);

    // Section weights: toe (w0), linear (w1), shoulder (w2)
    float3 w0 = 1.0 - smoothstep(0.0, m, x);
    float3 w2 = step(S0, x);
    float3 w1 = 1.0 - w0 - w2;

    // Toe: power curve for black tightness
    float3 T = m * pow(max(x / m, 1e-6), c) + b;
    // Linear: constant-slope midtone section
    float3 L = m + a * (x - m);
    // Shoulder: exponential rolloff to max brightness P
    float3 S = P - (P - S1) * exp(CP * (x - S0));

    return T * w0 + L * w1 + S * w2;
}


//=============================================================================//
//  Tonemapper selector: dispatches to the appropriate operator by index       //
//=============================================================================//

float3 ApplyTonemap(float3 color, int mode, float curve, float whitePoint, float exposure)
{
    color *= exposure;

    [branch] switch (mode)
    {
        case 0: return Tonemap_Linear(color);
        case 1: return Tonemap_Reinhard(color, whitePoint, curve);
        case 2: return Tonemap_HejlBurgess(color, whitePoint);
        case 3: return Tonemap_Hable(color, 1.0);
        case 4: return Tonemap_ACES(color);
        case 5: return Tonemap_AgX(color);
        case 6: return Tonemap_Lottes(color);
        case 7: return Tonemap_GranTurismo(color, max(whitePoint * 0.1, 0.5), max(curve, 0.1));
        default: return Tonemap_Reinhard(color, whitePoint, curve);
    }
}


#endif // EOTE_TONEMAPPERS_FXH
