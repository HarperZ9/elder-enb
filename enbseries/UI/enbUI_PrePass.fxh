//----------------------------------------------------------------------------------------------//
//																								//
//								 Main ENB PrePass UI file										//
//						      by LonelyKitsuune aka Skratzer									//
//						Updated for ENB Extender by LonelyKitsuune								//
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

UI_FileHeaderLong(">>>            ENB PrePass for SSE            <<<",
				  ">>>              by LonelyKitsuune              <<<")

UI_WHITESPACE(1)
#if ENABLE_TOOLS
UI_ELEMENT(_Tools_Header,"               >>>>>>TOOLS<<<<<<")
UI_WHITESPACE(2)
bool UI_Visualize_Occlu <string UIName="Visualize Occlusion Texture"; > = {false};
bool UI_Visualize_Rays  <string UIName="Visualize Sun Rays";          > = {false};
UI_WHITESPACE(3)
UI_WHITESPACE(4)
#endif //ENABLE_TOOLS

#undef SHADERGROUP


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 1

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(_DSRS_Header,"  >>>>>>DUAL SUN RAY SYSTEM<<<<<<")
UI_WHITESPACE(5)
int   UIDSRS_Quality   <string UIName="|- DSRS - Quality";		 string UIWidget="Quality";         > = {1};
float UIDSRS_RayLength <string UIName="|- DSRS - Length";		 float UIMin=1.0; float UIMax= 4.0; > = {1.0};
float UIDSRS_HDRDark   <string UIName="|- DSRS - HDR Darkening"; float UIMin=0.0; float UIMax= 1.0; > = {0.3};
float UIDSRS_Desat     <string UIName="|- DSRS - Desaturation";  float UIMin=0.0; float UIMax= 1.0; > = {1.0};
UI_SPECIAL_WHITESPACE(1)
UI_ELEMENT(_DSR_Header,               "|------------ Direct Sun Rays")
bool  UIDSR_Enable     <string UIName="|- DSR - Enable";                                     > = {true};
float UIDSR_Falloff    <string UIName="|- DSR - Falloff"; float UIMin=0.0; float UIMax= 1.0; > = {1.0};
#endif //NOTFIRSTTIME

UI_SPECIAL_WHITESPACE(SWSN)
float  SEPARATE_VAR(UIDSR_Int)       <string UIName=TO_STRING(|- DSR - TODIE - Intensity);		float UIMin=0.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {1.0};
float  SEPARATE_VAR(UIDSR_CloudDens) <string UIName=TO_STRING(|- DSR - TODIE - Cloud Density);	float UIMin=0.1; float UIMax=16.0; string Separation = "ExteriorWeather";> = {3.0};
float3 SEPARATE_VAR(UIDSR_Color)     <string UIName=TO_STRING(|- DSR - TODIE - Color);			string UIWidget="Color";		   string Separation = "ExteriorWeather";> = {1,1,1};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 2

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_SPECIAL_WHITESPACE(3)
UI_SPECIAL_WHITESPACE(4)
UI_ELEMENT(_DVR_Header,               "|------------ Distant Volumetric Rays")
bool  UIDVR_Enable     <string UIName="|- DVR - Enable";												       > = {true};
float UIDVR_Falloff    <string UIName="|- DVR - Falloff";				    float UIMin=0.0; float UIMax= 1.0; > = {1.0};
int   UIDVR_RayType    <string UIName="|- DVR - Ray Occlusion Type";	    int   UIMin=  1; int   UIMax=   4; > = {4};
float UIDVR_DepthStart <string UIName="|- DVR - Type 4 - Depth Fade Start"; float UIMin=0.0; float UIMax= 1.0; > = {0.4};
float UIDVR_DepthEnd   <string UIName="|- DVR - Type 4 - Depth Fade End";   float UIMin=0.0; float UIMax= 1.0; > = {0.8};
#endif //NOTFIRSTTIME

UI_SPECIAL_WHITESPACE(SWSN)
float  SEPARATE_VAR(UIDVR_Int)       <string UIName=TO_STRING(|- DVR - TODIE - Intensity);		float UIMin=0.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {1.0};
float  SEPARATE_VAR(UIDVR_CloudDens) <string UIName=TO_STRING(|- DVR - TODIE - Cloud Density);	float UIMin=0.1; float UIMax=16.0; string Separation = "ExteriorWeather";> = {3.0};
float3 SEPARATE_VAR(UIDVR_Color)     <string UIName=TO_STRING(|- DVR - TODIE - Color);			string UIWidget="Color";		   string Separation = "ExteriorWeather";> = {1,1,1};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 3

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(_AtmoFog_Header,"    >>>>>>ATMOSPHERIC FOG<<<<<<")
UI_WHITESPACE(6)
bool  UIFog_Enable <string UIName="|- Enable Atmospheric Fog"; > = {true};
#endif //NOTFIRSTTIME

UI_SPECIAL_WHITESPACE(SWSN)
float3 SEPARATE_VAR(UIFog_Color)   <string UIName=TO_STRING(|- Fog - TODIE - Tint);    string UIWidget="Color";                               string Separation = "ExteriorWeather";> = {0.5,0.6,0.7};
float  SEPARATE_VAR(UIFog_Density) <string UIName=TO_STRING(|- Fog - TODIE - Density); float UIStep=0.001; float UIMin=0.0; float UIMax=100.0; string Separation = "ExteriorWeather";> = {10.0};

#endif //SHADERGROUP

#undef TODIE









