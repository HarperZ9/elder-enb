#include "ElderNativeParameters.fxh"
#include "ElderColorCore.fxh"

cbuffer ElderColorReferenceParameters : register(b0)
{
    float3 ElderReferenceSceneLinear;
    float ElderReferencePadding0;
};

ElderColorCoreParameters ElderReferenceNativeParameters()
{
    ElderColorCoreParameters parameters;
    parameters.exposure_ev =
        ElderNativeSanitize_ElderExposureCompensationEv();
    parameters.warm_cool = ElderNativeSanitize_ElderColorWarmCool();
    parameters.tint = ElderNativeSanitize_ElderColorTint();
    parameters.toe = ElderNativeSanitize_ElderTonemapToe();
    parameters.shoulder = ElderNativeSanitize_ElderTonemapShoulder();
    parameters.mid_gray = ElderNativeSanitize_ElderTonemapMidGray();
    parameters.white_point = ElderNativeSanitize_ElderTonemapWhitePoint();
    parameters.local_contrast =
        ElderNativeSanitize_ElderTonemapLocalContrast();
    parameters.saturation = ElderNativeSanitize_ElderColorSaturation();
    parameters.vibrance = ElderNativeSanitize_ElderColorVibrance();
    parameters.highlight_desaturation =
        ElderNativeSanitize_ElderHighlightDesaturation();
    parameters.highlight_gamut_preservation =
        ElderNativeSanitize_ElderHighlightGamutPreservation();
    parameters.shadow_hue_stability =
        ElderNativeSanitize_ElderShadowHueStability();
    parameters.shadow_tint = ElderNativeSanitize_ElderShadowTint();
    parameters.highlight_tint = ElderNativeSanitize_ElderHighlightTint();
    return parameters;
}

float4 ElderColorReferencePixelMain() : SV_Target0
{
    if (!ElderColorFinite3(ElderReferenceSceneLinear))
    {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    float3 evaluated = ElderNativeActive_ElderMasterEnabled()
            && ElderNativeSanitize_ElderMasterEnabled()
        ? ElderEvaluateColorCore(
            ElderReferenceSceneLinear,
            ElderReferenceNativeParameters())
        : ElderReferenceSceneLinear;
    return float4(evaluated, 1.0);
}
