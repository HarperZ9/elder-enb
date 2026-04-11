//----------------------------------------------------------------------------------------------//
//																								//
//					   enbunderwater.fx file by LonelyKitsuune aka Skratzer						//
//						       for ENB (DirectX 11 Shader Model 5)								//
//																								//
//			   Copyright (c) 2019-2020 LonelyKitsuune / T.Thanner - CC BY-NC-ND 4.0				//
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
//Applies a small blur to the depth data before
//using it to reduce harsh/alialised edges
#define ENABLE_DEPTH_PRE_BLUR						1		//[0-1]


//Use bicubic filtering to upscale the scene
//-> Enable this option if you use heavy lens distortion settings
#define USE_BICUBIC_LENS_DISTORTION_UPSCALING		0		//[0-1]



//----------------------------------------------------------------------------------------------//
//										Internal Parameters										//
//----------------------------------------------------------------------------------------------//

#include "UI/enbUI_Primer.fxh"

UI_FileHeaderLong(">>>   ENB Underwater Shader for SSE   <<<",
				  ">>>              by LonelyKitsuune              <<<")

UI_WHITESPACE(1)
UI_ELEMENT(UIB_Header,					"            >>>>>>DEPTH BLUR<<<<<<")
UI_WHITESPACE(2)
float UIB_DepthCurve	 <string UIName="|- Blur - Depth Curve";							    float UIMin= 0.0; float UIMax=20.0; > = { 0.4};
float UIB_MaxAmount		 <string UIName="|- Blur - Max Amount";								    float UIMin= 0.0; float UIMax=20.0; > = { 6.0};
float UIB_EdgeBleedReduc <string UIName="|- Blur - Edge Bleeding Reduction";				    float UIMin= 0.0; float UIMax= 1.0; > = { 0.7};
int   UIB_Quality		 <string UIName="|- Blur - Quality";		 string UIWidget="Quality"; int   UIMin=   0; int   UIMax=   2; > = {   1};
float UIB_AnimSpeed		 <string UIName="|- Blur - Animation Speed";						    float UIMin= 0.0; float UIMax= 4.0; > = { 0.7};
float UIB_AnimWeight	 <string UIName="|- Blur - Animation Weight";						    float UIMin= 0.0; float UIMax= 1.0; > = { 0.8};

UI_WHITESPACE(3)
UI_WHITESPACE(4)
UI_ELEMENT(UIW_Header,					"      >>>>>>WAVE DISTORTION<<<<<<")
UI_WHITESPACE(5)
float UIW_DepthCurve	 <string UIName="|- WD - Depth Curve";							    float UIMin= 0.0; float UIMax=20.0; > = { 0.4};
float UIW_Amount		 <string UIName="|- WD - Distortion Amount";					    float UIMin= 0.0; float UIMax= 3.0; > = { 0.5};
float UIW_Dispersion	 <string UIName="|- WD - Dispersion Amount";					    float UIMin=-1.0; float UIMax= 1.0; > = { 0.1};
float UIW_AnimSpeed		 <string UIName="|- WD - Animation Speed";						    float UIMin= 0.0; float UIMax= 4.0; > = { 0.7};

UI_WHITESPACE(6)
UI_WHITESPACE(7)
UI_ELEMENT(UID_Header,					"      >>>>>>LENS DISTORTION<<<<<<")
UI_WHITESPACE(8)
float UID_Curve			 <string UIName="|- LD - Lens Curve";							    float UIMin= 1.5; float UIMax=10.0; > = { 4.0};
float UID_Amount		 <string UIName="|- LD - Distortion Amount";					    float UIMin=-1.0; float UIMax= 1.0; > = {-0.1};
float UID_Chroma		 <string UIName="|- LD - Chromatic Distortion"; float UIStep=0.001; float UIMin= 0.0; float UIMax= 1.0; > = {0.01};



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

Texture2D TextureOriginal;		//color R10B10G10A2 32 bit ldr format
Texture2D TextureColor;			//color which is output of previous technique (except when drawed to temporary render target), R10B10G10A2 32 bit ldr format
Texture2D TextureDepth;			//scene depth R32F 32 bit hdr format
Texture2D TextureMask;			//Mask of underwater area on the screen

//temporary textures which can be set as render target for techniques via annotations like <string RenderTarget="RenderTargetRGBA32";>
Texture2D RenderTargetRGBA32; 	//R8G8B8A8 32 bit ldr format
Texture2D RenderTargetRGBA64; 	//R16B16G16A16 64 bit ldr format
Texture2D RenderTargetRGBA64F; 	//R16B16G16A16F 64 bit hdr format
Texture2D RenderTargetR16F; 	//R16F 16 bit hdr format with red channel only
Texture2D RenderTargetR32F; 	//R32F 32 bit hdr format with red channel only
Texture2D RenderTargetRGB32F; 	//32 bit hdr format without alpha

float4 TintColor;				//xyz - tint color, w - tint amount

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

//Helper with some useful macros, variables and functions
#include "Helper/enbHelper_Common.fxh"


//----------------------------------------------------------------------------------------------//

//Changes the way out of bound samples get treated
//when using heavy lens distortion settings
// 0 - Clamp at borders (default)
// 1 - Passthrough of non distorted screen
// 2 - Fill with water tint (recommended)
#define FILLING_METHOD 2 //[0-2]


//----------------------------------------------------------------------------------------------//

SamplerState Linear_Sampler_Noise
{
		Filter = MIN_MAG_MIP_LINEAR;
		AddressU = Wrap;
		AddressV = Wrap;
};

Texture2D UnderwaterNoiseTex <string ResourceName="Textures/UnderwaterNoise.png";>;

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


//----------------------------------------------------------------------------------------------//
//								     Functions and Variables									//
//																								//
//----------------------------------------------------------------------------------------------//

static const float BlurQuality[3] = { 1.9, 1.5, 1.2 };
static const float SqrtTwoPI      = sqrt(2.0 * PI);

float SampleUnderwaterMask(float2 Coords)
{ return TextureMask.Sample(Point_Sampler, Coords).x; }

float GetAnimatedNoise(float2 Coords, float AnimSpeed, float TOffset)
{
	float2 NoiseCoords = Coords + frac((Timer.x + TOffset) * 16777.21 * AnimSpeed);
	return UnderwaterNoiseTex.Sample(Linear_Sampler_Noise, NoiseCoords).x;
}

float2 GetAnimatedNoiseVec(float2 Coords, float AnimSpeed, float TOffset)
{
	float2 NoiseCoords = Coords + frac((Timer.x + TOffset) * 16777.21 * AnimSpeed);
	return float2(UnderwaterNoiseTex.Sample(Linear_Sampler_Noise,       NoiseCoords).x,
				  UnderwaterNoiseTex.Sample(Linear_Sampler_Noise, 1.0 - NoiseCoords).x);
}


//----------------------------------------------------------------------------------------------//
//										      Shaders											//
//																								//
//----------------------------------------------------------------------------------------------//

VertexShaderOutput VS_Draw(VertexShaderInput IN)
{
	VertexShaderOutput OUT;
	OUT.pos      = float4(IN.pos.xyz, 1.0);
	OUT.texcoord = IN.txcoord.xy;
	
	return OUT;
}


float4 PS_WaveDistortion(VertexShaderOutput IN) : SV_Target
{
	float CenterDepth = FastLinDepth(TextureDepth.Sample(Point_Sampler, IN.texcoord).x, 200.0);
	float DistAmount  = pow(CenterDepth, UIW_DepthCurve);
		  DistAmount *= UIW_Amount * 0.1 * SampleUnderwaterMask(IN.texcoord);
	
	float2 DistVec    = GetAnimatedNoiseVec(IN.texcoord, 0.1 * UIW_AnimSpeed, 0.5);
		   DistVec    = (DistVec * 2.0 - 1.0) * DistAmount;
	float2 DistCoords = IN.texcoord + DistVec;
	
	float4 CenterColor = { TextureColor.Sample(Point_Sampler, IN.texcoord).rgb, CenterDepth };
	
	float4 Color;
	Color.r = TextureColor.Sample(Linear_Sampler, DistCoords + DistVec * UIW_Dispersion).r;
	Color.g = TextureColor.Sample(Linear_Sampler, DistCoords).g;
	Color.b = TextureColor.Sample(Linear_Sampler, DistCoords - DistVec * UIW_Dispersion).b;
	
	float DistDepth  = FastLinDepth(TextureDepth.Sample(Point_Sampler, DistCoords).x, 200.0);
	float DepthDelta = saturate((CenterDepth - DistDepth) * 100.0);
		  Color.w    = DistDepth;
	
	Color     = lerp(Color, CenterColor, DepthDelta);
	Color.rgb = sRGB2Lin(Color.rgb);
	
	return Color;
}


float PS_DrawBlurMask(VertexShaderOutput IN) : SV_Target
{
	#if ENABLE_DEPTH_PRE_BLUR
		static const float2 offsets[4] = { float2( 0.5, 0.5) * PixelSize,
										   float2(-0.5, 0.5) * PixelSize,
										   float2(-0.5,-0.5) * PixelSize,
										   float2( 0.5,-0.5) * PixelSize };
		
		float Depth = 0.0;
		
		[unroll] for(int i=0; i<4; i++)
			Depth += RenderTargetRGBA64.SampleLevel(Linear_Sampler, IN.texcoord + offsets[i],0).w;
		Depth /= 4.0;
	#else
		float Depth = RenderTargetRGBA64.Sample(Point_Sampler, IN.texcoord).w;
	#endif
	
	float Mask = SampleUnderwaterMask(IN.texcoord) * pow(Depth, UIB_DepthCurve);
	
	float Noise = GetAnimatedNoise(IN.texcoord, 0.1 * UIB_AnimSpeed, 0.0);
		  Mask *= lerp(1.0, Noise, UIB_AnimWeight);
	
	return Mask;
}


float4 PS_GaussBlur(VertexShaderOutput IN, uniform float2 Axis, uniform Texture2D InputTex) : SV_Target
{
	float  Mask  = RenderTargetR16F.Sample(Point_Sampler, IN.texcoord).x;
	float3 Color = InputTex.Sample(Point_Sampler, IN.texcoord);
	
	float Sigma       = UIB_MaxAmount * Mask + DELTA;
	float OffsetScale = 1.0 - sqrt(saturate(Sigma / 3.0)) * 0.5;
	
	float4 StepSize     = PixelSize.xyxy * float4(Axis, -Axis);
	float4 HalfStepSize = StepSize * OffsetScale;
		   StepSize    *= 2.0;
	
	float WeightFactor =  rcp(Sigma * SqrtTwoPI);
	float LoopCount    = ceil(Sigma * BlurQuality[UIB_Quality] - 0.01);
		  Sigma        =  rcp(Sigma * Sigma);
	
	float  WeightSum  = WeightFactor * OffsetScale;
	float3 BlurredCol = WeightSum * Color;
		   Mask      *= UIB_EdgeBleedReduc;
	
	[loop] for(float i=1.0; i <= LoopCount; i++)
	{
		float  GaussWeight = WeightFactor * exp(i*i*-Sigma);
		float4 CurrOffset  = IN.texcoord.xyxy + i * StepSize - HalfStepSize;
		
		float2 FinalWeights = { RenderTargetR16F.SampleLevel(Linear_Sampler, CurrOffset.xy,0).x,
								RenderTargetR16F.SampleLevel(Linear_Sampler, CurrOffset.zw,0).x };
			   FinalWeights = saturate(1.0 - (Mask - FinalWeights * UIB_EdgeBleedReduc) * i) * GaussWeight;
		
		BlurredCol += FinalWeights.x * InputTex.SampleLevel(Linear_Sampler, CurrOffset.xy,0).rgb;
		BlurredCol += FinalWeights.y * InputTex.SampleLevel(Linear_Sampler, CurrOffset.zw,0).rgb;
		WeightSum  += FinalWeights.x + FinalWeights.y;
	}
	
	Color = BlurredCol / WeightSum;
	if(Axis.x == 0.0) Color = Lin2sRGB(Color);
	
	return float4(Color, 1.0);
}


float4 PS_LensDistortion(VertexShaderOutput IN) : SV_Target
{
	float MaskedDistAmount = UID_Amount * SampleUnderwaterMask(IN.texcoord);
	
	float2 DistortVec  = IN.texcoord * 2.0 - 1.0;
	float  DistortGrad = length(DistortVec);
		   DistortVec /= float2(1.0, ScreenSize.z);
	
	float DistortShift = pow(DistortGrad / 1.15, UID_Curve);
		  DistortVec  *= DistortShift * MaskedDistAmount / DistortGrad;
	
	float2 DistortCoords    = DistortVec + IN.texcoord;
	float2 CorrectionZoom   = saturate(abs(MaskedDistAmount)) * float2(3.0, 1.0) + 1.0;
		   CorrectionZoom.x = (MaskedDistAmount > 0.0) ? CorrectionZoom.x : CorrectionZoom.y;
		   DistortCoords    = (DistortCoords - 0.5) / CorrectionZoom.x + 0.5;
	
	#if FILLING_METHOD != 0
		bool OutOfBounds = !all(saturate(DistortCoords - DistortCoords * DistortCoords));
	#endif
	#if FILLING_METHOD == 1
		DistortCoords = OutOfBounds ? IN.texcoord : DistortCoords;
	#endif
	
	float3 Color;
	
	#if USE_BICUBIC_LENS_DISTORTION_UPSCALING
		Color.r = BicubicFilter(TextureColor, DistortCoords + DistortVec * UID_Chroma).r;
		Color.g = BicubicFilter(TextureColor, DistortCoords).g;
		Color.b = BicubicFilter(TextureColor, DistortCoords - DistortVec * UID_Chroma).b;
	#else
		Color.r = TextureColor.Sample(Linear_Sampler, DistortCoords + DistortVec * UID_Chroma).r;
		Color.g = TextureColor.Sample(Linear_Sampler, DistortCoords).g;
		Color.b = TextureColor.Sample(Linear_Sampler, DistortCoords - DistortVec * UID_Chroma).b;
	#endif
	
	#if FILLING_METHOD == 2
		Color = OutOfBounds ? TintColor.rgb * TintColor.w : Color;
	#endif
	
	return float4(Color, 1.0);
}


//----------------------------------------------------------------------------------------------//
//										    Techniques											//
//																								//
//----------------------------------------------------------------------------------------------//

TECH11(Underwater  <string UIName="Underwater - Kitsuune";
				    string RenderTarget="RenderTargetRGBA64";>, VS_Draw(), PS_WaveDistortion())
TECH11(Underwater1 <string RenderTarget="RenderTargetR16F";>,	VS_Draw(), PS_DrawBlurMask())
TECH11(Underwater2,												VS_Draw(), PS_GaussBlur(float2(1,0), RenderTargetRGBA64))
TECH11(Underwater3,												VS_Draw(), PS_GaussBlur(float2(0,1), TextureColor))
TECH11(Underwater4,												VS_Draw(), PS_LensDistortion())



