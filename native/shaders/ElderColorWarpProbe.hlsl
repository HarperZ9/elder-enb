#include "ElderNativeParameters.fxh"
#include "ElderColorCore.fxh"

StructuredBuffer<float4> ElderWarpSceneValues : register(t0);
RWStructuredBuffer<float4> ElderWarpResults : register(u0);

ElderColorCoreParameters ElderWarpDefaultParameters()
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

[numthreads(64, 1, 1)]
void ElderColorWarpProbeMain(uint3 dispatch_thread_id : SV_DispatchThreadID)
{
    uint element_count;
    uint element_stride;
    ElderWarpSceneValues.GetDimensions(element_count, element_stride);
    if (dispatch_thread_id.x >= element_count || element_stride != 16)
    {
        return;
    }

    float4 scene = ElderWarpSceneValues[dispatch_thread_id.x];
    float3 evaluated = ElderNativeActive_ElderMasterEnabled()
            && ElderNativeSanitize_ElderMasterEnabled()
        ? ElderEvaluateColorCore(scene.rgb, ElderWarpDefaultParameters())
        : scene.rgb;
    ElderWarpResults[dispatch_thread_id.x] = float4(evaluated, scene.a);
}
