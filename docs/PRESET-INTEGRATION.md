# Wiring the frame pulse into a preset shader

Elder ships no `.fx` files. The shaders in a user's `enbseries` folder come from
whatever preset they installed, so the runtime pulse only reaches a live frame
once a preset shader reads it. This is the integration, kept here rather than in
the package because the shader it edits is not Elder's to redistribute.

## Declare the parameter

Next to ENB's own externals, near the top of the shader:

```hlsl
float4  ElderRuntimeFramePulse
<
    string UIName = "Elder Runtime | Frame Pulse";
    string UIWidget = "Ignore";
> = {0.0, 0.0, 0.0, 0.0};
```

    x  frame counter, 1-based, wrapped at 2^24; exactly 0 when not live
    y  frame delta in seconds
    z  output width      w  output height

All zero when the plugin is absent. Every read below has to tolerate that, and
a shader that integrates `y` without checking `x` first will freeze rather than
misbehave.

The parameter has to be read somewhere the compiler cannot prove is dead, or it
is stripped and the runtime's write lands nowhere. Using it in the dither below
is enough; a declaration on its own is not.

## Animate an existing dither

Most presets already dither before the eight-bit write. If yours does, animate
it rather than adding a second one: two dithers stacked are worse than either.

For interleaved gradient noise, which is what the Elder preset uses, advance the
sample position:

```hlsl
float ditherCycle = (ElderRuntimeFramePulse.x >= 1.0)
    ? fmod(ElderRuntimeFramePulse.x, 64.0)
    : 0.0;
float2 ditherPos = pos.xy + (5.588238 * ditherCycle).xx;
```

then sample the noise at `ditherPos` instead of `pos.xy`. `5.588238` over a
64-frame cycle is the published IGN advance, chosen so consecutive frames land
far apart in the noise field. The cycle keeps the value small enough to stay
exactly representable however long the session runs.

When the plugin is absent the offset is zero and the dither is bit-for-bit what
it was before.

## If your preset has no dither

Use `ElderTemporalDither.fxh` from `Native/Shaders`, which brings its own
ordered pattern and rotates it in value space. Apply it last, after tonemapping
and after any gamut compression: dithering earlier pushes the offset through a
curve that compresses it away in the shadows, which is where banding is worst.

## Why the pulse rather than ENB's Timer

`Timer` is already available and would also animate a dither, so this is worth
stating plainly rather than overselling the plugin.

Two differences. `Timer` is wall-clock, so the pattern advances by elapsed time
rather than by rendered frame, and it jumps unevenly through a stutter. The
pulse advances exactly once per frame. And `Timer` grows without bound, so its
float precision decays over a long session, while the pulse wraps at 2^24 and
stays exact.

Neither is dramatic. If you have no plugin, animating with `Timer` is a
reasonable substitute and better than a static dither.

## Verifying it works

`ElderEnbRuntimeFrameProbeV1` reports the published frame count, which
distinguishes a plugin that is merely bound from one that is driving frames.
If that count climbs and the dither still looks static, the parameter was
stripped: check that the shader reads it somewhere the compiler cannot fold
away.
