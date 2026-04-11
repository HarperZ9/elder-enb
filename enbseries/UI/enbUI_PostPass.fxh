//----------------------------------------------------------------------------------------------//
//																								//
//								 Main ENB PostPass UI file										//
//						       by LonelyKitsuune aka Skratzer									//
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

UI_FileHeaderLong(">>>         COLOR & POST FX SUITE         <<<",
				  ">>>              by LonelyKitsuune              <<<")

#if ENABLE_TOOLS

UI_WHITESPACE(1)
UI_ELEMENT(_Tools_Header,"               >>>>>>TOOLS<<<<<<")
UI_WHITESPACE(2)

#if AA_SUPPORT_PRESET > 2
bool UI_CREAAShowEdgeTex <string UIName="Show CREAA EdgeTex";              > = {false};
#endif
#if !DIRECT_COLOR_GRADING
bool UI_ShowInternalLUT  <string UIName="Show Internal Color Grading LUT"; > = {false};
#endif
UI_WHITESPACE(3)

#endif //ENABLE_TOOLS

#undef SHADERGROUP


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 1

#ifndef NOTFIRSTTIME
#define NOTFIRSTTIME
UI_WHITESPACE(4)
UI_ELEMENT(_KCGS_Header,"        >>>>>>COLOR GRADING<<<<<<")
UI_WHITESPACE(5)
float UICG_LumaZonesOverlap		 <string UIName="|- CG - Luma Zones Overlap";			float UIMin=0.0; float UIMax=1.0; > = {1.0};
float Day_UICG_ExtLUTWeight		 <string UIName="|- CG - External LUT Weight Day";		float UIMin=0.0; float UIMax=1.0; > = {1.0};
float Night_UICG_ExtLUTWeight	 <string UIName="|- CG - External LUT Weight Night";	float UIMin=0.0; float UIMax=1.0; > = {1.0};
float Interior_UICG_ExtLUTWeight <string UIName="|- CG - External LUT Weight Interior";	float UIMin=0.0; float UIMax=1.0; > = {1.0};
#if !DIRECT_COLOR_GRADING
float UICG_LUTDither			 <string UIName="|- CG - LUT Dithering Amount";			float UIMin=0.0; float UIMax=1.0; > = {0.0};
#endif
UI_SPECIAL_WHITESPACE(1)
#endif //NOTFIRSTTIME

UI_ELEMENT(_KCGS_TODIE_Header,					               TO_STRING(|------- TODIE -------------------------------------))
float  SEPARATE_VAR(UICG_Brightness)			<string UIName=TO_STRING(|- CG - TODIE - Brightness);							float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float  SEPARATE_VAR(UICG_Contrast)				<string UIName=TO_STRING(|- CG - TODIE - Contrast);								float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float  SEPARATE_VAR(UICG_GammaCurve)			<string UIName=TO_STRING(|- CG - TODIE - Gamma Curve);							float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float  SEPARATE_VAR(UICG_Saturation)			<string UIName=TO_STRING(|- CG - TODIE - Saturation);							float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float  SEPARATE_VAR(UICG_Vibrance)				<string UIName=TO_STRING(|- CG - TODIE - Vibrance);								float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float  SEPARATE_VAR(UICG_BlackLevelIn)			<string UIName=TO_STRING(|- CG - TODIE - Black Level In);     float UIStep=1.0; float UIMin=  0.0; float UIMax=511.0; > = {0.0};
float  SEPARATE_VAR(UICG_WhiteLevelIn)			<string UIName=TO_STRING(|- CG - TODIE - White Level In);     float UIStep=1.0; float UIMin=  0.0; float UIMax=511.0; > = {255.0};
float  SEPARATE_VAR(UICG_BlackLevelOut)			<string UIName=TO_STRING(|- CG - TODIE - Black Level Out);    float UIStep=1.0; float UIMin=  0.0; float UIMax=511.0; > = {0.0};
float  SEPARATE_VAR(UICG_WhiteLevelOut)			<string UIName=TO_STRING(|- CG - TODIE - White Level Out);    float UIStep=1.0; float UIMin=  0.0; float UIMax=511.0; > = {255.0};
float3 SEPARATE_VAR(UICG_ChannelMixRed)			<string UIName=TO_STRING(|- CG - TODIE - Channel Mixer Red);					string UIWidget="Color";		      > = {1.0, 0.0, 0.0};
float3 SEPARATE_VAR(UICG_ChannelMixGreen)		<string UIName=TO_STRING(|- CG - TODIE - Channel Mixer Green);					string UIWidget="Color";		      > = {0.0, 1.0, 0.0};
float3 SEPARATE_VAR(UICG_ChannelMixBlue)		<string UIName=TO_STRING(|- CG - TODIE - Channel Mixer Blue);					string UIWidget="Color";		      > = {0.0, 0.0, 1.0};
UI_SPECIAL_WHITESPACE(SWSN1)
float  SEPARATE_VAR(UICG_HighlSat)				<string UIName=TO_STRING(|- CG - TODIE - Highlight Saturation);					float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float  SEPARATE_VAR(UICG_HighlBright)			<string UIName=TO_STRING(|- CG - TODIE - Highlight Brightness);					float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float3 SEPARATE_VAR(UICG_HighlTint)				<string UIName=TO_STRING(|- CG - TODIE - Highlight Tint);						string UIWidget="Color";		      > = {1.0, 1.0, 1.0};
float  SEPARATE_VAR(UICG_MidtoSat)				<string UIName=TO_STRING(|- CG - TODIE - Midtone Saturation);					float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float  SEPARATE_VAR(UICG_MidtoBright)			<string UIName=TO_STRING(|- CG - TODIE - Midtone Brightness);					float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float3 SEPARATE_VAR(UICG_MidtoTint)				<string UIName=TO_STRING(|- CG - TODIE - Midtone Tint);							string UIWidget="Color";		      > = {1.0, 1.0, 1.0};
float  SEPARATE_VAR(UICG_ShadoSat)				<string UIName=TO_STRING(|- CG - TODIE - Shadow Saturation);					float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float  SEPARATE_VAR(UICG_ShadoBright)			<string UIName=TO_STRING(|- CG - TODIE - Shadow Brightness);					float UIMin= -1.0; float UIMax=  3.0; > = {0.0};
float3 SEPARATE_VAR(UICG_ShadoTint)				<string UIName=TO_STRING(|- CG - TODIE - Shadow Tint);							string UIWidget="Color";		      > = {1.0, 1.0, 1.0};
UI_SPECIAL_WHITESPACE(SWSN2)
float  SEPARATE_VAR(UICG_HueShiftRed)			<string UIName=TO_STRING(|- CG - TODIE - Hue Shift Red);						float UIMin=-10.0; float UIMax= 10.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueShiftOrange)		<string UIName=TO_STRING(|- CG - TODIE - Hue Shift Orange);						float UIMin=-10.0; float UIMax= 10.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueShiftYellow)		<string UIName=TO_STRING(|- CG - TODIE - Hue Shift Yellow);						float UIMin=-10.0; float UIMax= 10.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueShiftGreen)			<string UIName=TO_STRING(|- CG - TODIE - Hue Shift Green);						float UIMin=-10.0; float UIMax= 10.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueShiftCyan)			<string UIName=TO_STRING(|- CG - TODIE - Hue Shift Cyan);						float UIMin=-10.0; float UIMax= 10.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueShiftBlue)			<string UIName=TO_STRING(|- CG - TODIE - Hue Shift Blue);						float UIMin=-10.0; float UIMax= 10.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueShiftMagenta)		<string UIName=TO_STRING(|- CG - TODIE - Hue Shift Magenta);					float UIMin=-10.0; float UIMax= 10.0; > = {0.0};
UI_SPECIAL_WHITESPACE(SWSN3)
float  SEPARATE_VAR(UICG_HueSatRed)				<string UIName=TO_STRING(|- CG - TODIE - Saturation Red);						float UIMin= -1.0; float UIMax=  2.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueSatOrange)			<string UIName=TO_STRING(|- CG - TODIE - Saturation Orange);					float UIMin= -1.0; float UIMax=  2.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueSatYellow)			<string UIName=TO_STRING(|- CG - TODIE - Saturation Yellow);					float UIMin= -1.0; float UIMax=  2.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueSatGreen)			<string UIName=TO_STRING(|- CG - TODIE - Saturation Green);						float UIMin= -1.0; float UIMax=  2.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueSatCyan)			<string UIName=TO_STRING(|- CG - TODIE - Saturation Cyan);						float UIMin= -1.0; float UIMax=  2.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueSatBlue)			<string UIName=TO_STRING(|- CG - TODIE - Saturation Blue);						float UIMin= -1.0; float UIMax=  2.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueSatMagenta)			<string UIName=TO_STRING(|- CG - TODIE - Saturation Magenta);					float UIMin= -1.0; float UIMax=  2.0; > = {0.0};
UI_SPECIAL_WHITESPACE(SWSN4)
float  SEPARATE_VAR(UICG_HueBrightRed)			<string UIName=TO_STRING(|- CG - TODIE - Brightness Red);						float UIMin= -1.0; float UIMax=  1.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueBrightOrange)		<string UIName=TO_STRING(|- CG - TODIE - Brightness Orange);					float UIMin= -1.0; float UIMax=  1.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueBrightYellow)		<string UIName=TO_STRING(|- CG - TODIE - Brightness Yellow);					float UIMin= -1.0; float UIMax=  1.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueBrightGreen)		<string UIName=TO_STRING(|- CG - TODIE - Brightness Green);						float UIMin= -1.0; float UIMax=  1.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueBrightCyan)			<string UIName=TO_STRING(|- CG - TODIE - Brightness Cyan);						float UIMin= -1.0; float UIMax=  1.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueBrightBlue)			<string UIName=TO_STRING(|- CG - TODIE - Brightness Blue);						float UIMin= -1.0; float UIMax=  1.0; > = {0.0};
float  SEPARATE_VAR(UICG_HueBrightMagenta)		<string UIName=TO_STRING(|- CG - TODIE - Brightness Magenta);					float UIMin= -1.0; float UIMax=  1.0; > = {0.0};

#undef SWSN1
#undef SWSN2
#undef SWSN3
#undef SWSN4


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
#elif SHADERGROUP == 2

#if AA_SUPPORT_PRESET > 0
UI_WHITESPACE(6)
UI_WHITESPACE(7)
UI_ELEMENT(_AA_Header,"         >>>>>>ANTIALIASING<<<<<<")
UI_WHITESPACE(8)

#if AA_SUPPORT_PRESET == 1 || AA_SUPPORT_PRESET > 2
bool UISMAA_Enable		   <string UIName="|- AA - Enable  SMAA"; > = {true};
#endif

#if AA_SUPPORT_PRESET > 1 && AA_SUPPORT_PRESET != 4
bool UIFXAA_Enable		   <string UIName="|- AA - Enable  FXAA"; > = {false};
#endif

#if AA_SUPPORT_PRESET > 3
bool UICREAA_Enable		   <string UIName="|- AA - Enable CREAA"; > = {false};
#endif

#if AA_SUPPORT_PRESET > 1 && AA_SUPPORT_PRESET != 4
UI_SPECIAL_WHITESPACE(2)
float UIFXAA_SubPix		   <string UIName="|- FXAA - Sub-Pixel Antialiasing";	      float UIMin=0.0; float UIMax=1.0;  > = {0.75};
float UIFXAA_EdgeThresh    <string UIName="|- FXAA - Edge Detection Threshold";       float UIMin=0.0; float UIMax=1.0;  > = {0.166};
float UIFXAA_EdgeThreshMin <string UIName="|- FXAA - Minimum Luminance";		      float UIMin=0.0; float UIMax=1.0;  > = {0.0833};
#endif

#if AA_SUPPORT_PRESET > 3
UI_SPECIAL_WHITESPACE(3)
float UIAA_Sensitivity	   <string UIName="|- CREAA - Sensitivity"; float UIStep=1.0; float UIMin=1.0; float UIMax=10.0; > = {3.0};
float UIAA_Intensity	   <string UIName="|- CREAA - Intensity";				      float UIMin=0.0; float UIMax=0.66; > = {0.4};
#endif

#endif //AA_SUPPORT_PRESET


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

#if ENABLE_BLUR_SUITE
UI_WHITESPACE(9)
UI_WHITESPACE(10)
UI_ELEMENT(_Blur_Header,"           >>>>>>BLUR SUITE<<<<<<")
UI_WHITESPACE(11)

bool  UIB_EnableBlur	 <string UIName="|- Blur - Enable";																       > = {false};
float UIB_MaxAmount		 <string UIName="|- Blur - Amount";								    float UIMin=0.0; float UIMax=50.0; > = {2.0};
int   UIB_BlurType       <string UIName="|- Blur - Type";								    int   UIMin=  1; int   UIMax=   4; > = {  1}; //1 = 2D blur, 2-4 = 1D blur
int   UIB_Quality		 <string UIName="|- Blur - Quality"; string UIWidget="Quality";     int   UIMin=  0; int   UIMax=   2; > = {  1};
UI_SPECIAL_WHITESPACE(4)
bool  UIB_EnableRadial   <string UIName="|- Blur - Type 2-4 - Use Radial Direction";									       > = {true};
int   UIB_BlurDir        <string UIName="|- Blur - Type 2-4 - Non-Radial Direction (\xB0)"; int   UIMin=  0; int   UIMax= 360; > = {  0};
UI_SPECIAL_WHITESPACE(5)
bool  UIB_EnableVig		 <string UIName="|- Blur - Vignette - Enable";													       > = {false};
float UIB_VigCurve		 <string UIName="|- Blur - Vignette - Curve";					    float UIMin=0.0; float UIMax=10.0; > = {1.0};
float UIB_VigInner		 <string UIName="|- Blur - Vignette - Inner radius";			    float UIMin=0.0; float UIMax= 2.0; > = {0.2};
float UIB_VigOuter  	 <string UIName="|- Blur - Vignette - Outer radius";			    float UIMin=0.0; float UIMax= 2.0; > = {1.0};
UI_SPECIAL_WHITESPACE(6)
bool  UIB_EnableDepth	 <string UIName="|- Blur - Depth - Enable";														       > = {false};
bool  UIB_DepthInvert	 <string UIName="|- Blur - Depth - Invert";														       > = {false};
float UIB_DepthCurve     <string UIName="|- Blur - Depth - Curve";						    float UIMin=0.0; float UIMax=10.0; > = {1.0};
float UIB_DepthStart     <string UIName="|- Blur - Depth - Fade Start"; float UIStep=0.001; float UIMin=0.0; float UIMax= 1.0; > = {0.0};
float UIB_DepthEnd		 <string UIName="|- Blur - Depth - Fade End";   float UIStep=0.001; float UIMin=0.0; float UIMax= 1.0; > = {1.0};
float UIB_EdgeBleedReduc <string UIName="|- Blur - Depth - Edge Bleeding Reduction";	    float UIMin=0.0; float UIMax= 1.0; > = {0.3};

#endif //ENABLE_BLUR_SUITE


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(12)
UI_WHITESPACE(13)
UI_ELEMENT(_Sharp_Header,"             >>>>>>SHARPEN<<<<<<")
UI_WHITESPACE(14)

bool  UIUM_Enable		<string UIName="|- Sharp - Enable Unsharp Mask";										      > = {true};
#if ENABLE_HIGH_QUALITY_SHARPENING
float UIUM_Steps		<string UIName="|- Sharp - Steps";		float UIStep=1.0; float UIMin=1.0;  float UIMax=15.0; > = {1.0};
#else
float UIUM_Steps		<string UIName="|- Sharp - Steps";		float UIStep=1.0; float UIMin=1.0;  float UIMax=SHARP_MAX_KERNELSIZE - 1.0; > = {1.0};
#endif
float UIUM_StepSize		<string UIName="|- Sharp - Step Size";					  float UIMin=0.01; float UIMax=1.25; > = {1.0};
float UIUM_Amount		<string UIName="|- Sharp - Amount";						  float UIMin=0.0;  float UIMax=10.0; > = {0.7};
float UIUM_LumaClamp	<string UIName="|- Sharp - Luma Clamping";				  float UIMin=0.0;  float UIMax= 2.0; > = {0.1};
UI_SPECIAL_WHITESPACE(7)
float UIUM_ConWeight	<string UIName="|- Sharp - Contrast Awareness";			  float UIMin=0.0;  float UIMax= 1.0; > = {0.6};
float UIUM_EdgeMask		<string UIName="|- Sharp - Object Edge Removal";		  float UIMin=0.0;  float UIMax= 1.0; > = {0.5};
float UIUM_Depthfade	<string UIName="|- Sharp - Depth Fade";					  float UIMin=0.01; float UIMax= 1.0; > = {1.0};
float UIUM_DepthBlur	<string UIName="|- Sharp - Depth Blur";					  float UIMin=0.0;  float UIMax= 1.0; > = {1.0};
bool  UIUM_Visualize	<string UIName="|- Sharp - Show Mask";													      > = {false};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(15)
UI_WHITESPACE(16)
UI_ELEMENT(_MC_Header1," >>>>MONOCHROMA - COLORFILTER<<<<")
UI_WHITESPACE(17)

bool   UIMC_Colorfilter_Enable	<string UIName="|- MC - Enable Colorfilter";																	> = {false};
float3 UIMC_HueSelect			<string UIName="|- MC - Color Selection";				string UIWidget="Color";								> = {1,0,0};
float  UIMC_FilterRange			<string UIName="|- MC - Filter Range";					float UIMin=0.0;  float UIMax=1.0; float UIStep=0.0001; > = {0.08};
float  UIMC_Hardness			<string UIName="|- MC - Filtering Hardness";			float UIMin=0.0;  float UIMax=1.0; float UIStep=0.01;	> = {0.00};
float  UIMC_Sat					<string UIName="|- MC - Filtered Saturation";			float UIMin=0.0;  float UIMax=5.0; float UIStep=0.01;	> = {1.00};
float  UIMC_NF_Sat				<string UIName="|- MC - Non-Filtered Saturation";		float UIMin=0.0;  float UIMax=1.0; float UIStep=0.01;	> = {0.00};

UI_WHITESPACE(18)
UI_WHITESPACE(19)
UI_ELEMENT(_MC_Header2,"   >>>>>>MONOCHROMA - B&W<<<<<<")
UI_WHITESPACE(20)
bool   UIBW_Enable				<string UIName="|- BW - Enable Black and White Filter";																> = {false};
float  UIBW_RedWeight			<string UIName="|- BW - Red Weight";						float UIMin=0.0;  float UIMax=1.0; float UIStep=0.001;  > = {0.213};//~Rec.709
float  UIBW_GreenWeight			<string UIName="|- BW - Green Weight";						float UIMin=0.0;  float UIMax=1.0; float UIStep=0.001;  > = {0.715};
float  UIBW_BlueWeight			<string UIName="|- BW - Blue Weight";						float UIMin=0.0;  float UIMax=1.0; float UIStep=0.001;  > = {0.072};
float4 UIBW_Tint				<string UIName="|- BW - Tint";								string UIWidget="Color";								> = {0.439,0.259,0.0784,0.0}; //Sepia


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(21)
UI_WHITESPACE(22)
UI_ELEMENT(_Vignette_Header,"             >>>>>>VIGNETTE<<<<<<")
UI_WHITESPACE(23)

bool   UI_VigEnable				<string UIName="|- Vignette - Enable";													    > = {false};
int    UI_VigBlendMode    		<string UIName="|- Vignette - Blend Mode";				int   UIMin=1;	  int   UIMax=4;    > = {1};
float  UI_VigRadiusInner		<string UIName="|- Vignette - Inner radius";			float UIMin=0.00; float UIMax=2.0;  > = {0.5};
float  UI_VigRadiusOuter  		<string UIName="|- Vignette - Outer radius";			float UIMin=0.00; float UIMax=2.0;  > = {1.2};
float  UI_VigWidth   			<string UIName="|- Vignette - Width";					float UIMin=0.00; float UIMax=1.0;  > = {0.0};
float  UI_VigHeight   			<string UIName="|- Vignette - Height";					float UIMin=0.00; float UIMax=1.0;  > = {0.0};
float4 UI_VigColor   			<string UIName="|- Vignette - Color"; 					string UIWidget="Color";		    > = {0.0,0.0,0.0,0.5};
float  UI_VigCurve   			<string UIName="|- Vignette - Curve";					float UIMin=0.01; float UIMax=10.0; > = {1.5};
bool   UI_VigShowRadii			<string UIName="|- Vignette - Show Radii";												    > = {false};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(24)
UI_WHITESPACE(25)
UI_ELEMENT(_CA_Header,">>>>>>CHROMATIC ABERRATION<<<<<<")
UI_WHITESPACE(26)

bool   UICA_Enable		<string UIName="|- CA - Enable Chromatic Aberration";									  > = {false};
float  UICA_HighPass	<string UIName="|- CA - HighPass";				      float UIMin= 0.0; float UIMax=2.0;  > = {0.0};
float  UICA_Amount  	<string UIName="|- CA - Amount";				      float UIMin=-8.0; float UIMax=8.0;  > = {1.0};
float  UICA_MaxRadius	<string UIName="|- CA - Max Radius";			      float UIMin= 1.0; float UIMax=3.0;  > = {1.0};
float  UICA_Curve   	<string UIName="|- CA - Curve";					      float UIMin= 1.0; float UIMax=10.0; > = {1.5};
bool   UICA_Visualize	<string UIName="|- CA - Show CA Area";													  > = {false};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(27)
UI_WHITESPACE(28)
UI_ELEMENT(_Grain_Header,"                 >>>>>>GRAIN<<<<<<")
UI_WHITESPACE(29)

bool  UIGrain_Enable			<string UIName="|- Grain - Enable";										   > = {false};
float UIGrain_Int				<string UIName="|- Grain - Intensity";	float UIMin= 0.0; float UIMax=1.0; > = {0.04};
float UIGrain_Saturation		<string UIName="|- Grain - Saturation"; float UIMin= 0.0; float UIMax=1.0; > = {0.0};
float UIGrain_Motion			<string UIName="|- Grain - Motion"; 	float UIMin=-2.0; float UIMax=2.0; > = {0.2};


//----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//

UI_WHITESPACE(30)
UI_WHITESPACE(31)
UI_ELEMENT(_Border_Header," >>>>>>LETTERBOX / PILLARBOX<<<<<<")
UI_WHITESPACE(32)

bool   UIBorder_Enable			<string UIName="|- Box - Enable Letterbox / Pillarbox";											 > = {false};
float4 UIBorder_Color			<string UIName="|- Box - Color";								string UIWidget="Color";		 > = {0,0,0,1};
float  UIBorder_Ratio			<string UIName="|- Box - Ratio";								float UIMin=0; float UIMax=30;   > = {2.3};
bool   UIBorder_Use_PxlOs		<string UIName="|- Box - Use Pixel Offsets instead";											 > = {false};
float  UIBorder_Width			<string UIName="|- Box - Width  (in Pixels)"; float UIStep=1.0; float UIMin=0; float UIMax=4000; > = {0.0};
float  UIBorder_Height			<string UIName="|- Box - Height (in Pixels)"; float UIStep=1.0; float UIMin=0; float UIMax=4000; > = {0.0};

#undef SHADERGROUP

#endif //SHADERGROUP

#undef TODIE
