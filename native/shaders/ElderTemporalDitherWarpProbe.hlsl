// Parity probe for ElderTemporalDither.fxh.
//
// The dither exists in two places: the HLSL that ships, and the C++ reference
// the tests assert against. Two copies of the same Bayer table and the same
// rotation is exactly the kind of duplication that drifts silently, so this
// probe runs the shipped HLSL on a software device and the test compares it to
// the reference value by value.
//
// The pulse is supplied per element rather than read from the real parameter,
// so one dispatch can cover the live and inactive cases and several frames.

#include "ElderTemporalDither.fxh"

// x, y: pixel coordinate. z: pulse frame, 0 for inactive. w: unused.
StructuredBuffer<float4> ElderDitherProbeInputs : register(t0);

// x: bayer value. y: phase rotation. z: signed offset. w: dithered mid-level.
RWStructuredBuffer<float4> ElderDitherProbeResults : register(u0);

// The probe drives the pulse itself instead of reading ElderRuntimeFramePulse,
// so the two paths under test are the maths, not ENB's parameter plumbing.
static float ElderDitherProbeFrame = 0.0;

float ElderDitherProbeRotation()
{
    if (!(ElderDitherProbeFrame >= 1.0))
    {
        return 0.0;
    }
    return fmod(ElderDitherProbeFrame, 4.0) * 0.25;
}

[numthreads(64, 1, 1)]
void ElderTemporalDitherWarpProbeMain(uint3 dispatch_thread_id : SV_DispatchThreadID)
{
    uint element_count;
    uint element_stride;
    ElderDitherProbeInputs.GetDimensions(element_count, element_stride);
    if (dispatch_thread_id.x >= element_count || element_stride != 16)
    {
        return;
    }

    const float4 input = ElderDitherProbeInputs[dispatch_thread_id.x];
    ElderDitherProbeFrame = input.z;

    const float bayer = ElderDitherBayer4x4(input.xy);
    const float rotation = ElderDitherProbeRotation();
    const float rotated = frac(bayer + rotation);
    const float offset = (rotated - 0.5) * ElderDitherQuantum;

    // A value exactly between two eight-bit levels: the case the whole effect
    // is built for.
    const float dithered = saturate(50.5 / 255.0 + offset);

    ElderDitherProbeResults[dispatch_thread_id.x] =
        float4(bayer, rotation, offset, dithered);
}
