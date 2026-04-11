//----------------------------------------------------------------------------------------------//
//										GLOBAL OPTIONS FILE										//
//----------------------------------------------------------------------------------------------//
//								==================================								//
//								//     Silent Horizons ENB      //								//
//								//								//								//
//								//		by LonelyKitsuune		//								//
//								==================================								//
//----------------------------------------------------------------------------------------------//


//Simplified version of the most important settings for tweakers
// -> Everything that beginns with #define in this file is a global setting
// -> The values inside the brackets "[]" behind the main variable are the possible inputs


//For more experience users:
//If you want more control over the shaders go into the .fx files and
//enable LOCAL_OVERRIDE to tune each setting manually




//--------------------------------------------------------------------------------
//DEPTH OF FIELD OPTIONS
//--------------------------------------------------------------------------------
//Enables partial occlusion of bokeh discs at screen corners
#define ENABLE_OPTICAL_VIGNETTE			1 //[0-1]


//Enables bokeh specific chromatic aberration
#define ENABLE_CHROMATIC_ABERRATION		1 //[0-1]


//Enables custom texture-based bokeh shapes
#define ENABLE_STYLIZED_BOKEHSHAPES		1 //[0-1]


//Enables uneven weighting of bokeh discs
#define ENABLE_SPHERICAL_ABERRATION		1 //[0-1]


//Enables bokeh shape diffraction
#define ENABLE_DIFFRACTION				1 //[0-1]


//Enables DoF limited graining
// 1 - Individual bokeh shape grain
// 2 - Full screen grain
#define ENABLE_GRAINING					2 //[0-2]


//Enables the option to visualize the focusing area
#define ENABLE_FOCUSING_TOOL			1 //[0-1]

