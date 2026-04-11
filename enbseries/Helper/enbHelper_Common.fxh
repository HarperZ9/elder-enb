//----------------------------------------------------------------------------------------------//
//																								//
//					   Common helper library by LonelyKitsuune aka Skratzer						//
//								 for ENB (DirectX 11 Shader Model 5)							//
//																								//
//			   Copyright (c) 2019-2020 LonelyKitsuune / T.Thanner - CC BY-NC-ND 4.0				//
//																								//
//----------------------------------------------------------------------------------------------//

//Include debugging helper if needed
//#include "Helper/enbHelper_Debug.fxh"


//----------------------------------------------------------------------------------------------//

//Some useful variable macros
#define LUM_709	float3(0.2125, 0.7154, 0.0721)
#define LUM_601	float3(0.2989, 0.5870, 0.1140)
#define K_LUM	float3(0.25,   0.60,   0.15)
#define ALT_LUM	float3(0.25,   0.50,   0.25)
#define N_LUM	0.333333
#define DELTA	1e-6//1e-8
#define PI		3.1415926535897932384626433832795

//And some useful variables
static const float2 PixelSize = float2(ScreenSize.y, ScreenSize.y * ScreenSize.z);
static const float2 ScreenRes = float2(ScreenSize.x, ScreenSize.x * ScreenSize.w); //(Width,Height)

//Shorter syntax
#define NI nointerpolation


//----------------------------------------------------------------------------------------------//
//Macros for basic technique setups
#define TECH11(NAME, VS, PS) \
technique11 NAME {pass p0 {SetVertexShader(CompileShader(vs_5_0, VS));\
						   SetPixelShader (CompileShader(ps_5_0, PS));}}

#define TWOPASSTECH11(NAME, VS1, PS1, VS2, PS2) \
technique11 NAME {pass p0 {SetVertexShader(CompileShader(vs_5_0, VS1));\
						   SetPixelShader (CompileShader(ps_5_0, PS1));}\
				  pass p1 {SetVertexShader(CompileShader(vs_5_0, VS2));\
						   SetPixelShader (CompileShader(ps_5_0, PS2));}}


//Technique macros for pre-compiled shaders
#define TECH11_COMP(NAME, VS, PS) \
technique11 NAME {pass p0 {SetVertexShader(VS);  SetPixelShader(PS);}}

#define TWOPASSTECH11_COMP(NAME, VS1, PS1, VS2, PS2) \
technique11 NAME {pass p0 {SetVertexShader(VS1); SetPixelShader(PS1);}\
				  pass p1 {SetVertexShader(VS2); SetPixelShader(PS2);}}


//Basic vertex shader and blank pixel shader to clear out rendertargets if needed
void   VS_Basic(inout float4 pos : SV_POSITION, inout float4 txcoord : TEXCOORD0) { pos.w= 1.0; }
float4 PS_Blank(float4 pos : SV_POSITION, float4 txcoord : TEXCOORD0) : SV_Target { return 0.0; }


//----------------------------------------------------------------------------------------------//

//TODIE Separations
float  TODIESep(float  Dawn, float  Sunrise, float  Day, float  Sunset, float  Dusk, float  Night, float  Interior)
{ return lerp(TimeOfDay1.x * Dawn   + TimeOfDay1.y * Sunrise + TimeOfDay1.z * Day +
		      TimeOfDay1.w * Sunset + TimeOfDay2.x * Dusk    + TimeOfDay2.y * Night, Interior, EInteriorFactor); }

float3 TODIESep(float3 Dawn, float3 Sunrise, float3 Day, float3 Sunset, float3 Dusk, float3 Night, float3 Interior)
{ return lerp(TimeOfDay1.x * Dawn   + TimeOfDay1.y * Sunrise + TimeOfDay1.z * Day +
		      TimeOfDay1.w * Sunset + TimeOfDay2.x * Dusk    + TimeOfDay2.y * Night, Interior, EInteriorFactor); }

#define TODIE_SEPARATION(x) TODIESep(Dawn_##x, Sunrise_##x, Day_##x, Sunset_##x, Dusk_##x, Night_##x, Interior_##x)


//TODIE Separations (Dawn and Dusk to Twilight)
float  TODIETLSep(float  Twilight, float  Sunrise, float  Day, float  Sunset, float  Night, float  Interior)
{ return lerp(TimeOfDay1.x * Twilight + TimeOfDay1.y * Sunrise  + TimeOfDay1.z * Day +
		      TimeOfDay1.w * Sunset   + TimeOfDay2.x * Twilight + TimeOfDay2.y * Night, Interior, EInteriorFactor); }

float3 TODIETLSep(float3 Twilight, float3 Sunrise, float3 Day, float3 Sunset, float3 Night, float3 Interior)
{ return lerp(TimeOfDay1.x * Twilight + TimeOfDay1.y * Sunrise  + TimeOfDay1.z * Day +
		      TimeOfDay1.w * Sunset   + TimeOfDay2.x * Twilight + TimeOfDay2.y * Night, Interior, EInteriorFactor); }

#define TODIETL_SEPARATION(x) TODIETLSep(Twilight_##x, Sunrise_##x, Day_##x, Sunset_##x, Night_##x, Interior_##x)


//DNI Separations
float  DNISep(float  Day, float  Night, float  Interior)
{ return lerp(lerp(Night, Day, ENightDayFactor), Interior, EInteriorFactor); }

float3 DNISep(float3 Day, float3 Night, float3 Interior)
{ return lerp(lerp(Night, Day, ENightDayFactor), Interior, EInteriorFactor); }

#define DNI_SEPARATION(x) DNISep(Day_##x, Night_##x, Interior_##x)


//DNIE Separations
float  DNIESep(float  Day, float  Night, float  IDay, float  INight)
{ return lerp(lerp(Night, Day, ENightDayFactor), lerp(INight, IDay, ENightDayFactor), EInteriorFactor); }

float3 DNIESep(float3 Day, float3 Night, float3 IDay, float3 INight)
{ return lerp(lerp(Night, Day, ENightDayFactor), lerp(INight, IDay, ENightDayFactor), EInteriorFactor); }

#define DNIE_SEPARATION(x) DNIESep(Day_##x, Night_##x, InteriorDay_##x, InteriorNight_##x)


//IE Separations
float  IESep(float  Exterior, float  Interior)
{ return lerp(Exterior, Interior, EInteriorFactor); }

float3 IESep(float3 Exterior, float3 Interior)
{ return lerp(Exterior, Interior, EInteriorFactor); }

#define IE_SEPARATION(x) IESep(Exterior_##x, Interior_##x)


//----------------------------------------------------------------------------------------------//
//Various functions

//Returns scaled texcoords for a four-tile texture atlas
float2 AtlasFetch_4(float2 Coord, uint TexSelect)
{ static const float2 TexPos[4] = {0.0,0.0, 0.5,0.0, 0.0,0.5, 0.5,0.5};
  return mad(Coord, 0.5, TexPos[TexSelect-1]); }


//Highpass filter with limiting shoulder
float LimitedHighPass(float x, float Thresh, float Curve, float Shoulder)
{
		x = pow(abs(x / Thresh), Thresh * Curve * 2.0);
		x = min(x, pow(abs(Curve),4) * Shoulder);
		return (x * Shoulder) / (x + Thresh);
}


//Maps x [0,1] to specific range
float MapToRange(float x, float Min, float Max)
{ return x * (Max - Min) + Min; }
//MapToRange(LinearStep(IMin, IMax, x), OMin, OMax);


//Simplified diffraction
float Diffraction(float x, float freq, float phase, float ampli)
{
	float  sinc = PI * (x * freq - phase) + DELTA;
		   sinc = sin(sinc) / sinc;
	return sinc * sinc * ampli;
}


#define INITIALIZE_ARRAY(Array, Size)\
[unroll] for(int i=0; i<Size; i++) Array[i] = 0.0


float GetTempUIVar(int Index)
{
	float TempArray[10] = { tempF1, tempF2, tempF3.xy };
	return TempArray[Index];
}


//----------------------------------------------------------------------------------------------//
//Functions for angle/vector direction manipulation

//Get 2D direction vector (+overload)
float2 GetDirVec(float Deg)
{ float2 Vec; sincos(radians(Deg), Vec.y, Vec.x); return Vec; }

float4 GetDirVec(float2 Deg) //Deg.x -> xy, Deg.y -> zw
{ float4 Vec; sincos(radians(Deg), Vec.yw, Vec.xz); return Vec; }


//Polar/Cartesian transforms (arctangent intrinsics generate tons of instructions, use carefully!)
float2 CartToPolar(float2 CartCoords)
{
	float2 PolarCoords = { length(CartCoords), atan2(CartCoords.y, CartCoords.x) };
		   PolarCoords.y = (PolarCoords.x == 0.0) ? 0.0 : PolarCoords.y;
	return PolarCoords; //[Radius,Theta(Radians)]
}

float2 PolarToCart(float2 PolarCoords)
{
	float2 CartCoords; sincos(PolarCoords.y, CartCoords.y, CartCoords.x);
	return CartCoords * PolarCoords.x;
}


//Simpler and faster rotation function (CCW -> counter clock wise)
float2 MatrixRotate(float2 Coords, float Deg, bool CCW)
{
	float4 RotDir = CCW ? float4(1.0,  1.0, -1.0, 1.0):
						  float4(1.0, -1.0,  1.0, 1.0);
	return mul(float2x2(RotDir * GetDirVec(Deg).xyyx), Coords);
}


//----------------------------------------------------------------------------------------------//
//Scale fullscreen quad through vertex shader (via multiplier or target resolution)

void ScaleScreenQuad_Mult(inout float2 Pos, float2 Scale)
{
	Pos  = Pos * Scale + float2(-1.0, 1.0);
	Pos += float2(Scale.x, -Scale.y);
}

void ScaleScreenQuad_Res(inout float2 Pos, float2 TargetRes)
{ ScaleScreenQuad_Mult(Pos, TargetRes / ScreenRes); }


//----------------------------------------------------------------------------------------------//
//Quick max & min functions

float max2(float2 a)
{ return max(a.x, a.y); }

float min2(float2 a)
{ return min(a.x, a.y); }


float max3(float3 a)
{ return max(a.x, max(a.y, a.z)); }

float min3(float3 a)
{ return min(a.x, min(a.y, a.z)); }


float max4(float4 a)
{ return max(a.x, max(a.y, max(a.z, a.w))); }

float min4(float4 a)
{ return min(a.x, min(a.y, min(a.z, a.w))); }


//----------------------------------------------------------------------------------------------//
//Extract nth root

float  nRoot(float  x, float  n)
{ return pow(abs(x), rcp(n)); }

float2 nRoot(float2 x, float2 n)
{ return pow(abs(x), rcp(n)); }

float3 nRoot(float3 x, float3 n)
{ return pow(abs(x), rcp(n)); }

float4 nRoot(float4 x, float4 n)
{ return pow(abs(x), rcp(n)); }


//nth Root like curve for n>4 and x[0,1]
// -> Can also be used as a faster but very rough nRoot() approximation
float nRootCurve(float x, float n)
{
	float Power    = rcp(n);
	float Inverter = Power + 1.0;
	
	float2 ZeroCorrection;
	ZeroCorrection    = float2(Power, Inverter);
	ZeroCorrection   *= ZeroCorrection;
	ZeroCorrection.x /= ZeroCorrection.y;
	
	return saturate(Inverter - Power * rsqrt(x + ZeroCorrection.x));
}


//----------------------------------------------------------------------------------------------//
//Zero and delta limit macros

#define zerolim(a)  max(a, 0.0)
#define deltalim(a) max(a, DELTA)


//----------------------------------------------------------------------------------------------//
//Color to Chroma functions

float3 ColorToChroma(float3 Color, float3 LumaWeight)
{ return Color / deltalim(dot(Color, LumaWeight)); }

float3 ColorToChroma(float3 Color)
{ return ColorToChroma(Color, N_LUM); }


//----------------------------------------------------------------------------------------------//
//Depth linearization

float LinearDepth(float Depth, float Near, float Far)
{ return (2.0 * Near)/(Far + Near - Depth * (Far - Near)); }

float  FastLinDepth(float  Depth, float Far)
{ return Depth / mad(-Depth, Far, Far + 1.0); }

float2 FastLinDepth(float2 Depth, float Far)
{ return Depth / mad(-Depth, Far, Far + 1.0); }

float3 FastLinDepth(float3 Depth, float Far)
{ return Depth / mad(-Depth, Far, Far + 1.0); }

float4 FastLinDepth(float4 Depth, float Far)
{ return Depth / mad(-Depth, Far, Far + 1.0); }


//----------------------------------------------------------------------------------------------//
//Noise/random number algorithms

//Pseudo Random number generator
float Random(float2 coord)
{ return abs(frac(sin(dot(coord, float2(25.9796, 156.466))) * 43758.5453)); }


//Modified Pseudo-RNG
float4 RandomF4(float4 seed)
{ return abs(frac(sin(seed * float4(25.9796, 156.466, 78.233, 51.9592)) * 43758.5453)); }

float RandomF1(float seed)
{ return abs(frac(sin(seed * 78.233) * 43758.5453)); }


//Pseudo-RNG with gaussian-like distribution
float RandomGauss(float2 Coords)
{
	float4 Noise  = { 0.0, 0.25, 0.5, 0.75 };
		   Noise += dot(Coords, Random(Coords));
	return dot(RandomF4(Noise), 0.25);
}

//ALU noise in Next-gen post processing in COD:AW
float InterleavedGradientNoise(float2 coord)
{ return frac(52.9829189 * frac(dot(coord, float2 (0.06711056, 0.00583715)))); }


//----------------------------------------------------------------------------------------------//
//Additional interpolations and curves

float  LinearStep(float  Low, float  Up, float  x)
{ return saturate((x - Low) / (Up - Low)); }

float2 LinearStep(float2 Low, float2 Up, float2 x)
{ return saturate((x - Low) / (Up - Low)); }

float3 LinearStep(float3 Low, float3 Up, float3 x)
{ return saturate((x - Low) / (Up - Low)); }


//Optimized linearstep for constant input
// -> gets compiled into a single mad_sat instruction
float ConstOptLinStep(uniform float Low, uniform float Up, float x)
{
	const float Denominator = rcp(Up - Low);
	
	float Mul = Denominator;
	float Add = -Low * Denominator;
	
	return saturate(x * Mul + Add);
}


float smootherstep(float Low, float Up, float x)
{
	x = LinearStep(Low, Up, x);
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

//Catmull-Rom
float CatmullRom(float x, float CP1, float CP2, float CP3, float CP4)
{
	float x2 = x*x;
	return		0.5 * ((2.0 * CP2) + (-CP1 + CP3) * x +
		   (2.0 * CP1 - 5.0 * CP2 + 4.0 * CP3 - CP4) * x2 +
		   (     -CP1 + 3.0 * CP2 - 3.0 * CP3 + CP4) * x2 * x);
}

float2 CatmullRom(float2 x, float2 CP1, float2 CP2, float2 CP3, float2 CP4)
{
	float2 x2 = x*x;
	return		0.5 * ((2.0 * CP2) + (-CP1 + CP3) * x +
		   (2.0 * CP1 - 5.0 * CP2 + 4.0 * CP3 - CP4) * x2 +
		   (     -CP1 + 3.0 * CP2 - 3.0 * CP3 + CP4) * x2 * x);
}


//----------------------------------------------------------------------------------------------//
//Conversion from linear RGB to sRGB (gamma space) and vice versa

//Accurate conversions (abs on pow base for numerical safety with negative inputs)
float3 Lin2sRGB(float3 Color)
{ return Color > 0.0031308 ? 1.055 * pow(abs(Color), 1.0/2.4) - 0.055 : 12.92 * Color; }

float3 sRGB2Lin(float3 Color)
{ return Color > 0.04045 ? pow(abs(Color / 1.055 + 0.055 / 1.055), 2.4) : Color / 12.92; }


//Approximation by Ian Taylor
float3 sRGB2Lin_Approx(float3 Color)
{ return Color * (Color * (Color * 0.305306011 + 0.682171111) + 0.012522878); }


//Inaccurate but cheap approximations
float3 Lin2sRGB_Fast(float3 Color)
{ return pow(abs(Color), 1.0/2.2); }

float3 sRGB2Lin_Fast(float3 Color)
{ return pow(abs(Color), 2.2); }


//Fastest but even more inaccurate approximations
//-> Should be avoided for color sensitive work! (e.g. color grading)
float3 Lin2sRGB_Fastest(float3 Color)
{ return sqrt(Color); }

float3 sRGB2Lin_Fastest(float3 Color)
{ return Color * Color; }


//----------------------------------------------------------------------------------------------//
//CIE color space conversions (XYZ, Lab and LCh)


//D65, 2° Observer (normalized to Y = 1.0)
static const float3 TristimulusValues = { 0.95047, 1.0, 1.08883 };

static const float3x3 LinRGB2XYZMat = //D65
{ 0.4124564,  0.3575761,  0.1804375,
  0.2126729,  0.7151522,  0.0721750,
  0.0193339,  0.1191920,  0.9503041 };

static const float3x3 XYZ2LinRGBMat = //D65
{ 3.2404542, -1.5371385, -0.4985314,
 -0.9692660,  1.8760108,  0.0415560,
  0.0556434, -0.2040259,  1.0572252 };


float3 sRGB2XYZ(float3 RGB)
{ return mul(LinRGB2XYZMat, sRGB2Lin(RGB)); }

float3 XYZ2sRGB(float3 XYZ)
{ return Lin2sRGB(mul(XYZ2LinRGBMat, XYZ)); }


float3 XYZ2Lab(float3 XYZ)
{
	XYZ /= TristimulusValues;
	XYZ  = XYZ > 0.008856 ? pow(abs(XYZ), 1.0/3.0) : 7.787037 * XYZ + 16.0/116.0;
	
	float L = 116.0 *  XYZ.y - 16.0; //[0,100]
	float a = 500.0 * (XYZ.x - XYZ.y);
	float b = 200.0 * (XYZ.y - XYZ.z);
	return float3(L, a, b);
}

float3 Lab2XYZ(float3 Lab)
{
	//Lab.yz = clamp(Lab.yz, -128.0, 127.0);
	float3 XYZ;
	XYZ.y = 16.0/116.0 + Lab.x / 116.0;
	XYZ.x = XYZ.y + Lab.y / 500.0;
	XYZ.z = XYZ.y - Lab.z / 200.0;
	
	XYZ  = XYZ > 0.206897 ? pow(abs(XYZ),3) : XYZ / 7.787037 - (16.0/116.0) / 7.787037;
	XYZ *= TristimulusValues;
	return XYZ;
}


float3 Lab2LCh(float3 Lab) //h in radians!
{ return float3(Lab.x, CartToPolar(Lab.yz)); }

float3 LCh2Lab(float3 LCh)
{ return float3(LCh.x, PolarToCart(LCh.yz)); }


float3 sRGB2LCh(float3 RGB)
{ return Lab2LCh(XYZ2Lab(sRGB2XYZ(RGB))); }

float3 LCh2sRGB(float3 LCh)
{ return XYZ2sRGB(Lab2XYZ(LCh2Lab(LCh))); }


//----------------------------------------------------------------------------------------------//
//RGB - HSL/HCV conversion by Ian Taylor

float3 RGB2HCV(float3 RGB)
{
	//Based on work by Sam Hocevar and Emil Persson
	RGB		 = saturate(RGB);
	float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
	float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
	float  C = Q.x - min(Q.w, Q.y);
	float  H = abs((Q.w - Q.y) / (6.0 * C + DELTA) + Q.z);
	return float3(H, C, Q.x);
}

float3 RGB2HSL(float3 RGB)
{
	float3 HCV = RGB2HCV(RGB);
	float  L   = HCV.z - HCV.y * 0.5;
	float  S   = HCV.y / ((1.0 + DELTA) - abs(L * 2.0 - 1.0));
	return float3(HCV.x, S, L);
}

float3 HSL2RGB(float3 HSL)
{
		   HSL = saturate(HSL);
	float3 RGB = saturate(float3(abs(HSL.x * 6.0 - 3.0) - 1.0,
						   2.0 - abs(HSL.x * 6.0 - 2.0),
						   2.0 - abs(HSL.x * 6.0 - 4.0)));
	float C = (1.0 - abs(2.0 * HSL.z - 1.0)) * HSL.y;
	return (RGB - 0.5) * C + HSL.z;
}


//----------------------------------------------------------------------------------------------//
//Alternative Texture filtering modes


//----------------------------------------------------------------------------------------------//
//						    More accurate, manual bilinear filtering							//
//																								//
//										  Reference:											//
//		      https://iquilezles.org/www/articles/hwinterpolation/hwinterpolation.htm			//
//----------------------------------------------------------------------------------------------//

/*float4 Acc_BilinearFilter(Texture2D Tex, float2 Coords)
{
	float2 TexRes;
	Tex.GetDimensions(TexRes.x, TexRes.y);
	
	float2 Step       = Coords * TexRes - 0.5;
	float2 IntCoords  = floor(Step);
	float2 FracCoords = frac (Step);
	
	float4 a = Tex.Sample(Point_Sampler, (IntCoords + float2(0.5, 0.5)) / TexRes);
	float4 b = Tex.Sample(Point_Sampler, (IntCoords + float2(1.5, 0.5)) / TexRes);
	float4 c = Tex.Sample(Point_Sampler, (IntCoords + float2(0.5, 1.5)) / TexRes);
	float4 d = Tex.Sample(Point_Sampler, (IntCoords + float2(1.5, 1.5)) / TexRes);
	
	return lerp(lerp(a, b, FracCoords.x), lerp(c, d, FracCoords.x), FracCoords.y);
}

float4 Acc_BilinearFilter(Texture2D Tex, float2 Coords, uint Level)
{
	float2 TexRes;
	Tex.GetDimensions(TexRes.x, TexRes.y);
	
	float2 Step       = Coords * TexRes - 0.5;
	float2 IntCoords  = floor(Step);
	float2 FracCoords = frac (Step);
	
	float4 a = Tex.SampleLevel(Point_Sampler, (IntCoords + float2(0.5, 0.5)) / TexRes, Level);
	float4 b = Tex.SampleLevel(Point_Sampler, (IntCoords + float2(1.5, 0.5)) / TexRes, Level);
	float4 c = Tex.SampleLevel(Point_Sampler, (IntCoords + float2(0.5, 1.5)) / TexRes, Level);
	float4 d = Tex.SampleLevel(Point_Sampler, (IntCoords + float2(1.5, 1.5)) / TexRes, Level);
	
	return lerp(lerp(a, b, FracCoords.x), lerp(c, d, FracCoords.x), FracCoords.y);
}*/


//----------------------------------------------------------------------------------------------//
//				 B-Spline bicubic filtering function for ENB by kingeric1992					//
//				  http://enbseries.enbdev.com/forum/viewtopic.php?f=7&t=4714					//
//																								//
//										  Reference:											//
//		      https://developer.nvidia.com/gpugems/GPUGems2/gpugems2_chapter20.html				//
//						http://vec3.ca/bicubic-filtering-in-fewer-taps/							//
//----------------------------------------------------------------------------------------------//

float4 BicubicFilter(Texture2D InputTex, float2 texcoord, float2 texsize)
{
	float4 uv;
	uv.xy = texcoord * texsize;
	
	//distant to nearest center    
	float2 center  = floor(uv - 0.5) + 0.5;
	float2 dist1st = uv - center;
	float2 dist2nd = dist1st * dist1st;
	float2 dist3rd = dist2nd * dist1st;
	
	//B-Spline weights
	float2 weight0 =     -dist3rd + 3 * dist2nd - 3 * dist1st + 1;
	float2 weight1 =  3 * dist3rd - 6 * dist2nd               + 4;
	float2 weight2 = -3 * dist3rd + 3 * dist2nd + 3 * dist1st + 1;  
	float2 weight3 =      dist3rd;    
	
	weight0 += weight1;
	weight2 += weight3;
	
	//sample point to utilize bilinear filtering interpolation
	uv.xy  = center - 1 + weight1 / weight0;
	uv.zw  = center + 1 + weight3 / weight2;
	uv    /= texsize.xyxy;
	
	//Sample and blend
	return (weight0.y * (InputTex.Sample(Linear_Sampler, uv.xy) * weight0.x  +
						 InputTex.Sample(Linear_Sampler, uv.zy) * weight2.x) +
			weight2.y * (InputTex.Sample(Linear_Sampler, uv.xw) * weight0.x  +
						 InputTex.Sample(Linear_Sampler, uv.zw) * weight2.x)) / 36;
}

//Use screen resolution as default if texture size isn't provided
float4 BicubicFilter(Texture2D InputTex, float2 texcoord)
{ return BicubicFilter(InputTex, texcoord, ScreenRes); }


//----------------------------------------------------------------------------------------------//
//						     Alternative bicubic filtering function								//
//																								//
//										  Reference:											//
//						     https://www.shadertoy.com/view/lstSRS								//
//----------------------------------------------------------------------------------------------//

/*float4 cubic(float x)
{
	float x2 = x * x;
	float x3 = x2 * x;
	float4 w;
	
	w.x =     -x3 + 3.0*x2 - 3.0*x + 1.0;
	w.y =  3.0*x3 - 6.0*x2         + 4.0;
	w.z = -3.0*x3 + 3.0*x2 + 3.0*x + 1.0;
	w.w =      x3;
	return w / 6.0;
}

float4 BicubicFilter(Texture2D InputTex, float2 texcoord, float2 texsize)
{
	texcoord *= texsize;
	
	float fx = frac(texcoord.x);
	float fy = frac(texcoord.y);
	texcoord.x -= fx;
	texcoord.y -= fy;
	
	float4 xcubic = cubic(fx - 0.5);
	float4 ycubic = cubic(fy - 0.5);
	
	float4 fcubic  = float4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	float4 offset  = texcoord.xxyy + float4(-0.5, 1.5, -0.5, 1.5);
		   offset += xcubic.ywyw / fcubic;
		   offset /= texsize;
	
	float4 sample0 = InputTex.Sample(Linear_Sampler, offset.xz);
	float4 sample1 = InputTex.Sample(Linear_Sampler, offset.yz);
	float4 sample2 = InputTex.Sample(Linear_Sampler, offset.xw);
	float4 sample3 = InputTex.Sample(Linear_Sampler, offset.yw);
	
	float2 interp = fcubic.xz / (fcubic.xz + fcubic.yw);
	
	return lerp(lerp(sample3, sample2, interp.x),
				lerp(sample1, sample0, interp.x), interp.y);
}*/


/*BlendState BlendTest
{ //non-zero backbuffer blending ops
  //behave weird in some DX11 ENB fx files
BlendEnable[0]  =TRUE;
SrcBlend        =SRC_ALPHA; //Current Pixel * pre blend op
DestBlend       =ZERO; //Backbuffer/RT Pixel * pre blend op
BlendOp         =ADD;
};*/

//----------------------------------------------------------------------------------------------//
//										  FIELD STYLE 1											//
//----------------------------------------------------------------------------------------------//

/*‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\
|										  FIELD STYLE 2											|
\______________________________________________________________________________________________*/
