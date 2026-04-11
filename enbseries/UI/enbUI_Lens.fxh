//----------------------------------------------------------------------------------------------//
//																								//
//								  Main ENB Lens UI file											//
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

UI_FileHeaderLong(">>>            ENB Master Lens 4.0            <<<",
				  ">>>              by LonelyKitsuune              <<<")
UI_WHITESPACE(1)


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(2)
UI_ELEMENT(ML_Features,"      >>>>>>LENS FEATURE-SET<<<<<<")
UI_WHITESPACE(3)
UI_ELEMENT(ML_TechNote1,		 "|         Toggle Ghosts and Starburst")
UI_ELEMENT(ML_TechNote2,		 "|        Lensflares through TECHNIQUE")
UI_SPECIAL_WHITESPACE(1)
#ifdef ENABLE_WEATHERFX_SHADERS
bool UIWFXRain_Enable  <string UIName="|- Enable Weather FX - Rain";	  > = {false};
bool UIWFXFrost_Enable <string UIName="|- Enable Weather FX - Frost";	  > = {false};
#endif
bool UIAF_Enable       <string UIName="|- Enable Anamorphic Lens Flares"; > = {false};
bool UIR_Enable        <string UIName="|- Enable Lens Reflections";		  > = {false};
bool UID_Enable        <string UIName="|- Enable Lens Dirt";			  > = {false};
bool UICA_Enable       <string UIName="|- Enable Chromatic Aberration";   > = {false};
bool UIFG_Enable       <string UIName="|- Enable Film Grain";             > = {false};
bool UI_IgnoreSky      <string UIName="|- Lensflares ignore Sun/Sky";	  > = {false};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 1

UI_ELEMENT(ML_WeatherFX,"      >>>>>>WEATHER EFFECTS<<<<<<")
UI_WHITESPACE(4)
float  Day_UIWFXRain_Intensity	  <string UIName="|- RainFX - Day - Intensity";			   float UIMin=0.0;  float UIMax=10.0; float UIStep=0.01; > = {1.0};
float4 Day_UIWFXRain_SkyColor	  <string UIName="|- RainFX - Day - Sky Color";			   string UIWidget="Color";								  > = {1.0, 1.0, 1.0, 1.0};
float4 Day_UIWFXRain_EnvColor	  <string UIName="|- RainFX - Day - Environment Color";    string UIWidget="Color";								  > = {0.3, 0.3, 0.3, 1.0};
float  Night_UIWFXRain_Intensity  <string UIName="|- RainFX - Night - Intensity";		   float UIMin=0.0;  float UIMax=10.0; float UIStep=0.01; > = {1.0};
float4 Night_UIWFXRain_SkyColor	  <string UIName="|- RainFX - Night - Sky Color";		   string UIWidget="Color";								  > = {1.0, 1.0, 1.0, 1.0};
float4 Night_UIWFXRain_EnvColor   <string UIName="|- RainFX - Night - Environment Color";  string UIWidget="Color";								  > = {0.3, 0.3, 0.3, 1.0};
UI_SPECIAL_WHITESPACE(2)
float  Day_UIWFXFrost_Intensity   <string UIName="|- FrostFX - Day - Intensity";		   float UIMin=0.0;  float UIMax=5.0;  float UIStep=0.01; > = {0.5};
float4 Day_UIWFXFrost_SkyColor	  <string UIName="|- FrostFX - Day - Sky Color";		   string UIWidget="Color";								  > = {1.0, 1.0, 1.0, 1.0};
float4 Day_UIWFXFrost_EnvColor	  <string UIName="|- FrostFX - Day - Environment Color";   string UIWidget="Color";								  > = {0.3, 0.3, 0.3, 1.0};
float  Night_UIWFXFrost_Intensity <string UIName="|- FrostFX - Night - Intensity";		   float UIMin=0.0;  float UIMax=5.0;  float UIStep=0.01; > = {0.5};
float4 Night_UIWFXFrost_SkyColor  <string UIName="|- FrostFX - Night - Sky Color";		   string UIWidget="Color";								  > = {1.0, 1.0, 1.0, 1.0};
float4 Night_UIWFXFrost_EnvColor  <string UIName="|- FrostFX - Night - Environment Color"; string UIWidget="Color";								  > = {0.3, 0.3, 0.3, 1.0};
UI_SPECIAL_WHITESPACE(3)
UI_ELEMENT(ML_RainFX,							 "|--------- Rain Droplets")
float  UIWFXRain_Tickrate		  <string UIName="|- RainFX - Tickrate";		    float UIMin=0.01; float UIMax=10.0; float UIStep=0.01;  > = {0.15};
float  UIWFXRain_FadeCurve		  <string UIName="|- RainFX - Fade Curve";		    float UIMin=0.01; float UIMax=10.0; float UIStep=0.01;  > = {1.8};
float  UIWFXRain_MinSize		  <string UIName="|- RainFX - Min Size";		    float UIMin=0.0;  float UIMax=10.0; float UIStep=0.001; > = {0.03};
float  UIWFXRain_MaxSize		  <string UIName="|- RainFX - Max Size";		    float UIMin=0.01; float UIMax=10.0; float UIStep=0.001; > = {0.15};
float  UIWFXRain_MaxDeformation	  <string UIName="|- RainFX - Max Deformation";		float UIMin=0.0;  float UIMax= 2.0; float UIStep=0.01;  > = {0.15};
#if RAINFX_ENABLE_DISPERSION
float  UIWFXRain_Dispersion       <string UIName="|- RainFX - Dispersion";		    float UIMin=0.0;  float UIMax=99.0; float UIStep=0.01;  > = {1.0};
#endif
float  UIWFXRain_DripSpeed		  <string UIName="|- RainFX - Dripping Speed";	    float UIMin=0.0;  float UIMax= 5.0; float UIStep=0.001; > = {0.2};
float  UIWFXRain_DripDrift		  <string UIName="|- RainFX - Dripping Drift";	    float UIMin=0.0;  float UIMax= 5.0; float UIStep=0.001; > = {0.1};
float  UIWFXRain_Curvature		  <string UIName="|- RainFX - Droplet Curvature";   float UIMin=0.0;  float UIMax= 2.0; float UIStep=0.01;  > = {1.0};
float  UIWFXRain_Sigma			  <string UIName="|- RainFX - Blur Amount";		    float UIMin=0.0;  float UIMax=20.0; float UIStep=0.01;  > = {0.0};
UI_SPECIAL_WHITESPACE(4)
UI_ELEMENT(ML_FrostFX,							 "|--------- Frost Vignette")
float  UIWFXFrost_PulseRate		  <string UIName="|- FrostFX - Pulse Rate";		    float UIMin=0.0;  float UIMax=10.0; float UIStep=0.01; > = {0.1};
float  UIWFXFrost_PulseStrength	  <string UIName="|- FrostFX - Pulse Strength";	    float UIMin=0.0;  float UIMax=10.0; float UIStep=0.01; > = {0.5};
float  UIWFXFrost_Curve			  <string UIName="|- FrostFX - Curve";			    float UIMin=0.01; float UIMax=15.0; float UIStep=0.01; > = {1.5};
float  UIWFXFrost_RadiusInner	  <string UIName="|- FrostFX - Inner Radius";	    float UIMin=0.0;  float UIMax= 2.0; float UIStep=0.01; > = {1.2};
float  UIWFXFrost_RadiusOuter	  <string UIName="|- FrostFX - Outer Radius";	    float UIMin=0.0;  float UIMax= 2.0; float UIStep=0.01; > = {0.5};
float3 UIWFXFrost_Tint			  <string UIName="|- FrostFX - Tint";			    string UIWidget="Color";							   > = {1.0, 1.0, 1.0};
//UI_SPECIAL_WHITESPACE(5)
#if FROSTFX_USE_REFRACTION_METHOD
float  UIWFXFrost_Opacity         <string UIName="|- FrostFX - Opacity";            float UIMin=0.0;  float UIMax=99.0; float UIStep=0.1;  > = {50.0};
float  UIWFXFrost_RefracRange	  <string UIName="|- FrostFX - Refraction Range";   float UIMin=0.0;  float UIMax= 1.0; float UIStep=0.01; > = {0.2};
bool   UIWFXFrost_AllowOvershoot  <string UIName="|- FrostFX - Approx. missing Data";													   > = {true};
#else
float3 UIWFXFrost_LayerInt		  <string UIName="|- FrostFX - Layer Intensity - "; float UIMin=0.0;  float UIMax= 1.0; float UIStep=0.01; > = {1.0, 1.0, 1.0};
#endif


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 3

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(ML_StartBurst,">>>>>>STARBURST LENS FLARES<<<<<<")
UI_WHITESPACE(9)
#endif //NOTFIRSTTIME

float SEPARATE_VAR(UISB_Strength) <string UIName=TO_STRING(|- Starburst - TODIE - Intensity);		float UIMin=0.0; float UIMax=100.0; > = {1.0};
float SEPARATE_VAR(UISB_Thresh)   <string UIName=TO_STRING(|- Starburst - TODIE - Threshold);		float UIMin=0.1; float UIMax=100.0; > = {5.0};

#ifdef LASTTIME
UI_SPECIAL_WHITESPACE(6)
bool   UISB_HQ			  <string UIName="|- Starburst - Enable HQ Mode";														 > = {false};
float  UISB_Shape		  <string UIName="|- Starburst - Lens Shape";	     float UIMin=4.0; float UIMax=  9.0; float UIStep=1; > = {0.0};
float  UISB_AngleOffset	  <string UIName="|- Starburst - Lens Angle (\xB0)"; float UIMin=0.0; float UIMax=360.0; float UIStep=1; > = {0.0};
float  UISB_Width		  <string UIName="|- Starburst - Scale";		     float UIMin=0.0;									 > = {20.0};
float  UISB_ThreshCurve	  <string UIName="|- Starburst - Threshold Curve";   float UIMin=0.0; float UIMax= 30.0;				 > = {2.0};
float  UISB_Falloff		  <string UIName="|- Starburst - Falloff";		     float UIMin=0.5; float UIMax=  2.0;				 > = {1.0};
float  UISB_Imperfections <string UIName="|- Starburst - Imperfections";     float UIMin=0.0; float UIMax= 10.0;				 > = {0.0};
float  UISB_Saturation	  <string UIName="|- Starburst - Saturation";	     float UIMin=0.0; float UIMax= 10.0;				 > = {1.5};
float4 UISB_Tint		  <string UIName="|- Starburst - Tint";			     string UIWidget = "Color";							 > = {1.0, 1.0, 1.0, 0.0};

#undef LASTTIME
#endif //LASTTIME


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 2

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(ML_AnamFlare,"  >>>>>ANAMORPHIC LENS FLARES<<<<<")
UI_WHITESPACE(5)
#endif //NOTFIRSTTIME

float SEPARATE_VAR(UIAF_Int)    <string UIName=TO_STRING(|- AnamFlare - TODIE - Intensity); float UIMin=0.0; float UIMax=10.0; > = {1.0};
float SEPARATE_VAR(UIAF_Thresh) <string UIName=TO_STRING(|- AnamFlare - TODIE - Threshold); float UIMin=0.0; float UIMax=20.0; > = {1.0};

#ifdef LASTTIME
UI_SPECIAL_WHITESPACE(7)
float UIAF_Rotation  <string UIName="|- AnamFlare - Rotation";	    float UIStep=1.0; float UIMin=0.0; float UIMax=180.0; > = {90.0};
float UIAF_CoreFoc   <string UIName="|- AnamFlare - Core Focus";				      float UIMin=0.0; float UIMax=20.0;  > = { 0.4};
float UIAF_CoreInt   <string UIName="|- AnamFlare - Core Intensity";			      float UIMin=0.0; float UIMax=10.0;  > = { 1.5};
float UIAF_CoreMax   <string UIName="|- AnamFlare - Core Max";					      float UIMin=0.0; float UIMax=10.0;  > = { 2.0};
float UIAF_Width     <string UIName="|- AnamFlare - Width";						      float UIMin=1.0; float UIMax=100.0; > = {15.0};
float UIAF_Sat	     <string UIName="|- AnamFlare - Saturation";				      float UIMin=0.0; float UIMax=10.0;  > = { 1.0};
#if ANAM_ENABLE_MIRRORED_FLARE
float UIAF_MirrorInt <string UIName="|- AnamFlare - Mirror Intensity";			      float UIMin=0.0; float UIMax=10.0;  > = {0.5};
#endif

#undef LASTTIME
#endif //LASTTIME


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 4

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(ML_Dirt,"             >>>>>>LENS DIRT<<<<<<")
UI_WHITESPACE(7)
#endif //NOTFIRSTTIME

float SEPARATE_VAR(UID_Strength) <string UIName=TO_STRING(|- Dirt - TODIE - Intensity); float UIMin=0.0; float UIMax=100.0; > = {0.5};
float SEPARATE_VAR(UID_Power)    <string UIName=TO_STRING(|- Dirt - TODIE - Power);     float UIMin=0.0; float UIMax=100.0; > = {1.5};

#ifdef LASTTIME
UI_SPECIAL_WHITESPACE(8)
int UID_Select <string UIName="|- Dirt - Select Texture"; int UIMin=1; int UIMax=4; > = {1};

#undef LASTTIME
#endif //LASTTIME


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 5
UI_ELEMENT(_CA_Header,">>>>>>CHROMATIC ABERRATION<<<<<<")
UI_WHITESPACE(8)

float UICA_Strength    <string UIName="|- CA - Strength";            float UIMin=-8.0;  float UIMax= 8.0;  float UIStep=0.01; > = {1.0};
float UICA_Curve       <string UIName="|- CA - Curve";               float UIMin= 0.01; float UIMax=10.0;  float UIStep=0.01; > = {1.5};
UI_SPECIAL_WHITESPACE(15)
UI_ELEMENT(_CA_Spectral,                  "|--------- Spectral Dispersion")
float UICA_Spread      <string UIName="|- CA - Spectral Spread";    float UIMin= 0.0;  float UIMax= 3.0;  float UIStep=0.01; > = {1.0};
float UICA_Barrel      <string UIName="|- CA - Barrel Distortion";   float UIMin=-2.0;  float UIMax= 2.0;  float UIStep=0.01; > = {0.0};
float UICA_FringeSat   <string UIName="|- CA - Fringe Saturation";   float UIMin= 0.0;  float UIMax= 2.0;  float UIStep=0.01; > = {1.0};
UI_SPECIAL_WHITESPACE(16)
UI_ELEMENT(_CA_Tuning,                    "|--------- Fine Tuning")
float UICA_RedBias     <string UIName="|- CA - Red Channel Bias";    float UIMin=-2.0;  float UIMax= 2.0;  float UIStep=0.01; > = {1.0};
float UICA_BlueBias    <string UIName="|- CA - Blue Channel Bias";   float UIMin=-2.0;  float UIMax= 2.0;  float UIStep=0.01; > = {1.0};
float UICA_Deadzone    <string UIName="|- CA - Center Deadzone";     float UIMin= 0.0;  float UIMax= 0.5;  float UIStep=0.01; > = {0.05};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 6

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(ML_Reflections,"      >>>>>>LENS REFLECTIONS<<<<<<")
UI_WHITESPACE(6)
#endif //NOTFIRSTTIME

float SEPARATE_VAR(UIR_Strength) <string UIName=TO_STRING(|- Reflection - TODIE - Intensity); float UIMin=0.0; float UIMax=100.0; > = {5.0};
float SEPARATE_VAR(UIR_Power)    <string UIName=TO_STRING(|- Reflection - TODIE - Power);     float UIMin=0.0; float UIMax=100.0; > = {1.5};

#ifdef LASTTIME
UI_SPECIAL_WHITESPACE(9)
float3 UIR_ColorFilter1 <string UIName="|- Reflection - Color Filter 1"; string UIWidget = "Color"; > = {0.3, 0.4, 0.4};
float3 UIR_ColorFilter2 <string UIName="|- Reflection - Color Filter 2"; string UIWidget = "Color"; > = {0.2, 0.4, 0.5};
float3 UIR_ColorFilter3 <string UIName="|- Reflection - Color Filter 3"; string UIWidget = "Color"; > = {0.5, 0.3, 0.7};
float3 UIR_ColorFilter4 <string UIName="|- Reflection - Color Filter 4"; string UIWidget = "Color"; > = {0.1, 0.2, 0.7};

#undef LASTTIME
#endif //LASTTIME


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 7

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(ML_Ghosts,"     >>>>>>GHOST LENS FLARES<<<<<<")
UI_WHITESPACE(10)
#endif //NOTFIRSTTIME

float SEPARATE_VAR(UIG_Strength) <string UIName=TO_STRING(|- Ghosts - TODIE - Intensity); float UIMin=0.0; float UIMax=100.0; float UIStep=0.1; > = {1.0};
float SEPARATE_VAR(UIG_Power)    <string UIName=TO_STRING(|- Ghosts - TODIE - Power);     float UIMin=0.0; float UIMax=100.0;					> = {8.0};

#ifdef LASTTIME
UI_SPECIAL_WHITESPACE(10)
float UIG_FNumber 		<string UIName="|- Ghosts - Lens F Number";		 	float UIMin=2.0; float UIMax=8.0;				    > = {7.0};
float UIG_Shape 		<string UIName="|- Ghosts - Lens Shape"; 			float UIMin=4.0; float UIMax=9.0;   float UIStep=1; > = {0.0};
float UIG_AngleOffset	<string UIName="|- Ghosts - Lens Angle"; 			float UIMin=0.0; float UIMax=360.0; float UIStep=1; > = {0.0};
float UIG_Ratio			<string UIName="|- Ghosts - Lens Ratio"; 			float UIMin=0.0;								    > = {1.0};
bool  UIG_ForceDeform	<string UIName="|- Ghosts - Enable Forced Deform";													    > = {false};
float UIG_Deform 		<string UIName="|- Ghosts - Forced Deform Ratio"; 	float UIMin=0.0; float UIMax=1.0;				    > = {1.0}; //( 0 == circle, 1 == polygon)
float UIG_ShapeWeight	<string UIName="|- Ghosts - Lens Shape Weight";		float UIMin=0.0; float UIMax=2.0;				    > = {2.0};
float UIG_Grain			<string UIName="|- Ghosts - Lens Grain"; 			float UIMin=0.0;								    > = {0.2};

#if MULTIIRIS_ENABLE_CHROMATICABERRATION
UI_SPECIAL_WHITESPACE(11)
UI_ELEMENT(ML_CA,				       "|- Ghosts --------- Chromatic Aberration")
float  UIG_CACurve		<string UIName="|- Ghosts - CA Curve";	float UIMin=0.0;		   > = { 0.8 };
float  UIG_CAScale		<string UIName="|- Ghosts - CA Scale";							   > = {-1.05};
float3 UIG_CAColor0		<string UIName="|- Ghosts - CA Color0"; string UIWidget = "Color"; > = {1.0, 0.0, 0.0};
float3 UIG_CAColor1		<string UIName="|- Ghosts - CA Color1"; string UIWidget = "Color"; > = {0.0, 1.0, 0.0};
float3 UIG_CAColor2		<string UIName="|- Ghosts - CA Color2"; string UIWidget = "Color"; > = {0.0, 0.0, 1.0};
#endif //MULTIIRIS_ENABLE_CHROMATICABERRATION

UI_SPECIAL_WHITESPACE(12)
UI_ELEMENT(ML_Flare1,			       "|- Ghosts --------- Flares 1")
float4 Intensity1		<string UIName="|- Ghosts - Intensity1";					   > = {1.0,  1.0,   1.0, 1.0};
float4 Curve1 			<string UIName="|- Ghosts - Curve1";						   > = {1.0,  1.25,  1.0, 1.0};
float4 Scale1 			<string UIName="|- Ghosts - Scale1";						   > = {0.0, -0.30, -0.5, 1.0};
float4 Tint1 			<string UIName="|- Ghosts - Tint1"; string UIWidget = "Color"; > = {0.25, 0.25,  1.0, 1.0};
UI_SPECIAL_WHITESPACE(13)
UI_ELEMENT(ML_Flare2,			       "|- Ghosts --------- Flares 2")
float4 Intensity2 		<string UIName="|- Ghosts - Intensity2";					   > = {1.0,  1.0,  1.0,   1.0};
float4 Curve2 			<string UIName="|- Ghosts - Curve2";						   > = {1.4,  1.0,  1.0,   0.7};
float4 Scale2 			<string UIName="|- Ghosts - Scale2";						   > = {0.66, 2.0, -0.66, -0.5};
float4 Tint2 			<string UIName="|- Ghosts - Tint2"; string UIWidget = "Color"; > = {0.66, 1.0,  1.0,   0.25};
UI_SPECIAL_WHITESPACE(14)
UI_ELEMENT(ML_Flare3,			       "|- Ghosts --------- Flares 3")
float4 Intensity3 		<string UIName="|- Ghosts - Intensity3";					   > = {1.0,  1.0,  1.0,   1.0};
float4 Curve3 			<string UIName="|- Ghosts - Curve3";						   > = {1.0,  0.8,  1.0,   3.0};
float4 Scale3 			<string UIName="|- Ghosts - Scale3";						   > = {3.0, -1.5, -2.0, -20.0};
float4 Tint3 			<string UIName="|- Ghosts - Tint3"; string UIWidget = "Color"; > = {1.0,  1.0,  1.0,   0.0};

#undef LASTTIME
#endif //LASTTIME


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 8

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(ML_FilmGrain,"        >>>>>>FILM GRAIN<<<<<<")
UI_WHITESPACE(25)
#endif //NOTFIRSTTIME

float SEPARATE_VAR(UIFG_Intensity) <string UIName=TO_STRING(|- Film Grain - TODIE - Intensity); float UIMin=0.0; float UIMax=1.0; float UIStep=0.001; > = {0.12};

#ifdef LASTTIME
UI_SPECIAL_WHITESPACE(17)
UI_ELEMENT(ML_FGStructure,                "|--------- Grain Structure")
float  UIFG_Size          <string UIName="|- Film Grain - Size";             float UIMin=0.5;  float UIMax=4.0;  float UIStep=0.01; > = {1.0};
float  UIFG_Roughness     <string UIName="|- Film Grain - Roughness";        float UIMin=0.0;  float UIMax=1.0;  float UIStep=0.01; > = {0.5};
float  UIFG_AnimSpeed     <string UIName="|- Film Grain - Animation Speed";  float UIMin=0.0;  float UIMax=2.0;  float UIStep=0.01; > = {1.0};
UI_SPECIAL_WHITESPACE(18)
UI_ELEMENT(ML_FGResponse,                 "|--------- Luminance Response")
float  UIFG_ShadowGrain   <string UIName="|- Film Grain - Shadow Grain";    float UIMin=0.0;  float UIMax=2.0;  float UIStep=0.01; > = {1.4};
float  UIFG_MidtoneGrain  <string UIName="|- Film Grain - Midtone Grain";   float UIMin=0.0;  float UIMax=2.0;  float UIStep=0.01; > = {1.0};
float  UIFG_HighlightGrain<string UIName="|- Film Grain - Highlight Grain";  float UIMin=0.0;  float UIMax=2.0;  float UIStep=0.01; > = {0.3};
UI_SPECIAL_WHITESPACE(19)
UI_ELEMENT(ML_FGEmulsion,                 "|--------- Emulsion Layers")
float3 UIFG_ChannelWeight <string UIName="|- Film Grain - RGB Weight";       float UIMin=0.0;  float UIMax=2.0;  float UIStep=0.01; > = {0.95, 1.0, 1.15};
float  UIFG_ChannelDecorr <string UIName="|- Film Grain - Channel Decorrelation"; float UIMin=0.0; float UIMax=1.0; float UIStep=0.01; > = {0.35};

#undef LASTTIME
#endif //LASTTIME


#endif //SHADERGROUP

#undef TODIE










