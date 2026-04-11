//----------------------------------------------------------------------------------------------//
//																								//
//				  Gaussian-like blue noise dither by LonelyKitsuune aka Skratzer				//
//								for ENB (DirectX 11 Shader Model 5)								//
//																								//
//			   Copyright (c) 2019-2020 LonelyKitsuune / T.Thanner - CC BY-NC-ND 4.0				//
//																								//
//----------------------------------------------------------------------------------------------//

#ifndef _KITSUUNE_DITHER_
#define _KITSUUNE_DITHER_


//----------------------------------------------------------------------------------------------//
// IMPLEMENTATION (add dithering before colors get compressed into a lower bit depth)
//		GaussBlueDither(Color.rgb, IN.pos.xy, target bit depth)


//Quantize output color directly (only useful for debugging)
#define QUANTIZE_OUTPUT 0 //[0-1]


//8x8 atlas with 64x64 blue noise textures
// -> Thanks to Christoph Peters for the individual textures (Moments in Graphics Blog)
Texture2D BlueNoiseTexAtlas <string ResourceName="Textures/BlueNoiseAtlas.png";>;


//----------------------------------------------------------------------------------------------//

float3 GetTemporalDitherParams(float TOffset)
{
	#ifndef DITHER_UI_PROVIDED
		const float UID_Motion = 1.0;
	#endif
	
	float DitherTimer = floor((Timer.z + TOffset) * UID_Motion);
	float GridSwitch  = frac(floor(DitherTimer / 64.0) * 0.5);
	
	float TimeSelect  = frac(DitherTimer / 64.0) * 64.0;
	float AtlasColumn = floor(TimeSelect / 8.0);
	float AtlasRow    = TimeSelect - AtlasColumn * 8.0;
	
	return float3(float2(AtlasRow, AtlasColumn) * 64.0, GridSwitch);
}

void GaussBlueDither(inout float3 Color, float2 Pos, float3 TemporalParams, int BitDepth)
{
	#ifndef DITHER_UI_PROVIDED
		const bool  UID_Visualize = false;
		const float UID_Intensity = 1.0;
	#endif
	
	const float OutputAccuracy = exp2(BitDepth) - 1.0;
	const float AccuracyStep   = rcp(OutputAccuracy);
	
	//Subdivide screen into 64 pixel quads
	float2 FracPos, NoisePos;
	FracPos = frac(Pos / 64.0);
	
	//Add offsets and reverse fractional position every 64 ticks
	NoisePos = abs(TemporalParams.z * 2.0 - FracPos);
	NoisePos = NoisePos * 64.0 + TemporalParams.xy;
	
	//Sample blue noise (one per channel) and compute gaussian like distributed dither
	float Dither = dot(BlueNoiseTexAtlas.Load(int3(NoisePos,0)), 0.25);
		  Dither = UID_Intensity * (Dither * 2.0 - 1.0);
	
	//Remove dither from pixels that approach pure white/black
	float2 HiLoLimit = { (OutputAccuracy - 0.5) * AccuracyStep, 0.5 * AccuracyStep };
		   HiLoLimit = LinearStep(float2(1.0, 0.0), HiLoLimit, dot(Color, K_LUM));
		   Dither   *= min2(HiLoLimit);
	
	
	Color = saturate(Dither * AccuracyStep + (UID_Visualize ? 0.5 : Color));
	
	#if QUANTIZE_OUTPUT
	Color = round(Color / AccuracyStep) * AccuracyStep;
	#endif
}

void GaussBlueDither(inout float3 Color, float2 Pos, int BitDepth)
{ GaussBlueDither(Color, Pos, GetTemporalDitherParams(0.0), BitDepth); }


#endif //_KITSUUNE_DITHER_
