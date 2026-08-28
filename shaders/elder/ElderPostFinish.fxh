#ifndef ELDER_POST_FINISH_FXH
#define ELDER_POST_FINISH_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderPostFinish.fxh
#endif

float ElderFinishHash(float2 pixel)
{
    float3 value = frac(float3(pixel.xyx) * 0.1031);
    value += dot(value, value.yzx + 33.33);
    return frac((value.x + value.y) * value.z);
}

float3 ElderApplyLdrVignette(float2 uv, float3 display_color)
{
    float2 centered = uv - 0.5.xx;
    float vignette = saturate(1.0 - dot(centered, centered) * 0.55);
    float amount =
        saturate(ElderPostpassVignetteStrength) * saturate(ElderPostpassIntensity);
    return lerp(display_color, display_color * vignette, amount);
}

float3 ElderApplyFineGrain(float2 uv, float3 display_color)
{
    float2 pixel = floor(uv * max(ElderScreenResolution(ScreenSize), 1.0.xx));
    float grain = (ElderFinishHash(pixel + float2(71.0, 71.0)) - 0.5)
        * (saturate(ElderPostpassGrainShape) / 255.0);
    return saturate(display_color + grain.xxx);
}

float3 ElderApplyTerminalTriangularDither(float2 uv, float3 display_color)
{
    float2 pixel = floor(uv * max(ElderScreenResolution(ScreenSize), 1.0.xx));
    float triangular = ElderFinishHash(pixel)
        - ElderFinishHash(pixel + float2(17.0, 53.0));
    return saturate(display_color + (triangular / 255.0).xxx);
}

float3 ElderFinishLdr(float2 uv, float3 display_color)
{
    if (!ElderStageIsActive() || ElderPostpassIntensity <= 0.0)
    {
        return display_color;
    }

    float3 finished = saturate(ElderFiniteOrBlack(display_color));
    finished = ElderApplyLdrVignette(uv, finished);
    finished = ElderApplyFineGrain(uv, finished);
    return ElderApplyTerminalTriangularDither(uv, finished);
}

#endif  // ELDER_POST_FINISH_FXH
