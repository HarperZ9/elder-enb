#define ELDER_STAGE_CAPABILITY ELDER_CAPABILITY_IDENTITY
#define ELDER_STAGE_OWNS_COLOR 1
#define ELDER_STAGE_OWNS_DEPTH 0
#define ELDER_STAGE_OWNS_NORMAL 0
#define ELDER_STAGE_OWNS_MASK 0
#define ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW 0
#define ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION 0
#define ELDER_STAGE_OWNS_BRIDGE_VALUE 0
#define ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE 0
#define ELDER_STAGE_SCRATCH_OWNER ELDER_SCRATCH_BLOOM
#define ELDER_STAGE_SCRATCH_READ ELDER_SCRATCH_NONE
#define ELDER_STAGE_OWNS_FULL_FRAME_HISTORY 0
#define ELDER_STAGE_OWNS_OBJECT_MOTION 0
#define ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY 0
#define ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING 0
#define ELDER_STAGE_PARAMETER_SLOT 2

#include "elder/ElderHostCapabilities.fxh"
#include "elder/ElderStageParameters.fxh"
#include "elder/ElderPipelineCommon.fxh"

// Scene input plus the six host-owned chain octaves. The 0.504 host feeds
// the bloom chain the square downsampled HDR scene whose dimensions arrive
// in BloomSize. Each numbered octave below is a host-owned square target at
// its literal size: a technique writes one through its RenderTarget
// annotation and later techniques read it by name. The annotation-less
// final technique writes the surface the main effect consumes as bloom.
Texture2D TextureDownsampled;
Texture2D RenderTarget512;
Texture2D RenderTarget256;
Texture2D RenderTarget128;
Texture2D RenderTarget64;
Texture2D RenderTarget32;
Texture2D RenderTarget16;
float4 ScreenSize;
// Host-owned size of the bloom render chain, packed like ScreenSize:
// x = width, y = 1/width, z = aspect, w = 1/aspect.
float4 BloomSize;

SamplerState Sampler0
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Clamp;
    AddressV = Clamp;
};

// Linear filtering for every chain resample.
SamplerState Sampler1
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

#include "elder/ElderBloom.fxh"

float4 ElderBloomExtract(ElderStageVSOutput input) : SV_Target
{
    float source_texel = ElderFinite1(BloomSize.y) && BloomSize.y > 0.0
        ? BloomSize.y
        : (1.0 / 1024.0);
    return ElderExtractBloomOctave(
        TextureDownsampled, Sampler1, input.texcoord, source_texel);
}

float4 ElderBloomOctaveTo256(ElderStageVSOutput input) : SV_Target
{
    return ElderBloomDownsampleOctave(
        RenderTarget512, Sampler1, input.texcoord, 1.0 / 512.0);
}

float4 ElderBloomOctaveTo128(ElderStageVSOutput input) : SV_Target
{
    return ElderBloomDownsampleOctave(
        RenderTarget256, Sampler1, input.texcoord, 1.0 / 256.0);
}

float4 ElderBloomOctaveTo64(ElderStageVSOutput input) : SV_Target
{
    return ElderBloomDownsampleOctave(
        RenderTarget128, Sampler1, input.texcoord, 1.0 / 128.0);
}

float4 ElderBloomOctaveTo32(ElderStageVSOutput input) : SV_Target
{
    return ElderBloomDownsampleOctave(
        RenderTarget64, Sampler1, input.texcoord, 1.0 / 64.0);
}

float4 ElderBloomOctaveTo16(ElderStageVSOutput input) : SV_Target
{
    return ElderBloomDownsampleOctave(
        RenderTarget32, Sampler1, input.texcoord, 1.0 / 32.0);
}

float4 ElderBloomMain(ElderStageVSOutput input) : SV_Target
{
    float4 source = TextureDownsampled.Sample(Sampler0, input.texcoord);
    float3 octave_512 =
        RenderTarget512.SampleLevel(Sampler1, input.texcoord, 0.0).rgb;
    float3 octave_256 =
        RenderTarget256.SampleLevel(Sampler1, input.texcoord, 0.0).rgb;
    float3 octave_128 =
        RenderTarget128.SampleLevel(Sampler1, input.texcoord, 0.0).rgb;
    float3 octave_64 =
        RenderTarget64.SampleLevel(Sampler1, input.texcoord, 0.0).rgb;
    float3 octave_32 =
        RenderTarget32.SampleLevel(Sampler1, input.texcoord, 0.0).rgb;
    float3 octave_16 =
        RenderTarget16.SampleLevel(Sampler1, input.texcoord, 0.0).rgb;
    return ElderApplyBloom(source, octave_512, octave_256, octave_128,
        octave_64, octave_32, octave_16);
}

technique11 Draw <string UIName = "Elder [30] Bloom"; string RenderTarget = "RenderTarget512";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderBloomExtract()));
    }
}

technique11 Draw1 <string RenderTarget = "RenderTarget256";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderBloomOctaveTo256()));
    }
}

technique11 Draw2 <string RenderTarget = "RenderTarget128";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderBloomOctaveTo128()));
    }
}

technique11 Draw3 <string RenderTarget = "RenderTarget64";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderBloomOctaveTo64()));
    }
}

technique11 Draw4 <string RenderTarget = "RenderTarget32";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderBloomOctaveTo32()));
    }
}

technique11 Draw5 <string RenderTarget = "RenderTarget16";>
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderBloomOctaveTo16()));
    }
}

technique11 Draw6
{
    pass p0
    {
        SetVertexShader(CompileShader(vs_5_0, ElderFullscreenVertex()));
        SetPixelShader(CompileShader(ps_5_0, ElderBloomMain()));
    }
}
