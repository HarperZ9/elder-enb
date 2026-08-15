#ifndef ELDER_DISPLAY_OUTPUT_FXH
#define ELDER_DISPLAY_OUTPUT_FXH

#include "ElderColorCore.fxh"
#include "ElderTemporalDither.fxh"

// The composed display stage: colour core, then dither, in that order.
//
// This is the entry point a preset's enbeffect.fx calls. It exists because the
// order is not a free choice and getting it wrong silently wastes the dither.
//
// The dither has to come last, after tonemapping, because its whole job is to
// survive the eight-bit quantisation that happens immediately after this
// returns. Dithering before the tonemap would push the offset through a
// non-linear curve that compresses it away in the shadows, which is exactly
// where banding is worst and where the dither is most needed.
//
// It also has to come after the gamut compression the colour core ends with,
// or the compression would pull the two dithered levels back toward each other
// and undo the spread.

float3 ElderEvaluateDisplayOutput(
    float3 scene_linear,
    ElderColorCoreParameters parameters,
    float2 texcoord)
{
    const float3 graded = ElderEvaluateColorCore(scene_linear, parameters);
    return ElderApplyTemporalDither(graded, texcoord);
}

#endif  // ELDER_DISPLAY_OUTPUT_FXH
