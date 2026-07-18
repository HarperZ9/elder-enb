#ifndef ELDER_QUALITY_TIER
#define ELDER_QUALITY_TIER 1
#endif

#if ELDER_QUALITY_TIER < 0 || ELDER_QUALITY_TIER > 4
#error ELDER_QUALITY_TIER must be in [0,4]
#endif

static const uint ElderQualityTier = ELDER_QUALITY_TIER;

#if ELDER_QUALITY_TIER == 0
static const uint ElderAODirections = 4;
static const uint ElderAOSteps = 2;
static const uint ElderSSRSteps = 0;
static const uint ElderDOFRings = 0;
static const uint ElderBloomRadius = 2;
static const uint ElderLensGhosts = 0;
static const uint ElderRoomLightRefinement = 0;
#elif ELDER_QUALITY_TIER == 1
static const uint ElderAODirections = 6;
static const uint ElderAOSteps = 3;
static const uint ElderSSRSteps = 0;
static const uint ElderDOFRings = 2;
static const uint ElderBloomRadius = 3;
static const uint ElderLensGhosts = 1;
static const uint ElderRoomLightRefinement = 1;
#elif ELDER_QUALITY_TIER == 2
static const uint ElderAODirections = 8;
static const uint ElderAOSteps = 4;
static const uint ElderSSRSteps = 8;
static const uint ElderDOFRings = 3;
static const uint ElderBloomRadius = 4;
static const uint ElderLensGhosts = 2;
static const uint ElderRoomLightRefinement = 1;
#elif ELDER_QUALITY_TIER == 3
static const uint ElderAODirections = 12;
static const uint ElderAOSteps = 5;
static const uint ElderSSRSteps = 12;
static const uint ElderDOFRings = 4;
static const uint ElderBloomRadius = 5;
static const uint ElderLensGhosts = 2;
static const uint ElderRoomLightRefinement = 2;
#else
static const uint ElderAODirections = 16;
static const uint ElderAOSteps = 6;
static const uint ElderSSRSteps = 16;
static const uint ElderDOFRings = 5;
static const uint ElderBloomRadius = 6;
static const uint ElderLensGhosts = 3;
static const uint ElderRoomLightRefinement = 2;
#endif
