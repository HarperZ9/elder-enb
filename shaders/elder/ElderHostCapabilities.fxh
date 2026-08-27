#ifndef ELDER_HOST_CAPABILITIES_FXH
#define ELDER_HOST_CAPABILITIES_FXH

#define ELDER_CAPABILITY_IDENTITY 0
#define ELDER_CAPABILITY_SPATIAL  1
#define ELDER_CAPABILITY_BRIDGE   2
#define ELDER_CAPABILITY_NATIVE   3

#define ELDER_SCRATCH_NONE        0
#define ELDER_SCRATCH_PREPASS     1
#define ELDER_SCRATCH_DOF         2
#define ELDER_SCRATCH_BLOOM       3
#define ELDER_SCRATCH_ADAPTATION  4
#define ELDER_SCRATCH_LENS        5
#define ELDER_SCRATCH_MAIN        6
#define ELDER_SCRATCH_POSTPASS    7
#define ELDER_SCRATCH_SUNSPRITE   8
#define ELDER_SCRATCH_UNDERWATER  9

#ifndef ELDER_STAGE_CAPABILITY
#error Elder stage must declare ELDER_STAGE_CAPABILITY before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_COLOR
#error Elder stage must declare color ownership before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_DEPTH
#error Elder stage must declare depth ownership before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_NORMAL
#error Elder stage must declare normal ownership before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_MASK
#error Elder stage must declare mask ownership before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW
#error Elder stage must declare native celestial/view ownership before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION
#error Elder stage must declare previous scalar adaptation ownership before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_BRIDGE_VALUE
#error Elder stage must declare Bridge value ownership before including the contract
#endif
#ifndef ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE
#error Elder stage must declare native capability availability before including the contract
#endif
#ifndef ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE
#error Elder stage must declare Bridge capability availability before including the contract
#endif
#ifndef ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE
#error Elder stage must declare spatial capability availability before including the contract
#endif
#ifndef ELDER_STAGE_SCRATCH_OWNER
#error Elder stage must declare current-frame scratch ownership before including the contract
#endif
#ifndef ELDER_STAGE_SCRATCH_READ
#error Elder stage must declare every scratch read before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_FULL_FRAME_HISTORY
#error Elder stage must declare full-frame history availability before including the contract
#endif
#ifndef ELDER_STAGE_OWNS_OBJECT_MOTION
#error Elder stage must declare object-motion availability before including the contract
#endif
#ifndef ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY
#error Elder stage must declare scratch lifetime before including the contract
#endif
#ifndef ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING
#error Elder stage must declare alpha packing before including the contract
#endif

#if ELDER_STAGE_CAPABILITY < ELDER_CAPABILITY_IDENTITY || ELDER_STAGE_CAPABILITY > ELDER_CAPABILITY_NATIVE
#error Elder stage capability must be ordered from identity through native
#endif
#if ELDER_STAGE_OWNS_COLOR < 0 || ELDER_STAGE_OWNS_COLOR > 1
#error Elder stage color ownership must be boolean
#endif
#if ELDER_STAGE_OWNS_DEPTH < 0 || ELDER_STAGE_OWNS_DEPTH > 1
#error Elder stage depth ownership must be boolean
#endif
#if ELDER_STAGE_OWNS_NORMAL < 0 || ELDER_STAGE_OWNS_NORMAL > 1
#error Elder stage normal ownership must be boolean
#endif
#if ELDER_STAGE_OWNS_MASK < 0 || ELDER_STAGE_OWNS_MASK > 1
#error Elder stage mask ownership must be boolean
#endif
#if ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW < 0 || ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW > 1
#error Elder stage native celestial/view ownership must be boolean
#endif
#if ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION < 0 || ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION > 1
#error Elder stage previous scalar adaptation ownership must be boolean
#endif
#if ELDER_STAGE_OWNS_BRIDGE_VALUE < 0 || ELDER_STAGE_OWNS_BRIDGE_VALUE > 1
#error Elder stage Bridge value ownership must be boolean
#endif
#if ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE < 0 || ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE > 1
#error Elder stage native capability availability must be boolean
#endif
#if ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE < 0 || ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE > 1
#error Elder stage Bridge capability availability must be boolean
#endif
#if ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE < 0 || ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE > 1
#error Elder stage spatial capability availability must be boolean
#endif
#if ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE && ELDER_STAGE_CAPABILITY < ELDER_CAPABILITY_NATIVE
#error Elder stage declares a native input below the native capability level
#endif
#if ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE && ELDER_STAGE_CAPABILITY < ELDER_CAPABILITY_BRIDGE
#error Elder stage declares a Bridge input below the Bridge capability level
#endif
#if ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE && ELDER_STAGE_CAPABILITY < ELDER_CAPABILITY_SPATIAL
#error Elder stage declares a spatial input below the spatial capability level
#endif
#if ELDER_STAGE_NATIVE_CAPABILITY_AVAILABLE && ELDER_STAGE_OWNS_NATIVE_CELESTIAL_VIEW == 0 && ELDER_STAGE_OWNS_PREVIOUS_SCALAR_ADAPTATION == 0
#error Native capability requires a declared native celestial/view or scalar adaptation input
#endif
#if ELDER_STAGE_BRIDGE_CAPABILITY_AVAILABLE && ELDER_STAGE_OWNS_BRIDGE_VALUE == 0
#error Bridge capability requires a declared Bridge value
#endif
#if ELDER_STAGE_SPATIAL_CAPABILITY_AVAILABLE && ELDER_STAGE_OWNS_DEPTH == 0 && ELDER_STAGE_OWNS_NORMAL == 0 && ELDER_STAGE_OWNS_MASK == 0
#error Spatial capability requires a declared depth, normal, or mask input
#endif
#if ELDER_STAGE_SCRATCH_OWNER < ELDER_SCRATCH_NONE || ELDER_STAGE_SCRATCH_OWNER > ELDER_SCRATCH_UNDERWATER
#error Elder stage scratch owner is not a named current-frame surface
#endif
#if ELDER_STAGE_SCRATCH_READ < ELDER_SCRATCH_NONE || ELDER_STAGE_SCRATCH_READ > ELDER_SCRATCH_UNDERWATER
#error Elder stage scratch read is not a named current-frame surface
#endif
#if ELDER_STAGE_SCRATCH_READ != ELDER_SCRATCH_NONE && ELDER_STAGE_SCRATCH_READ != ELDER_STAGE_SCRATCH_OWNER
#error Elder stage reads scratch it does not own
#endif
#if ELDER_STAGE_OWNS_FULL_FRAME_HISTORY != 0
#error Full-frame history is unavailable in the initial public release
#endif
#if ELDER_STAGE_OWNS_OBJECT_MOTION != 0
#error Object motion vectors are unavailable in the initial public release
#endif
#if ELDER_STAGE_TREATS_SCRATCH_AS_HISTORY != 0
#error Current-frame scratch cannot be treated as persistent history
#endif
#if ELDER_STAGE_CROSS_EFFECT_ALPHA_PACKING != 0
#error Cross-effect alpha packing requires an explicit round-trip contract
#endif

#endif
