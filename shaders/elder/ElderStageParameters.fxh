#ifndef ELDER_STAGE_PARAMETERS_FXH
#define ELDER_STAGE_PARAMETERS_FXH

#ifndef ELDER_STAGE_PARAMETER_SLOT
#error Elder stage must select ELDER_STAGE_PARAMETER_SLOT before including ElderStageParameters.fxh
#endif

bool ElderSuiteEnabled
<
    string UIName = "Elder 00 | Master | Suite Enabled";
> = true;

int ElderTierResetGuidance
<
    string UIName = "Elder 00 | Tier | Reset Guidance (Balanced: 1)";
    string UIWidget = "Spinner";
    int UIMin = 0;
    int UIMax = 4;
    int UIStep = 1;
> = 1;

float ElderTierBalancedReference
<
    string UIName = "Elder 00 | Tier | Balanced Baseline";
    string UIWidget = "Spinner";
    int UIHidden = 1;
    float UIMin = 1.0;
    float UIMax = 1.0;
    float UIStep = 1.0;
> = 1.0;

#if ELDER_STAGE_PARAMETER_SLOT == 0
bool ElderPrepassEnabled <string UIName = "Elder 10 | Prepass | Enabled";> = true;
float ElderPrepassIntensity <string UIName = "Elder 10 | Prepass | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderPrepassDepthShape <string UIName = "Elder 10 | Prepass | Depth Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderPrepassEnabled
#define ELDER_STAGE_INTENSITY ElderPrepassIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 1
bool ElderDepthOfFieldEnabled <string UIName = "Elder 20 | Depth of Field | Enabled";> = true;
bool ElderDepthOfFieldAutofocus <string UIName = "Elder 20 | Depth of Field | Autofocus";> = true;
float ElderDepthOfFieldIntensity <string UIName = "Elder 20 | Depth of Field | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.00; float UIStep = 0.01;> = 0.75;
float ElderDepthOfFieldFocusDepth <string UIName = "Elder 20 | Depth of Field | Focus Depth"; string UIWidget = "Spinner"; float UIMin = 0.01; float UIMax = 0.99; float UIStep = 0.01;> = 0.55;
float ElderDepthOfFieldFocusRange <string UIName = "Elder 20 | Depth of Field | Focus Range"; string UIWidget = "Spinner"; float UIMin = 0.03; float UIMax = 0.60; float UIStep = 0.01;> = 0.22;
float ElderDepthOfFieldForegroundStrength <string UIName = "Elder 20 | Depth of Field | Foreground Strength"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 0.60; float UIStep = 0.01;> = 0.20;
float ElderDepthOfFieldBackgroundStrength <string UIName = "Elder 20 | Depth of Field | Background Strength"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 0.80; float UIStep = 0.01;> = 0.35;
float ElderDepthOfFieldMaxBlur <string UIName = "Elder 20 | Depth of Field | Max Blur"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.00; float UIStep = 0.01;> = 0.45;
#define ELDER_STAGE_ENABLED ElderDepthOfFieldEnabled
#define ELDER_STAGE_INTENSITY ElderDepthOfFieldIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 2
bool ElderBloomEnabled <string UIName = "Elder 30 | Bloom | Enabled";> = true;
float ElderBloomIntensity <string UIName = "Elder 30 | Bloom | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 0.45; float UIStep = 0.01;> = 0.12;
float ElderBloomThreshold <string UIName = "Elder 30 | Bloom | Highlight Threshold"; string UIWidget = "Spinner"; float UIMin = 0.70; float UIMax = 4.00; float UIStep = 0.01;> = 1.45;
float ElderBloomSoftKnee <string UIName = "Elder 30 | Bloom | Soft Knee"; string UIWidget = "Spinner"; float UIMin = 0.01; float UIMax = 1.00; float UIStep = 0.01;> = 0.25;
float ElderBloomRadiusScale <string UIName = "Elder 30 | Bloom | Radius Scale"; string UIWidget = "Spinner"; float UIMin = 0.25; float UIMax = 1.50; float UIStep = 0.01;> = 0.80;
#define ELDER_STAGE_ENABLED ElderBloomEnabled
#define ELDER_STAGE_INTENSITY ElderBloomIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 3
bool ElderAdaptationEnabled <string UIName = "Elder 40 | Adaptation | Enabled";> = true;
float ElderAdaptationIntensity <string UIName = "Elder 40 | Adaptation | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.55;
float ElderAdaptationBrightenRate <string UIName = "Elder 40 | Adaptation | Brighten Rate"; string UIWidget = "Spinner"; float UIMin = 0.05; float UIMax = 4.00; float UIStep = 0.01;> = 0.70;
float ElderAdaptationDarkenRate <string UIName = "Elder 40 | Adaptation | Darken Rate"; string UIWidget = "Spinner"; float UIMin = 0.05; float UIMax = 4.00; float UIStep = 0.01;> = 0.45;
float ElderAdaptationMinLuminance <string UIName = "Elder 40 | Adaptation | Min Luminance"; string UIWidget = "Spinner"; float UIMin = 0.001; float UIMax = 1.00; float UIStep = 0.001;> = 0.08;
float ElderAdaptationMaxLuminance <string UIName = "Elder 40 | Adaptation | Max Luminance"; string UIWidget = "Spinner"; float UIMin = 1.00; float UIMax = 32.00; float UIStep = 0.01;> = 8.00;
#define ELDER_STAGE_ENABLED ElderAdaptationEnabled
#define ELDER_STAGE_INTENSITY ElderAdaptationIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 4
bool ElderLensEnabled <string UIName = "Elder 50 | Lens | Enabled";> = true;
float ElderLensIntensity <string UIName = "Elder 50 | Lens | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 0.30; float UIStep = 0.01;> = 0.07;
float ElderLensGhostStrength <string UIName = "Elder 50 | Lens | Ghost Strength"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 0.35; float UIStep = 0.01;> = 0.05;
float ElderLensHaloStrength <string UIName = "Elder 50 | Lens | Halo Strength"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 0.30; float UIStep = 0.01;> = 0.04;
float ElderLensEnergyCap <string UIName = "Elder 50 | Lens | Energy Cap"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 0.50; float UIStep = 0.01;> = 0.08;
#define ELDER_STAGE_ENABLED ElderLensEnabled
#define ELDER_STAGE_INTENSITY ElderLensIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 5
bool ElderMainEffectEnabled <string UIName = "Elder 60 | Main Effect | Enabled";> = true;
float ElderMainEffectIntensity <string UIName = "Elder 60 | Main Effect | Color-Core Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderMainEffectOpticalShape <string UIName = "Elder 60 | Main Effect | Optical Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderMainEffectEnabled
#define ELDER_STAGE_INTENSITY ElderMainEffectIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 6
bool ElderPostpassEnabled <string UIName = "Elder 70 | Postpass | Enabled";> = true;
float ElderPostpassIntensity <string UIName = "Elder 70 | Postpass | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderPostpassVignetteStrength <string UIName = "Elder 70 | Postpass | Vignette Strength"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 0.35; float UIStep = 0.01;> = 0.18;
float ElderPostpassGrainShape <string UIName = "Elder 70 | Postpass | Grain Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.0;
#define ELDER_STAGE_ENABLED ElderPostpassEnabled
#define ELDER_STAGE_INTENSITY ElderPostpassIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 7
bool ElderSunSpriteEnabled <string UIName = "Elder 80 | Sun Sprite | Enabled";> = true;
float ElderSunSpriteIntensity <string UIName = "Elder 80 | Sun Sprite | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.18;
float ElderSunSpriteDiscShape <string UIName = "Elder 80 | Sun Sprite | Disc Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderSunSpriteEnabled
#define ELDER_STAGE_INTENSITY ElderSunSpriteIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 8
bool ElderUnderwaterEnabled <string UIName = "Elder 90 | Underwater | Enabled";> = true;
float ElderUnderwaterIntensity <string UIName = "Elder 90 | Underwater | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.55;
float ElderUnderwaterDensityShape <string UIName = "Elder 90 | Underwater | Density Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.25;
#define ELDER_STAGE_ENABLED ElderUnderwaterEnabled
#define ELDER_STAGE_INTENSITY ElderUnderwaterIntensity
#else
#error Elder stage parameter slot must be one of 0-8
#endif

bool ElderStageIsActive()
{
    return ElderSuiteEnabled && ELDER_STAGE_ENABLED && ELDER_STAGE_INTENSITY > 0.0;
}

#endif
