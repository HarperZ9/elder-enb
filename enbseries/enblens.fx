//----------------------------------------------------------------------------------------------//
//										   MASTER LENS											//
//----------------------------------------------------------------------------------------------//
//																								//
//						enblens.fx file by LonelyKitsuune aka Skratzer							//
//						      for ENB (DirectX 11 Shader Model 5)								//
//																								//
//			   Copyright (c) 2018-2020 LonelyKitsuune / T.Thanner - CC BY-NC-ND 4.0				//
//																								//
//-------------------------------------------CREDITS--------------------------------------------//
//																								//
//				 Boris Vorontsov for ENBSeries and the initial lens reflection code				//
//						  Kingeric1992 for the initial ghost lensflare code						//
//																								//
//----------------------------------------------------------------------------------------------//
//								==================================								//
//								//     Silent Horizons ENB      //								//
//								//								//								//
//								//		by LonelyKitsuune		//								//
//								==================================								//
//----------------------------------------------------------------------------------------------//

/*¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\
|		MASTER LENS FEATURES:																	|
|				Ghosts and Hoop/Ring lens flares												|
|				Lens Reflections																|
|				Anamorphic lens flare															|
|				Selectable lens dirt															|
|				Starburst lens flare															|
|				WeatherFX (Rain Droplets + Frost Vignette)										|
\______________________________________________________________________________________________*/

//This file needs my helper and UI files to work!


//--------------------------------------------------------------------------------
//Ghosts and Starburst use techniques as their disabling method to safe performance when they aren't needed.
//This allows them to have basically no performance impact when disabled (without pre-processor directives).
// -> Both are multipass shaders that would need a bunch of clip or branching ops to be disabled in realtime otherwise.


//--------------------------------------------------------------------------------
//Enables full local control over this shader file
#define LOCAL_OVERRIDE							0 //[0-1]


//--------------------------------------------------------------------------------
//GHOST LENS FLARE OPTIONS
//--------------------------------------------------------------------------------
//Enables additional ghosts specific chromatic aberration
#define GHOSTS_ENABLE_CHROMATICABERRATION		0 //[0-1]


//--------------------------------------------------------------------------------
//STARBURST LENS FLARE OPTIONS
//--------------------------------------------------------------------------------
//Use only the brightest burst when more than one intersect
#define STARBURST_USE_MAX_COLOR					0 //[0-1]-G


//--------------------------------------------------------------------------------
//ANAMORPHIC LENS FLARE OPTIONS
//--------------------------------------------------------------------------------
//Enable an additional mirrored anamorphic flare
#define ANAM_ENABLE_MIRRORED_FLARE				0 //[0-1]


//--------------------------------------------------------------------------------
//WEATHER EFFECT OPTIONS
//--------------------------------------------------------------------------------
//Enables individual per droplet light dispersion
#define RAINFX_ENABLE_DISPERSION				0 //[0-1]-G


//Switches to a single layer frost texture with approximated refractions
#define FROSTFX_USE_REFRACTION_METHOD			1 //[0-1]-G



//----------------------------------------------------------------------------------------------//
//										 Global Parameters										//
//----------------------------------------------------------------------------------------------//

#if !LOCAL_OVERRIDE
#undef RAINFX_ENABLE_DISPERSION
#undef STARBURST_USE_MAX_COLOR
#undef FROSTFX_USE_REFRACTION_METHOD
#undef RAINFX_ENABLE_FAKE_SKY_REFLECTION
#include "enbglobals.fxh"
#endif //LOCAL_OVERRIDE


//----------------------------------------------------------------------------------------------//
//										Internal Parameters										//
//----------------------------------------------------------------------------------------------//

#include "UI/enbUI_Primer.fxh"

//Load weather indices from external file (for WeatherFX)
#include "Weather/_ShaderWeatherIndex.fxh"

//Feature-set switches
#define SHADERGROUP 0
#include "UI/enbUI_Lens.fxh"
#undef SHADERGROUP
UI_WHITESPACE(11)
UI_WHITESPACE(12)

//Weather Effect
#ifdef ENABLE_WEATHERFX_SHADERS
#define SHADERGROUP 1
#include "UI/enbUI_Lens.fxh"
#undef SHADERGROUP
UI_WHITESPACE(13)
UI_WHITESPACE(14)
#endif //ENABLE_WEATHERFX_SHADERS


//Anamorphic Lensflare (DNI)
#define SHADERGROUP 2
#define TODIE Day
#include "UI/enbUI_Lens.fxh"

#define TODIE Night
#include "UI/enbUI_Lens.fxh"

#define LASTTIME
#define TODIE Interior
#include "UI/enbUI_Lens.fxh"
UI_WHITESPACE(15)
UI_WHITESPACE(16)
#undef SHADERGROUP
#undef NOTFIRSTTIME


//Lens Reflections (DNI)
#define SHADERGROUP 3
#define TODIE Day
#include "UI/enbUI_Lens.fxh"

#define TODIE Night
#include "UI/enbUI_Lens.fxh"

#define LASTTIME
#define TODIE Interior
#include "UI/enbUI_Lens.fxh"
UI_WHITESPACE(17)
UI_WHITESPACE(18)
#undef SHADERGROUP
#undef NOTFIRSTTIME


//Lens Dirt (DNI)
#define SHADERGROUP 4
#define TODIE Day
#include "UI/enbUI_Lens.fxh"

#define TODIE Night
#include "UI/enbUI_Lens.fxh"

#define LASTTIME
#define TODIE Interior
#include "UI/enbUI_Lens.fxh"
UI_WHITESPACE(19)
UI_WHITESPACE(20)
#undef SHADERGROUP
#undef NOTFIRSTTIME


//Chromatic Aberration
#define SHADERGROUP 5
#include "UI/enbUI_Lens.fxh"
#undef SHADERGROUP
UI_WHITESPACE(21)
UI_WHITESPACE(22)


//Starburst (DNI)
#define SHADERGROUP 6
#define TODIE Day
#include "UI/enbUI_Lens.fxh"

#define TODIE Night
#include "UI/enbUI_Lens.fxh"

#define LASTTIME
#define TODIE Interior
#include "UI/enbUI_Lens.fxh"
UI_WHITESPACE(23)
UI_WHITESPACE(24)
#undef SHADERGROUP
#undef NOTFIRSTTIME


//Ghosts (DNI)
#define SHADERGROUP 7
#define TODIE Day
#include "UI/enbUI_Lens.fxh"

#define TODIE Night
#include "UI/enbUI_Lens.fxh"

#define LASTTIME
#define TODIE Interior
#include "UI/enbUI_Lens.fxh"
#undef SHADERGROUP
#undef NOTFIRSTTIME


//Film Grain (DNI)
#define SHADERGROUP 8
#define TODIE Day
#include "UI/enbUI_Lens.fxh"

#define TODIE Night
#include "UI/enbUI_Lens.fxh"

#define LASTTIME
#define TODIE Interior
#include "UI/enbUI_Lens.fxh"
#undef SHADERGROUP
#undef NOTFIRSTTIME



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


//----------------------------------------------------------------------------------------------//
//						       External enb debugging parameters for							//
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

Texture2D TextureDownsampled;  //color R16B16G16A16 64 bit or R11G11B10 32 bit hdr format. 1024*1024 size
Texture2D TextureColor;        //color which is output of previous technique (except when drawed to temporary render target), R16B16G16A16 64 bit hdr format. screen size
Texture2D TextureOriginal;     //color R16B16G16A16 64 bit or R11G11B10 32 bit hdr format, screen size. PLEASE AVOID USING IT BECAUSE OF ALIASING ARTIFACTS, UNLESS YOU FIX THEM
Texture2D TextureDepth;        //scene depth R32F 32 bit hdr format, screen size. PLEASE AVOID USING IT BECAUSE OF ALIASING ARTIFACTS, UNLESS YOU FIX THEM
Texture2D TextureAperture;     //this frame aperture 1*1 R32F hdr red channel only. computed in PS_Aperture of enbdepthoffield.fx

//temporary textures which can be set as render target for techniques via annotations like <string RenderTarget="RenderTargetRGBA32";>
//RenderTarget1024 to RenderTarget16 are prefilled with enbbloom.fx output
Texture2D RenderTarget1024;    //R16B16G16A16F 64 bit hdr format, 1024*1024 size -- Bugged? Overwrites bloom output somehow
Texture2D RenderTarget512;     //R16B16G16A16F 64 bit hdr format, 512*512 size   -- Used by Reflection
Texture2D RenderTarget256;     //R16B16G16A16F 64 bit hdr format, 256*256 size   -- Used by AnamorphicFlare + Reflection
Texture2D RenderTarget128;     //R16B16G16A16F 64 bit hdr format, 128*128 size
Texture2D RenderTarget64;      //R16B16G16A16F 64 bit hdr format, 64*64 size
Texture2D RenderTarget32;      //R16B16G16A16F 64 bit hdr format, 32*32 size
Texture2D RenderTarget16;      //R16B16G16A16F 64 bit hdr format, 16*16 size
Texture2D RenderTargetRGBA32;  //R8G8B8A8      32 bit ldr format, screen size
Texture2D RenderTargetRGBA64F; //R16B16G16A16F 64 bit hdr format, screen size    -- Used by AnamorphicFlare, Ghosts and WeatherFX


//Atlas with 4 different lensdirt textures
Texture2D LensDirtAtlas <string ResourceName="Textures/LensDirtTexAtlas.png";>;

//Atlas with various lens raindrop normal maps
Texture2D RainDrops <string ResourceName="Textures/LensRainDroplets.png";>;

//Different frost textures per channel
//R=Main Frost - G=Background Frost - B=Single Crystals
Texture2D FrostTex <string ResourceName="Textures/LensFrostTextures.png";>;

//Refraction frost texture
//R,G=precomputed sobel operator - B=Frost Mask
Texture2D FrostTexRefrac <string ResourceName="Textures/LensFrostRefractionTexture.png";>;

//----------------------------------------------------------------------------------------------//

SamplerState Point_Sampler
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Border;
	AddressV = Border;
};

SamplerState Linear_Sampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Border;
	AddressV = Border;
};


SamplerState Point_Sampler_Rain
{
//Using mirroring can produce wrong refractions and reflections,
//but ensures that all droplets have enough data to sample
// -> workaround for screen space limitation
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Mirror;
	AddressV = Mirror;
};

SamplerState Linear_Sampler_Rain
{
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Mirror;
	AddressV = Mirror;
};


SamplerState Linear_Sampler_CA
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};


//----------------------------------------------------------------------------------------------//

SamplerComparisonState Linear_Sampler_Grt
{
	Filter = COMPARISON_MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
	ComparisonFunc = Greater;
};

float MaskDaySky(float2 Coords)
{ return saturate(TextureDepth.SampleCmpLevelZero(Linear_Sampler_Grt,Coords,1.0).x + (1.0 - ENightDayFactor)); }


//----------------------------------------------------------------------------------------------//

//Raindrop blending
BlendState RainBlending
{
	BlendEnable[0] = TRUE;
	SrcBlend       = ONE;
	DestBlend      = ZERO;
	BlendOp        = ADD;
};


//----------------------------------------------------------------------------------------------//

//Helper with some useful macros, variables and functions
#include "Helper/enbHelper_Common.fxh"

//Constant for gaussian weight computation
static const float SqrtTwoPI = sqrt(2.0 * PI);


//----------------------------------------------------------------------------------------------//
//										   Generic Structs										//
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



//----------------------------------------------------------------------------------------------//
//								      ANAMORPHIC LENS FLARE										//
//																								//
//----------------------------------------------------------------------------------------------//

//----------------------------------------------------------------------------------------------//
//Structs

struct VertexShaderOutputAnamFlarePrePass
{
   float4 pos         : SV_POSITION;
   float2 texcoord    : TEXCOORD0;
NI float2 UIAF_Thresh : TEXCOORD1;
};

struct VertexShaderOutputAnamFlare
{
   float4 pos	       : SV_POSITION;
   float2 texcoord     : TEXCOORD0;
NI float  UIAF_Int     : ANAM0;
NI float  AnamWidth    : ANAM1;
NI float  WeightFactor : ANAM2;
NI float  LoopCount    : ANAM3;
NI float2 RotPixelSize : ANAM4;
};


//----------------------------------------------------------------------------------------------//
//Final rendertarget scalings (for RenderTarget256)

static const float2 AF_RTSize      = 256.0;
static const float2 AF_RTPixelSize = 1.0 / 256.0;
static       float2 AF_RTResMult   = rcp(ScreenRes * AF_RTPixelSize);


//----------------------------------Anamorphic Lensflare PrePass--------------------------------//

VertexShaderOutputAnamFlarePrePass VS_AnamFlarePrePass(VertexShaderInput IN)
{
	VertexShaderOutputAnamFlarePrePass OUT;
	OUT.pos      = float4(IN.pos.xyz, 1.0);
	OUT.texcoord = IN.txcoord.xy;
	
	ScaleScreenQuad_Res(OUT.pos.xy, AF_RTSize);
	
	OUT.UIAF_Thresh.x = DNI_SEPARATION(UIAF_Thresh);
	OUT.UIAF_Thresh.y = OUT.UIAF_Thresh.x + UIAF_CoreFoc;
	
	return OUT;
}

float4 PS_AnamFlarePrePass(VertexShaderOutputAnamFlarePrePass IN) : SV_Target
{
	if(!UIAF_Enable) discard;
	float3 Color = 0.0;
	
	static const float2 SourcePixelSize = 1.0 / 1024.0; //TextureDownsampled
	static const float2 Offset[4] =
	{ SourcePixelSize * float2( 1.0, 1.0),
	  SourcePixelSize * float2(-1.0, 1.0),
	  SourcePixelSize * float2( 1.0,-1.0),
	  SourcePixelSize * float2(-1.0,-1.0) };
	
	
	[branch] if (UI_IgnoreSky)
	[unroll] for(int i=0; i<4; i++)
	{
	float2 CurrOffset = IN.texcoord + Offset[i];
		   Color      = max(Color, MaskDaySky(CurrOffset) * TextureDownsampled.Sample(Linear_Sampler, CurrOffset).rgb);
	}
	else
	[unroll] for(int i=0; i<4; i++)
		Color = max(Color, TextureDownsampled.Sample(Linear_Sampler, IN.texcoord + Offset[i]).rgb);
	
	
	float Luma   = dot(Color, N_LUM);
		  Color /= deltalim(Luma);
	
	Luma  *= smoothstep(IN.UIAF_Thresh.x, IN.UIAF_Thresh.y, Luma);
	Luma  *= min(Luma, UIAF_CoreMax);
	Color *= pow(min(Luma, UIAF_CoreMax * 4.0), UIAF_CoreInt);
	
	return float4(Color, 1.0);
}

//-----------------------------------Anamorphic Lensflare Main----------------------------------//

VertexShaderOutputAnamFlare VS_AnamFlare(VertexShaderInput IN)
{
	VertexShaderOutputAnamFlare OUT;
	OUT.pos	     = float4(IN.pos.xyz, 1.0);
	OUT.texcoord = IN.txcoord.xy * AF_RTResMult;
	
	OUT.UIAF_Int	 = DNI_SEPARATION(UIAF_Int);
	OUT.RotPixelSize = GetDirVec(UIAF_Rotation) * PixelSize * float2(1.0, ScreenSize.z);
	
	OUT.AnamWidth    = UIAF_Width * 2.0;
	OUT.WeightFactor =  rcp(OUT.AnamWidth * SqrtTwoPI);
	OUT.LoopCount    = ceil(mad(OUT.AnamWidth, 2.0, 2.0));
	OUT.AnamWidth	 = -rcp(OUT.AnamWidth * OUT.AnamWidth);
	
	return OUT;
}

float4 PS_AnamFlare(VertexShaderOutputAnamFlare IN) : SV_Target
{
	//1D blur at low res to achieve bigger flares with lower performance impact
	//-> Aliasing artifacts aren't that noticable when the blurring
	//   axis is perfectly vertical/horizontal (0°/90°/180°)
	if(!UIAF_Enable) discard;
	
	float3 AnamFlare = IN.WeightFactor * RenderTargetRGBA64F.Sample(Linear_Sampler, IN.texcoord).rgb;
	float  WeightSum = IN.WeightFactor;
	
	#if ANAM_ENABLE_MIRRORED_FLARE
		AnamFlare += UIAF_MirrorInt * IN.WeightFactor *
		RenderTargetRGBA64F.Sample(Linear_Sampler, AF_RTResMult - IN.texcoord).rgb;
	#endif
	
	[loop] for(float i=1.0; i <= IN.LoopCount; i++)
	{
		float4 Offset      = IN.texcoord.xyxy + IN.RotPixelSize.xyxy * float4(i.xx, -i.xx);
		float  GaussWeight = IN.WeightFactor * exp(i*i*IN.AnamWidth);
		
		AnamFlare += GaussWeight * RenderTargetRGBA64F.SampleLevel(Linear_Sampler, Offset.xy, 0).rgb;
		AnamFlare += GaussWeight * RenderTargetRGBA64F.SampleLevel(Linear_Sampler, Offset.zw, 0).rgb;
		WeightSum += GaussWeight * 2.0;
		
		#if ANAM_ENABLE_MIRRORED_FLARE
			Offset       = AF_RTResMult.xyxy - Offset;
			GaussWeight *= UIAF_MirrorInt;
			AnamFlare   += GaussWeight * RenderTargetRGBA64F.SampleLevel(Linear_Sampler, Offset.xy, 0).rgb;
			AnamFlare   += GaussWeight * RenderTargetRGBA64F.SampleLevel(Linear_Sampler, Offset.zw, 0).rgb;
		#endif
	}
	
	AnamFlare /= WeightSum;
	AnamFlare *= IN.UIAF_Int;
	
	float AnamLuma  = dot(AnamFlare, K_LUM);
		  AnamFlare = zerolim(lerp(AnamLuma, AnamFlare, UIAF_Sat));
	
	return float4(AnamFlare, saturate(0.25 + (AnamLuma * 2.0 - 1.0) * 0.25));
}



//----------------------------------------------------------------------------------------------//
//								        GHOST LENS FLARES										//
//																								//
//		       Original - http://enbseries.enbdev.com/forum/viewtopic.php?f=7&t=5347			//
//----------------------------------------------------------------------------------------------//

//----------------------------------------------------------------------------------------------//
//Structs

struct VertexShaderInputPrepass
{
   float3 pos    : POSITION;
   float4 offset : TEXCOORD0;
};

struct VertexShaderOutputPrepass
{
   float4 pos          : SV_POSITION;
   float4 offset       : TEXCOORD0;
NI float  UIG_Power    : DNI0;
NI float  UIG_Strength : DNI1;
};

struct VertexShaderOutputGhostsMain
{
   float4 pos          : SV_POSITION;
   float2 texcoord     : TEXCOORD0;
NI float  Shape        : TEXCOORD1;
NI float2 vertices[10] : TEXCOORD2;
};


//----------------------------------------------------------------------------------------------//
//Global settings

#define FLARECOUNT 12
static const float Fmin             = 2.8; //maximum F-number to have circle shape
static const float Fmax             = 4.0; //minimum F-number to have solid polygon shape
static const float GaussSensitivity = 0.1; //controles the sensitivity of gaussian mask thats used to create ring flares
static const float PrefilterRange   = 4.0;


//----------------------------------------------------------------------------------------------//
//Input structs

struct FlareStruct
{
   float  index;
   float  curve;
   float  scale;
   float4 tint;
};

static FlareStruct FlareData[FLARECOUNT] =
{
	{ 1, Curve1.x, Scale1.x, Tint1 * Intensity1.x },
	{ 1, Curve1.y, Scale1.y, Tint1 * Intensity1.y },
	{ 1, Curve1.z, Scale1.z, Tint1 * Intensity1.z },
	{ 1, Curve1.w, Scale1.w, Tint1 * Intensity1.w },
	
	{ 2, Curve2.x, Scale2.x, Tint2 * Intensity2.x },
	{ 2, Curve2.y, Scale2.y, Tint2 * Intensity2.y },
	{ 2, Curve2.z, Scale2.z, Tint2 * Intensity2.z },
	{ 2, Curve2.w, Scale2.w, Tint2 * Intensity2.w },
	
	{ 3, Curve3.x, Scale3.x, Tint3 * Intensity3.x },
	{ 3, Curve3.y, Scale3.y, Tint3 * Intensity3.y },
	{ 3, Curve3.z, Scale3.z, Tint3 * Intensity3.z },
	{ 3, Curve3.w, Scale3.w, Tint3 * Intensity3.w }
};


//----------------------------------------------------------------------------------------------//
//Functions + static inputs

static float2 blurratio = ScreenSize.y * float2(min(UIG_Ratio, 1.0), ScreenSize.z / max(UIG_Ratio, 1.0) );
static float  blurshape = UIG_ForceDeform ? UIG_Deform : smoothstep(Fmin, Fmax, UIG_FNumber);

float2 Distort(float2 coord, float curve, float scale)
{
	float r = length(coord * ScreenSize.y / blurratio);
	return coord + pow(2.0 * r, curve) * (coord / r) * scale;
}

float4 FlareFunc(float2 coord, FlareStruct IN)
{
	static const float2 FlareUV[4] = { float2(0.25, 0.75), float2(0.75, 0.75), float2(0.75, 0.25), float2(0.25, 0.25) }; 
	
		   coord    = Distort(coord, IN.curve, IN.scale) + FlareUV[IN.index];
	float2 border   = 1.0 - saturate((coord <= FlareUV[IN.index] - 0.25) + (coord >= FlareUV[IN.index] + 0.25));
	float4 lens     = border.x * border.y * TextureColor.Sample(Linear_Sampler, coord); 
		   lens.rgb = saturate(lens.rgb - lens.a * 4.0 * (1.0 - IN.tint.a) / UIG_FNumber) * IN.tint.rgb;
		   lens.rgb = saturate(lens.rgb - Random(coord) * clamp(abs(IN.curve - 1.0), 0.2, 0.5) * UIG_Grain / UIG_FNumber);
	return lens;
}


//--------------------------------------- Ghosts Prepass ---------------------------------------//

VertexShaderOutputPrepass VS_GhostsPrePass(VertexShaderInputPrepass IN)
{
	VertexShaderOutputPrepass OUT;
	float2 steps    = ScreenSize.y * PrefilterRange;
		   steps.y *= ScreenSize.z;
	
	OUT.offset = (IN.offset.xyxy * 3.0 - 1.5) + float4(steps, -steps);
	OUT.pos    = float4(IN.pos.xy * 0.5 - float2(0.5, -0.5), IN.pos.z, 1.0);
	
	OUT.UIG_Power    = DNI_SEPARATION(UIG_Power);
	OUT.UIG_Strength = DNI_SEPARATION(UIG_Strength);
	
	return OUT;
}

float4 PS_GhostsPrePass(VertexShaderOutputPrepass IN) : SV_Target
{
	float4 color  = 0.0;
	float2 offset = (IN.offset.xy + IN.offset.zw) * 0.5;
	
	IN.offset += 0.5;
	float2 coord[4] = { IN.offset.xy, IN.offset.xw,
						IN.offset.zy, IN.offset.zw };
	
	#if MULTIIRIS_ENABLE_CHROMATICABERRATION
	static const float4 CA_Tint[3] = { float4(UIG_CAColor0, 1.0),
									   float4(UIG_CAColor1, 1.0),
									   float4(UIG_CAColor2, 1.0) };
	
	offset = Distort(offset, UIG_CACurve, UIG_CAScale * 0.01) - offset;
	
	[unroll] for (float i=0.0; i<3.0; i++)
	{
		float4 sum = 0.0;
		[unroll] for (int j=0; j<4; j++)
		{
			float2 curros = coord[j] + offset * i;
			float4 temp   = TextureColor.Sample(Linear_Sampler, curros);
			
			[branch] if(UI_IgnoreSky) temp *= MaskDaySky(curros);
			
			curros	 = abs(curros * 1.8 - 0.9);
			curros.x = saturate(max(curros.x, curros.y));
			temp	*= 1.0 - pow(curros.x,4);
			
			temp.a = max3(temp.rgb);
			sum   += temp / (temp.a + 1.0);
		}
		color += saturate(pow(sum * 0.25, IN.UIG_Power) * IN.UIG_Strength) * CA_Tint[i];
	}
	
	#else
	
	float2 distort = length(offset * ScreenSize.y / blurratio);
		   offset  = distort * (offset / distort) * 0.02;
	
	[unroll] for (int j=0; j<4; j++)
	{
		float2 curros = coord[j] + offset;
		float4 temp   = TextureColor.Sample(Linear_Sampler, curros);
		
		[branch] if(UI_IgnoreSky) temp *= MaskDaySky(curros);
		
		curros	 = abs(curros * 1.8 - 0.9);
		curros.x = saturate(max(curros.x, curros.y));
		temp	*= 1.0 - pow(curros.x,4); //screen border fade
		
		temp.a = max3(temp.rgb);
		color += temp / (temp.a + 1.0);
	}
	
	color *= 0.25;
	
	//better flare color
	float2 maxcol = { max3(color.rgb), color.a };
	
	color  = float4(color.rgb / maxcol.x, 1.0);
	color *= saturate(pow(maxcol.xxxy, IN.UIG_Power) * IN.UIG_Strength) *
			 float4(1.0 + pow(color.rgb,3), 1.0);
	#endif
	
	return zerolim(color * 0.33333);
}


//----------------------------------------- Ghosts Main ----------------------------------------//

VertexShaderOutputGhostsMain VS_GhostsMain(VertexShaderInput IN)
{
	VertexShaderOutputGhostsMain OUT;
	OUT.texcoord = IN.txcoord * 0.5;
	OUT.pos      = float4(IN.pos.xy * 0.5 - float2(0.5, -0.5), IN.pos.z, 1.0);
	OUT.Shape    = UIG_Shape * (1.0 + UIG_ShapeWeight) + 1.0;
	
	[unroll] for(int i=0; i<10; i++)
		OUT.vertices[i] = GetDirVec(UIG_AngleOffset + i * 360.0 / UIG_Shape);
	
	return OUT;
}

float4 PS_GhostsMain(VertexShaderOutputGhostsMain IN, uniform float range) : SV_Target
{
	float4 color = TextureColor.Sample(Linear_Sampler, IN.texcoord);
	float  avg   = color.a;
	
	[unroll] for(float i=1.0; i < 3.0; i++)
	[loop] for(int j=0; j < UIG_Shape; j++)
	{
		float2 offset = IN.texcoord + IN.vertices[j] * blurratio * range * i;
		if(any(offset >= 0.495)) break;
		float4 tmp    = TextureColor.SampleLevel(Linear_Sampler, offset, 0.0);
			   avg   += tmp.a;
			   color  = max(color, tmp);
	}
	
	[loop] for(int k=0; k < UIG_Shape; k++)
	{
		float2 offset = IN.vertices[k] + IN.vertices[k + 1];
			   offset = IN.texcoord + offset / lerp(length(offset), 2.0, blurshape) * blurratio * range * 2.0;
		if(any(offset >= 0.495)) break;
		float4 tmp    = TextureColor.SampleLevel(Linear_Sampler, offset, 0.0);
			   avg   += tmp.a;
			   color  = max(color, tmp);
	}
	
	return float4(color.rgb, lerp(avg / IN.Shape, color.a, GaussSensitivity));
}


//---------------------------------------- Ghosts Bypass ---------------------------------------//

VertexShaderOutput VS_GhostsBypass(VertexShaderInput IN, uniform float2 offset, uniform float2 scale)
{
	VertexShaderOutput OUT;
	OUT.texcoord = IN.txcoord * scale;
	OUT.pos	     = float4((IN.pos.xy - offset) * scale, IN.pos.z, 1.0);
	return OUT;
}

float4 PS_GhostsBypass(VertexShaderOutput IN) : SV_Target
{ return TextureColor.Sample(Linear_Sampler, IN.texcoord); }


//----------------------------------------- Ghosts Mix -----------------------------------------//

VertexShaderOutput VS_GhostsMix(VertexShaderInput IN)
{
	VertexShaderOutput OUT;
	OUT.texcoord = IN.txcoord * 0.5 - 0.25;
	OUT.pos      = float4(IN.pos.xy * 0.5 - float2(0.5, -0.5), IN.pos.z, 1.0);
	return OUT;
}

/* 16x | 8x
 ------------
    2x | 4x */

float4 PS_GhostsMix(VertexShaderOutput IN) : SV_Target
{
	float4 flare = 0.0;
	
	[unroll] for (int i=0; i<FLARECOUNT; i++)
		flare += FlareFunc(IN.texcoord, FlareData[i]);
	return flare;
}


//---------------------------------------- Ghosts Fullres --------------------------------------//

VertexShaderOutput VS_GhostsFullres(VertexShaderInput IN)
{
	VertexShaderOutput OUT;
	OUT.pos			= float4(IN.pos.xyz,1.0);
	OUT.texcoord    = IN.txcoord * 0.5;
	OUT.texcoord.x -= PixelSize.x; //fixes screen border bug
	return OUT;
}

float4 PS_GhostsFullres(VertexShaderOutput IN) : SV_Target
{ return TextureColor.Sample(Linear_Sampler, IN.texcoord); }




//----------------------------------------------------------------------------------------------//
//										LENS REFLECTIONS										//
//																								//
//----------------------------------------------------------------------------------------------//

//----------------------------------------------------------------------------------------------//
//Struct

struct VertexShaderOutputReflection
{
   float4 pos      : SV_POSITION;
   float2 texcoord : TEXCOORD0;
NI float2 Lens     : TEXCOORD1;
};


//----------------------------------------Lens Reflection----------------------------------------//

VertexShaderOutputReflection VS_Reflection(VertexShaderInput IN)
{
	VertexShaderOutputReflection OUT;
	OUT.pos			= float4(IN.pos.xyz,1.0);
	OUT.texcoord.xy = IN.txcoord.xy;
	
	OUT.Lens.x = DNI_SEPARATION(UIR_Strength) * 0.25;
	OUT.Lens.y = DNI_SEPARATION(UIR_Power);
	
	return OUT;
}

float4 PS_Reflection(VertexShaderOutputReflection IN) : SV_Target
{
	if(!UIR_Enable) discard;
	float3 LensRef = 0.0;
	
	//Deepness, curvature and (inverse) size
	static const float3 RefOffset[4] = { 1.6,4.0,1.0,  0.7,0.25,2.0,
										 0.3,1.5,0.5, -0.5,1.00,1.0 };
	
	//Per reflection color filter
	float3 RefColor[4] = { UIR_ColorFilter1, UIR_ColorFilter2,
						   UIR_ColorFilter3, UIR_ColorFilter4 };
	
	[unroll] for(int i=0; i<4; i++)
	{
		float2 DistFact = IN.texcoord - 0.5;
		float2 Coords	= length(float2(DistFact.x * ScreenSize.z, DistFact.y));
			   Coords   = pow(2.0 * Coords, RefOffset[i].y);
			   Coords  *= RefOffset[i].x * DistFact;
			   Coords  *= RefOffset[i].z;
			   Coords	= 0.5 - Coords;
		float3 TempLens = RenderTarget256.SampleLevel(Linear_Sampler, Coords,0);
		
		[branch] if(UI_IgnoreSky) TempLens *= MaskDaySky(Coords);
		
		TempLens *= RefColor[i];
		DistFact  = Coords * 2.0 - 1.0;
		TempLens *= saturate(1.0 - dot(DistFact, DistFact));
		
		float TempNor  = max3(TempLens);
			  TempNor /= 1.0 + TempNor;
			  TempNor  = pow(TempNor, IN.Lens.y);
		
		LensRef += TempLens * TempNor;
	}
	
	return float4(LensRef * IN.Lens.x, 1.0);
}


//----------------------------------------------------------------------------------------------//
//								       STARBURST LENSFLARE										//
//																								//
//----------------------------------------------------------------------------------------------//

//----------------------------------------------------------------------------------------------//
//Structs

struct VertexShaderOutputSBPrePass
{
   float4 pos            : SV_POSITION;
   float2 texcoord       : TEXCOORD0;
NI float2 UISB_Thresh    : TEXCOORD1;
NI float  UISB_Strength  : SB0;
NI float3 UISB_Tint      : SB1;
NI float  SB_ThreshCurve : SB2;
NI float  SB_PowerLimit  : SB3;
};

struct VertexShaderOutputSBMain
{
   float4 pos             : SV_POSITION;
   float2 texcoord        : TEXCOORD0;
NI float2 LoopCount       : TEXCOORD1;
NI float  FlareSigma      : SB0;
NI float  WeightFactor    : SB1;
NI float2 RotPixelSize[9] : SB2;
};

struct VertexShaderOutputSBPostPass
{
   float4 pos      : SV_POSITION;
   float4 texcoord : TEXCOORD0;
};


//----------------------------------------------------------------------------------------------//
//Sacling factors for high quality and normal mode

static float4 Scalings = UISB_HQ ? float4(2.0, 0.5, 0.5 , 4.0):
								   float4(4.0, 1.0, 0.25, 2.0);


//---------------------------------------Starburst Prepass--------------------------------------//

VertexShaderOutputSBPrePass VS_StarburstPrePass(VertexShaderInput IN)
{
	VertexShaderOutputSBPrePass OUT;
	OUT.pos      = float4(IN.pos.xyz, 1.0);
	OUT.texcoord = IN.txcoord.xy;
	
	ScaleScreenQuad_Mult(OUT.pos.xy, Scalings.z);
	
	OUT.UISB_Thresh.x = DNI_SEPARATION(UISB_Thresh);
	OUT.UISB_Thresh.y = rcp(OUT.UISB_Thresh.x);
	OUT.UISB_Strength = DNI_SEPARATION(UISB_Strength);
	
	OUT.SB_ThreshCurve = UISB_ThreshCurve * 2.0 * OUT.UISB_Thresh.x;
	OUT.SB_PowerLimit  = pow(UISB_ThreshCurve,4) * OUT.UISB_Strength;
	OUT.UISB_Tint      = UISB_Tint.rgb / deltalim(dot(UISB_Tint.rgb, N_LUM));
	
	return OUT;
}

float4 PS_StarburstPrePass(VertexShaderOutputSBPrePass IN) : SV_Target
{
	static const float2 offset[4] =
	{ PixelSize.x,  PixelSize.y,  -PixelSize.x,  PixelSize.y,
	  PixelSize.x, -PixelSize.y,  -PixelSize.x, -PixelSize.y };
	
	float3 Color = 0.0;
	
	[branch] if(UI_IgnoreSky)
	[unroll] for(int i=0; i<4; i++)
	{
		float2 CurrOffset = IN.texcoord + offset[i];
		Color += MaskDaySky(CurrOffset) * TextureDownsampled.Sample(Linear_Sampler, CurrOffset).rgb;
	}
	else
	[unroll] for(int i=0; i<4; i++)
		Color += TextureDownsampled.SampleLevel(Linear_Sampler, IN.texcoord + offset[i],0).rgb;
	
	float Luma;
	Color *= 0.25;
	Luma   = dot(Color, N_LUM);
	Color /= deltalim(Luma);
	
	Luma   = pow(Luma * IN.UISB_Thresh.y, IN.SB_ThreshCurve);
	Luma   = min(Luma, IN.SB_PowerLimit);
	Luma   = (Luma * IN.UISB_Strength) / (Luma + IN.UISB_Thresh.x);
	Color  = lerp(Color, IN.UISB_Tint, UISB_Tint.a);
	Color  = lerp(Luma, Color * Luma, UISB_Saturation);
	Color *= 1.0 + UISB_Imperfections * (RandomGauss(IN.texcoord) - 0.5);
	
	return float4(zerolim(Color), 1.0);
}


//--------------------------------------Main Starburst Pass-------------------------------------//

VertexShaderOutputSBMain VS_StarburstMain(VertexShaderInput IN)
{
	VertexShaderOutputSBMain OUT;
	OUT.pos      = float4(IN.pos.xyz, 1.0);
	OUT.texcoord = IN.txcoord.xy * Scalings.z;
	
	ScaleScreenQuad_Mult(OUT.pos.xy, Scalings.z);
	
	OUT.FlareSigma   = UISB_Width * Scalings.w;
	OUT.WeightFactor =  rcp(OUT.FlareSigma * SqrtTwoPI);
	OUT.LoopCount.x  = ceil(OUT.FlareSigma * 2.0);
	OUT.FlareSigma	 = -rcp(OUT.FlareSigma * OUT.FlareSigma) * UISB_Falloff;
	
	OUT.LoopCount.y = ceil(UISB_Shape * saturate(UISB_Shape % 2.0 + 0.5));
	float2 ScaledPS = PixelSize * 1.25;
	
	[unroll] for(int i=0; i<9; i++)
	OUT.RotPixelSize[i] = GetDirVec(360.0 / UISB_Shape * (i + 0.5) + UISB_AngleOffset) * ScaledPS;
	
	return OUT;
}

float4 PS_StarburstMain(VertexShaderOutputSBMain IN) : SV_Target
{
	#if STARBURST_USE_MAX_COLOR
		#define ColSum Colors[j]
	#else
		#define ColSum Color
	#endif
	
	float3 Color     = IN.WeightFactor * TextureColor.Sample(Point_Sampler, IN.texcoord).rgb;
	float  WeightSum = IN.WeightFactor;
	
	#if STARBURST_USE_MAX_COLOR
		float3 Colors[9];
		[unroll] for(int k=0; k<9; k++) Colors[k] = 0.0;
	#endif
	
	[loop] for(float i=1.0; i <= IN.LoopCount.x; i++)
	{
	float GaussWeight = IN.WeightFactor * exp(i*i*IN.FlareSigma);

		[loop] for(int j=0; j < IN.LoopCount.y; j++)
		{
		float4 Offset     = IN.texcoord.xyxy + IN.RotPixelSize[j].xyxy * float4(i.xx, -i.xx);
			   ColSum    += GaussWeight * TextureColor.SampleLevel(Linear_Sampler, Offset.xy, 0).rgb;
			   ColSum    += GaussWeight * TextureColor.SampleLevel(Linear_Sampler, Offset.zw, 0).rgb;
			   WeightSum += GaussWeight * 2.0;
		}
	}
	
	#if STARBURST_USE_MAX_COLOR
			[unroll] for(k=0; k<9; k++) Colors[0] = max(Colors[0], Colors[k]);
			Color += Colors[0];
	#endif
	
	return float4(Color / WeightSum, 1.0); 
}

//--------------------------------------Starburst Postpass--------------------------------------//

VertexShaderOutputSBPostPass VS_StarburstPostPass(VertexShaderInput IN)
{
	VertexShaderOutputSBPostPass OUT;
	OUT.pos          = float4(IN.pos.xyz, 1.0);
	OUT.texcoord     = IN.txcoord.xyxy;
	OUT.texcoord.xy *= Scalings.z;
	return OUT;
}

float4 PS_StarburstPostPass(VertexShaderOutputSBPostPass IN, uniform bool SampleGhosts) : SV_Target
{
	float3 Color;
	
	[branch]
	if(!UISB_HQ)     Color  = BicubicFilter(TextureColor, IN.texcoord.xy, ScreenRes).rgb;
	else             Color  = TextureColor.Sample(Linear_Sampler, IN.texcoord.xy).rgb;
	if(SampleGhosts) Color += RenderTargetRGBA64F.Sample(Point_Sampler, IN.texcoord.zw).rgb;
	
	return float4(Color, 1.0);
}


//----------------------------------------------------------------------------------------------//
//								  LENS POSTPASS -> COMBINE + DIRT								//
//																								//
//----------------------------------------------------------------------------------------------//

//----------------------------------------------------------------------------------------------//
//Struct

struct VertexShaderOutputPostPass
{
   float4 pos            : SV_POSITION;
   float2 texcoord       : TEXCOORD0;
   float2 DirtCoords     : TEXCOORD1;
NI float  UID_Power      : DNI0;
NI float  UID_Strength   : DNI1;
NI bool   AFBlurSampling : DNI2;
};


//-----------------------------------------Lens Postpass----------------------------------------//

VertexShaderOutputPostPass VS_DirtAndPostPass(VertexShaderInput IN)
{
	VertexShaderOutputPostPass OUT;
	OUT.pos				= float4(IN.pos.xyz,1.0);
	OUT.texcoord.xy = IN.txcoord.xy;
	
	OUT.UID_Power      = DNI_SEPARATION(UID_Power);
	OUT.UID_Strength   = DNI_SEPARATION(UID_Strength);
	OUT.DirtCoords     = AtlasFetch_4(IN.txcoord, UID_Select);
	OUT.AFBlurSampling = fmod(UIAF_Rotation, 90.0) > 0.0;
	
	return OUT;
}


float4 PS_DirtAndPostPass(VertexShaderOutputPostPass IN, uniform bool SampleInput) : SV_Target
{
	float3 Color = 0.0;
	
	if(SampleInput) Color  =    TextureColor.Sample(Point_Sampler,  IN.texcoord).rgb;
	if(UIR_Enable ) Color += RenderTarget512.Sample(Linear_Sampler, IN.texcoord).rgb;
	if(UIAF_Enable)
	{
		float3 AnamCol = RenderTarget256.Sample(Linear_Sampler, IN.texcoord).rgb;
		
		[branch] if(IN.AFBlurSampling)
		{
			float  WeightSum = DELTA;
			float3 AnamBlur  = 0.0;
			
			static const float2 Offset[4] = { AF_RTPixelSize * float2( 1.0, 0.5),
											  AF_RTPixelSize * float2(-0.5, 1.0),
											  AF_RTPixelSize * float2(-1.0,-0.5),
											  AF_RTPixelSize * float2( 0.5,-1.0) };
			
			[unroll] for(int i=0; i<4; i++)
			{
				float4 CurrSample = RenderTarget256.Sample(Linear_Sampler, IN.texcoord + Offset[i]);
				
				AnamBlur  += CurrSample.a * CurrSample.rgb;
				WeightSum += CurrSample.a * 2.0;
			}
			AnamBlur /= WeightSum;
			AnamCol   = AnamBlur + AnamCol * 0.5;
		}
		Color += AnamCol;
	}
	
	
	[branch] if(UID_Enable)
	{
		float3 DirtMask, BloomMask;
		float  DirtMax;
		
		DirtMask  = LensDirtAtlas.Sample(Linear_Sampler, IN.DirtCoords);
		DirtMax   = max3(DirtMask);
		DirtMax	  = pow(DirtMax / (1.0 + DirtMax), IN.UID_Power);
		DirtMask *= DirtMax * IN.UID_Strength;
		BloomMask = RenderTarget128.Sample(Linear_Sampler, 1.0 - IN.texcoord).rgb * 0.1 +
					RenderTarget64 .Sample(Linear_Sampler,       IN.texcoord).rgb * 0.9;
		
		Color += DirtMask * BloomMask;
	}
	
	return float4(Color, 1.0);
}


//----------------------------------------------------------------------------------------------//
//										LENS WEATHER EFFECTS									//
//																								//
//----------------------------------------------------------------------------------------------//

//----------------------------------------------------------------------------------------------//
//Structs

struct VertexShaderOutputRain
{
   float4 pos        : SV_POSITION;
   float4 texcoord   : TEXCOORD0;
NI float  Fade       : PSINFO0;
NI bool   EnableRain : PSINFO1;
NI float  Rotation   : PSINFO2;
NI float4 SkyColor   : PSINFO3;
NI float4 EnvColor   : PSINFO4;
};

struct VertexShaderOutputRainBlur
{
   float4 pos          : SV_POSITION;
   float2 texcoord     : TEXCOORD0;
NI float  Sigma        : TEXCOORD1;
NI float  WeightFactor : TEXCOORD2;
NI float  LoopCount    : PSINFO0;
NI bool   EnableRain   : PSINFO1;
NI float  OffsetScale  : PSINFO2;
};

struct VertexShaderOutputFrost
{
   float4 pos          : SV_POSITION;
   float2 texcoord     : TEXCOORD0;
NI float2 Radii        : TEXCOORD1;
NI float3 Vignette     : PSINFO0;
NI bool   EnableFrost  : PSINFO1;
NI float3 FrostTint    : PSINFO2;
NI float  Sigma        : PSINFO3;
NI float  WeightFactor : PSINFO4;
NI float  LoopCount    : PSINFO5;
NI bool   EnableRain   : PSINFO6;
NI float  OffsetScale  : PSINFO7;
NI float4 SkyColor     : PSINFO8;
NI float4 EnvColor     : PSINFO9;
};


//----------------------------------------------------------------------------------------------//

//Size of the droplet texture atlas
#define RAINDROP_GRID_SIZE 4

//Disable WeatherFX if the multi weather system isn't configured correctly
#ifndef ENABLE_WEATHERFX_SHADERS
	static const bool UIWFXRain_Enable  = false;
	static const bool UIWFXFrost_Enable = false;
#endif


//----------------------------------------------------------------------------------------------//

float WeatherToEffectStrength(uint Outgoing, uint Incoming, float WeatherTran, float Step)
{
	float2 Weather    = { Outgoing, Incoming };
	float2 Transition = { WeatherTran, 1.0 - WeatherTran };
	
	Transition = saturate(Transition - Step) * rcp(1.0 - Step);
	Transition = lerp(Weather.xy, Weather.yx, Transition);
	
	return (Incoming >= Outgoing) ? Transition.x : Transition.y;
}


//----------------------------------------------------------------------------------------------//

void OOSSampleApprox(inout float3 SampleCol, float2 SampleCoords, float4 SkyColor, float4 EnvColor)
{
	float SkyColWeight  = saturate(SampleCoords.y * -2.0 * SkyColor.a);
	float EnvColWeight  = max2(abs(SampleCoords.x - 0.5) - 0.5);
	      EnvColWeight += saturate(SampleCoords.y - 1.0);
	      EnvColWeight  = saturate(EnvColWeight * 2.0 * EnvColor.a);
	
	SampleCol = lerp(SampleCol, SkyColor.rgb, SkyColWeight);
	SampleCol = lerp(SampleCol, EnvColor.rgb, EnvColWeight);
}

void OOSSampleApprox(inout float3 SampleCol, uint Index, float2 SampleCoords, float4 SkyColor, float4 EnvColor)
{
	float SkyColWeight  = saturate(SampleCoords.y * -2.0 * SkyColor.a);
	float EnvColWeight  = max2(abs(SampleCoords.x - 0.5) - 0.5);
	      EnvColWeight += saturate(SampleCoords.y - 1.0);
	      EnvColWeight  = saturate(EnvColWeight * 2.0 * EnvColor.a);
	
	SampleCol[Index] = lerp(SampleCol[Index], SkyColor[Index], SkyColWeight);
	SampleCol[Index] = lerp(SampleCol[Index], EnvColor[Index], EnvColWeight);
}


//--------------------------------------Rain Droplet Effect-------------------------------------//

VertexShaderOutputRain VS_Rain(VertexShaderInput IN, uniform float4 Seeds, uniform float TOffset)
{
	VertexShaderOutputRain OUT;
	OUT.pos        = float4(IN.pos.xy * PixelSize * 0.25, IN.pos.z, 1.0);
	OUT.texcoord   = IN.txcoord.xyxy;
	OUT.EnableRain = !EInteriorFactor && UIWFXRain_Enable;
	
	#ifdef ENABLE_WEATHERFX_SHADERS
	[branch] if(OUT.EnableRain)
	{
		//Determine rain strength
		uint  IncomingRain, OutgoingRain;
		uint2(IncomingRain, OutgoingRain) =
		(Weather.xy >= WFX_RAINY_WEATHERS_START && Weather.xy <= WFX_RAINY_WEATHERS_END) +
		(Weather.xy >= WFX_RAINSTORMS_START     && Weather.xy <= WFX_RAINY_WEATHERS_END);
		
		float RainStrength = WeatherToEffectStrength(OutgoingRain, IncomingRain, Weather.z, 0.6);
		OUT.EnableRain     = RainStrength > 0.0;
		
		[branch] if(OUT.EnableRain)
		{
			float2 Time; //x = seconds, y = frac part between seconds
			Time.x = Timer.x * 16777.216 * UIWFXRain_Tickrate;
			Time.x = Time.x * ceil(RainStrength) + TOffset;
			Time.y = modf(Time.x, Time.x);
			
			float4 RanValue1 = RandomF4(Time.x * Seeds);
			float4 RanValue2 = RandomF4(RanValue1);
			
			float  RScale	 = MapToRange(RanValue1.x, UIWFXRain_MinSize, UIWFXRain_MaxSize);
				   RScale	*= 1.0 + Time.y * 0.25;
			float  RRotation = RanValue1.y * 360.0;
			float2 ROffset	 = RanValue1.zw * 2.0 - 1.0;
			float2 RRatio	 = 1.0 + (RanValue2.xw * 2.0 - 1.0) * UIWFXRain_MaxDeformation;
			
			float   RDripping, RDripDrift;
			float2 (RDripping, RDripDrift) =
			saturate(CatmullRom(Time.y, RanValue2.xz, 0.0, 1.0, RanValue2.yw));
			
			RDripping  *= UIWFXRain_DripSpeed / UIWFXRain_Tickrate;
			RDripDrift *= UIWFXRain_DripDrift;
			RDripDrift  = step(RanValue2.x, 0.45) * RDripDrift * RanValue2.y -
						  step(0.75, RanValue2.z) * RDripDrift * RanValue2.w;
			
			//Quad Scale, Offset, Rotate
			OUT.pos.xy = IN.pos.xy * RScale * RRatio + ROffset;
			OUT.pos.xy = MatrixRotate(OUT.pos.xy, RRotation, false);
			
			OUT.Rotation = RRotation;
			
			//Make base quad squared and apply dripping motion
			OUT.pos.y  = OUT.pos.y * ScreenSize.z - RDripping;
			OUT.pos.x += RDripDrift;
			
			//Additional info for ps computations
			float2 AtlasCoords = floor(RanValue2.xy * RAINDROP_GRID_SIZE);
			   OUT.texcoord.zw = (AtlasCoords + OUT.texcoord.zw) / RAINDROP_GRID_SIZE;
			
			OUT.Fade  = lerp(Night_UIWFXRain_Intensity, Day_UIWFXRain_Intensity, ENightDayFactor);
			OUT.Fade *= min(RainStrength, 1.2);
			OUT.Fade *= 1.0 - pow(Time.y, UIWFXRain_FadeCurve);
			
			OUT.SkyColor = lerp(Night_UIWFXRain_SkyColor, Day_UIWFXRain_SkyColor, ENightDayFactor);
			OUT.EnvColor = lerp(Night_UIWFXRain_EnvColor, Day_UIWFXRain_EnvColor, ENightDayFactor);
		}
	}
	#endif //ENABLE_WEATHERFX_SHADERS
	
	return OUT;
}


float4 PS_Rain(VertexShaderOutputRain IN) : SV_Target
{
	if(!IN.EnableRain) discard;
	float4 DropCol = 0.0;
	
	#ifdef ENABLE_WEATHERFX_SHADERS
	static const float3 SourceRay   = { 0.0, 0.0, -1.0 };
	static const float4 RefracIndex = 1.000277 / float4(1.3310, 1.3330, 1.3358, 1.3325); //Air -> Water(R,G,B,~)
	
	float2 SSCoords      = IN.pos.xy * PixelSize;
	float4 DropletNormal = RainDrops.Sample(Linear_Sampler, IN.texcoord.zw);
	
	clip(DropletNormal.w - 0.01);
	
	DropletNormal.xyz = DropletNormal.xyz * 2.0 - 1.0;
	DropletNormal.xy *= UIWFXRain_Curvature;
	
	float3 RefracSample;
	
	#if !RAINFX_ENABLE_DISPERSION
		float3 RefracVec    = refract(SourceRay, DropletNormal.xyz, RefracIndex.w);
		float2 RefracCoords = SSCoords + MatrixRotate(RefracVec.xy / RefracVec.z, IN.Rotation, true);
			   RefracSample = TextureOriginal.Sample(Linear_Sampler_Rain, RefracCoords).rgb;
		OOSSampleApprox(RefracSample, RefracCoords, IN.SkyColor, IN.EnvColor);
	
	#else
		float3 ScaledRefracIndex;
		ScaledRefracIndex.y  = RefracIndex.y;
		ScaledRefracIndex.xz = lerp(RefracIndex.y, RefracIndex.xz, UIWFXRain_Dispersion);
		
		[unroll] for(int i=0; i<3; i++)
		{
			float3 RefracVec       = refract(SourceRay, DropletNormal.xyz, ScaledRefracIndex[i]);
			float2 RefracCoords    = SSCoords + RefracVec.xy / RefracVec.z;
				   RefracSample[i] = TextureOriginal.Sample(Linear_Sampler_Rain, RefracCoords)[i];
			OOSSampleApprox(RefracSample, i, RefracCoords, IN.SkyColor, IN.EnvColor);
		}
	#endif
	
	IN.Fade *= DropletNormal.w;
	DropCol  = float4(RefracSample, 1.0) * IN.Fade;
	
	#endif //ENABLE_WEATHERFX_SHADERS
	
	return saturate(DropCol);
}


VertexShaderOutputRainBlur VS_RainBlur(VertexShaderInput IN)
{
	VertexShaderOutputRainBlur OUT;
	OUT.pos			= float4(IN.pos.xyz, 1.0);
	OUT.texcoord.xy = IN.txcoord.xy;
	OUT.EnableRain  = !EInteriorFactor && UIWFXRain_Enable;
	
	#ifdef ENABLE_WEATHERFX_SHADERS
	[branch] if(OUT.EnableRain)
	{
		uint  IncomingRain, OutgoingRain;
		uint2(IncomingRain, OutgoingRain) =
		(Weather.xy >= WFX_RAINY_WEATHERS_START && Weather.xy <= WFX_RAINY_WEATHERS_END) +
		(Weather.xy >= WFX_RAINSTORMS_START     && Weather.xy <= WFX_RAINY_WEATHERS_END);
		
		float RainStrength = WeatherToEffectStrength(OutgoingRain, IncomingRain, Weather.z, 0.6);
		OUT.EnableRain     = RainStrength > 0.0;

		OUT.Sigma        = UIWFXRain_Sigma + DELTA;
		OUT.WeightFactor =  rcp(OUT.Sigma * SqrtTwoPI);
		OUT.LoopCount    = ceil(OUT.Sigma * 1.5 - 0.01);
		OUT.Sigma        = -rcp(OUT.Sigma * OUT.Sigma);
		OUT.OffsetScale  = 1.0 - sqrt(saturate(UIWFXRain_Sigma / 3.0)) * 0.5;
	}
	#endif //ENABLE_WEATHERFX_SHADERS
	
	return OUT;
}

float4 PS_RainBlur(VertexShaderOutputRainBlur IN) : SV_Target
{
	if(!IN.EnableRain) discard;
	float4 BlurredCol = 0.0;
	
	#ifdef ENABLE_WEATHERFX_SHADERS
	float4 StepSize     = PixelSize.xyxy * float4(1.0, 0.0, -1.0, 0.0);
	float4 HalfStepSize = StepSize * IN.OffsetScale;
		   StepSize    *= 2.0;
	
	float WeightSum  = IN.WeightFactor * IN.OffsetScale;
		  BlurredCol = WeightSum * RenderTargetRGBA32.Sample(Point_Sampler, IN.texcoord);
	
	[loop] for(float i=1.0; i <= IN.LoopCount; i++)
	{
		float  GaussWeight = IN.WeightFactor * exp(i*i*IN.Sigma);
		float4 CurrOffset  = IN.texcoord.xyxy + i * StepSize - HalfStepSize;
		
		BlurredCol += GaussWeight * RenderTargetRGBA32.SampleLevel(Linear_Sampler, CurrOffset.xy,0);
		BlurredCol += GaussWeight * RenderTargetRGBA32.SampleLevel(Linear_Sampler, CurrOffset.zw,0);
		WeightSum  += GaussWeight * 2.0;
	}
	
	BlurredCol /= WeightSum;
	#endif //ENABLE_WEATHERFX_SHADERS
	
	return BlurredCol;
}


//----------------------------------------------------------------------------------------------//
//								SPECTRAL CHROMATIC ABERRATION									//
//																								//
//	  Multi-wavelength dispersion with CIE-approximate spectral weights							//
//	  Cauchy-derived offsets: n(l)=A+B/l^2, centered at 550nm green								//
//----------------------------------------------------------------------------------------------//

// 6 spectral samples covering 430-660nm visible range
// Positive dispersion = blue/violet end (shorter wavelengths refract more)
// Negative dispersion = red end (longer wavelengths refract less)
static const float  CA_Offset[6] = {  1.0,   0.58,   0.20,  -0.10,  -0.52,  -1.0  };
static const float3 CA_Weight[6] = { float3(0.02, 0.00, 0.80),   //~430nm Violet-Blue
                                     float3(0.00, 0.20, 0.85),   //~470nm Blue-Cyan
                                     float3(0.05, 0.85, 0.10),   //~520nm Green
                                     float3(0.35, 0.90, 0.00),   //~560nm Yellow-Green
                                     float3(0.95, 0.25, 0.00),   //~610nm Orange
                                     float3(0.55, 0.02, 0.00) }; //~660nm Deep Red


float3 SpectralCA(float2 Texcoord, float2 VigDir, float VigDist)
{
	//Base dispersion magnitude (backward-compatible with original Strength/Curve)
	float Magnitude = pow(VigDist / 1.15, UICA_Curve);
	      Magnitude *= UICA_Strength / VigDist * 10.0;
	
	//Center deadzone: smoothly fades CA at screen center to prevent sampling artifacts
	Magnitude *= smoothstep(UICA_Deadzone, UICA_Deadzone + 0.15, VigDist);
	
	//Direction vector scaled by magnitude and pixel size
	float2 BaseVector = VigDir * Magnitude * PixelSize;
	
	//Accumulate spectral samples
	float3 AccColor  = float3(0.0, 0.0, 0.0);
	float3 AccWeight = float3(0.0, 0.0, 0.0);
	
	[unroll] for(int s = 0; s < 6; s++)
	{
		//Per-wavelength dispersion scaled by spread control
		float Disp = CA_Offset[s] * UICA_Spread;
		
		//Asymmetric red/blue bias: interpolate between RedBias and BlueBias based on wavelength position
		float Bias = lerp(UICA_RedBias, UICA_BlueBias, saturate(CA_Offset[s] * 0.5 + 0.5));
		Disp *= Bias;
		
		//Barrel distortion: wavelength-dependent radial magnification (lateral CA)
		float BarrelMul = 1.0 + Disp * UICA_Barrel * VigDist * 0.5;
		
		//Final sample UV for this wavelength
		float2 SampleUV = Texcoord + BaseVector * Disp * BarrelMul;
		
		//Accumulate weighted spectral contribution
		float3 Tap = TextureColor.Sample(Linear_Sampler_CA, SampleUV).rgb;
		
		AccColor  += Tap * CA_Weight[s];
		AccWeight += CA_Weight[s];
	}
	
	//Normalize per channel independently
	AccColor /= deltalim(AccWeight);
	
	//Fringe saturation control: blend between monochrome and full color
	float  Luma = dot(AccColor, K_LUM);
	float3 Mono = float3(Luma, Luma, Luma);
	AccColor = lerp(Mono, AccColor, UICA_FringeSat);
	
	return AccColor;
}


//-------------------------------------Frost Vignette Effect------------------------------------//

VertexShaderOutputFrost VS_Frost(VertexShaderInput IN)
{
	VertexShaderOutputFrost OUT;
	OUT.pos         = float4(IN.pos.xyz, 1.0);
	OUT.texcoord    = IN.txcoord.xy;
	OUT.EnableFrost = !EInteriorFactor && UIWFXFrost_Enable;
	OUT.EnableRain  = !EInteriorFactor && UIWFXRain_Enable;
	
	#ifdef ENABLE_WEATHERFX_SHADERS
	[branch] if(OUT.EnableFrost)
	{
		//Determine frost strength
		uint  IncomingSnow, OutgoingSnow;
		uint2(IncomingSnow, OutgoingSnow) =
		(Weather.xy >= WFX_SNOWY_WEATHERS_START && Weather.xy <= WFX_SNOWY_WEATHERS_END) +
		(Weather.xy == WFX_SNOWSTORM);
		
		float FrostStrength = WeatherToEffectStrength(OutgoingSnow, IncomingSnow, Weather.z, 0.5);
		OUT.EnableFrost     = FrostStrength > 0.0;
		
		[branch] if(OUT.EnableFrost)
		{
			float2 Time; //x = seconds, y = frac part between seconds
			Time.y = modf(Timer.x * 16777.216 * UIWFXFrost_PulseRate, Time.x);
			Time.y = abs(ceil(fmod(Time.x, 2.0)) - Time.y);
			
			//Additional info for ps computations
			float UIWFXFrost_Intensity = lerp(Night_UIWFXFrost_Intensity, Day_UIWFXFrost_Intensity, ENightDayFactor);
			OUT.Vignette.z = 4.0 - FrostStrength * 1.5;
			
			FrostStrength *= 1.0 + Time.y * UIWFXFrost_PulseStrength;
			OUT.Vignette.x = UIWFXFrost_Curve + (2.0 - FrostStrength) * 0.1;
			OUT.Vignette.y = UIWFXFrost_Intensity * saturate(FrostStrength);
			
			OUT.Radii.x  = zerolim(UIWFXFrost_RadiusInner - FrostStrength * 0.1);
			OUT.Radii.y  = rcp(max(UIWFXFrost_RadiusOuter, OUT.Radii.x + DELTA) - OUT.Radii.x);
			OUT.Radii.x *= OUT.Radii.y;
			
			OUT.FrostTint = UIWFXFrost_Tint / deltalim(dot(UIWFXFrost_Tint, N_LUM));
			
			OUT.SkyColor = lerp(Night_UIWFXFrost_SkyColor, Day_UIWFXFrost_SkyColor, ENightDayFactor);
			OUT.EnvColor = lerp(Night_UIWFXFrost_EnvColor, Day_UIWFXFrost_EnvColor, ENightDayFactor);
		}
	}
	
	[branch] if(OUT.EnableRain)
	{
		uint  IncomingRain, OutgoingRain;
		uint2(IncomingRain, OutgoingRain) =
		(Weather.xy >= WFX_RAINY_WEATHERS_START && Weather.xy <= WFX_RAINY_WEATHERS_END) +
		(Weather.xy >= WFX_RAINSTORMS_START     && Weather.xy <= WFX_RAINY_WEATHERS_END);
		
		float RainStrength = WeatherToEffectStrength(OutgoingRain, IncomingRain, Weather.z, 0.6);
		OUT.EnableRain     = RainStrength > 0.0;

		OUT.Sigma        = UIWFXRain_Sigma + DELTA;
		OUT.WeightFactor =  rcp(OUT.Sigma * SqrtTwoPI);
		OUT.LoopCount    = ceil(OUT.Sigma * 1.5 - 0.01);
		OUT.Sigma        = -rcp(OUT.Sigma * OUT.Sigma);
		OUT.OffsetScale  = 1.0 - sqrt(saturate(UIWFXRain_Sigma / 3.0)) * 0.5;
	}
	#endif //ENABLE_WEATHERFX_SHADERS
	
	return OUT;
}


float4 PS_Frost(VertexShaderOutputFrost IN) : SV_Target
{
	float4 Color       = { TextureColor.Sample(Point_Sampler, IN.texcoord).rgb, 0.0 };
	float2 VigVector   = IN.texcoord * 2.0 - 1.0;
	float  VigGradient = length(VigVector);
	
	[branch] if(UICA_Enable)
	{
		Color.rgb = SpectralCA(IN.texcoord, VigVector, VigGradient);
	}
	
	#ifdef ENABLE_WEATHERFX_SHADERS
	[branch] if(IN.EnableRain)
	{
		float4 StepSize     = PixelSize.xyxy * float4(0.0, 1.0, 0.0, -1.0);
		float4 HalfStepSize = StepSize * IN.OffsetScale;
			   StepSize    *= 2.0;
		
		float  WeightSum  = IN.WeightFactor * IN.OffsetScale;
		float4 BlurredCol = WeightSum * RenderTargetRGBA64F.Sample(Point_Sampler, IN.texcoord);
		
		[loop] for(float i=1.0; i <= IN.LoopCount; i++)
		{
			float  GaussWeight = IN.WeightFactor * exp(i*i*IN.Sigma);
			float4 CurrOffset  = IN.texcoord.xyxy + i * StepSize - HalfStepSize;
			
			BlurredCol += GaussWeight * RenderTargetRGBA64F.SampleLevel(Linear_Sampler, CurrOffset.xy,0);
			BlurredCol += GaussWeight * RenderTargetRGBA64F.SampleLevel(Linear_Sampler, CurrOffset.zw,0);
			WeightSum  += GaussWeight * 2.0;
		}
		
		Color += BlurredCol / WeightSum;
	}
	
	[branch] if(IN.EnableFrost)
	{
		float VigWeight = VigGradient * IN.Radii.y - IN.Radii.x; //LinearStep
			  VigWeight = saturate(pow(VigWeight, IN.Vignette.x) * IN.Vignette.y);
		
		#if FROSTFX_USE_REFRACTION_METHOD
			//Refraction approximation using sobel operator and 2D "normal mapping"
			float3 FrostData = FrostTexRefrac.Sample(Linear_Sampler, IN.texcoord).xyz;
			
			float2 MappedCoords  = FrostData.xy * 2.0 + 1.0;
				   MappedCoords *= UIWFXFrost_RefracRange;
				   MappedCoords -= UIWFXFrost_RefracRange * 2.0;
				   MappedCoords += IN.texcoord;
			
			float3 RefracCol   = TextureOriginal.Sample(Linear_Sampler_Rain, MappedCoords).rgb;
			bool   NoOvershoot = all(saturate(MappedCoords - MappedCoords * MappedCoords));
				   NoOvershoot = NoOvershoot || UIWFXFrost_AllowOvershoot;
				   VigWeight   = saturate(VigWeight * FrostData.z * NoOvershoot);
			
			float Opacity   = FrostData.z / dot(abs(FrostData.xy - 0.5), 99.0 - UIWFXFrost_Opacity);
				  RefracCol = lerp(RefracCol, IN.FrostTint, saturate(Opacity));
			
			OOSSampleApprox(RefracCol, MappedCoords, IN.SkyColor, IN.EnvColor);
			Color = lerp(Color, float4(RefracCol, 1.0), VigWeight);
			
		#else
			float3 FrostTexture = FrostTex.Sample(Linear_Sampler, IN.texcoord).rgb;
			
			FrostTexture = dot(pow(FrostTexture, IN.Vignette.z), UIWFXFrost_LayerInt);
			Color.rgb    = lerp(Color.rgb, FrostTexture * IN.FrostTint, VigWeight);
		#endif //FROSTFX_USE_REFRACTION_METHOD
	}
	#endif //ENABLE_WEATHERFX_SHADERS
	
	return Color;
}



//----------------------------------------------------------------------------------------------//
//									  PROFESSIONAL FILM GRAIN									//
//																								//
//	 Multi-layer emulsion grain with luminance response and per-channel decorrelation			//
//----------------------------------------------------------------------------------------------//

//----------------------------------------------------------------------------------------------//
//Struct

struct VertexShaderOutputFilmGrain
{
   float4 pos            : SV_POSITION;
   float2 texcoord       : TEXCOORD0;
NI float  FG_Int         : FG0;
NI float  FG_Size        : FG1;
NI float  FG_Roughness   : FG2;
NI float  FG_FrameSeed   : FG3;
NI float3 FG_LumaResp    : FG4; //shadow, midtone, highlight weights
NI float3 FG_ChanWeight   : FG5;
NI float  FG_ChanDecorr   : FG6;
};


//----------------------------------------------------------------------------------------------//
//Grain noise generation using sin-based PRNGs (matches existing codebase pattern)

float FG_Noise(float2 Coord, float Seed)
{ return abs(frac(sin(dot(Coord + Seed, float2(12.9898, 78.233))) * 43758.5453)); }

float FG_Noise2(float2 Coord, float Seed)
{ return abs(frac(sin(dot(Coord + Seed, float2(25.9796, 156.466))) * 43758.5453)); }


//Multi-layer grain with gaussian-like distribution and clumping structure
float FG_Structured(float2 Coord, float Seed, float Roughness)
{
	//Primary grain: fine structure at full resolution
	float Fine = FG_Noise(Coord, Seed);
	
	//Secondary grain: coarser clumps at half resolution
	float Coarse = FG_Noise(floor(Coord * 0.5), Seed + 7.31);
	
	//Blend layers by roughness (0=pure fine, 1=prominent clumps)
	float Grain = lerp(Fine, Fine * 0.6 + Coarse * 0.4, Roughness);
	
	//Approximate gaussian via 3-sample averaging (Box-Muller approximation)
	float G2 = FG_Noise2(Coord, Seed + 3.17);
	float G3 = FG_Noise(Coord, Seed + 11.53);
	Grain = (Grain + G2 + G3) * 0.333333;
	
	//Center around zero [-0.5, +0.5]
	return Grain - 0.5;
}


//Film sensitometry: luminance-dependent grain response
//Shadows show heavy grain (underexposed silver halide clusters)
//Midtones show moderate grain
//Highlights show minimal grain (fully developed smooth emulsion)
float FG_LuminanceResponse(float Luma, float3 Response)
{
	float Shadow    = 1.0 - smoothstep(0.0, 0.35, Luma);
	float Highlight = smoothstep(0.55, 1.0, Luma);
	float Midtone   = 1.0 - Shadow - Highlight;
	
	return Shadow * Response.x + Midtone * Response.y + Highlight * Response.z;
}


//------------------------------Film Grain Vertex Shader------------------------------------------//

VertexShaderOutputFilmGrain VS_FilmGrain(VertexShaderInput IN)
{
	VertexShaderOutputFilmGrain OUT;
	OUT.pos      = float4(IN.pos.xyz, 1.0);
	OUT.texcoord = IN.txcoord.xy;
	
	//DNI intensity separation
	OUT.FG_Int        = DNI_SEPARATION(UIFG_Intensity);
	OUT.FG_Size       = UIFG_Size;
	OUT.FG_Roughness  = UIFG_Roughness;
	OUT.FG_ChanWeight  = UIFG_ChannelWeight;
	OUT.FG_ChanDecorr  = UIFG_ChannelDecorr;
	OUT.FG_LumaResp    = float3(UIFG_ShadowGrain, UIFG_MidtoneGrain, UIFG_HighlightGrain);
	
	//Temporal seed for per-frame grain animation
	OUT.FG_FrameSeed = floor(Timer.z * UIFG_AnimSpeed);
	
	return OUT;
}


//-------------------------------Film Grain Pixel Shader------------------------------------------//

float4 PS_FilmGrain(VertexShaderOutputFilmGrain IN) : SV_Target
{
	float3 Color = TextureColor.Sample(Point_Sampler, IN.texcoord).rgb;
	
	[branch] if(UIFG_Enable && IN.FG_Int > 0.0)
	{
		//Pixel coordinates scaled by grain size
		float2 GrainCoord = IN.pos.xy / IN.FG_Size;
		
		//Temporal offset to decorrelate frames
		float TSeed = IN.FG_FrameSeed * 137.31;
		
		//Base grain (red channel / monochrome base)
		float3 Grain;
		Grain.r = FG_Structured(GrainCoord, TSeed, IN.FG_Roughness);
		
		//Per-channel decorrelation simulating independent emulsion dye layers
		//0=monochromatic, 1=fully independent R/G/B grain patterns
		float GrainG = FG_Structured(GrainCoord, TSeed + 5.39, IN.FG_Roughness);
		float GrainB = FG_Structured(GrainCoord, TSeed + 9.71, IN.FG_Roughness);
		Grain.g = lerp(Grain.r, GrainG, IN.FG_ChanDecorr);
		Grain.b = lerp(Grain.r, GrainB, IN.FG_ChanDecorr);
		
		//Per-channel emulsion weights (blue typically grainier in real film stock)
		Grain *= IN.FG_ChanWeight;
		
		//Luminance-adaptive response
		float Luma     = dot(Color, K_LUM);
		float Response = FG_LuminanceResponse(Luma, IN.FG_LumaResp);
		
		//Final grain amount
		float3 GrainAmount = Grain * IN.FG_Int * Response;
		
		//Soft clamp to prevent harsh clipping at extremes
		GrainAmount = sign(GrainAmount) * (1.0 - exp(-abs(GrainAmount) * 4.0)) * 0.25;
		
		Color = saturate(Color + GrainAmount);
	}
	
	return float4(Color, 1.0);
}



//----------------------------------------------------------------------------------------------//
//										   Techniques												//
//																								//
//----------------------------------------------------------------------------------------------//
//"love and hate are just two words for passion"


//-----------------------------------Compilation Optimization-----------------------------------//

VertexShader VS_GhostsPrePass_Comp   =   CompileShader(vs_5_0, VS_GhostsPrePass());
VertexShader VS_GhostsMain_Comp      =   CompileShader(vs_5_0, VS_GhostsMain());
VertexShader VS_GhostsBypass_Comp[3] = { CompileShader(vs_5_0, VS_GhostsBypass(float2( 1.0,1.0), float2(0.5,0.5))),
										 CompileShader(vs_5_0, VS_GhostsBypass(float2( 1.0,1.0), float2(0.5,0.5))),
										 CompileShader(vs_5_0, VS_GhostsBypass(float2(-1.0,0.0), float2(0.5,1.0))) };
VertexShader VS_GhostsMix_Comp       =   CompileShader(vs_5_0, VS_GhostsMix());
VertexShader VS_GhostsFullres_Comp   =   CompileShader(vs_5_0, VS_GhostsFullres());

PixelShader  PS_GhostsPrePass_Comp   =   CompileShader(ps_5_0, PS_GhostsPrePass());
PixelShader  PS_GhostsMain_Comp[5]   = { CompileShader(ps_5_0, PS_GhostsMain(4.0 / UIG_FNumber       )),
										 CompileShader(ps_5_0, PS_GhostsMain(4.0 / UIG_FNumber *  2.0)),
										 CompileShader(ps_5_0, PS_GhostsMain(4.0 / UIG_FNumber *  4.0)),
										 CompileShader(ps_5_0, PS_GhostsMain(4.0 / UIG_FNumber *  8.0)),
										 CompileShader(ps_5_0, PS_GhostsMain(4.0 / UIG_FNumber * 16.0)) };
PixelShader  PS_GhostsBypass_Comp    =   CompileShader(ps_5_0, PS_GhostsBypass());
PixelShader  PS_GhostsMix_Comp       =   CompileShader(ps_5_0, PS_GhostsMix());
PixelShader  PS_GhostsFullres_Comp   =   CompileShader(ps_5_0, PS_GhostsFullres());


VertexShader VS_StarburstPrePass_Comp     =   CompileShader(vs_5_0, VS_StarburstPrePass());
VertexShader VS_StarburstMain_Comp        =   CompileShader(vs_5_0, VS_StarburstMain());
VertexShader VS_StarburstPostPass_Comp    =   CompileShader(vs_5_0, VS_StarburstPostPass());

PixelShader  PS_StarburstPrePass_Comp     =   CompileShader(ps_5_0, PS_StarburstPrePass());
PixelShader  PS_StarburstMain_Comp        =   CompileShader(ps_5_0, PS_StarburstMain());
PixelShader  PS_StarburstPostPass_Comp[2] = { CompileShader(ps_5_0, PS_StarburstPostPass(false)),
										      CompileShader(ps_5_0, PS_StarburstPostPass(true )) };


VertexShader VS_Basic_Comp = CompileShader(vs_5_0, VS_Basic());
PixelShader  PS_Blank_Comp = CompileShader(ps_5_0, PS_Blank());
PixelShader  PS_Rain_Comp  = CompileShader(ps_5_0, PS_Rain());

VertexShader VS_RainBlur_Comp = CompileShader(vs_5_0, VS_RainBlur());
PixelShader  PS_RainBlur_Comp = CompileShader(ps_5_0, PS_RainBlur());

VertexShader VS_Reflection_Comp = CompileShader(vs_5_0, VS_Reflection());
PixelShader  PS_Reflection_Comp = CompileShader(ps_5_0, PS_Reflection());

VertexShader VS_AnamFlarePrePass_Comp = CompileShader(vs_5_0, VS_AnamFlarePrePass());
PixelShader  PS_AnamFlarePrePass_Comp = CompileShader(ps_5_0, PS_AnamFlarePrePass());
VertexShader VS_AnamFlare_Comp        = CompileShader(vs_5_0, VS_AnamFlare());
PixelShader  PS_AnamFlare_Comp        = CompileShader(ps_5_0, PS_AnamFlare());

VertexShader VS_DirtAndPostPass_Comp    =   CompileShader(vs_5_0, VS_DirtAndPostPass());
PixelShader  PS_DirtAndPostPass_Comp[2] = { CompileShader(ps_5_0, PS_DirtAndPostPass(false)),
										    CompileShader(ps_5_0, PS_DirtAndPostPass(true )) };

VertexShader VS_Frost_Comp = CompileShader(vs_5_0, VS_Frost());
PixelShader  PS_Frost_Comp = CompileShader(ps_5_0, PS_Frost());

VertexShader VS_FilmGrain_Comp = CompileShader(vs_5_0, VS_FilmGrain());
PixelShader  PS_FilmGrain_Comp = CompileShader(ps_5_0, PS_FilmGrain());



//---------------------------------------Technique Macros---------------------------------------//

#undef  TECH11
#define TECH11(NAME, VS, PS) \
technique11 NAME {pass p0 {SetVertexShader(VS); SetPixelShader (PS);}}

#undef  TWOPASSTECH11
#define TWOPASSTECH11(NAME, VS1, PS1, VS2, PS2) \
technique11 NAME {pass p0 {SetVertexShader(VS1); SetPixelShader (PS1);}\
				  pass p1 {SetVertexShader(VS2); SetPixelShader (PS2);}}


#define GHOSTS_TECHBLOCK(a) \
TECH11        (COMBINE(a,1), VS_GhostsMain_Comp,      PS_GhostsMain_Comp[0]) \
TECH11        (COMBINE(a,2), VS_GhostsMain_Comp,      PS_GhostsMain_Comp[1]) \
TWOPASSTECH11 (COMBINE(a,3), VS_GhostsMain_Comp,      PS_GhostsMain_Comp[2], \
						     VS_GhostsBypass_Comp[0], PS_GhostsBypass_Comp)  \
TWOPASSTECH11 (COMBINE(a,4), VS_GhostsMain_Comp,      PS_GhostsMain_Comp[3], \
						     VS_GhostsBypass_Comp[1], PS_GhostsBypass_Comp)  \
TWOPASSTECH11 (COMBINE(a,5), VS_GhostsMain_Comp,      PS_GhostsMain_Comp[4], \
						     VS_GhostsBypass_Comp[2], PS_GhostsBypass_Comp)  \
TECH11        (COMBINE(a,6), VS_GhostsMix_Comp,       PS_GhostsMix_Comp)

#define STARBURST_TECHBLOCK(a,b1,b2,b3,b4,b5) \
TECH11        (COMBINE(a,b1), VS_Basic_Comp,			 PS_Blank_Comp) \
TWOPASSTECH11 (COMBINE(a,b2), VS_Basic_Comp,			 PS_Blank_Comp, \
						      VS_StarburstPrePass_Comp,	 PS_StarburstPrePass_Comp) \
TECH11        (COMBINE(a,b3), VS_StarburstMain_Comp,	 PS_StarburstMain_Comp) \
TECH11        (COMBINE(a,b4), VS_StarburstPostPass_Comp, PS_StarburstPostPass_Comp[b5])

#define RAINPASS(PN,VS) \
pass PN{ SetVertexShader(CompileShader(vs_5_0, VS_Rain##VS)); \
		 SetPixelShader (PS_Rain_Comp); \
		 SetBlendState  (RainBlending, float4(1.0,1.0,1.0,1.0), 0xFFFFFFFF); }

#define CLEARPASS(PN) \
pass PN{ SetVertexShader(VS_Basic_Comp);\
		 SetPixelShader (PS_Blank_Comp);}

#define RAINTECH(NAME) \
technique11 NAME <string RenderTarget="RenderTargetRGBA32";> \
{ CLEARPASS(Clear) \
  RAINPASS(Pass0,  (float4(967.0, 296.0, 477.0, 806.0),       0.0))  RAINPASS(Pass1,  (float4( 63.0, 278.0, 501.0, 392.0),  1.0/16.0)) \
  RAINPASS(Pass2,  (float4(615.0, 735.0, 628.0, 128.0),  2.0/16.0))  RAINPASS(Pass3,  (float4(490.0, 339.0, 887.0, 289.0),  3.0/16.0)) \
  RAINPASS(Pass4,  (float4(665.0, 708.0, 408.0, 518.0),  4.0/16.0))  RAINPASS(Pass5,  (float4(173.0, 683.0, 784.0, 453.0),  5.0/16.0)) \
  RAINPASS(Pass6,  (float4( 72.0, 866.0,  83.0, 292.0),  6.0/16.0))  RAINPASS(Pass7,  (float4(493.0, 338.0, 694.0, 133.0),  7.0/16.0)) \
  RAINPASS(Pass8,  (float4(217.0, 612.0, 251.0, 867.0),  8.0/16.0))  RAINPASS(Pass9,  (float4(368.0, 199.0, 834.0, 959.0),  9.0/16.0)) \
  RAINPASS(Pass10, (float4(567.0, 913.0, 780.0, 545.0), 10.0/16.0))  RAINPASS(Pass11, (float4(649.0, 764.0, 304.0, 620.0), 11.0/16.0)) \
  RAINPASS(Pass12, (float4(924.0, 104.0, 226.0, 849.0), 12.0/16.0))  RAINPASS(Pass13, (float4(993.0, 495.0, 320.0, 382.0), 13.0/16.0)) \
  RAINPASS(Pass14, (float4(352.0, 472.0, 213.0, 382.0), 14.0/16.0))  RAINPASS(Pass15, (float4( 67.0, 144.0,  16.0, 861.0), 15.0/16.0)) }


//----------------------------------Technique with everything-----------------------------------//

TECH11			    (KitsuuneMasterLensA   <string UIName="Master Lens";>,				  VS_GhostsPrePass_Comp,    PS_GhostsPrePass_Comp)
GHOSTS_TECHBLOCK    (KitsuuneMasterLensA)
TECH11			    (KitsuuneMasterLensA7  <string RenderTarget="RenderTarget512";>,      VS_Reflection_Comp,	    PS_Reflection_Comp)
TWOPASSTECH11	    (KitsuuneMasterLensA8  <string RenderTarget="RenderTargetRGBA64F";>,  VS_Basic_Comp,		    PS_Blank_Comp,
																						  VS_AnamFlarePrePass_Comp, PS_AnamFlarePrePass_Comp)
TECH11			    (KitsuuneMasterLensA9  <string RenderTarget="RenderTarget256";>,      VS_AnamFlare_Comp,	    PS_AnamFlare_Comp)
TECH11			    (KitsuuneMasterLensA10 <string RenderTarget="RenderTargetRGBA64F";>,  VS_GhostsFullres_Comp,    PS_GhostsFullres_Comp)
STARBURST_TECHBLOCK (KitsuuneMasterLensA,11,12,13,14,1)
TECH11			    (KitsuuneMasterLensA15,												  VS_DirtAndPostPass_Comp,  PS_DirtAndPostPass_Comp[1])
RAINTECH		    (KitsuuneMasterLensA16)
TECH11			    (KitsuuneMasterLensA17 <string RenderTarget="RenderTargetRGBA64F";>,  VS_RainBlur_Comp,		    PS_RainBlur_Comp)
TECH11			    (KitsuuneMasterLensA18,												  VS_Frost_Comp,		    PS_Frost_Comp)
TECH11			    (KitsuuneMasterLensA19,												  VS_FilmGrain_Comp,	    PS_FilmGrain_Comp)


//-----------------------------------Technique without Ghosts-----------------------------------//

TECH11				   (KitsuuneMasterLensB  <string UIName="Master Lens - No Ghosts";
										  string RenderTarget="RenderTarget512";>,		  VS_Reflection_Comp,	    PS_Reflection_Comp)
TWOPASSTECH11	    (KitsuuneMasterLensB1 <string RenderTarget="RenderTargetRGBA64F";>,	  VS_Basic_Comp,		    PS_Blank_Comp,
																						  VS_AnamFlarePrePass_Comp, PS_AnamFlarePrePass_Comp)
TECH11			    (KitsuuneMasterLensB2 <string RenderTarget="RenderTarget256";>,		  VS_AnamFlare_Comp,	    PS_AnamFlare_Comp)
STARBURST_TECHBLOCK (KitsuuneMasterLensB,3,4,5,6,0)
TECH11			    (KitsuuneMasterLensB7,												  VS_DirtAndPostPass_Comp, PS_DirtAndPostPass_Comp[1])
RAINTECH		    (KitsuuneMasterLensB8)
TECH11			    (KitsuuneMasterLensB9 <string RenderTarget="RenderTargetRGBA64F";>,	  VS_RainBlur_Comp,		   PS_RainBlur_Comp)
TECH11			    (KitsuuneMasterLensB10,												  VS_Frost_Comp,		   PS_Frost_Comp)
TECH11			    (KitsuuneMasterLensB11,												  VS_FilmGrain_Comp,	   PS_FilmGrain_Comp)


//---------------------------------Technique without StarBurst----------------------------------//

TECH11			    (KitsuuneMasterLensC   <string UIName="Master Lens - No Starburst";>, VS_GhostsPrePass_Comp,    PS_GhostsPrePass_Comp)
GHOSTS_TECHBLOCK    (KitsuuneMasterLensC)
TECH11			    (KitsuuneMasterLensC7,												  VS_GhostsFullres_Comp,    PS_GhostsFullres_Comp)
TECH11			    (KitsuuneMasterLensC8  <string RenderTarget="RenderTarget512";>,      VS_Reflection_Comp,	    PS_Reflection_Comp)
TWOPASSTECH11	    (KitsuuneMasterLensC9  <string RenderTarget="RenderTargetRGBA64F";>,  VS_Basic_Comp,		    PS_Blank_Comp,
																						  VS_AnamFlarePrePass_Comp, PS_AnamFlarePrePass_Comp)
TECH11			    (KitsuuneMasterLensC10 <string RenderTarget="RenderTarget256";>,	  VS_AnamFlare_Comp,	    PS_AnamFlare_Comp)
TECH11			    (KitsuuneMasterLensC11,												  VS_DirtAndPostPass_Comp,  PS_DirtAndPostPass_Comp[1])
RAINTECH		    (KitsuuneMasterLensC12)
TECH11			    (KitsuuneMasterLensC13 <string RenderTarget="RenderTargetRGBA64F";>,  VS_RainBlur_Comp,		    PS_RainBlur_Comp)
TECH11			    (KitsuuneMasterLensC14,												  VS_Frost_Comp,		    PS_Frost_Comp)
TECH11			    (KitsuuneMasterLensC15,												  VS_FilmGrain_Comp,	    PS_FilmGrain_Comp)


//----------------------------Technique without Ghosts and StarBurst----------------------------//

TECH11			    (KitsuuneMasterLensD  <string UIName="Master Lens - No Ghosts - No Starburst";
										  string RenderTarget="RenderTarget512";>,		  VS_Reflection_Comp,	    PS_Reflection_Comp)
TWOPASSTECH11	    (KitsuuneMasterLensD1 <string RenderTarget="RenderTargetRGBA64F";>,	  VS_Basic_Comp,		    PS_Blank_Comp,
																						  VS_AnamFlarePrePass_Comp, PS_AnamFlarePrePass_Comp)
TECH11			    (KitsuuneMasterLensD2 <string RenderTarget="RenderTarget256";>,		  VS_AnamFlare_Comp,	    PS_AnamFlare_Comp)
TECH11			    (KitsuuneMasterLensD3,												  VS_DirtAndPostPass_Comp,  PS_DirtAndPostPass_Comp[0])
RAINTECH		    (KitsuuneMasterLensD4)
TECH11			    (KitsuuneMasterLensD5 <string RenderTarget="RenderTargetRGBA64F";>,	  VS_RainBlur_Comp,		    PS_RainBlur_Comp)
TECH11			    (KitsuuneMasterLensD6,												  VS_Frost_Comp,		    PS_Frost_Comp)
TECH11			    (KitsuuneMasterLensD7,												  VS_FilmGrain_Comp,	    PS_FilmGrain_Comp)

