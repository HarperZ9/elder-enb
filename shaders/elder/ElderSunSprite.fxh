#ifndef ELDER_SUN_SPRITE_FXH
#define ELDER_SUN_SPRITE_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderSunSprite.fxh
#endif

// Additive sprite contribution for one directional light. Placement and
// visibility come from the caller; this function only shapes the disc and
// halo. uv and sun_uv are screen UV with y down; aspect (width/height)
// corrects the x axis so the disc stays circular on any resolution. The
// result is HDR scene light added on top of the frame, bounded below 8.0.
float3 ElderEvaluateSunSprite(
    float2 uv,
    float2 sun_uv,
    float aspect,
    float visibility,
    float3 sun_color)
{
    if (ElderSunSpriteIntensity <= 0.0 || visibility <= 0.0)
    {
        return 0.0.xxx;
    }

    float2 delta = uv - sun_uv;
    delta.x *= aspect;
    float distance_to_disc = length(delta);

    // Radius is a fraction of screen height. The halo half-life sits at two
    // disc radii, so the glow dies within roughly eight radii instead of
    // collapsing inside the disc the way the old 48/radius exponent did.
    float radius = lerp(0.008, 0.024, saturate(ElderSunSpriteDiscShape));
    float disc = 1.0 - smoothstep(radius * 0.70, radius, distance_to_disc);
    float halo = exp2(-distance_to_disc / max(radius * 2.0, 0.0001));

    float3 sprite = sun_color
        * (disc * 4.0 + halo)
        * saturate(visibility)
        * saturate(ElderSunSpriteIntensity);
    return min(ElderFiniteOrBlack(sprite), 8.0.xxx);
}

#endif  // ELDER_SUN_SPRITE_FXH
