#ifndef ELDER_LENS_FXH
#define ELDER_LENS_FXH

#ifndef ELDER_PIPELINE_COMMON_FXH
#error Include ElderPipelineCommon.fxh before ElderLens.fxh
#endif

float ElderLensScratchAlpha(float source_alpha)
{
    return ElderFinite1(source_alpha) ? source_alpha : 1.0;
}

float4 ElderNeutralLensScratch(float source_alpha)
{
    return float4(0.0.xxx, ElderLensScratchAlpha(source_alpha));
}

float4 ElderLensContribution(float3 radiance, float source_alpha)
{
    float cap_value = max(ElderLensEnergyCap, 0.0);
    float3 bounded_radiance = min(ElderFiniteOrBlack(radiance), cap_value.xxx);
    return float4(bounded_radiance, ElderLensScratchAlpha(source_alpha));
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
        return ElderNeutralLensScratch(bloom_source.a);
    }

    if (ElderLensGhosts == 0u)
    {
        return ElderNeutralLensScratch(bloom_source.a);
    }

    if (!ElderFinite3(bloom_source.rgb) || !ElderFinite1(bloom_source.a)
        || !ElderFinite3(ScreenSize.xyz))
    {
        return ElderNeutralLensScratch(bloom_source.a);
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
    float3 capped_lens = min(
        lens_add * saturate(ElderLensIntensity),
        max(ElderLensEnergyCap, 0.0).xxx);
    return ElderLensContribution(capped_lens, bloom_source.a);
}

#endif  // ELDER_LENS_FXH
