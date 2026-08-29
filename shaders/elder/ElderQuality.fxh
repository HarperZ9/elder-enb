#ifndef ELDER_QUALITY_FXH
#define ELDER_QUALITY_FXH

#include "elder/ElderTier.fxh"

#if ELDER_QUALITY_TIER < 0 || ELDER_QUALITY_TIER > 4
#error ELDER_QUALITY_TIER must be in [0,4]
#endif

static const uint ElderQualityTier = ELDER_QUALITY_TIER;

#if ELDER_QUALITY_TIER == 0
#define ELDER_AO_DIRECTIONS_VALUE 4
#define ELDER_AO_STEPS_VALUE 2
#define ELDER_SSR_STEPS_VALUE 0
#define ELDER_DOF_RINGS_VALUE 0
#define ELDER_BLOOM_RADIUS_VALUE 2
#define ELDER_LENS_GHOSTS_VALUE 0
#define ELDER_ROOM_LIGHT_REFINEMENT_VALUE 0
#elif ELDER_QUALITY_TIER == 1
#define ELDER_AO_DIRECTIONS_VALUE 6
#define ELDER_AO_STEPS_VALUE 3
#define ELDER_SSR_STEPS_VALUE 0
#define ELDER_DOF_RINGS_VALUE 6
#define ELDER_BLOOM_RADIUS_VALUE 3
#define ELDER_LENS_GHOSTS_VALUE 1
#define ELDER_ROOM_LIGHT_REFINEMENT_VALUE 1
#elif ELDER_QUALITY_TIER == 2
#define ELDER_AO_DIRECTIONS_VALUE 8
#define ELDER_AO_STEPS_VALUE 4
#define ELDER_SSR_STEPS_VALUE 8
#define ELDER_DOF_RINGS_VALUE 8
#define ELDER_BLOOM_RADIUS_VALUE 4
#define ELDER_LENS_GHOSTS_VALUE 2
#define ELDER_ROOM_LIGHT_REFINEMENT_VALUE 1
#elif ELDER_QUALITY_TIER == 3
#define ELDER_AO_DIRECTIONS_VALUE 12
#define ELDER_AO_STEPS_VALUE 5
#define ELDER_SSR_STEPS_VALUE 12
#define ELDER_DOF_RINGS_VALUE 10
#define ELDER_BLOOM_RADIUS_VALUE 5
#define ELDER_LENS_GHOSTS_VALUE 2
#define ELDER_ROOM_LIGHT_REFINEMENT_VALUE 2
#else
#define ELDER_AO_DIRECTIONS_VALUE 16
#define ELDER_AO_STEPS_VALUE 6
#define ELDER_SSR_STEPS_VALUE 16
#define ELDER_DOF_RINGS_VALUE 12
#define ELDER_BLOOM_RADIUS_VALUE 6
#define ELDER_LENS_GHOSTS_VALUE 3
#define ELDER_ROOM_LIGHT_REFINEMENT_VALUE 2
#endif

// Reserved budget axes. No shader consumes ElderSSRSteps or
// ElderRoomLightRefinement in this release. Reflections stay identity and
// the room light lift in ElderPrepassCore.fxh uses fixed coefficients at
// every tier. The values stay pinned so the ini metadata, the manifest,
// and the tier probe remain one ladder when an implementation lands.
static const uint ElderAODirections = ELDER_AO_DIRECTIONS_VALUE;
static const uint ElderAOSteps = ELDER_AO_STEPS_VALUE;
static const uint ElderSSRSteps = ELDER_SSR_STEPS_VALUE;
static const uint ElderDOFRings = ELDER_DOF_RINGS_VALUE;
static const uint ElderBloomRadius = ELDER_BLOOM_RADIUS_VALUE;
static const uint ElderLensGhosts = ELDER_LENS_GHOSTS_VALUE;
static const uint ElderRoomLightRefinement = ELDER_ROOM_LIGHT_REFINEMENT_VALUE;

#endif  // ELDER_QUALITY_FXH
