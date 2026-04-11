//----------------------------------------------------------------------------------------------//
//																								//
//								  Main ENB Bloom UI file										//
//						      by LonelyKitsuune aka Skratzer									//
//																								//
//----------------------------------------------------------------------------------------------//

//This file requires my UI Primer header to work!
#ifndef _UI_PRIMER_
#error UI_Primer couldnt be found!
#endif

//----------------------------------------------------------------------------------------------//
//								  User Interface Parameters										//
//																								//
//----------------------------------------------------------------------------------------------//


#if SHADERGROUP == 0

UI_FileHeaderLong(">>>      Dynamic Bloom 2.2 for ENB       <<<",
				  ">>>              by LonelyKitsuune              <<<")

#if ENABLE_TOOLS
UI_WHITESPACE(1)
UI_ELEMENT(_Tools_Header,"               >>>>>>TOOLS<<<<<<")
UI_WHITESPACE(2)
int  UI_PASSOUTPUT		<string UIName="Show Pass Output"; int UIMin=0; int UIMax=7;> = {0};
#if ENABLE_DEPTH_TESTING
bool UI_Visualize_Depth <string UIName="Visualize Depth";> = {false};
#endif //ENABLE_DEPTH_TESTING
UI_WHITESPACE(3)
#endif //ENABLE_TOOLS

//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 1

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(_Prepass_Header,"             >>>>>>PREPASS<<<<<<")
UI_WHITESPACE(4)
#if BLOOM_PREPASS_STYLE == 2
bool UI_Smooth_Threshold <string UIName="|---- Use Smooth Threshold"; > = {true};
UI_SPECIAL_WHITESPACE(1)
#endif //BLOOM_PREPASS_STYLE
#endif //NOTFIRSTTIME

#if BLOOM_PREPASS_STYLE == 1
float SEPARATE_VAR(UI_InBlack)			<string UIName=TO_STRING(|- TODIE - In Black);			float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {0.0};
float SEPARATE_VAR(UI_InWhite)			<string UIName=TO_STRING(|- TODIE - In White);			float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {1.0};
float SEPARATE_VAR(UI_OutBlack)			<string UIName=TO_STRING(|- TODIE - Out Black);			float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {0.0};
float SEPARATE_VAR(UI_OutWhite)			<string UIName=TO_STRING(|- TODIE - Out White);			float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {1.0};
float SEPARATE_VAR(UI_Saturation)		<string UIName=TO_STRING(|- TODIE - Saturation);		float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {1.0};
#elif BLOOM_PREPASS_STYLE == 2
float SEPARATE_VAR(UI_Brightness)		<string UIName=TO_STRING(|- TODIE - Brightness);		float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {1.0};
float SEPARATE_VAR(UI_Contrast)			<string UIName=TO_STRING(|- TODIE - Contrast);			float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {1.0};
float SEPARATE_VAR(UI_Saturation)		<string UIName=TO_STRING(|- TODIE - Saturation);		float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {1.0};
float SEPARATE_VAR(UI_ThresholdLower)	<string UIName=TO_STRING(|- TODIE - Lower Threshold);	float UIMin=0.0; float UIMax=10.0; float UIStep=0.0001; > = {0.0};
float SEPARATE_VAR(UI_ThresholdUpper)	<string UIName=TO_STRING(|- TODIE - Upper Threshold);	float UIMin=0.0; float UIMax=10.0; float UIStep=0.0001; > = {1.0};
#endif //BLOOM_PREPASS_STYLE

#if ENABLE_SKIN_ATTENUATION
float SEPARATE_VAR(UI_SkinAttenu)		<string UIName=TO_STRING(|- TODIE - Skin Attenuation);	float UIMin=0.0; float UIMax=10.0; float UIStep=0.001;  > = {1.0};
#endif


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 2

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(_Main_Header,"               >>>>>>BLOOM<<<<<<")
UI_WHITESPACE(5)
int UI_Quality <string UIName="|---- Bloom Quality"; string UIWidget="Quality"; > = {0};
UI_SPECIAL_WHITESPACE(2)
#endif //NOTFIRSTTIME

float  SEPARATE_VAR(UI_Sigma)				  <string UIName=TO_STRING(|- TODIE - Bloom Sigma (Width));				float UIMin=0.5; float UIMax=20.0; float UIStep=0.001; > = {3.0};
float  SEPARATE_VAR(UI_HoriIntensity)		  <string UIName=TO_STRING(|- TODIE - Bloom Intensity Horizontal);		float UIMin=0.0; float UIMax=10.0; float UIStep=0.001; > = {1.0};
float  SEPARATE_VAR(UI_VertIntensity)		  <string UIName=TO_STRING(|- TODIE - Bloom Intensity Vertical);		float UIMin=0.0; float UIMax=10.0; float UIStep=0.001; > = {1.0};


#ifdef LASTTIME
#if ENABLE_DEPTH_TESTING
UI_SPECIAL_WHITESPACE(3)
UI_SPECIAL_WHITESPACE(4)
bool  UI_Depth_Calc		  <string UIName="|---- Exterior - Activate Depth Testing";														  > = {false};
bool  UI_DepthInvert	  <string UIName="|- Exterior - Invert Depth";																	  > = {false};
float UI_FarDepth		  <string UIName="|- Exterior - Depthfade";				float UIMin=0.0; float UIMax=5000.0; float UIStep=1.0;   > = {3500.0};
float UI_DepthWidth		  <string UIName="|- Exterior - Bloom Depth Width";		float UIMin=0.0; float UIMax=2.0;    float UIStep=0.001; > = {0.5};
float UI_DepthInt		  <string UIName="|- Exterior - Bloom Depth Intensity";	float UIMin=0.0; float UIMax=2.0;    float UIStep=0.001; > = {0.2};
#endif //ENABLE_DEPTH_TESTING
#undef LASTTIME
#endif //LASTTIME


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 3

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(_Mix_Header,"            >>>>>>BLOOM MIX<<<<<<")
UI_WHITESPACE(6)
bool  UI_Normalize_BloomSum		  <string UIName="|---- Normalize Bloom after Mixing";					    > = {true};

#if ENABLE_TINYBLOOM
bool  UI_TinyBloom				  <string UIName="|---- Enable TinyBloom";								    > = {true};
#endif //ENABLE_TINYBLOOM

#if ENABLE_SOURCE_MASKING
UI_SPECIAL_WHITESPACE(34)
bool  UI_Mask_BloomSource		  <string UIName="|---- Mask Bloom Source";								    > = {false};
float UI_Mask_Weight			  <string UIName="|- Masking Strength";   float UIMin=0.0; float UIMax=1.0; > = {1.0};
#endif //ENABLE_SOURCE_MASKING

#if ENABLE_BLOOM_GRAIN
UI_SPECIAL_WHITESPACE(35)
bool  UI_Enable_Grain			  <string UIName="|---- Enable Grain";									    > = {false};
float UI_GrainIntensity			  <string UIName="|- Grain Intensity";	  float UIMin=0.0; float UIMax=1.0; > = {0.2};
float UI_GrainSaturation		  <string UIName="|- Grain Saturation";   float UIMin=0.0; float UIMax=3.0; > = {0.0};
float UI_GrainMotion			  <string UIName="|- Grain Motion";		  float UIMin=0.0; float UIMax=0.5; > = {0.2};
#endif //ENABLE_BLOOM_GRAIN

#if ENABLE_DIRT_REFLECTION
UI_SPECIAL_WHITESPACE(36)
bool  UI_EnableDirtRef			  <string UIName="|---- Enable Dirt Reflection";								    > = {false};
float UI_DirtRef				  <string UIName="|- Dirt Reflection";			 float UIMin=0.0; float UIMax=10.0; > = {0.8};
float UI_DirtRefThresh			  <string UIName="|- Dirt Reflection Threshold"; float UIMin=0.0; float UIMax=10.0; > = {1.5};
float UI_DirtRefCurve			  <string UIName="|- Dirt Reflection Curve";	 float UIMin=0.1; float UIMax=10.0; > = {1.5};
int   UI_DirtSelect				  <string UIName="|- Select Dirt Texture";		 int   UIMin=1;   int   UIMax=4;    > = {1};
#endif //ENABLE_DIRT_REFLECTION

UI_SPECIAL_WHITESPACE(6)
#endif //NOTFIRSTTIME

#if ENABLE_AUTOMATIC_WEIGHTING
float SEPARATE_VAR(UI_AutoWeight_Bias)			<string UIName=TO_STRING(|- AutoWeighting Bias TODIE);   float UIMin=0.1; float UIMax=20.0; float UIStep=0.01; > = {3.0};
#else
float SEPARATE_VAR(UI_RenderTargetStrength1024) <string UIName=TO_STRING(|- TODIE - 1024 Pass Strength); float UIMin=0.0; float UIMax=10.0; float UIStep=0.01; > = {1.0};
float SEPARATE_VAR(UI_RenderTargetStrength512)  <string UIName=TO_STRING(|- TODIE - 512 Pass Strength);  float UIMin=0.0; float UIMax=10.0; float UIStep=0.01; > = {1.0};
float SEPARATE_VAR(UI_RenderTargetStrength256)  <string UIName=TO_STRING(|- TODIE - 256 Pass Strength);  float UIMin=0.0; float UIMax=10.0; float UIStep=0.01; > = {1.0};
float SEPARATE_VAR(UI_RenderTargetStrength128)  <string UIName=TO_STRING(|- TODIE - 128 Pass Strength);  float UIMin=0.0; float UIMax=10.0; float UIStep=0.01; > = {1.0};
float SEPARATE_VAR(UI_RenderTargetStrength64)   <string UIName=TO_STRING(|- TODIE - 64 Pass Strength);   float UIMin=0.0; float UIMax=10.0; float UIStep=0.01; > = {1.0};
float SEPARATE_VAR(UI_RenderTargetStrength32)   <string UIName=TO_STRING(|- TODIE - 32 Pass Strength);   float UIMin=0.0; float UIMax=10.0; float UIStep=0.01; > = {1.0};
float SEPARATE_VAR(UI_RenderTargetStrength16)   <string UIName=TO_STRING(|- TODIE - 16 Pass Strength);   float UIMin=0.0; float UIMax=10.0; float UIStep=0.01; > = {1.0};
#endif

#if ENBALE_BLOOM_TINTING
UI_SPECIAL_WHITESPACE(SWSN)
float3 SEPARATE_VAR(UI_RenderTargetTint1024) <string UIName=TO_STRING(|- TODIE - 1024 Pass Tint); string UIWidget="Color"; > = {1.0,1.0,1.0};
float3 SEPARATE_VAR(UI_RenderTargetTint512)  <string UIName=TO_STRING(|- TODIE - 512 Pass Tint);  string UIWidget="Color"; > = {1.0,1.0,1.0};
float3 SEPARATE_VAR(UI_RenderTargetTint256)  <string UIName=TO_STRING(|- TODIE - 256 Pass Tint);  string UIWidget="Color"; > = {1.0,1.0,1.0};
float3 SEPARATE_VAR(UI_RenderTargetTint128)  <string UIName=TO_STRING(|- TODIE - 128 Pass Tint);  string UIWidget="Color"; > = {1.0,1.0,1.0};
float3 SEPARATE_VAR(UI_RenderTargetTint64)   <string UIName=TO_STRING(|- TODIE - 64 Pass Tint);   string UIWidget="Color"; > = {1.0,1.0,1.0};
float3 SEPARATE_VAR(UI_RenderTargetTint32)   <string UIName=TO_STRING(|- TODIE - 32 Pass Tint);   string UIWidget="Color"; > = {1.0,1.0,1.0};
float3 SEPARATE_VAR(UI_RenderTargetTint16)   <string UIName=TO_STRING(|- TODIE - 16 Pass Tint);   string UIWidget="Color"; > = {1.0,1.0,1.0};
#endif //ENBALE_BLOOM_TINTING


#endif //SHADERGROUP

#undef TODIE










