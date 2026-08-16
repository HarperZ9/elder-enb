#ifndef ELDER_STAGE_PARAMETERS_FXH
#define ELDER_STAGE_PARAMETERS_FXH

#ifndef ELDER_STAGE_PARAMETER_SLOT
#error Elder stage must select ELDER_STAGE_PARAMETER_SLOT before including ElderStageParameters.fxh
#endif

bool ElderSuiteEnabled
<
    string UIName = "[Elder 00] Master | Suite Enabled";
> = true;

int ElderTierResetGuidance
<
    string UIName = "[Elder 00] Tier | Reset Guidance (Balanced = 1)";
    string UIWidget = "Spinner";
    int UIMin = 0;
    int UIMax = 4;
    int UIStep = 1;
> = 1;

float ElderTierBalancedReference
<
    string UIName = "[Elder 00] Tier | Balanced Baseline";
    string UIWidget = "Spinner";
    int UIHidden = 1;
    float UIMin = 1.0;
    float UIMax = 1.0;
    float UIStep = 1.0;
> = 1.0;

#if ELDER_STAGE_PARAMETER_SLOT == 0
bool ElderPrepassEnabled <string UIName = "[Elder 10] Prepass | Enabled";> = true;
float ElderPrepassIntensity <string UIName = "[Elder 10] Prepass | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderPrepassDepthShape <string UIName = "[Elder 10] Prepass | Depth Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderPrepassEnabled
#define ELDER_STAGE_INTENSITY ElderPrepassIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 1
bool ElderDepthOfFieldEnabled <string UIName = "[Elder 20] Depth of Field | Enabled";> = true;
float ElderDepthOfFieldIntensity <string UIName = "[Elder 20] Depth of Field | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderDepthOfFieldFocusShape <string UIName = "[Elder 20] Depth of Field | Focus Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderDepthOfFieldEnabled
#define ELDER_STAGE_INTENSITY ElderDepthOfFieldIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 2
bool ElderBloomEnabled <string UIName = "[Elder 30] Bloom | Enabled";> = true;
float ElderBloomIntensity <string UIName = "[Elder 30] Bloom | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderBloomThresholdShape <string UIName = "[Elder 30] Bloom | Threshold Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 4.0; float UIStep = 0.01;> = 1.0;
#define ELDER_STAGE_ENABLED ElderBloomEnabled
#define ELDER_STAGE_INTENSITY ElderBloomIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 3
bool ElderAdaptationEnabled <string UIName = "[Elder 40] Adaptation | Enabled";> = true;
float ElderAdaptationIntensity <string UIName = "[Elder 40] Adaptation | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderAdaptationResponseShape <string UIName = "[Elder 40] Adaptation | Response Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderAdaptationEnabled
#define ELDER_STAGE_INTENSITY ElderAdaptationIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 4
bool ElderLensEnabled <string UIName = "[Elder 50] Lens | Enabled";> = true;
float ElderLensIntensity <string UIName = "[Elder 50] Lens | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderLensApertureShape <string UIName = "[Elder 50] Lens | Aperture Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderLensEnabled
#define ELDER_STAGE_INTENSITY ElderLensIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 5
bool ElderMainEffectEnabled <string UIName = "[Elder 60] Main Effect | Enabled";> = true;
float ElderMainEffectIntensity <string UIName = "[Elder 60] Main Effect | Color-Core Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderMainEffectDisplayShape <string UIName = "[Elder 60] Main Effect | Display Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderMainEffectEnabled
#define ELDER_STAGE_INTENSITY ElderMainEffectIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 6
bool ElderPostpassEnabled <string UIName = "[Elder 70] Postpass | Enabled";> = true;
float ElderPostpassIntensity <string UIName = "[Elder 70] Postpass | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderPostpassGrainShape <string UIName = "[Elder 70] Postpass | Grain Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.0;
#define ELDER_STAGE_ENABLED ElderPostpassEnabled
#define ELDER_STAGE_INTENSITY ElderPostpassIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 7
bool ElderSunSpriteEnabled <string UIName = "[Elder 80] Sun Sprite | Enabled";> = true;
float ElderSunSpriteIntensity <string UIName = "[Elder 80] Sun Sprite | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderSunSpriteDiscShape <string UIName = "[Elder 80] Sun Sprite | Disc Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.5;
#define ELDER_STAGE_ENABLED ElderSunSpriteEnabled
#define ELDER_STAGE_INTENSITY ElderSunSpriteIntensity
#elif ELDER_STAGE_PARAMETER_SLOT == 8
bool ElderUnderwaterEnabled <string UIName = "[Elder 90] Underwater | Enabled";> = true;
float ElderUnderwaterIntensity <string UIName = "[Elder 90] Underwater | Intensity"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 1.0;
float ElderUnderwaterDensityShape <string UIName = "[Elder 90] Underwater | Density Shape"; string UIWidget = "Spinner"; float UIMin = 0.0; float UIMax = 1.0; float UIStep = 0.01;> = 0.25;
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
