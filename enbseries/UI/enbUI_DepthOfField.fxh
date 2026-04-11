//----------------------------------------------------------------------------------------------//
//																								//
//						      Main ENB Depth of Field UI file									//
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

UI_FileHeaderLong(">>>          Avanced Depth of Field          <<<",
				  ">>>                Kitsuune Edition               <<<")
UI_WHITESPACE(1)


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 1

UI_ELEMENT(_Focus_Header,"               >>>>>>FOCUS<<<<<<")
UI_WHITESPACE(2)
int   UI_FocusType				<string UIName="|- Focus Type (1-Auto, 2-Mouse, 3-Manual)";				 int   UIMin=1;    int   UIMax=3;   > = {1};
#if ENABLE_FOCUSING_TOOL
bool  UI_VisualizeFocus			<string UIName="|- Visualize Focus";																	    > = {false};
#endif
UI_SPECIAL_WHITESPACE(1)
UI_ELEMENT(_DOF_FocusInfo1,				       "|- 1 - Autofocus")
float2 UI_AutofocusCenter		<string UIName="|- Autofocus Sample Center";							 float UIMin=0.00; float UIMax=1.0; > = {0.5,0.5};
float  UI_AutofocusRadius		<string UIName="|- Autofocus Sample Radius";							 float UIMin=0.01; float UIMax=1.0; > = {0.05};
UI_SPECIAL_WHITESPACE(2)
UI_ELEMENT(_DOF_FocusInfo2,				       "|- 2 - Mousefocus (right click to focus)")
float  UI_MousefocusRadius		<string UIName="|- Mousefocus Sample Radius";							 float UIMin=0.01; float UIMax=1.0; > = {0.05};
UI_SPECIAL_WHITESPACE(3)
UI_ELEMENT(_DOF_FocusInfo3,				       "|- 3 - Manual Focus")
float  UI_ManualfocusDepth		<string UIName="|- Manual Focus Depth";			    float UIStep=0.0001; float UIMin=0.0;  float UIMax=1.0; > = {0.05};
UI_WHITESPACE(3)
UI_WHITESPACE(4)
UI_ELEMENT(_DOF_Header,"        >>>>>>DEPTH OF FIELD<<<<<<")
UI_WHITESPACE(5)
UI_ELEMENT(_DOF_DoFInfo,				       "|------- DOF")
float  UI_NearBlurCurve			<string UIName="|- DOF - Near Blur Curve";								 float UIMin=0.01;  float UIMax=20.0;  > = {1.0};
float  UI_NearBlurBleed			<string UIName="|- DOF - Near Blur Bleeding";							 float UIMin=0.0;   float UIMax= 2.0;  > = {1.0};
float  UI_FarBlurCurve			<string UIName="|- DOF - Far Blur Curve";								 float UIMin=0.01;  float UIMax=20.0;  > = {1.4};
#if ENABLE_FAR_BOKEH_FREEZING
bool   UI_FreezeFarBokeh		<string UIName="|- DOF - Freeze Far Bokeh";																       > = {false};
#endif
float  UI_HyperFocus			<string UIName="|- DOF - Hyperfocal Depth Distance"; float UIStep=0.001; float UIMin=0.0;   float UIMax=1.0;   > = {0.015};
bool   UI_RemoveFPSObjects      <string UIName="|- DOF - Remove FPS Objects";															       > = {true};
float  UI_RenderResMult			<string UIName="|- DOF - Blur Render Res mult";							 float UIMin=0.5;   float UIMax=1.0;   > = {0.5};
float  UI_SmootheningAmount		<string UIName="|- DOF - Gaussian PostBlur Width";						 float UIMin=0.0;   float UIMax=20.0;  > = {4.0};
int    UI_GaussQuality			<string UIName="|- DOF - Gaussian Quality";   string UIWidget="Quality"; int   UIMin=0;     int   UIMax=2;     > = {  1};
#if ENABLE_COC_DEBUGGING
int    UI_CoCDebug				<string UIName="|- DOF - CoC Debug";									 int   UIMin=0;     int   UIMax=4;     > = {  0};
#endif
UI_SPECIAL_WHITESPACE(4)
UI_ELEMENT(_DOF_BokehInfo,				       "|------- BOKEH")
float  UI_BokehIntensity		<string UIName="|- Bokeh - Intensity";									 float UIMin=0.0;   float UIMax=1.0;   > = {0.5};
float  UI_BokehCurve			<string UIName="|- Bokeh - Curve";										 float UIMin=0.0;   float UIMax=20.0;  > = {1.0};
float  UI_ShapeRadius			<string UIName="|- Bokeh - Shape Max Size";		     float UIStep=0.1;	 float UIMin=0.0;   float UIMax=100.0; > = {15.0};
int    UI_ShapeVertices			<string UIName="|- Bokeh - Shape Vertices";								 int   UIMin=3;     int   UIMax=9;     > = {6};
int    UI_ShapeQuality			<string UIName="|- Bokeh - Shape Quality";								 int   UIMin=2;     int   UIMax=50;    > = {5};
float  UI_ShapeCurvatureAmount	<string UIName="|- Bokeh - Shape Roundness";							 float UIMin=-1.0;  float UIMax=1.0;   > = {1.0};
float  UI_ShapeRotation			<string UIName="|- Bokeh - Shape Rotation (\xB0)";   float UIStep=1;	 float UIMin=0;     float UIMax=360;   > = {15};
float  UI_ShapeAnamorphRatio	<string UIName="|- Bokeh - Shape Aspect Ratio";							 float UIMin=0.0;   float UIMax=2.0;   > = {1.0};
bool   UI_ShapeCut				<string UIName="|- Bokeh - Cut Shape in Half";															       > = {false};

#if ENABLE_STYLIZED_BOKEHSHAPES
UI_SPECIAL_WHITESPACE(5)
UI_ELEMENT(_DOF_StyleInfo,				       "|------- STYLIZED BOKEH SHAPES")
bool   UI_EnableStyle			<string UIName="|- Style - Override Bokeh Shape";														    > = {false};
float  UI_StyleTex				<string UIName="|- Style - Choose Shape Texture";   float UIStep=1;		float UIMin=1.0; float UIMax=9.0;   > = {1.0};
float  UI_StyleIntensity		<string UIName="|- Style - Intensity";									float UIMin=0.0; float UIMax=1.0;   > = {1.0};
float  UI_StyleRadius			<string UIName="|- Style - Shape Max Size";		    float UIStep=0.1;	float UIMin=0.0; float UIMax=100.0; > = {15.0};
float  UI_StyleQualityLevel		<string UIName="|- Style - Shape Quality Level";    float UIStep=1;		float UIMin=1.0; float UIMax=4.0;   > = {2.0};
float  UI_StyleRotation			<string UIName="|- Style - Shape Rotation (\xB0)";  float UIStep=1;		float UIMin=0.0; float UIMax=359.0; > = {0.0};
float  UI_StyleSmoothening		<string UIName="|- Style - Gaussian Blur Override";						float UIMin=0.0; float UIMax=20.0;  > = {2.0};
#endif //ENABLE_STYLIZED_BOKEHSHAPES

#if ENABLE_SPHERICAL_ABERRATION
UI_SPECIAL_WHITESPACE(6)
UI_ELEMENT(_DOF_SAInfo,						       "|------- SPHERICAL ABERRATION")
float  UI_SphericalAmount		<string UIName="|- Bokeh - Shape SA Amount"; float UIMin=-1.0; float UIMax=1.0; > = {0.1};
float  UI_SphericalCurve		<string UIName="|- Bokeh - Shape SA Curve";  float UIMin= 0.0; float UIMax=3.0; > = {0.25};
#endif //ENABLE_SPHERICAL_ABERRATION

#if ENABLE_DIFFRACTION
UI_SPECIAL_WHITESPACE(7)
UI_ELEMENT(_DOF_DiInfo,						       "|------- DIFFRACTION")
float  UI_DiffractionAmount		<string UIName="|- Bokeh - Diffraction Amount";    float UIMin=0.0;  float UIMax= 1.0; > = {0.25};
float  UI_DiffractionFreq		<string UIName="|- Bokeh - Diffraction Frequency"; float UIMin=0.01; float UIMax=20.0; > = {8.0};
#endif //ENABLE_DIFFRACTION

#if ENABLE_OPTICAL_VIGNETTE
UI_SPECIAL_WHITESPACE(9)
UI_ELEMENT(_DOF_OVInfo,						       "|------- OPTICAL VIGNETTE")
float  UI_ShapeVignetteCurve		<string UIName="|- Bokeh - Shape Vignette Curve";  float UIMin=0.5; float UIMax=2.5; > = {0.75};
float  UI_ShapeVignetteAmount		<string UIName="|- Bokeh - Shape Vignette Amount"; float UIMin=0.0; float UIMax=2.0; > = {1.0};
#endif //ENABLE_OPTICAL_VIGNETTE

#if ENABLE_CHROMATIC_ABERRATION
UI_SPECIAL_WHITESPACE(10)
UI_ELEMENT(_DOF_CAInfo,						       "|------- CHROMATIC ABERRATION")
float  UI_LongitudChromaAmount		<string UIName="|- Bokeh - Longitudinal CA Amount"; float UIMin=-1.0; float UIMax=1.0; > = {0.3};
float  UI_LateralChromaAmount		<string UIName="|- Bokeh - Lateral CA Amount";      float UIMin=-1.0; float UIMax=1.0; > = {0.2};
float  UI_LateralChromaCurve		<string UIName="|- Bokeh - Lateral CA Curve";       float UIMin= 0.0; float UIMax=8.0; > = {1.3};
int    UI_ChromaMode				<string UIName="|- Bokeh - CA Type";                int   UIMin=   0; int   UIMax=  2; > = {2};
#endif

#if ENABLE_GRAINING == 1
UI_SPECIAL_WHITESPACE(8)
UI_ELEMENT(_DOF_GInfo,						       "|------- GRAINING")
float UI_GrainAmount			<string UIName="|- Bokeh - Grain Amount"; float UIMin=0.0; float UIMax= 1.0; > = {0.1};
float UI_GrainSeed				<string UIName="|- Bokeh - Grain Seed";   float UIMin=0.0; float UIMax=10.0; > = {0.23};
#elif ENABLE_GRAINING == 2
UI_SPECIAL_WHITESPACE(8)
UI_ELEMENT(_DOF_GInfo,						       "|------- GRAINING")
float UI_GrainInt				<string UIName="|- DOF - Grain Intensity";  float UIMin= 0.0; float UIMax=0.5; > = {0.05};
float UI_GrainSaturation		<string UIName="|- DOF - Grain Saturation"; float UIMin= 0.0; float UIMax=1.0; > = {0.5};
float UI_GrainMotion			<string UIName="|- DOF - Grain Motion";     float UIMin=-2.0; float UIMax=2.0; > = {0.1};
#endif //ENABLE_GRAINING


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 2

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(_DOFCC_Header,"   >>>>>>DOF COLOR GRADING<<<<<<")
UI_WHITESPACE(9)
bool  UICG_Enable		<string UIName="|---- Enable DOF Color Grading";										> = {true};
int   UICG_Mask			<string UIName="|- DOFCG - CC Mask (1-Bokeh, 2-CoC)"; int   UIMin=1;   int   UIMax=2;   > = {1};
float UICG_ConGrayLvl	<string UIName="|- DOFCG - Contrast Gray Level";      float UIMin=0.0; float UIMax=1.0; > = {0.5};
UI_SPECIAL_WHITESPACE(11)
#endif //NOTFIRSTTIME

float SEPARATE_VAR(UICG_Saturation) <string UIName=TO_STRING(|- DOFCG - TODIE - Saturation); float UIMin=0.0; float UIMax=10.0; > = {1.0};
float SEPARATE_VAR(UICG_Brightness) <string UIName=TO_STRING(|- DOFCG - TODIE - Brightness); float UIMin=0.0; float UIMax=10.0; > = {1.0};
float SEPARATE_VAR(UICG_Contrast)   <string UIName=TO_STRING(|- DOFCG - TODIE - Contrast);   float UIMin=0.0; float UIMax=10.0; > = {1.0};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 3

UI_ELEMENT(_DOFK_Header,"           >>>>>>DOF KEYING<<<<<<")
UI_WHITESPACE(10)
bool   UIK_Enable <string UIName="|---- Enable DOF Keying";										  > = {false};
int    UIK_Mask   <string UIName="|- DOFK - Key Mask (1-Bokeh, 2-DOF)"; int UIMin=1; int UIMax=2; > = {2};
float3 UIK_Color  <string UIName="|- DOFK - Keycolor";						string UIWidget="Color";  > = {0,1,0};

#endif //SHADERGROUP

#undef TODIE




