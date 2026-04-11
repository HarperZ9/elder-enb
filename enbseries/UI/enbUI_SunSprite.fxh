//----------------------------------------------------------------------------------------------//
//																								//
//								Main ENB Sunsprite UI file										//
//						      by LonelyKitsuune aka Skratzer									//
//						Updated for use with ENB Extender by Cr0w								//
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

UI_FileHeaderLong(">>>        ENB Sunsprite 2.1 for SSE        <<<",
				  ">>>              by LonelyKitsuune              <<<")

//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(1)
UI_ELEMENT(Lens_Settings,"         >>>>>>LENS SETTINGS<<<<<<")
UI_WHITESPACE(2)
bool  UI_EnableGlares      <string UIName="|- Enable Glares";                                                    > = {false};	
bool  UI_EnableStarburst   <string UIName="|- Enable Starburst";                                                 > = {false};
bool  UI_EnableAnam        <string UIName="|- Enable Anamorphic Flares";                                         > = {false};
bool  UI_EnableGhost       <string UIName="|- Enable Ghost Flares";                                              > = {false};
bool  UI_EnableHoop        <string UIName="|- Enable Hoop/Ring Flare";                                           > = {false};
UI_SPECIAL_WHITESPACE(21)
int   UI_ApertureShape     <string UIName="|- Aperture - Shape";             int   UIMin=4;    int   UIMax=9;	string Separation = "ExteriorWeather";> = {6};
int   UI_ApertureRotation  <string UIName="|- Aperture - Rotation(\xB0)";    int   UIMin=0;    int   UIMax=360;  string Separation = "ExteriorWeather";> = {0};
float UI_ApertureRoundness <string UIName="|- Aperture - Roundness";         float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {0.1};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(3)
UI_WHITESPACE(4)
UI_ELEMENT(SB_Settings," >>>>>>STARBURST LENS FLARE<<<<<<")
UI_WHITESPACE(5)

float  UISB_FlareInt          <string UIName="|- Starburst - TODIE -  Intensity";              float UIMin=0.0; float UIMax=10.0; > = {1.0};
float  UISB_Scale             <string UIName="|- Starburst - Scale";                  float UIMin=0.0; float UIMax= 3.0; string Separation = "ExteriorWeather";> = {1.0};
float  UISB_Falloff           <string UIName="|- Starburst - Falloff";                float UIMin=1.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {1.0};
float  UISB_BurstWidth        <string UIName="|- Starburst - Burst Width";            float UIMin=0.0; float UIMax= 1.0; string Separation = "ExteriorWeather";> = {0.8};
float  UISB_BurstWidthCurve   <string UIName="|- Starburst - Burst Width Curve";      float UIMin=0.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.7};
float  UISB_RandFrequency     <string UIName="|- Starburst - Randomness Frequency";   float UIMin=0.0; float UIMax=50.0; string Separation = "ExteriorWeather";> = {10.0};
float  UISB_RandIntensity     <string UIName="|- Starburst - Randomness Intensity";   float UIMin=0.0; float UIMax= 5.0; string Separation = "ExteriorWeather";> = {1.0};
float  UISB_StrayBurstAmount  <string UIName="|- Starburst - Stray Bursts Amount";    float UIMin=0.0; float UIMax= 1.0; string Separation = "ExteriorWeather";> = {0.1};
float  UISB_StrayBurstInt     <string UIName="|- Starburst - Stray Bursts Intensity"; float UIMin=0.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.8};
float  UISB_StrayBurstFalloff <string UIName="|- Starburst - Stray Bursts Falloff";   float UIMin=1.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {5.0};
float4 UISB_FlareTint         <string UIName="|- Starburst - Tint";                   string UIWidget="Color";           string Separation = "ExteriorWeather";> = {1,1,1,1};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(6)
UI_WHITESPACE(7)
UI_ELEMENT(HOOP_Settings,"      >>>>>>HOOP LENS FLARE<<<<<<")
UI_WHITESPACE(8)

float  UIHoop_Int         <string UIName="|- Hoop - Intensity";							     float UIMin=0.0;  float UIMax=20.0;  string Separation = "ExteriorWeather";> = {2.0};
float  UIHoop_Scale       <string UIName="|- Hoop - Scale";								     float UIMin=0.0;  float UIMax=20.0;  string Separation = "ExteriorWeather";> = {7.5};
float  UIHoop_Offset      <string UIName="|- Hoop - Offset";							     float UIMin=-5.0; float UIMax=5.0;   string Separation = "ExteriorWeather";> = {0.7};
float  UIHoop_Width       <string UIName="|- Hoop - Width";								     float UIMin=0.0;  float UIMax=1.0;   string Separation = "ExteriorWeather";> = {0.25};
float  UIHoop_Roundness   <string UIName="|- Hoop - Roundness";							     float UIMin=0.0;  float UIMax=10.0;  string Separation = "ExteriorWeather";> = {1.0};
float  UIHoop_CA          <string UIName="|- Hoop - Chromatic Aberration";				     float UIMin=0.0;  float UIMax=5.0;   string Separation = "ExteriorWeather";> = {0.1};
float  UIHoop_SunDistMod  <string UIName="|- Hoop - Distance Modifier";					     float UIMin=0.0;  float UIMax=10.0;  string Separation = "ExteriorWeather";> = {1.5};
float  UIHoop_Fade        <string UIName="|- Hoop - Fade";								     float UIMin=0.0;  float UIMax=3.0;   string Separation = "ExteriorWeather";> = {0.7};
float  UIHoop_PatternFreq <string UIName="|- Hoop - Pattern Frequency";    float UIStep=1.0; float UIMin=0.0;  float UIMax=500.0; string Separation = "ExteriorWeather";> = {100.0};
float  UIHoop_IntRandom   <string UIName="|- Hoop - Intensity Randomness"; float UIStep=1.0; float UIMin=0.0;  float UIMax=300.0; string Separation = "ExteriorWeather";> = {80.0};
float4 UIHoop_Tint        <string UIName="|- Hoop - Tint";								     string UIWidget="Color";             string Separation = "ExteriorWeather";> = {1,1,1,1};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(9)
UI_WHITESPACE(10)
UI_ELEMENT(G_Settings,"     >>>>>>SUN AND LENS GLARE<<<<<<")
UI_WHITESPACE(11)

float4 UI_LensGlareCol <string UIName="|- Glare - Lens Color";      string UIWidget="Color";           string Separation = "ExteriorWeather";> = {1,1,1,1};
float  UI_LensGlareInt <string UIName="|- Glare - Lens Intensity";  float UIMin=0.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.5};
float4 UI_SunGlareCol  <string UIName="|- Glare - Sun Color";       string UIWidget="Color";           string Separation = "ExteriorWeather";> = {1,1,1,1};
float  UI_SunGlareInt  <string UIName="|- Glare - Sun Intensity";   float UIMin=0.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.2};

#undef SHADERGROUP


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 1

#if PASS == 1
UI_ELEMENT(AF_Flares,">>>>>>ANAMORPHIC LENS FLARE<<<<<<")
UI_WHITESPACE(12)
float4 UIAF_Tint <string UIName="|- AnamFlares - Tint";      string UIWidget="Color";          > = {1,1,1,1};
float  UIAF_Int  <string UIName="|- AnamFlares - Intensity"; float UIMin=0.0; float UIMax=2.0; > = {1.0};
#endif

UI_SPECIAL_WHITESPACE(SWS)
UI_ELEMENT(COMBINE(AF_Flare,PASS),             TO_STRING(|- Anam PASS ------------------------------------------))
bool  COMBINE(UIAF_Mirror,PASS) <string UIName=TO_STRING(|- Anam PASS - Mirror);                                        > = {false};
float COMBINE(UIAF_Int,PASS)    <string UIName=TO_STRING(|- Anam PASS - Intensity); float UIMin=0.01; float UIMax=10.0; string Separation = "ExteriorWeather";> = {1.5};
float COMBINE(UIAF_Curve,PASS)  <string UIName=TO_STRING(|- Anam PASS - Curve);     float UIMin=1.0;  float UIMax=10.0; string Separation = "ExteriorWeather";> = {3.0};
float COMBINE(UIAF_Offset,PASS) <string UIName=TO_STRING(|- Anam PASS - Offset);    float UIMin=-3.0; float UIMax=3.0;  string Separation = "ExteriorWeather";> = {1.0};
float COMBINE(UIAF_Width,PASS)  <string UIName=TO_STRING(|- Anam PASS - Width);     float UIMin=0.01; float UIMax=3.0;  string Separation = "ExteriorWeather";> = {2.0};

#undef PASS
#undef SWS


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 2

#if PASS == 1
UI_ELEMENT(G_Flares,"          >>>>>>GHOST FLARES<<<<<<")
UI_WHITESPACE(13)
float UIG_DiffFreq    <string UIName="|- Ghost - Diffraction Frequency";  float UIMin=1.0; float UIMax= 1.5; string Separation = "ExteriorWeather";> = {1.0};
float UIG_Int         <string UIName="|- Ghost - Intensity";              float UIMin=0.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {1.0};
float UIG_OMoveWeight <string UIName="|- Ghost - Offset Movement Weight"; float UIMin=0.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.0};
float UIG_OMoveSeed   <string UIName="|- Ghost - Offset Movement Seed";   float UIMin=0.0; float UIStep=1.0; string Separation = "ExteriorWeather";> = {0.0};
float UIG_OffsetCurve <string UIName="|- Ghost - Offset Curve";           float UIMin=1.0; float UIMax=10.0; string Separation = "ExteriorWeather";> = {1.0};
#endif

UI_SPECIAL_WHITESPACE(SWS)
UI_ELEMENT(COMBINE(G_Flare,PASS),                   TO_STRING(|- Flare PASS ------------------------------------------))
float  COMBINE(UIG_Int,PASS)         <string UIName=TO_STRING(|- Flare PASS - Intensity);             float UIMin=0.01; float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.8};
float  COMBINE(UIG_Offset,PASS)      <string UIName=TO_STRING(|- Flare PASS - Offset);                float UIMin=-3.0; float UIMax=3.0;  string Separation = "ExteriorWeather";> = {1.0};
float  COMBINE(UIG_Scale,PASS)       <string UIName=TO_STRING(|- Flare PASS - Scale);                 float UIMin=0.01; float UIMax=20.0; string Separation = "ExteriorWeather";> = {1.0};
float4 COMBINE(UIG_Tint,PASS)        <string UIName=TO_STRING(|- Flare PASS - Tint);                  string UIWidget="Color";            string Separation = "ExteriorWeather";> = {1,1,1,1};
float  COMBINE(UIG_Feather,PASS)     <string UIName=TO_STRING(|- Flare PASS - Feathering);            float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {0.05};
float  COMBINE(UIG_Weight,PASS)      <string UIName=TO_STRING(|- Flare PASS - Shape Weight);          float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {1.0};
float  COMBINE(UIG_Vignette,PASS)    <string UIName=TO_STRING(|- Flare PASS - Vignette);              float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {0.0};
float  COMBINE(UIG_CA,PASS)          <string UIName=TO_STRING(|- Flare PASS - Chromatic Aberration);  float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {0.1};
float  COMBINE(UIG_DiffInt,PASS)     <string UIName=TO_STRING(|- Flare PASS - Diffraction Intensity); float UIMin=0.0;  float UIMax=20.0; string Separation = "ExteriorWeather";> = {0.5};
float  COMBINE(UIG_DirtInt,PASS)     <string UIName=TO_STRING(|- Flare PASS - Dirt Intensity);        float UIMin=0.0;  float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.2};

#undef PASS
#undef SWS


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 3

UI_SPECIAL_WHITESPACE(SWS)
UI_ELEMENT(COMBINE(DG_Flare,PASS),                   TO_STRING(|- Double Flare PASS ---------------------------------))
float  COMBINE(UIDG_Int,PASS)         <string UIName=TO_STRING(|- Double Flare PASS - Intensity);             float UIMin=0.01; float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.8};
float  COMBINE(UIDG_Offset,PASS)      <string UIName=TO_STRING(|- Double Flare PASS - Offset);                float UIMin=-3.0; float UIMax=3.0;  string Separation = "ExteriorWeather";> = {1.0};
float  COMBINE(UIDG_Scale,PASS)       <string UIName=TO_STRING(|- Double Flare PASS - Scale);                 float UIMin=0.01; float UIMax=20.0; string Separation = "ExteriorWeather";> = {1.0};
float4 COMBINE(UIDG_Tint,PASS)        <string UIName=TO_STRING(|- Double Flare PASS - Tint);                  string UIWidget="Color";            string Separation = "ExteriorWeather";> = {1,1,1,1};
float  COMBINE(UIDG_Feather,PASS)     <string UIName=TO_STRING(|- Double Flare PASS - Feathering);            float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {0.05};
float  COMBINE(UIDG_Weight,PASS)      <string UIName=TO_STRING(|- Double Flare PASS - Shape Weight);          float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {1.0};
float  COMBINE(UIDG_Vignette,PASS)    <string UIName=TO_STRING(|- Double Flare PASS - Vignette);              float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {0.0};
float  COMBINE(UIDG_CA,PASS)          <string UIName=TO_STRING(|- Double Flare PASS - Chromatic Aberration);  float UIMin=0.0;  float UIMax=1.0;  string Separation = "ExteriorWeather";> = {0.1};
float  COMBINE(UIDG_DiffInt,PASS)     <string UIName=TO_STRING(|- Double Flare PASS - Diffraction Intensity); float UIMin=0.0;  float UIMax=20.0; string Separation = "ExteriorWeather";> = {0.5};
float  COMBINE(UIDG_DirtInt,PASS)     <string UIName=TO_STRING(|- Double Flare PASS - Dirt Intensity);        float UIMin=0.0;  float UIMax=10.0; string Separation = "ExteriorWeather";> = {0.2};
float  COMBINE(UIDG_Dupl_Offset,PASS) <string UIName=TO_STRING(|- Double Flare PASS - Duplicate Offset-Mod);  float UIMin=-6.0; float UIMax=6.0;  string Separation = "ExteriorWeather";> = {0.0};

#undef PASS
#undef SWS

#endif //SHADERGROUP










