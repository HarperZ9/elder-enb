// Silent Horizons Addon CodeGen Output (c) LonelyKitsuune 2020
// This file has been automatically generated. 


#if    SNOW_LOADED && !PHOTO_LOADED && !STYLE_LOADED && !PARTICLE_LOADED
SNOW_TECHS    (KitsuunePrePass, 3, 4, 5)

#elif !SNOW_LOADED &&  PHOTO_LOADED && !STYLE_LOADED && !PARTICLE_LOADED
PHOTO_TECH    (KitsuunePrePass, 3)

#elif  SNOW_LOADED &&  PHOTO_LOADED && !STYLE_LOADED && !PARTICLE_LOADED
SNOW_TECHS    (KitsuunePrePass, 3, 4, 5)
PHOTO_TECH    (KitsuunePrePass, 6)

#elif !SNOW_LOADED && !PHOTO_LOADED &&  STYLE_LOADED && !PARTICLE_LOADED
STYLE_TECHS   (KitsuunePrePass, 3, 4)

#elif  SNOW_LOADED && !PHOTO_LOADED &&  STYLE_LOADED && !PARTICLE_LOADED
SNOW_TECHS    (KitsuunePrePass, 3, 4, 5)
STYLE_TECHS   (KitsuunePrePass, 6, 7)

#elif !SNOW_LOADED &&  PHOTO_LOADED &&  STYLE_LOADED && !PARTICLE_LOADED
PHOTO_TECH    (KitsuunePrePass, 3)
STYLE_TECHS   (KitsuunePrePass, 4, 5)

#elif  SNOW_LOADED &&  PHOTO_LOADED &&  STYLE_LOADED && !PARTICLE_LOADED
SNOW_TECHS    (KitsuunePrePass, 3, 4, 5)
PHOTO_TECH    (KitsuunePrePass, 6)
STYLE_TECHS   (KitsuunePrePass, 7, 8)

#elif !SNOW_LOADED && !PHOTO_LOADED && !STYLE_LOADED &&  PARTICLE_LOADED
PARTICLE_TECHS(KitsuunePrePass, 3, 4)

#elif  SNOW_LOADED && !PHOTO_LOADED && !STYLE_LOADED &&  PARTICLE_LOADED
SNOW_TECHS    (KitsuunePrePass, 3, 4, 5)
PARTICLE_TECHS(KitsuunePrePass, 6, 7)

#elif !SNOW_LOADED &&  PHOTO_LOADED && !STYLE_LOADED &&  PARTICLE_LOADED
PHOTO_TECH    (KitsuunePrePass, 3)
PARTICLE_TECHS(KitsuunePrePass, 4, 5)

#elif  SNOW_LOADED &&  PHOTO_LOADED && !STYLE_LOADED &&  PARTICLE_LOADED
SNOW_TECHS    (KitsuunePrePass, 3, 4, 5)
PHOTO_TECH    (KitsuunePrePass, 6)
PARTICLE_TECHS(KitsuunePrePass, 7, 8)

#elif !SNOW_LOADED && !PHOTO_LOADED &&  STYLE_LOADED &&  PARTICLE_LOADED
STYLE_TECHS   (KitsuunePrePass, 3, 4)
PARTICLE_TECHS(KitsuunePrePass, 5, 6)

#elif  SNOW_LOADED && !PHOTO_LOADED &&  STYLE_LOADED &&  PARTICLE_LOADED
SNOW_TECHS    (KitsuunePrePass, 3, 4, 5)
STYLE_TECHS   (KitsuunePrePass, 6, 7)
PARTICLE_TECHS(KitsuunePrePass, 8, 9)

#elif !SNOW_LOADED &&  PHOTO_LOADED &&  STYLE_LOADED &&  PARTICLE_LOADED
PHOTO_TECH    (KitsuunePrePass, 3)
STYLE_TECHS   (KitsuunePrePass, 4, 5)
PARTICLE_TECHS(KitsuunePrePass, 6, 7)

#elif  SNOW_LOADED &&  PHOTO_LOADED &&  STYLE_LOADED &&  PARTICLE_LOADED
SNOW_TECHS    (KitsuunePrePass, 3, 4, 5)
PHOTO_TECH    (KitsuunePrePass, 6)
STYLE_TECHS   (KitsuunePrePass, 7, 8)
PARTICLE_TECHS(KitsuunePrePass, 9, 10)

#endif
