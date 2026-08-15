#ifndef ELDER_TEMPORAL_DITHER_FXH
#define ELDER_TEMPORAL_DITHER_FXH

#include "ElderRuntimeParameters.fxh"

// Temporal dither: the first consumer of the runtime frame pulse.
//
// The colour core tonemaps to a display-referred value which ENB then writes at
// eight bits per channel. A smooth gradient quantised at eight bits bands, and
// Elder's own output bands worst exactly where it matters: night skies, fog,
// and the shadow rolloff the tonemap toe produces.
//
// Adding a sub-quantum offset before the quantisation breaks a band edge into
// interleaved pixels of the two neighbouring levels, which the eye reads as the
// intermediate value. That much needs no runtime at all. What the runtime adds
// is time: advancing the pattern every frame turns a fixed dot texture into
// noise that averages out over a few frames, so the gradient reads as smooth
// rather than as a visible screen-door.
//
// Degradation is the point of the design:
//
//   plugin absent   static ordered dither, which still removes banding but
//                   leaves a fixed pattern
//   plugin present  the same dither advanced per frame, which the eye
//                   integrates away
//
// So the shader is useful on its own and better with the bridge, and it never
// depends on the bridge being there.

// One quantisation step at eight bits. The offset must stay inside this or the
// dither stops being invisible and starts being noise.
static const float ElderDitherQuantum = 1.0 / 255.0;

// A 4x4 ordered Bayer matrix, normalised to [0,1). Ordered rather than random
// because a random offset per pixel produces static that survives temporal
// averaging, while an ordered pattern cancels cleanly.
float ElderDitherBayer4x4(float2 pixel)
{
    const float2 cell = floor(fmod(abs(pixel), 4.0));
    const int index = int(cell.y) * 4 + int(cell.x);

    // Row-major Bayer values, times 16.
    float scaled = 0.0;
    if (index == 0)       scaled = 0.0;
    else if (index == 1)  scaled = 8.0;
    else if (index == 2)  scaled = 2.0;
    else if (index == 3)  scaled = 10.0;
    else if (index == 4)  scaled = 12.0;
    else if (index == 5)  scaled = 4.0;
    else if (index == 6)  scaled = 14.0;
    else if (index == 7)  scaled = 6.0;
    else if (index == 8)  scaled = 3.0;
    else if (index == 9)  scaled = 11.0;
    else if (index == 10) scaled = 1.0;
    else if (index == 11) scaled = 9.0;
    else if (index == 12) scaled = 15.0;
    else if (index == 13) scaled = 7.0;
    else if (index == 14) scaled = 13.0;
    else                  scaled = 5.0;

    // Centre the cell on 0.5. Plain scaled/16 yields values 0/16..15/16 whose
    // mean is 0.46875, so an offset built from it carries a DC bias of about
    // -0.03 of a quantum: the whole image drifts fractionally darker. The half
    // step removes that exactly.
    return (scaled + 0.5) / 16.0;
}

// Per-frame rotation of the pattern, in value space rather than screen space.
//
// Offsetting the lookup coordinate instead is the obvious approach and it does
// not work: which four cells a pixel visits then depends on where that pixel
// sits, and for many pixels all four land on the same side of the threshold.
// At (9,5) with a (phase, 3*phase) coordinate offset the four visited values
// are 0.125, 0.3125, 0.1875 and 0.25, every one of them below 0.5, so a value
// halfway between two levels rounds down on all four frames and never dithers
// at all.
//
// Rotating the value by a quarter of the range per phase is position
// independent: whatever a pixel's base value is, its four phases are that
// value plus 0, 1/4, 1/2 and 3/4, which always straddle the threshold and
// always average to the middle.
float ElderDitherPhaseRotation()
{
    if (!ElderRuntimeBridgeLive()) {
        return 0.0;
    }
    return fmod(ElderRuntimeFramePulse.x, 4.0) * 0.25;
}

// The offset to add before quantisation, in output units.
//
// Centred on zero: a dither that only ever adds brightness lifts black, which
// on a night sky is worse than the banding it removes.
float ElderDitherOffset(float2 pixel_coordinate)
{
    const float bayer = ElderDitherBayer4x4(pixel_coordinate);
    const float rotated = frac(bayer + ElderDitherPhaseRotation());
    return (rotated - 0.5) * ElderDitherQuantum;
}

// Applies the dither to a display-referred colour.
//
// Takes a texcoord and derives the pixel from the runtime's reported output
// size, so the pattern is one cell per output pixel at any resolution. Falling
// back to a fixed 1920x1080 when the bridge is absent keeps the cell size
// sane rather than collapsing the whole pattern into a single cell.
float3 ElderApplyTemporalDither(float3 color, float2 texcoord)
{
    float2 output_size = ElderRuntimeOutputSize();
    if (output_size.x < 1.0 || output_size.y < 1.0) {
        output_size = float2(1920.0, 1080.0);
    }

    const float offset = ElderDitherOffset(texcoord * output_size);

    // Clamp after offsetting. A negative offset on a black pixel would
    // otherwise produce a negative value that the following stage has to cope
    // with, and black is where this effect is most often applied.
    return saturate(color + offset.xxx);
}


// Temporal offset for an interleaved-gradient-noise dither.
//
// The shipped Elder preset already dithers with IGN, and its noise is
// per-channel, which decorrelates better than a single luma offset. Replacing
// it with the Bayer path above would be a regression, so the pulse animates it
// in place instead.
//
// IGN is animated by advancing the sample position, not the value: the
// published constant is 5.588238 per frame over a 64-frame cycle, chosen so
// successive frames land far apart in the noise field. Returns zero when the
// bridge is absent, leaving the preset's original static dither exactly as it
// was.
float2 ElderDitherIgnOffset()
{
    if (!ElderRuntimeBridgeLive()) {
        return float2(0.0, 0.0);
    }
    const float cycle = fmod(ElderRuntimeFramePulse.x, 64.0);
    return (5.588238 * cycle).xx;
}

#endif  // ELDER_TEMPORAL_DITHER_FXH
