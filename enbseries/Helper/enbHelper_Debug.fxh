//----------------------------------------------------------------------------------------------//
//																								//
//						  Debugging Helper by LonelyKitsuune aka Skratzer						//
//								for ENB (DirectX 11 Shader Model 5)								//
//																								//
//			   Copyright (c) 2019-2020 LonelyKitsuune / T.Thanner - CC BY-NC-ND 4.0				//
//																								//
//----------------------------------------------------------------------------------------------//


#ifndef _KITSUUNE_DEBUG_
#define _KITSUUNE_DEBUG_


//------------------------------------Number Display Function-----------------------------------//

//PIXELSHADER IMPLEMENTATION:
//		Debug_DrawNumberMix      (Color.rgb, IN.texcoord, Number, Position, Size, Precision);
//		Debug_DrawFloat4_TopRight(Color.rgb, IN.texcoord, Number,                 Precision);
//
//		-> Precision = Maximum length of fractional part [0-7]

//Character texture
Texture2D CharTex <string ResourceName="Textures/CharTexture.png";>;
static const float2 CharTexTileSize = 1.0 / float2(14.0, 7.0);

//Denominators for fraction parts
#define MAX_PRECISION 8
static const uint DigitPosDenom[MAX_PRECISION] =
{ 1, 1e+1, 1e+2, 1e+3, 1e+4, 1e+5, 1e+6, 1e+7 };


//I need to redesign this entire function at some point
//Not very proudy of this spaghetti code... it works for debugging tho
float Debug_DrawNumber(float2 Coords, float Number, float2 Position, float2 Size, float Precision)
{
	float AbsNum		 = abs(Number);
	float PredCount  = ceil(log10(max(AbsNum + AbsNum * 5e-7, 1.0 + 1e-6)));
		  Precision  = round(clamp(Precision + 1.0, 0.0, MAX_PRECISION - PredCount));
	float DigitCount = 2.0 + Precision;
	
	Size   *= float2(ScreenSize.z, 0.75);
	Size.x += (Precision - MAX_PRECISION + PredCount) * ScreenSize.z * 0.01;
	
	float  CurrentDigit;
	float2 CurrentPos   = (Coords - Position) / Size;
		   CurrentPos.x = modf(CurrentPos.x * (DigitCount + PredCount), CurrentDigit);
	
		   PredCount      -= 1.0;
	float  CurrentDigitPos = CurrentDigit - PredCount;
	float2 Offset;
	
	[branch] if(CurrentDigit == 0.0) //sign
		Offset = (Number < 0.0) * float2(13.0, 0.0);
	
	else if(CurrentDigitPos == 2.0) //dot
		Offset = float2(0.0, 1.0);
	
	else if(CurrentDigitPos > 2.0) //decimal
	{
		int   DenomIndex = DigitCount - (CurrentDigit - (MAX_PRECISION - Precision));
		uint2 Digit      = { DigitPosDenom[DenomIndex-1], DigitPosDenom[DenomIndex] };
		
		//Integer math to avoid float precision errors
		Digit = (uint2)round(AbsNum * pow(0.1, PredCount) * 1e+7) / Digit;
		Digit.x -= Digit.y * 10;
		
		Offset = float2(Digit.x + 2.0, 1.0);
	}
	else //predecimal
	{
		float2 Digit = PredCount + float2(1.0, 2.0) - CurrentDigit;
		
		Digit = trunc(trunc(AbsNum) * pow(0.1, Digit));
		Digit.x -= Digit.y * 10.0;
		
		Offset = float2(Digit.x + 2.0, 1.0);
	}
	
	float Deriv = saturate(1.0 - fwidth(CurrentPos.x));
	Deriv *= all(Position < Coords && Coords < (Position + Size));
	
	CurrentPos = (CurrentPos + Offset) * CharTexTileSize;
	return CharTex.Sample(Linear_Sampler, CurrentPos).r * Deriv;
}


void Debug_DrawNumberMix(inout float3 Color, float2 Coords, float Number, float2 Position, float2 Size, float Precision)
{ float Temp = Debug_DrawNumber(Coords, Number, Position, Size, Precision); Color += Temp * (Temp - Color); }

void Debug_DrawFloat4_TopRight(inout float3 Color, float2 Coords, float4 Number, float Precision)
{
	Debug_DrawNumberMix(Color, Coords, Number.x, float2(0.8, 0.0), 0.1, Precision);
	Debug_DrawNumberMix(Color, Coords, Number.y, float2(0.8, 0.1), 0.1, Precision);
	Debug_DrawNumberMix(Color, Coords, Number.z, float2(0.8, 0.2), 0.1, Precision);
	Debug_DrawNumberMix(Color, Coords, Number.w, float2(0.8, 0.3), 0.1, Precision);
}

//Alternative mixing mode (negative color)
void Debug_DrawNumberMix_Neg(inout float3 Color, float2 Coords, float Number, float2 Position, float2 Size, float Precision)
{ Color = lerp(Color, saturate(1.0 - Color), Debug_DrawNumber(Coords, Number, Position, Size, Precision)); }

void Debug_DrawFloat4_TopRight_Neg(inout float3 Color, float2 Coords, float4 Number, float Precision)
{
	Debug_DrawNumberMix_Neg(Color, Coords, Number.x, float2(0.8, 0.0), 0.1, Precision);
	Debug_DrawNumberMix_Neg(Color, Coords, Number.y, float2(0.8, 0.1), 0.1, Precision);
	Debug_DrawNumberMix_Neg(Color, Coords, Number.z, float2(0.8, 0.2), 0.1, Precision);
	Debug_DrawNumberMix_Neg(Color, Coords, Number.w, float2(0.8, 0.3), 0.1, Precision);
}

#endif //_KITSUUNE_DEBUG_








