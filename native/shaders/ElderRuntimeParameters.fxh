#ifndef ELDER_RUNTIME_PARAMETERS_FXH
#define ELDER_RUNTIME_PARAMETERS_FXH

// Runtime-published parameters.
//
// Distinct from ElderNativeParameters.fxh, which is generated from the authored
// schema and holds values a user tunes. Nothing here is user-tunable: the Elder
// runtime plugin writes these each frame, and the shader only reads them. They
// carry no widget and no default worth editing, so they are hand-written rather
// than generated from a schema that exists to describe sliders.
//
// The runtime writes the frame pulse through the ENB SDK as a COLOR4, sixteen
// bytes, four floats. Layout matches enbcore::runtime::FramePulsePayload:
//
//     x  wrapped 1-based frame counter, exactly 0 while inactive
//     y  delta seconds for the frame
//     z  output width in pixels
//     w  output height in pixels
//
// The inactive payload is all zeroes and is written deliberately. A withheld or
// rejected pulse must not leave a stale live payload visible, so the runtime
// overwrites with zeroes rather than skipping the write.

float4 ElderRuntimeFramePulse
<
    string UIName = "Elder Runtime | Frame Pulse";
    string UIWidget = "Ignore";
> = {0.0, 0.0, 0.0, 0.0};

bool ElderRuntimeFinite(float value)
{
    return (asuint(value) & 0x7f800000u) != 0x7f800000u;
}

// True when the native bridge published a live pulse this frame.
//
// Test the counter, not the delta or the dimensions. The counter is the only
// field the runtime guarantees strictly positive while live, and it is the one
// the publication policy validates as an exact integer in [1, 2^24].
bool ElderRuntimeBridgeLive()
{
    return ElderRuntimeFinite(ElderRuntimeFramePulse.x)
        && ElderRuntimeFramePulse.x >= 1.0;
}

// Frame delta in seconds, or 0.0 when the bridge is not live. Guard any
// per-frame accumulation on ElderRuntimeBridgeLive() first: a shader that
// integrates this without checking will freeze rather than misbehave, which is
// the intended failure, but it will look like a bug.
float ElderRuntimeDeltaSeconds()
{
    return ElderRuntimeBridgeLive() ? ElderRuntimeFramePulse.y : 0.0;
}

// Output dimensions the runtime observed, or 0 when not live.
float2 ElderRuntimeOutputSize()
{
    return ElderRuntimeBridgeLive()
        ? float2(ElderRuntimeFramePulse.z, ElderRuntimeFramePulse.w)
        : float2(0.0, 0.0);
}

#endif  // ELDER_RUNTIME_PARAMETERS_FXH
