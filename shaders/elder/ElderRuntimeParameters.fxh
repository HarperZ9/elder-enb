#ifndef ELDER_RUNTIME_PARAMETERS_FXH
#define ELDER_RUNTIME_PARAMETERS_FXH

// Hidden runtime-published prepass payloads. Task 6 owns the native publisher;
// Task 3 only defines the shader ABI and fail-closed read contract.

float4 ElderRuntimeRoomLight
<
    string UIName = "Elder Runtime | Room Light";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

float4 ElderRuntimeStatus
<
    string UIName = "Elder Runtime | Status";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

// Room light layout:
//   x = bounded room luminance
//   y = exterior daylight contribution
//   z = aperture/open fraction
//   w = sealed-room flag
//
// Status layout:
//   x = schema/live marker
//   y = valid marker, written last by the publisher
//   z = folded generation
//   w = schema fingerprint tag

bool ElderRuntimeParameterFinite1(float value)
{
    return (asuint(value) & 0x7fffffffu) < 0x7f800000u;
}

bool ElderRuntimeParameterFinite4(float4 value)
{
    return all((asuint(value) & 0x7fffffffu.xxxx) < 0x7f800000u.xxxx);
}

bool ElderRuntimeStatusIsValid(float4 status)
{
    return ElderRuntimeParameterFinite4(status)
        && status.x >= 1.0
        && status.y >= 1.0;
}

bool ElderRuntimeRoomLightIsValid(float4 room_light)
{
    return ElderRuntimeParameterFinite4(room_light)
        && room_light.x >= 0.0
        && room_light.x <= 1000000.0
        && room_light.y >= 0.0
        && room_light.y <= room_light.x
        && room_light.z >= 0.0
        && room_light.z <= 1.0
        && room_light.w >= 0.0
        && room_light.w <= 1.0;
}

float4 ElderRuntimeSanitizeRoomLight(float4 room_light)
{
    return float4(
        clamp(room_light.x, 0.0, 1000000.0),
        clamp(room_light.y, 0.0, 1000000.0),
        saturate(room_light.z),
        saturate(room_light.w));
}

#endif  // ELDER_RUNTIME_PARAMETERS_FXH
