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

    // Energy model. The tonemap white point sits at 11.2, so a disc that
    // should read as a blown highlight must arrive near this module's pinned
    // 8.0 radiance bound. The old disc gain of 4.0 peaked at 0.9 radiance
    // under the shipped 0.18 dial, about the sky's own radiance, and the
    // noon disc measured 147.9 mean luma against a 107.5 sky in playtest.
    // These gains put the disc core at the bound from the shipped dial
    // upward, so across quality tiers the dial shapes the halo weight while
    // the core stays a clipped highlight.
    float disc_energy = disc * 40.0;
    float halo_energy = halo * 6.0;
    float3 sprite = sun_color
        * (disc_energy + halo_energy)
        * saturate(visibility)
        * saturate(ElderSunSpriteIntensity);
    return min(ElderFiniteOrBlack(sprite), 8.0.xxx);
}

#endif  // ELDER_SUN_SPRITE_FXH
