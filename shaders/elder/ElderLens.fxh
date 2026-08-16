#ifndef ELDER_LENS_FXH
#define ELDER_LENS_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderLens.fxh
#endif

float4 ElderStageOpticalIdentityWhenDisabled(
    float4 source,
    float4 candidate,
    bool stage_enabled,
    float intensity)
{
    return ElderStageIdentity(source, candidate, stage_enabled, intensity);
}

void ElderAccumulateLensGhost(
    inout float3 accumulated_lens,
    inout float accumulated_weight,
    float2 center_vector,
    float ghost_order)
{
    float ghost_scale = 0.45 + ghost_order * 0.28;
    float2 ghost_uv = saturate(0.5.xx - center_vector * ghost_scale);
    float3 ghost_color = TextureBloom.SampleLevel(Sampler0, ghost_uv, 0.0).rgb;
    float ghost_weight = 1.0 / (ghost_order + 1.0);
    accumulated_lens += ElderFiniteOrBlack(ghost_color) * ghost_weight;
    accumulated_weight += ghost_weight;
}

float4 ElderApplyLens(float2 uv, float4 bloom_source)
{
    if (!ElderStageIsActive() || ELDER_STAGE_INTENSITY <= 0.0)
    {
        return bloom_source;
    }

    if (ElderLensGhosts == 0u)
    {
        return bloom_source;
    }

    if (!ElderFinite3(bloom_source.rgb) || !ElderFinite1(bloom_source.a)
        || !ElderFinite3(ScreenSize.xyz))
    {
        return bloom_source;
    }

    float2 center_vector = uv - 0.5.xx;
    float3 accumulated_lens = 0.0.xxx;
    float accumulated_weight = 0.0;

#if ELDER_LENS_GHOSTS_VALUE >= 1
    ElderAccumulateLensGhost(accumulated_lens, accumulated_weight, center_vector, 1.0);
#endif
#if ELDER_LENS_GHOSTS_VALUE >= 2
    ElderAccumulateLensGhost(accumulated_lens, accumulated_weight, center_vector, 2.0);
#endif
#if ELDER_LENS_GHOSTS_VALUE >= 3
    ElderAccumulateLensGhost(accumulated_lens, accumulated_weight, center_vector, 3.0);
#endif

    float center_distance = length(center_vector);
    float2 safe_direction = center_distance > 0.0001
        ? center_vector / center_distance
        : float2(0.0, 1.0);
    float2 halo_uv = saturate(0.5.xx - safe_direction * 0.22);
    float3 halo_color = ElderFiniteOrBlack(
        TextureBloom.SampleLevel(Sampler0, halo_uv, 0.0).rgb);

    float3 filtered_lens = accumulated_lens / max(accumulated_weight, 0.0001);
    float3 lens_add =
        filtered_lens * max(ElderLensGhostStrength, 0.0)
        + halo_color * max(ElderLensHaloStrength, 0.0)
            * saturate(1.0 - center_distance * 1.35);
    float3 capped_lens = min(lens_add, max(ElderLensEnergyCap, 0.0).xxx);
    float3 candidate_color = bloom_source.rgb + capped_lens;
    float4 candidate = float4(
        ElderFinite3(candidate_color) ? max(candidate_color, 0.0.xxx) : bloom_source.rgb,
        bloom_source.a);
    return ElderStageOpticalIdentityWhenDisabled(bloom_source, candidate, true, 1.0);
}

#endif  // ELDER_LENS_FXH
