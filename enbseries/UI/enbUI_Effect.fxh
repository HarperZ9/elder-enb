//----------------------------------------------------------------------------------------------//
//																								//
//								 Main ENB Effect UI file										//
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

UI_FileHeaderLong(">>>              ENB Effect for SSE              <<<",
				  ">>>              by LonelyKitsuune              <<<")
UI_WHITESPACE(1)
#if ENABLE_ADAPTTOOL
UI_ELEMENT(_AdaptHeader,"           >>>>>>ADAPT TOOL<<<<<<")
UI_WHITESPACE(2)
bool  AdaptToolEnabled <string UIName="|- Enable Adapt Tool";									    > = {false};
float AdaptToolMax     <string UIName="|- Adapt Max Brightness"; float UIMin=-9.0; float UIMax=3.0; > = { 1.00};
float AdaptToolMin     <string UIName="|- Adapt Min Brightness"; float UIMin=-9.0; float UIMax=3.0; > = {-4.00};
UI_WHITESPACE(3)
#endif //ENABLE_ADAPTTOOL

#undef SHADERGROUP


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 1

UI_ELEMENT(_LensHeader," >>>>>>EXTENDED LENS MIXING<<<<<<")
UI_WHITESPACE(4)
float  UIL_Brightness	<string UIName="|- Lens Brightness"; float UIStep=0.001; float UIMin=0.0; float UIMax=5.0; > = {1.0};
float  UIL_Saturation	<string UIName="|- Lens Saturation"; float UIStep=0.001; float UIMin=0.0; float UIMax=5.0; > = {1.0};
float3 UIL_LensTint		<string UIName="|- Lens Tint";       string UIWidget="Color";							   > = {1,1,1};
float  UIL_Contrast		<string UIName="|- Lens Contrast";   float UIStep=0.001; float UIMin=0.0; float UIMax=1.0; > = {0.0};

#undef SHADERGROUP


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 2

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(_EBM_Header,">>>>>>EXTENDED BLOOM MIXING<<<<<<")
UI_WHITESPACE(5)
bool UIB_Visualize		<string UIName="|- Visualize Bloom";	  > = {false};
#if EBM_ENABLE == 1
bool UIB_Subtract_Scene	<string UIName="|- Subtract Scene Color"; > = {false};
#endif //EBM_ENABLE
UI_SPECIAL_WHITESPACE(1)
#endif //NOTFIRSTTIME

#if EBM_ENABLE == 1
float  SEPARATE_VAR(UIB_Contrast)				<string UIName=TO_STRING(|- TODIE - Bloom Contrast);			float UIStep=0.001; float UIMin=0.0; float UIMax=1.0; > = {0.0};
float  SEPARATE_VAR(UIB_SaturationL1)			<string UIName=TO_STRING(|- TODIE - Layer1 Saturation);			float UIStep=0.001; float UIMin=0.0; float UIMax=5.0; > = {1.0};
float3 SEPARATE_VAR(UIB_BloomTintL1)			<string UIName=TO_STRING(|- TODIE - Layer1 Tint);				string UIWidget="Color";						      > = {1,1,1};
float  SEPARATE_VAR(UIB_BloomIntensityL1)		<string UIName=TO_STRING(|- TODIE - Layer1 Intensity);			float UIStep=0.001; float UIMin=0.0; float UIMax=3.0; > = {1.0};
float  SEPARATE_VAR(UIB_SaturationL2)			<string UIName=TO_STRING(|- TODIE - Layer2 Saturation);			float UIStep=0.001; float UIMin=0.0; float UIMax=5.0; > = {1.0};
float3 SEPARATE_VAR(UIB_BloomTintL2)			<string UIName=TO_STRING(|- TODIE - Layer2 Tint);				string UIWidget="Color";						      > = {1,1,1};
float  SEPARATE_VAR(UIB_BloomIntensityL2)		<string UIName=TO_STRING(|- TODIE - Layer2 Intensity);			float UIStep=0.001; float UIMin=0.0; float UIMax=3.0; > = {1.0};
float  SEPARATE_VAR(UIB_SaturationL3)			<string UIName=TO_STRING(|- TODIE - Layer3 Saturation);			float UIStep=0.001; float UIMin=0.0; float UIMax=5.0; > = {1.0};
float3 SEPARATE_VAR(UIB_BloomTintL3)			<string UIName=TO_STRING(|- TODIE - Layer3 Tint);				string UIWidget="Color";						      > = {1,1,1};
float  SEPARATE_VAR(UIB_BloomIntensityL3)		<string UIName=TO_STRING(|- TODIE - Layer3 Intensity);			float UIStep=0.001; float UIMin=0.0; float UIMax=3.0; > = {1.0};
#elif EBM_ENABLE == 2
float  SEPARATE_VAR(UIB_Contrast)				<string UIName=TO_STRING(|- TODIE - Bloom Contrast);			float UIStep=0.001; float UIMin=0.0; float UIMax=3.0; > = {0.0};
float  SEPARATE_VAR(UIB_Saturation)				<string UIName=TO_STRING(|- TODIE - Bloom Saturation);			float UIStep=0.001; float UIMin=0.0; float UIMax=5.0; > = {1.0};
float3 SEPARATE_VAR(UIB_BloomTint)				<string UIName=TO_STRING(|- TODIE - Bloom Tint);				string UIWidget="Color";						      > = {1,1,1};
float  SEPARATE_VAR(UIB_BloomIntensity)			<string UIName=TO_STRING(|- TODIE - Bloom Intensity);			float UIStep=0.001; float UIMin=0.0; float UIMax=3.0; > = {1.0};
#endif //EBM_ENABLE


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 3

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(AGISHeader,"                >>>>>>AGIS<<<<<<")
UI_WHITESPACE(6)
UI_ELEMENT(AGISDesc,"| Apply Game ImageSpace")
UI_SPECIAL_WHITESPACE(2)
#endif //NOTFIRSTTIME

float SEPARATE_VAR(UIAGIS_SatMin)		<string UIName=TO_STRING(|- TODIE - Min IS Saturation);	float UIStep=0.001; float UIMin=0.0; float UIMax=10.0; > = {0.0};
float SEPARATE_VAR(UIAGIS_SatMax)		<string UIName=TO_STRING(|- TODIE - Max IS Saturation);	float UIStep=0.001; float UIMin=0.0; float UIMax=10.0; > = {2.0};
float SEPARATE_VAR(UIAGIS_ConMin)		<string UIName=TO_STRING(|- TODIE - Min IS Contrast);	float UIStep=0.001; float UIMin=0.0; float UIMax=10.0; > = {0.0};
float SEPARATE_VAR(UIAGIS_ConMax)		<string UIName=TO_STRING(|- TODIE - Max IS Contrast);	float UIStep=0.001; float UIMin=0.0; float UIMax=10.0; > = {2.0};
float SEPARATE_VAR(UIAGIS_BrigMin)		<string UIName=TO_STRING(|- TODIE - Min IS Brightness); float UIStep=0.001; float UIMin=0.0; float UIMax=10.0; > = {0.0};
float SEPARATE_VAR(UIAGIS_BrigMax)		<string UIName=TO_STRING(|- TODIE - Max IS Brightness); float UIStep=0.001; float UIMin=0.0; float UIMax=10.0; > = {2.0};
float SEPARATE_VAR(UIAGIS_TintMax)		<string UIName=TO_STRING(|- TODIE - Max IS Tint);		float UIStep=0.001; float UIMin=0.0; float UIMax= 1.0; > = {1.0};
float SEPARATE_VAR(UIAGIS_FadeMax)		<string UIName=TO_STRING(|- TODIE - Max IS Fade);		float UIStep=0.001; float UIMin=0.0; float UIMax= 1.0; > = {1.0};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 4

#ifndef NOTFIRSTTIME
UI_ELEMENT(HCGHeader,"   >>>>>>HDR COLOR GRADING<<<<<<")
UI_WHITESPACE(8)
#define NOTFIRSTTIME
#endif //NOTFIRSTTIME

float  SEPARATE_VAR(UIHCG_Exposure)		 <string UIName=TO_STRING(|- TODIE - Exposure (F-Stops));		float UIStep=0.001; float UIMin=-6.0; float UIMax= 6.0; > = {0.0};
float  SEPARATE_VAR(UIHCG_Contrast)		 <string UIName=TO_STRING(|- TODIE - Contrast);					float UIStep=0.001; float UIMin= 0.0; float UIMax= 3.0; > = {1.0};
float  SEPARATE_VAR(UIHCG_ConMiddleGrey) <string UIName=TO_STRING(|- TODIE - Contrast Middle Grey);		float UIStep=0.001; float UIMin= 0.0; float UIMax= 3.0; > = {0.18};
float  SEPARATE_VAR(UIHCG_Saturation)	 <string UIName=TO_STRING(|- TODIE - Saturation);				float UIStep=0.001; float UIMin= 0.0; float UIMax=10.0; > = {0.0};
float3 SEPARATE_VAR(UIHCG_Colorbalance)  <string UIName=TO_STRING(|- TODIE - Color Balance);			string UIWidget="Color";								> = {1,1,1};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 5

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_ELEMENT(TM_Header,"           >>>>>>TONEMAPPER<<<<<<")
UI_WHITESPACE(9)
#if ENABLE_CROSSTALK
float UICT_Saturation	<string UIName="|- Crosstalk Saturation"; float UIStep=0.001; float UIMin=0.0; float UIMax=100.0; > = {1.0};
float UICT_Weight		<string UIName="|- Crosstalk Weight";     float UIStep=0.001; float UIMin=0.0; float UIMax=100.0; > = {1.0};
UI_SPECIAL_WHITESPACE(3)
#endif //ENABLE_CROSSTALK
#endif //NOTFIRSTTIME

UI_ELEMENT(TM_TODIE_Header,								       TO_STRING(|- TODIE ---------------------------------------))
float SEPARATE_VAR(UI_AdaptationMax)			<string UIName=TO_STRING(|- TODIE - Max Adapt);			float UIStep=0.001; float UIMin=0.0;   float UIMax=5.0; > = {1.0};
float SEPARATE_VAR(UI_AdaptationMin)			<string UIName=TO_STRING(|- TODIE - Min Adapt);			float UIStep=0.001; float UIMin=0.0;   float UIMax=5.0; > = {0.0};
UI_SPECIAL_WHITESPACE(SWSN)
#if CHOOSE_TONEMAPPER == 1
float SEPARATE_VAR(UITM_midIn)					<string UIName=TO_STRING(|- TODIE - Middle Grey);		float UIStep=0.001; float UIMin=0.0;   float UIMax=10.0; > = {0.18};
float SEPARATE_VAR(UITM_Contrast)				<string UIName=TO_STRING(|- TODIE - Contrast (Toe));	float UIStep=0.001; float UIMin=0.0;   float UIMax=3.0;  > = {1.0};
float SEPARATE_VAR(UITM_Shoulder)				<string UIName=TO_STRING(|- TODIE - Shoulder);			float UIStep=0.001; float UIMin=0.0;   float UIMax=3.0;  > = {1.0};
#elif CHOOSE_TONEMAPPER == 2
float SEPARATE_VAR(UITM_ExposureBias)			<string UIName=TO_STRING(|- TODIE - Exposure Bias);		float UIStep=0.001; float UIMin=0.0;   float UIMax=10.0; > = {1.0};
float SEPARATE_VAR(UITM_ShoulderStrength)		<string UIName=TO_STRING(|- TODIE - Shoulder Strength);	float UIStep=0.001; float UIMin=0.0;   float UIMax=10.0; > = {0.15};
float SEPARATE_VAR(UITM_LinearStrength)			<string UIName=TO_STRING(|- TODIE - Linear Strength);	float UIStep=0.001; float UIMin=0.0;   float UIMax=10.0; > = {0.5};
float SEPARATE_VAR(UITM_LinearAngle)			<string UIName=TO_STRING(|- TODIE - Linear Angle);		float UIStep=0.001; float UIMin=0.0;   float UIMax=10.0; > = {0.1};
float SEPARATE_VAR(UITM_ToeStrength)			<string UIName=TO_STRING(|- TODIE - Toe Strength);		float UIStep=0.001; float UIMin=0.0;   float UIMax=10.0; > = {0.2};
float SEPARATE_VAR(UITM_ToeNumerator)			<string UIName=TO_STRING(|- TODIE - Toe Numerator);		float UIStep=0.001; float UIMin=0.0;   float UIMax=10.0; > = {0.02};
float SEPARATE_VAR(UITM_ToeDenominator)			<string UIName=TO_STRING(|- TODIE - Toe Denominator);	float UIStep=0.001; float UIMin=0.001; float UIMax=10.0; > = {0.3};
float SEPARATE_VAR(UITM_LinearWhite)			<string UIName=TO_STRING(|- TODIE - Linear White);		float UIStep=0.001; float UIMin=0.0;   float UIMax=20.0; > = {11.2};
#elif CHOOSE_TONEMAPPER == 3
float SEPARATE_VAR(UITM_WhitePoint)				<string UIName=TO_STRING(|- TODIE - White Point);		float UIStep=0.001; float UIMin=0.001; float UIMax=10.0; > = {1.0};
#endif

#undef SWSN


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 6

UI_ELEMENT(_DitherHeader,"           >>>>>>DITHERING<<<<<<")
UI_WHITESPACE(10)
float UID_Intensity		<string UIName="|- Dither - Intensity";		float UIMin=0.0; float UIMax=200.0; > = {1.0};
float UID_Motion		<string UIName="|- Dither - Motion";		float UIMin=0.0; float UIMax=  1.0; > = {1.0};
bool  UID_Visualize		<string UIName="|- Dither - Visualize";										    > = {false};

#undef SHADERGROUP


#endif //SHADERGROUP

#undef TODIE

