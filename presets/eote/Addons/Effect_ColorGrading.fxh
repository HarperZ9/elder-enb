//=============================================================================
//  Effect_ColorGrading.fxh — Professional Color Grading Suite
//
//  7 grading stages for enbeffect.fx GRADE pipeline:
//    Lift/Gamma/Gain, Channel Mixer, Hue vs Saturation, Vibrance,
//    S-Curve Contrast, Color Balance, Clarity (local contrast)
//
//  All features disabled by default — backward-compatible.
//  Author: Zain Dana Harper — March 2026
//=============================================================================

#ifndef EFFECT_COLORGRADING_FXH
#define EFFECT_COLORGRADING_FXH


//=== UI PARAMETERS ===//

// --- Lift / Gamma / Gain (3-way color corrector) ---

bool ui_LGGEnable
<
    string UIName = "GRADE | Lift/Gamma/Gain Enable";
> = {false};

float3 ui_LGGLift
<
    string UIName = "GRADE | Lift (Shadows RGB)";
    string UIWidget = "Color";
> = {0.0, 0.0, 0.0};

float3 ui_LGGGamma
<
    string UIName = "GRADE | Gamma (Midtones RGB)";
    string UIWidget = "Color";
> = {1.0, 1.0, 1.0};

float3 ui_LGGGain
<
    string UIName = "GRADE | Gain (Highlights RGB)";
    string UIWidget = "Color";
> = {1.0, 1.0, 1.0};

bool ui_LGGLumaPreserve
<
    string UIName = "GRADE | LGG Preserve Luminance";
> = {false};

// --- Channel Mixer (3x3 RGB matrix) ---

bool ui_CMixEnable
<
    string UIName = "GRADE | Channel Mixer Enable";
> = {false};

float ui_CMixRR < string UIName = "CMIX | Red from Red";   string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};
float ui_CMixRG < string UIName = "CMIX | Red from Green"; string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {0.0};
float ui_CMixRB < string UIName = "CMIX | Red from Blue";  string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {0.0};
float ui_CMixGR < string UIName = "CMIX | Green from Red";   string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {0.0};
float ui_CMixGG < string UIName = "CMIX | Green from Green"; string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};
float ui_CMixGB < string UIName = "CMIX | Green from Blue";  string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {0.0};
float ui_CMixBR < string UIName = "CMIX | Blue from Red";   string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {0.0};
float ui_CMixBG < string UIName = "CMIX | Blue from Green"; string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {0.0};
float ui_CMixBB < string UIName = "CMIX | Blue from Blue";  string UIWidget = "Spinner"; float UIMin = -1.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};

// --- Hue vs Saturation (6-band per-hue adjustment) ---

bool ui_HvSEnable
<
    string UIName = "GRADE | Hue vs Saturation Enable";
> = {false};

float ui_HvSRed     < string UIName = "HvS | Red Saturation";     string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};
float ui_HvSYellow  < string UIName = "HvS | Yellow Saturation";  string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};
float ui_HvSGreen   < string UIName = "HvS | Green Saturation";   string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};
float ui_HvSCyan    < string UIName = "HvS | Cyan Saturation";    string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};
float ui_HvSBlue    < string UIName = "HvS | Blue Saturation";    string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};
float ui_HvSMagenta < string UIName = "HvS | Magenta Saturation"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 2.0; float UIStep = 0.01; > = {1.0};

// --- Vibrance (intelligent saturation) ---

bool ui_VibranceEnable
<
    string UIName = "GRADE | Vibrance Enable";
> = {false};

float ui_VibranceAmount
<
    string UIName = "VIBRANCE | Amount";
    string UIWidget = "Spinner";
    float UIMin = -1.0;
    float UIMax = 2.0;
    float UIStep = 0.01;
> = {0.3};

float ui_VibranceSkinProtect
<
    string UIName = "VIBRANCE | Skin Protection";
    string UIWidget = "Spinner";
    float UIMin = 0.0;
    float UIMax = 1.0;
    float UIStep = 0.01;
> = {0.5};

// --- S-Curve Contrast ---

bool ui_SCurveEnable
<
    string UIName = "GRADE | S-Curve Enable";
> = {false};

float ui_SCurveSlope
<
    string UIName = "SCURVE | Slope";
    string UIWidget = "Spinner";
    float UIMin = 1.0;
    float UIMax = 20.0;
    float UIStep = 0.1;
> = {6.0};

float ui_SCurvePivot
<
    string UIName = "SCURVE | Pivot Point";
    string UIWidget = "Spinner";
    float UIMin = 0.1;
    float UIMax = 0.9;
    float UIStep = 0.01;
> = {0.5};

bool ui_SCurveLumaOnly
<
    string UIName = "SCURVE | Luminance Only";
> = {true};

// --- Color Balance (shadows/midtones/highlights) ---

bool ui_CBEnable
<
    string UIName = "GRADE | Color Balance Enable";
> = {false};

float3 ui_CBShadow
<
    string UIName = "CBAL | Shadow Shift (warm = R, cool = B)";
    string UIWidget = "Color";
> = {0.5, 0.5, 0.5};

float3 ui_CBMidtone
<
    string UIName = "CBAL | Midtone Shift";
    string UIWidget = "Color";
> = {0.5, 0.5, 0.5};

float3 ui_CBHighlight
<
    string UIName = "CBAL | Highlight Shift";
    string UIWidget = "Color";
> = {0.5, 0.5, 0.5};

// --- Clarity (local contrast) ---

bool ui_ClarityEnable
<
    string UIName = "GRADE | Clarity Enable";
> = {false};

float ui_ClarityAmount
<
    string UIName = "CLARITY | Amount";
    string UIWidget = "Spinner";
    float UIMin = -1.0;
    float UIMax = 2.0;
    float UIStep = 0.01;
> = {0.5};

float ui_ClarityRadius
<
    string UIName = "CLARITY | Radius";
    string UIWidget = "Spinner";
    float UIMin = 2.0;
    float UIMax = 30.0;
    float UIStep = 0.5;
> = {15.0};

float ui_ClarityMidtoneBias
<
    string UIName = "CLARITY | Midtone Bias";
    string UIWidget = "Spinner";
    float UIMin = 0.5;
    float UIMax = 3.0;
    float UIStep = 0.1;
> = {1.0};

float ui_ClarityMaxDelta
<
    string UIName = "CLARITY | Max Delta (halo prevent)";
    string UIWidget = "Spinner";
    float UIMin = 0.05;
    float UIMax = 0.5;
    float UIStep = 0.01;
> = {0.15};


//=== HELPER: RGB ↔ HSL ===//

static const float3 CG_LUM = float3(0.2126, 0.7152, 0.0722);

float CG_RGBToHue(float3 c)
{
    float cMax = max(c.r, max(c.g, c.b));
    float cMin = min(c.r, min(c.g, c.b));
    float delta = cMax - cMin;
    if (delta < 0.0001) return 0.0;
    float hue;
    if (cMax == c.r)      hue = fmod((c.g - c.b) / delta, 6.0);
    else if (cMax == c.g) hue = (c.b - c.r) / delta + 2.0;
    else                  hue = (c.r - c.g) / delta + 4.0;
    return frac(hue / 6.0);
}

float CG_RGBSaturation(float3 c)
{
    float cMax = max(c.r, max(c.g, c.b));
    float cMin = min(c.r, min(c.g, c.b));
    return (cMax > 0.0001) ? (cMax - cMin) / cMax : 0.0;
}


//=== GRADING FUNCTIONS ===//

// 1. Lift / Gamma / Gain — industry-standard 3-way corrector
float3 CG_LiftGammaGain(float3 color)
{
    // CDL extension: result = pow(max(color * gain + lift, 0), 1/gamma)
    float3 lifted = max(color * ui_LGGGain + (ui_LGGLift - 0.0), 0.0);
    float3 result = pow(lifted, 1.0 / max(ui_LGGGamma, 0.001));

    if (ui_LGGLumaPreserve)
    {
        // Restore original luminance after color shift
        float origLuma = dot(color, CG_LUM);
        float newLuma  = dot(result, CG_LUM);
        if (newLuma > 0.0001)
            result *= origLuma / newLuma;
    }

    return saturate(result);
}

// 2. Channel Mixer — 3x3 RGB→RGB matrix
float3 CG_ChannelMixer(float3 color)
{
    float3 result;
    result.r = dot(color, float3(ui_CMixRR, ui_CMixRG, ui_CMixRB));
    result.g = dot(color, float3(ui_CMixGR, ui_CMixGG, ui_CMixGB));
    result.b = dot(color, float3(ui_CMixBR, ui_CMixBG, ui_CMixBB));
    return saturate(result);
}

// 3. Hue vs Saturation — per-hue band adjustment (6 bands with smooth falloff)
float3 CG_HueVsSat(float3 color)
{
    float hue = CG_RGBToHue(color);
    float sat = CG_RGBSaturation(color);
    float luma = dot(color, CG_LUM);

    // 6 hue bands centered at: Red=0, Yellow=1/6, Green=2/6, Cyan=3/6, Blue=4/6, Magenta=5/6
    // Smooth triangular band shape (width = 1/6 per band with overlap)
    float satMults[6] = { ui_HvSRed, ui_HvSYellow, ui_HvSGreen,
                          ui_HvSCyan, ui_HvSBlue, ui_HvSMagenta };

    float totalMult = 0.0;
    float totalWeight = 0.0;

    [unroll]
    for (int i = 0; i < 6; i++)
    {
        float bandCenter = float(i) / 6.0;
        // Circular distance on hue wheel
        float d = abs(hue - bandCenter);
        d = min(d, 1.0 - d);
        // Triangular weight: 1 at center, 0 at ±1/6
        float w = saturate(1.0 - d * 6.0);
        totalMult += satMults[i] * w;
        totalWeight += w;
    }

    float finalMult = (totalWeight > 0.001) ? totalMult / totalWeight : 1.0;
    return lerp(luma, color, sat * finalMult / max(sat, 0.0001));
}

// 4. Vibrance — protects saturated colors and skin tones
float3 CG_Vibrance(float3 color)
{
    float luma = dot(color, CG_LUM);
    float currentSat = CG_RGBSaturation(color);

    // Skin tone detection: hue range ~0-40° (warm reds/oranges)
    float hue = CG_RGBToHue(color);
    float skinMask = smoothstep(0.0, 0.05, hue) * smoothstep(0.15, 0.08, hue);
    skinMask *= smoothstep(0.1, 0.3, currentSat); // Must have some saturation

    // Boost inversely proportional to current saturation (protect saturated colors)
    float boost = ui_VibranceAmount * (1.0 - currentSat);

    // Reduce boost for skin tones
    boost *= (1.0 - skinMask * ui_VibranceSkinProtect);

    return lerp(luma, color, 1.0 + boost);
}

// 5. S-Curve — logistic sigmoid contrast
float3 CG_SCurve(float3 color)
{
    float luma = dot(color, CG_LUM);

    // Logistic sigmoid: 1 / (1 + exp(-slope * (x - pivot)))
    // Rescaled to map [0,1] → [0,1] with anchor at pivot
    float sigmoidLuma = 1.0 / (1.0 + exp(-ui_SCurveSlope * (luma - ui_SCurvePivot)));

    // Normalize: ensure 0→0 and 1→1
    float sig0 = 1.0 / (1.0 + exp(-ui_SCurveSlope * (0.0 - ui_SCurvePivot)));
    float sig1 = 1.0 / (1.0 + exp(-ui_SCurveSlope * (1.0 - ui_SCurvePivot)));
    sigmoidLuma = (sigmoidLuma - sig0) / (sig1 - sig0);

    if (ui_SCurveLumaOnly)
    {
        // Apply contrast to luminance only, preserve chrominance
        float ratio = (luma > 0.0001) ? sigmoidLuma / luma : 1.0;
        return saturate(color * ratio);
    }
    else
    {
        // Per-channel S-curve
        float3 result;
        [unroll] for (int ch = 0; ch < 3; ch++)
        {
            float s = 1.0 / (1.0 + exp(-ui_SCurveSlope * (color[ch] - ui_SCurvePivot)));
            result[ch] = (s - sig0) / (sig1 - sig0);
        }
        return saturate(result);
    }
}

// 6. Color Balance — zone-specific RGB offsets (shadows/midtones/highlights)
float3 CG_ColorBalance(float3 color)
{
    float luma = dot(color, CG_LUM);

    // Zone weights (smooth overlap, sum to ~1 for any luminance)
    float shadowW    = 1.0 - smoothstep(0.0, 0.5, luma);
    float midtoneW   = 1.0 - abs(luma - 0.5) * 2.0;
    midtoneW = max(midtoneW, 0.0);
    float highlightW = smoothstep(0.5, 1.0, luma);

    // Convert color picker 0.5-centered to ±offset
    float3 shadowOff    = (ui_CBShadow    - 0.5) * 2.0;
    float3 midtoneOff   = (ui_CBMidtone   - 0.5) * 2.0;
    float3 highlightOff = (ui_CBHighlight  - 0.5) * 2.0;

    float3 offset = shadowOff * shadowW + midtoneOff * midtoneW + highlightOff * highlightW;

    float3 result = color + offset * 0.1; // Scale down — these are subtle shifts

    // Luminance preservation
    float newLuma = dot(result, CG_LUM);
    if (newLuma > 0.0001)
        result *= luma / newLuma;

    return saturate(result);
}

// 7. Clarity — wide-radius unsharp mask with midtone bias (Lightroom model)
//    NOTE: This requires txcoord for neighbor sampling. Called from PS_Draw only.
float3 CG_Clarity(float3 color, float2 txcoord)
{
    // 9-tap cross+diagonal at wide radius for local mean approximation
    float2 off = float2(ScreenSize.y, ScreenSize.y * ScreenSize.z) * ui_ClarityRadius;

    float3 blur = color;
    blur += TextureColor.SampleLevel(smpLinear, txcoord + float2( off.x, 0), 0).rgb;
    blur += TextureColor.SampleLevel(smpLinear, txcoord + float2(-off.x, 0), 0).rgb;
    blur += TextureColor.SampleLevel(smpLinear, txcoord + float2(0,  off.y), 0).rgb;
    blur += TextureColor.SampleLevel(smpLinear, txcoord + float2(0, -off.y), 0).rgb;
    float2 dOff = off * 0.707;
    blur += TextureColor.SampleLevel(smpLinear, txcoord + float2( dOff.x,  dOff.y), 0).rgb;
    blur += TextureColor.SampleLevel(smpLinear, txcoord + float2(-dOff.x,  dOff.y), 0).rgb;
    blur += TextureColor.SampleLevel(smpLinear, txcoord + float2( dOff.x, -dOff.y), 0).rgb;
    blur += TextureColor.SampleLevel(smpLinear, txcoord + float2(-dOff.x, -dOff.y), 0).rgb;
    blur /= 9.0;

    // High-pass detail
    float3 detail = color - blur;

    // Midtone bias: peaks at 50% luminance, zero at black/white
    // Prevents blown highlights and crushed blacks
    float luma = dot(color, CG_LUM);
    float midtoneMask = 4.0 * luma * (1.0 - luma);
    midtoneMask = pow(saturate(midtoneMask), ui_ClarityMidtoneBias);

    // Soft clamping to prevent halo artifacts
    detail = clamp(detail, -ui_ClarityMaxDelta, ui_ClarityMaxDelta);

    return saturate(color + detail * ui_ClarityAmount * midtoneMask);
}


#endif // EFFECT_COLORGRADING_FXH
