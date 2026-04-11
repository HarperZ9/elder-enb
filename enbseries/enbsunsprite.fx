//----------------------------------------------------------------------------------------------//
//																								//
//						enbsunsprite.fx file by LonelyKitsuune aka Skratzer						//
//						   for Skyrim SE ENB (DirectX 11 Shader Model 5)						//
//																								//
//			   Copyright (c) 2019-2020 LonelyKitsuune / T.Thanner - CC BY-NC-ND 4.0				//
//																								//
//-------------------------------------------CREDITS--------------------------------------------//
//																								//
//								  Boris Vorontsov for ENBSeries									//
//																								//
//----------------------------------------------------------------------------------------------//
//								==================================								//
//								//     Silent Horizons ENB      //								//
//								//								//								//
//								//		by LonelyKitsuune		//								//
//								==================================								//
//----------------------------------------------------------------------------------------------//

//This file needs my helper and UI files to work!

//--------------------------------------------------------------------------------
//OPTIONS
//--------------------------------------------------------------------------------
//Enables a more accurate intensity and sun color detection
#define USE_CUSTOM_SUNINTENSITY_DETECTOR	1 //[0-1]
#define ENABLE_DETECTOR_DEPTH_TESTING		0 //[0-1]


//Compute randomness pattern with subpixel precision to
//produce a "supersampled" or blurred result
#define ENABLE_HOOP_ANTIALIASING			1 //[0-1]
#define ENABLE_STARBURST_ANTIALIASING		1 //[0-1]


//----------------------------------------------------------------------------------------------//
//										Internal Parameters										//
//----------------------------------------------------------------------------------------------//

#include "UI/enbUI_Primer.fxh"


//Lens settings with single-section-UI
#define SHADERGROUP 0
#include "UI/enbUI_SunSprite.fxh"
UI_WHITESPACE(14)
UI_WHITESPACE(15)


//Anamorphic Lens Flare
#define SHADERGROUP 1
#define PASS 1
#define SWS  1
#include "UI/enbUI_SunSprite.fxh"

#define PASS 2
#define SWS  2
#include "UI/enbUI_SunSprite.fxh"

#define PASS 3
#define SWS  3
#include "UI/enbUI_SunSprite.fxh"

UI_WHITESPACE(16)
UI_WHITESPACE(17)
#undef SHADERGROUP


//Ghost Lens Flare (first single then double)
#define SHADERGROUP 2
#define PASS 1
#define SWS  4
#include "UI/enbUI_SunSprite.fxh"

#define PASS 2
#define SWS  5
#include "UI/enbUI_SunSprite.fxh"

#define PASS 3
#define SWS  6
#include "UI/enbUI_SunSprite.fxh"

#define PASS 4
#define SWS  7
#include "UI/enbUI_SunSprite.fxh"

#define PASS 5
#define SWS  8
#include "UI/enbUI_SunSprite.fxh"

#define PASS 6
#define SWS  9
#include "UI/enbUI_SunSprite.fxh"

#define PASS 7
#define SWS  10
#include "UI/enbUI_SunSprite.fxh"

#define PASS 8
#define SWS  11
#include "UI/enbUI_SunSprite.fxh"

#define PASS 9
#define SWS  12
#include "UI/enbUI_SunSprite.fxh"
#undef SHADERGROUP


#define SHADERGROUP 3
#define PASS 1
#define SWS  13
#include "UI/enbUI_SunSprite.fxh"

#define PASS 2
#define SWS  14
#include "UI/enbUI_SunSprite.fxh"

#define PASS 3
#define SWS  15
#include "UI/enbUI_SunSprite.fxh"

#define PASS 4
#define SWS  16
#include "UI/enbUI_SunSprite.fxh"

#define PASS 5
#define SWS  17
#include "UI/enbUI_SunSprite.fxh"

#define PASS 6
#define SWS  18
#include "UI/enbUI_SunSprite.fxh"

#define PASS 7
#define SWS  19
#include "UI/enbUI_SunSprite.fxh"

#define PASS 8
#define SWS  20
#include "UI/enbUI_SunSprite.fxh"
#undef SHADERGROUP



//----------------------------------------------------------------------------------------------//
//						     External enb parameters, do not modify								//
//																								//
//----------------------------------------------------------------------------------------------//
float4 Timer;			// x = generic timer in range 0..1, period of 16777216 ms (4.6 hours), y = average fps,
						// z = frame number (cyclically wraps to 0 after 9999 frames passed), w = frame time elapsed (in seconds)
float4 ScreenSize;		// x = Width, y = 1/Width, z = aspect, w = 1/aspect, aspect is Width/Height
float  AdaptiveQuality;	// changes in range 0..1, 0 means full quality, 1 lowest dynamic quality (0.33, 0.66 are limits for quality levels)
float4 TimeOfDay1;		// x = dawn, y = sunrise, z = day, w = sunset. Interpolators range from 0..1
float4 TimeOfDay2;		// x = dusk, y = night. Interpolators range from 0..1
float  ENightDayFactor;	// changes in range 0..1, 0 means that night time, 1 - day time
float  EInteriorFactor;	// changes 0 or 1. 0 means that exterior, 1 - interior
float  FieldOfView;		// FOV in degrees
float4 Weather;			// x = current weather index, y = outgoing weather index, z = weather transition, w = time of the day in 24 standard hours.
						// Weather index is value from weather ini file, for example WEATHER002 means index==2, but index==0 means that weather not captured.
						// -> Needs ENB Helper skse64 plugin to work correctly!
float4 LightParameters; // xy = sun position on screen, w = visibility


//----------------------------------------------------------------------------------------------//
//						       External enb debugging parameters for								//
//								 shader programmers, do not modify								//
//----------------------------------------------------------------------------------------------//
float4 tempF1; //0,1,2,3
float4 tempF2; //5,6,7,8
float4 tempF3; //9,0
//keyboard controlled temporary variables. Press and hold key 1,2,3...8 together with PageUp or PageDown to modify.
//By default all set to 1.0

float4 tempInfo1;
// xy = cursor position in range 0..1 of screen;
// z = is shader editor window active;
// w = mouse buttons with values 0..7 as follows:
//    0 = none
//    1 = left
//    2 = right
//    3 = left+right
//    4 = middle
//    5 = left+middle
//    6 = right+middle
//    7 = left+right+middle (or rather cat is sitting on your mouse)

float4 tempInfo2;
// xy = cursor position of previous left mouse button click
// zw = cursor position of previous right mouse button click


//----------------------------------------------------------------------------------------------//
//						     Game and mod parameters, do not modify								//
//																								//
//----------------------------------------------------------------------------------------------//
Texture2D TextureMask;	//Mask of sun as visibility factor
Texture2D TextureColor;	//Scene color R16B16G16A16 64 bit hdr format
Texture2D TextureDepth;	//Scene depth R32F 32 bit hdr format

Texture2D LensDirtAtlas <string ResourceName="Textures/LensDirtTexAtlas.png";>;

SamplerState Point_Sampler
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};

SamplerState Linear_Sampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

#if ENABLE_DETECTOR_DEPTH_TESTING
SamplerComparisonState Linear_Sampler_Eql
{
	Filter = COMPARISON_MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
	ComparisonFunc = EQUAL;
};
#endif


//Helper with some useful macros, variables and functions
#include "Helper/enbHelper_Common.fxh"


//----------------------------------------------------------------------------------------------//
//										   Structs												//
//																								//
//----------------------------------------------------------------------------------------------//

struct VertexShaderInput
{
   float3 pos     : POSITION;
   float2 txcoord : TEXCOORD0;
};

struct VertexShaderOutput
{
   float4 pos      : SV_POSITION;
   float2 texcoord : TEXCOORD0;
};

struct VertexShaderOutputGSprite
{
   float4 pos                  : SV_POSITION;
   float4 texcoord             : TEXCOORD0;
NI float  SunInt               : SPRITE0;
NI float  RoundingRadius       : SPRITE1;
NI float2 CAOffsetVec          : SPRITE2;
NI float3 FlareTint            : SPRITE3;
NI float  Scale                : SPRITE4;
NI float2 ApertureVertices[10] : SPRITE5;
};

struct VertexShaderOutputSBSprite
{
   float4 pos                  : SV_POSITION;
   float4 texcoord             : TEXCOORD0;
NI float  SunInt               : SPRITE0;
NI float3 FlareTint            : SPRITE1;
NI bool   OddShape             : SPRITE2;
NI float  SafeZone             : SPRITE3;
NI float2 ApertureVertices[10] : SPRITE4;
};

struct VertexShaderOutputHoopSprite
{
   float4 pos                  : SV_POSITION;
   float4 texcoord             : TEXCOORD0;
NI float  SunInt               : SPRITE0;
NI float  RoundingRadius       : SPRITE1;
NI float2 CAOffsetVec          : SPRITE2;
NI float3 FlareTint            : SPRITE3;
NI float  MaxPossibleVertDist  : SPRITE4;
NI float2 ApertureVertices[10] : SPRITE5;
};

struct VertexShaderOutputAnamSprite
{
   float4 pos       : SV_POSITION;
   float4 texcoord  : TEXCOORD0;
NI float  SunInt    : SPRITE0;
NI float3 FlareTint : SPRITE3;
};

struct VertexShaderOutputLensGlareSprite
{
   float4 pos      : SV_POSITION;
   float4 texcoord : TEXCOORD0;
NI float4 Glare    : SPRITE0;
NI float  SunDist  : SPRITE1;
NI float  MinRatio : SPRITE2;
NI float  MaxRatio : SPRITE3;
};

struct VertexShaderOutputSunGlareSprite
{
   float4 pos      : SV_POSITION;
   float4 texcoord : TEXCOORD0;
NI float4 Glare    : SPRITE0;
};


//----------------------------------------------------------------------------------------------//
//										    Functions											//
//																								//
//----------------------------------------------------------------------------------------------//

//Lowest sun intensity before shaders are skipped
#define SUN_INTENSITY_CLIP 0.01


float3 DiffractionF3(float3 x, float freq, float phase, float ampli)
{
	float3 sinc = PI * (x * freq + phase) + DELTA;
		   sinc = sin(sinc) / sinc;
	return sinc * sinc * ampli;
}

static float GetSunIntensity(float FlareInt, out float3 SunCol)
{
	#if USE_CUSTOM_SUNINTENSITY_DETECTOR
		static const float2 offset[5] = { 0.0,0.0, 0.0,-1.5, -1.5,0.0, 1.5,0.0, 0.0,1.5 };
		
		float2 SunUV  = LightParameters.xy * float2(0.5, -0.5) + 0.5;
		float3 AvgCol = 0.0;
		
		[unroll] for(int i=0; i<5; i++)
		{
			float2 CurrCoords = SunUV + offset[i] * PixelSize;
			float3 CurrSample = TextureColor.SampleLevel(Linear_Sampler, CurrCoords,0).rgb;
			
			#if ENABLE_DETECTOR_DEPTH_TESTING
				CurrSample *= TextureDepth.SampleCmpLevelZero(Linear_Sampler_Eql, CurrCoords, 1.0).x;
			#endif
			
			AvgCol += CurrSample;
		}
		
		AvgCol *= 0.2;
		SunCol  = AvgCol / (AvgCol + 1.0);
		AvgCol *= saturate(TextureMask.Load(0).x * LightParameters.w);
		
		return pow(saturate(dot(AvgCol, N_LUM) / 2.5),4) * FlareInt;
	#else
		SunCol = 1.0;
		return saturate(TextureMask.Load(0) * LightParameters.w) * FlareInt;
	#endif
}


//----------------------------------------------------------------------------------------------//
//										      Shaders											//
//																								//
//----------------------------------------------------------------------------------------------//

//------------------------------------------Ghost Flares-----------------------------------------//

VertexShaderOutputGSprite VS_GhostSprite(VertexShaderInput IN,
	uniform float  FlareOffset, uniform float FlareScale,
	uniform float  FlareInt,    uniform float CAScale,
	uniform float4 FlareTint)
{
	VertexShaderOutputGSprite OUT;
	OUT.pos          = float4(IN.pos.xyz, 1.0);
	OUT.texcoord     = IN.txcoord.xyxy;
	OUT.texcoord.zw *= 2.0 * CAScale + 2.0;
	OUT.texcoord.zw -= CAScale + 1.0;
	
	OUT.SunInt = GetSunIntensity(FlareInt * UIG_Int * UI_EnableGhost, OUT.FlareTint);
	
	[branch] if(OUT.SunInt > SUN_INTENSITY_CLIP)
	{
		float  ParamLength = length(LightParameters.xy);
		float2 LightParams = LightParameters.xy / ParamLength * nRoot(ParamLength, UIG_OffsetCurve);
		
		float2   Offset = LightParams * -FlareOffset * ScreenSize.z * 0.75;
		float2x2 RotMat = GetDirVec(UI_ApertureRotation).xyyx * float4(1.0, -1.0, 1.0, 1.0);
		
		OUT.Scale  = FlareScale * 0.1 * (CAScale + 1.0);
		OUT.pos.xy = mul(RotMat, OUT.pos.xy);
		OUT.pos.y *= ScreenSize.z;
		OUT.pos.xy = OUT.pos.xy * OUT.Scale + Offset;
		
		float OffsetMovement = Random(floor(FlareOffset * 10.0) + UIG_OMoveSeed) * 2.0 - 1.0;
			  OUT.pos.xy    += Offset * OffsetMovement * UIG_OMoveWeight * length(Offset);
		
		
		[unroll] for(int i=0; i<9; i++)
		OUT.ApertureVertices[i] = GetDirVec(360.0 / UI_ApertureShape * i);
		OUT.ApertureVertices[9] = OUT.ApertureVertices[0];
		
		
		OUT.CAOffsetVec = normalize(LightParams - Offset) * CAScale * 0.3;
		OUT.CAOffsetVec = mul(RotMat, OUT.CAOffsetVec * float2(ScreenSize.z, -1.0));
		OUT.FlareTint   = lerp(OUT.FlareTint, ColorToChroma(FlareTint.rgb), FlareTint.a);
		
		float RandomDirt = floor(FlareOffset * 10.0);
			  RandomDirt = Random(RandomDirt) * 0.5 + 0.5;
		OUT.texcoord.xy  = AtlasFetch_4(OUT.texcoord.xy * RandomDirt,4);
		OUT.Scale        = max(saturate(OUT.Scale * 10.0), 0.5);
	}
	
	return OUT;
}

float4 PS_GhostSprite(VertexShaderOutputGSprite IN,
	uniform float FlareFeather, uniform float FlareDiffInt,
	uniform float FlareDirtInt, uniform float FlareWeight,
	uniform float FlareVignette) : SV_Target
{
	float3 CenterDistance = { length(IN.texcoord.zw - IN.CAOffsetVec),
							  length(IN.texcoord.zw),
							  length(IN.texcoord.zw + IN.CAOffsetVec) };
	
	clip(min(1.0 - min3(CenterDistance), IN.SunInt - SUN_INTENSITY_CLIP));
	
	float2 SSCoords    = IN.pos.xy * PixelSize;
	float3 RadialDist  = saturate(1.0 - CenterDistance);
	float3 MinEdgeDist = RadialDist;
	
	[branch] if(UI_ApertureRoundness < 1.0)
	{
		[loop]   for(int i=0; i < UI_ApertureShape; i++)
		[unroll] for(int j=-1; j<2;)
		{
			//Test if coords are outside or inside the aperture shape (only works for convex polygons)
			float2 Edge     = float2(-1.0, 1.0) * (IN.ApertureVertices[i+1] - IN.ApertureVertices[i]);
			float  EdgeDist = dot(Edge.yx, IN.ApertureVertices[i]) -
							  dot(Edge.yx, IN.texcoord.zw + IN.CAOffsetVec * j);
			
			EdgeDist = lerp(EdgeDist, RadialDist[++j], (-EdgeDist * EdgeDist + 1.0) * UI_ApertureRoundness);
			
			MinEdgeDist[j] = min(MinEdgeDist[j], EdgeDist);
		}
		
		clip(max3(MinEdgeDist));
	}
	
	float3 Color = IN.SunInt * (MinEdgeDist > 0.0) * IN.FlareTint;
	
	float PhaseShift = min(FlareFeather + DELTA, 0.1) * -18.0;
	float Frequency  = 30.0 * UIG_DiffFreq * IN.Scale;
	Color += DiffractionF3(MinEdgeDist, Frequency, PhaseShift, FlareDiffInt) * Color;
	
	Color *= smoothstep(0.0, FlareFeather + DELTA, MinEdgeDist);
	Color *= smoothstep(6.0 * pow(FlareWeight,3), 0.0, MinEdgeDist);
	
	float VigWeight = ScreenSize.z - FlareVignette * ScreenSize.z;
	Color *= LinearStep(VigWeight + 0.1, VigWeight - 0.1, length(SSCoords * 2.0 - 1.0));
	
	Color += Color * LensDirtAtlas.Sample(Linear_Sampler, IN.texcoord.xy) * FlareDirtInt;
	return float4(Color, 1.0);
}


//-------------------------------------Hoop/Ring Lens Flare-------------------------------------//

VertexShaderOutputHoopSprite VS_HoopSprite(VertexShaderInput IN)
{
	VertexShaderOutputHoopSprite OUT;
	OUT.pos          = float4(IN.pos.xyz,1.0);
	OUT.texcoord     = IN.txcoord.xyxy;
	OUT.texcoord.zw *= 2.0 * UIHoop_CA + 2.0;
	OUT.texcoord.zw -= UIHoop_CA + 1.0;
	
	OUT.SunInt = GetSunIntensity(UIHoop_Int * UI_EnableHoop, OUT.FlareTint);
	
	[branch] if(OUT.SunInt > SUN_INTENSITY_CLIP)
	{
		float SunDistance = length(LightParameters.xy) * UIHoop_SunDistMod;
		
		float2   Offset = LightParameters.xy * -UIHoop_Offset * ScreenSize.z * 0.75;
		float2x2 RotMat = GetDirVec(UI_ApertureRotation).xyyx * float4(1.0, -1.0, 1.0, 1.0);
		
		float2 Scale = UIHoop_Scale * 0.1 * (UIHoop_CA + 1.0) * SunDistance;
		OUT.SunInt  *= saturate(SunDistance);
		
		OUT.pos.xy = mul(RotMat, OUT.pos.xy);
		OUT.pos.y *= ScreenSize.z;
		OUT.pos.xy = OUT.pos.xy * Scale + Offset;
		
		
		[unroll] for(int i=0; i<9; i++)
		OUT.ApertureVertices[i] = GetDirVec(360.0 / UI_ApertureShape * i);
		OUT.ApertureVertices[9] = OUT.ApertureVertices[0];
		
		float2 HalfVertex = OUT.ApertureVertices[0] + 0.5 * (OUT.ApertureVertices[1] - OUT.ApertureVertices[0]);
		
		float HalfVertexLength  = length(HalfVertex);
		OUT.RoundingRadius      = lerp(HalfVertexLength, 1.0, 1.0 - UIHoop_Roundness);
		OUT.MaxPossibleVertDist = distance(HalfVertex / HalfVertexLength, OUT.ApertureVertices[0]);
		
		OUT.CAOffsetVec = (LightParameters.xy - Offset) * UIHoop_CA * 0.3;
		OUT.CAOffsetVec = mul(RotMat, OUT.CAOffsetVec * float2(ScreenSize.z, -1.0));
		OUT.FlareTint   = lerp(OUT.FlareTint, ColorToChroma(UIHoop_Tint.rgb), UIHoop_Tint.a);
	}
	
	return OUT;
}

float4 PS_HoopSprite(VertexShaderOutputHoopSprite IN) : SV_Target
{
	float3 CenterDistance = { length(IN.texcoord.zw - IN.CAOffsetVec),
							  length(IN.texcoord.zw),
							  length(IN.texcoord.zw + IN.CAOffsetVec) };
	
	clip(min(1.0 - min3(CenterDistance), IN.SunInt - SUN_INTENSITY_CLIP));
	
	float3 RadialDist  = saturate(1.0 - CenterDistance);
	float3 MinEdgeDist = RadialDist;
	
	[branch] if(UI_ApertureRoundness < 1.0)
	{
		[loop]   for(int i=0; i < UI_ApertureShape; i++)
		[unroll] for(int j=-1; j<2;)
		{
			float2 Edge     = float2(-1.0, 1.0) * (IN.ApertureVertices[i+1] - IN.ApertureVertices[i]);
			float  EdgeDist = dot(Edge.yx, IN.ApertureVertices[i]) -
							  dot(Edge.yx, IN.texcoord.zw + IN.CAOffsetVec * j);
			
			EdgeDist = lerp(EdgeDist, RadialDist[++j], (-EdgeDist * EdgeDist + 1.0) * UI_ApertureRoundness);
			
			MinEdgeDist[j] = min(MinEdgeDist[j], EdgeDist);
		}
		
		float3 Interpolator = LinearStep(IN.RoundingRadius, 1.0, CenterDistance);
			   MinEdgeDist  = lerp(MinEdgeDist, pow(RadialDist,2), Interpolator);
		
		clip(max3(MinEdgeDist));
	}
	
	float3 Color = IN.SunInt * (MinEdgeDist > 0.0) * IN.FlareTint;
	
	Color *= smoothstep(0.0, 0.05, MinEdgeDist);
	Color *= smoothstep(6.0 * pow(UIHoop_Width,3), 0.0, MinEdgeDist);
	Color *= pow(saturate(UIHoop_Fade - dot(IN.texcoord.zw, normalize(IN.CAOffsetVec))),4);
	
	float  MinVertDist = 1.0;
	float2 NormCoords  = normalize(IN.texcoord.zw);
	
	[loop] for(int i=0; i < UI_ApertureShape; i++)
		MinVertDist = min(MinVertDist, distance(NormCoords, IN.ApertureVertices[i]));
	
	float VertGradient = LinearStep(0.0, IN.MaxPossibleVertDist, MinVertDist);
	float HoopPattern  = pow(sin(VertGradient * UIHoop_PatternFreq * PI),2);
	
	#if ENABLE_HOOP_ANTIALIASING
		float PatternInt = 0.0;
		float StepSize   = max2(PixelSize);
		
		[unroll] for(float i=-2.0; i <= 2.0; i += 2.0)
		{
			float CurrPattern = floor((VertGradient + i * StepSize) * UIHoop_IntRandom);
				  PatternInt += HoopPattern * Random(CurrPattern);
		}
		
		Color *= PatternInt / 3.0;
	#else
		Color *= HoopPattern * Random(floor(VertGradient * UIHoop_IntRandom));
	#endif
	
	return float4(Color, 1.0);
}


//-------------------------------------Starburst Lens Flare-------------------------------------//

VertexShaderOutputSBSprite VS_StarburstSprite(VertexShaderInput IN)
{
	VertexShaderOutputSBSprite OUT;
	OUT.pos         = float4(IN.pos.xyz, 1.0);
	OUT.texcoord.xy = IN.txcoord.xy;
	OUT.texcoord.zw = IN.txcoord.xy * 2.0 - 1.0;
	
	OUT.pos.y *= ScreenSize.z;
	OUT.pos.xy = OUT.pos.xy * UISB_Scale + LightParameters.xy;
	
	
	[unroll] for(int i=0; i<9; i++)
	OUT.ApertureVertices[i] = GetDirVec(360.0 / UI_ApertureShape * (i + 0.5) + UI_ApertureRotation);
	OUT.ApertureVertices[9] = OUT.ApertureVertices[0];
	
	OUT.SunInt    = GetSunIntensity(UISB_FlareInt * UI_EnableStarburst, OUT.FlareTint);
	OUT.FlareTint = lerp(OUT.FlareTint, ColorToChroma(UISB_FlareTint.rgb), UISB_FlareTint.a);
	OUT.OddShape  = UI_ApertureShape & 1;
	OUT.SafeZone  = rcp(0.005 / UISB_Scale);
	
	return OUT;
}

float4 PS_StarburstSprite(VertexShaderOutputSBSprite IN) : SV_Target
{
	float SunDist = length(IN.texcoord.zw);
	clip(min(1.0 - SunDist, IN.SunInt - SUN_INTENSITY_CLIP));
	
	float  InvertedRoundness = 1.0 - UI_ApertureRoundness;
	float  MinVertDist       = 1.0;
	float2 NormCoords        = normalize(IN.texcoord.zw);
	
	[loop] for(int i=0; i < UI_ApertureShape; i++)
		MinVertDist = min(MinVertDist, distance( NormCoords, IN.ApertureVertices[i]));
	
	[loop] for(;i > 0 && IN.OddShape; i--)
		MinVertDist = min(MinVertDist, distance(-NormCoords, IN.ApertureVertices[i]));
	
	float BurstWidth  = pow(SunDist, UISB_BurstWidthCurve);
		  BurstWidth *= 250.0 - 250.0 * sqrt(UISB_BurstWidth);
	
	float StarMask = pow(saturate(1.0 - MinVertDist), BurstWidth * InvertedRoundness);
		  StarMask = lerp(1.0, StarMask, saturate(SunDist * IN.SafeZone));
	
	#if ENABLE_STARBURST_ANTIALIASING
		static const float2 offsets[4] = { 0.5,0.5, -0.5,0.5, 0.5,-0.5, -0.5,-0.5 };
		float Randomness    = 0.0;
		float RandFrequency = UISB_RandFrequency * 10.0;
		
		[unroll] for(int i=0; i<4; i++)
			Randomness += Random(floor(normalize(IN.texcoord.zw + offsets[i] * PixelSize) * RandFrequency));
		Randomness *= 0.25;
	#else
		float Randomness = Random(floor(NormCoords * UISB_RandFrequency * 10.0));
	#endif
	
	float FalloffGradient = saturate(1.0 - SunDist);
	float StrayBursts     = Randomness > 1.0 - DELTA - UISB_StrayBurstAmount;
		  StrayBursts    *= UISB_StrayBurstInt * InvertedRoundness;
		  Randomness      = Randomness * UISB_RandIntensity + 1.0;
	
	StarMask  = LinearStep(0.4, 0.6, StarMask);
	StarMask *= pow(FalloffGradient, UISB_Falloff * Randomness);
	StarMask += StrayBursts * pow(FalloffGradient, UISB_StrayBurstFalloff * Randomness);
	StarMask *= saturate(0.5 + 1.0 - (Randomness - 1.0));
	
	return float4(StarMask * IN.SunInt * IN.FlareTint, 1.0);
}


//------------------------------------Anamorphic Lens Flare-------------------------------------//

VertexShaderOutputAnamSprite VS_AnamorphicSprite(VertexShaderInput IN,
	uniform float FlareOffset, uniform float FlareWidth,
	uniform float FlareInt,    uniform bool  FlareMirror)
{
	VertexShaderOutputAnamSprite OUT;
	OUT.pos.zw      = float2(IN.pos.z, 1.0);
	OUT.texcoord.xy = IN.txcoord.xy;
	OUT.texcoord.zw = IN.txcoord.xy * 2.0 - 1.0;
	
	float2 Offset = LightParameters.xy * FlareOffset;
	float2 Scale  = { FlareWidth, 0.05 * ScreenSize.z };
	
	Offset.x  *= FlareMirror ? -1.0 : 1.0;
	OUT.pos.xy = IN.pos.xy * Scale + Offset;
	
	OUT.SunInt    = GetSunIntensity(FlareInt * UI_EnableAnam * UIAF_Int, OUT.FlareTint);
	OUT.FlareTint = lerp(OUT.FlareTint, ColorToChroma(UIAF_Tint), UIAF_Tint.a);
	
	return OUT;
}

float4 PS_AnamorphicSprite(VertexShaderOutputAnamSprite IN, uniform float FlareCurve) : SV_Target
{
	clip(IN.SunInt - SUN_INTENSITY_CLIP);
	
	IN.texcoord.zw = 1.0 - abs(IN.texcoord.zw);
	IN.SunInt     *= IN.texcoord.z;
	
	float  FlareGradient = LimitedHighPass(IN.texcoord.w, 1.0, FlareCurve, IN.SunInt);
	float3 Color         = IN.texcoord.z * FlareGradient * IN.FlareTint;
	
	return float4(Color, 1.0);
}


//------------------------------------------Lens Glare------------------------------------------//

VertexShaderOutputLensGlareSprite VS_LensGlareSprite(VertexShaderInput IN)
{
	VertexShaderOutputLensGlareSprite OUT;
	OUT.pos.zw      = float2(IN.pos.z,1.0);
	OUT.texcoord.xy = IN.txcoord.xy;
	OUT.texcoord.zw = IN.txcoord.xy * 2.0 - 1.0;
	
	float2 ScreenRatio = { 1.0, ScreenSize.z };
	
	OUT.pos.xy  = IN.pos.xy * ScreenRatio * ScreenSize.z;
	OUT.pos.xy -= LightParameters.xy;
	
	OUT.MinRatio = min2(ScreenRatio);
	OUT.MaxRatio = max2(ScreenRatio);
	
	OUT.Glare.a   = GetSunIntensity(UI_LensGlareInt * UI_EnableGlares, OUT.Glare.rgb);
	OUT.Glare.rgb = lerp(OUT.Glare.rgb, ColorToChroma(UI_LensGlareCol.rgb), UI_LensGlareCol.a);
	OUT.SunDist   = distance(-LightParameters.xy, LightParameters.xy);
	OUT.SunDist   = pow(saturate(1.0 - OUT.SunDist),2) * UI_LensGlareInt * 2.0;
	
	return OUT;
}

float4 PS_LensGlareSprite(VertexShaderOutputLensGlareSprite IN) : SV_Target
{
	clip(IN.Glare.a - SUN_INTENSITY_CLIP);
	float GlareShape = 1.0 - length(IN.texcoord.zw);
		  GlareShape = smoothstep(IN.MaxRatio, IN.MinRatio, GlareShape) * IN.SunDist;
	return float4(GlareShape * GlareShape * IN.Glare.rgb * IN.Glare.a, 1.0);
}


//-------------------------------------------Sun Glare------------------------------------------//

VertexShaderOutputSunGlareSprite VS_SunGlareSprite(VertexShaderInput IN)
{
	VertexShaderOutputSunGlareSprite OUT;
	OUT.pos.zw      = float2(IN.pos.z,1.0);
	OUT.texcoord.xy = IN.txcoord.xy;
	OUT.texcoord.zw = IN.txcoord.xy * 2.0 - 1.0;
	
	OUT.pos.xy  = IN.pos.xy * float2(1.0, ScreenSize.z) * 0.8;
	OUT.pos.xy += LightParameters.xy;
	
	OUT.Glare.a   = GetSunIntensity(UI_SunGlareInt * UI_EnableGlares, OUT.Glare.rgb);
	OUT.Glare.rgb = lerp(OUT.Glare.rgb, ColorToChroma(UI_SunGlareCol.rgb), UI_SunGlareCol.a);
	
	return OUT;
}

float4 PS_SunGlareSprite(VertexShaderOutputSunGlareSprite IN) : SV_Target
{
	clip(IN.Glare.a - SUN_INTENSITY_CLIP);
	float GlareShape = 1.0 - length(IN.texcoord.zw);
		  GlareShape = smoothstep(0.0, 1.0, GlareShape);
	return float4(GlareShape * IN.Glare.a * IN.Glare.rgb, 1.0);
}


//----------------------------------------------------------------------------------------------//
//										    Techniques											//
//																								//
//								   Boris' comment on techniques:								//
//    In this shader all techniques have additive blending mode (srcblend=one, destblend=one)	//
//								 No temporary render targets used								//
//----------------------------------------------------------------------------------------------//

//---------------------------------------Technique Macros---------------------------------------//

#define GHOST_PASS(a) \
pass GhostPass##a { \
SetVertexShader(CompileShader(vs_5_0, VS_GhostSprite(UIG_Offset##a, \
												     UIG_Scale##a,   UIG_Int##a, \
												     UIG_CA##a,      UIG_Tint##a))); \
SetPixelShader (CompileShader(ps_5_0, PS_GhostSprite(UIG_Feather##a, UIG_DiffInt##a, UIG_DirtInt##a, \
												     UIG_Weight##a,  UIG_Vignette##a))); }

#define DGHOST_PASS(a) \
pass DuplicateGhostPassA##a { \
SetVertexShader(CompileShader(vs_5_0, VS_GhostSprite(UIDG_Offset##a, \
												     UIDG_Scale##a,   UIDG_Int##a, \
												     UIDG_CA##a,      UIDG_Tint##a))); \
SetPixelShader (CompileShader(ps_5_0, PS_GhostSprite(UIDG_Feather##a, UIDG_DiffInt##a, UIDG_DirtInt##a, \
												     UIDG_Weight##a,  UIDG_Vignette##a))); } \
pass DuplicateGhostPassB##a { \
SetVertexShader(CompileShader(vs_5_0, VS_GhostSprite(UIDG_Offset##a + UIDG_Dupl_Offset##a, \
												     UIDG_Scale##a,   UIDG_Int##a * (0.0 < abs(UIDG_Dupl_Offset##a)), \
												     UIDG_CA##a,      UIDG_Tint##a))); \
SetPixelShader (CompileShader(ps_5_0, PS_GhostSprite(UIDG_Feather##a, UIDG_DiffInt##a, UIDG_DirtInt##a, \
												     UIDG_Weight##a,  UIDG_Vignette##a))); }

#define ANAM_PASS(a) \
pass AnamPass##a { \
SetVertexShader(CompileShader(vs_5_0, VS_AnamorphicSprite(UIAF_Offset##a, UIAF_Width##a, \
														  UIAF_Int##a,    UIAF_Mirror##a))); \
SetPixelShader (CompileShader(ps_5_0, PS_AnamorphicSprite(UIAF_Curve##a))); }

#define LENSGLARE_PASS pass LensGlarePass { \
SetVertexShader(CompileShader(vs_5_0, VS_LensGlareSprite())); \
SetPixelShader (CompileShader(ps_5_0, PS_LensGlareSprite())); }

#define SUNGLARE_PASS pass SunGlarePass { \
SetVertexShader(CompileShader(vs_5_0, VS_SunGlareSprite())); \
SetPixelShader (CompileShader(ps_5_0, PS_SunGlareSprite())); }

#define STARBURST_PASS pass StarburstPass { \
SetVertexShader(CompileShader(vs_5_0, VS_StarburstSprite())); \
SetPixelShader (CompileShader(ps_5_0, PS_StarburstSprite())); }

#define HOOP_PASS pass HoopPass { \
SetVertexShader(CompileShader(vs_5_0, VS_HoopSprite())); \
SetPixelShader (CompileShader(ps_5_0, PS_HoopSprite())); }


//-------------------------------------Sunsprite Technique--------------------------------------//


technique11 KitsuuneSunspriteGD <string UIName="Sunsprite - Kitsuune";>
{
	ANAM_PASS(1)   ANAM_PASS(2)   ANAM_PASS(3)
	LENSGLARE_PASS SUNGLARE_PASS  STARBURST_PASS
	GHOST_PASS(1)  GHOST_PASS(2)  GHOST_PASS(3)
	GHOST_PASS(4)  GHOST_PASS(5)  GHOST_PASS(6)
	GHOST_PASS(7)  GHOST_PASS(8)  GHOST_PASS(9)
	DGHOST_PASS(1) DGHOST_PASS(2) DGHOST_PASS(3)
	DGHOST_PASS(4) DGHOST_PASS(5) DGHOST_PASS(6)
	DGHOST_PASS(7) DGHOST_PASS(8) HOOP_PASS
}






