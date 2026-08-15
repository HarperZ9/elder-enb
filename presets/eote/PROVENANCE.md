# Provenance: the EotE preset shaders in this directory

These are preset shaders rather than Elder library code. They are here because
Elder's runtime frame pulse has to be read by a live shader to do anything, and
this is the shader that reads it.

## Authorship

**Zain Dana Harper wrote these**, as the "ENB of the Elders" (EotE) preset,
March 2026. They are first-party work, not a third-party preset Elder adapted.

That correction matters, because it was recorded the other way. The lineage
section of `shader-handoff/HANDOFF.md` lists an *"'ENB of the Elders' (EotE)
base preset"* as the *"upstream author of Elder's installed .fx stack"*, which
reads as a separate party. It is not one. The author confirmed authorship on
2026-08-15 and this file is the correction; `HANDOFF.md` still carries the older
wording and should be fixed when that document is next touched.

The `Adapted for ENB of the Elders by Zain Dana Harper` line in each shader
header means adapted *into* his own preset, not adapted *from* someone else's.

## What is genuinely third-party, and where

The techniques these shaders build on are other people's, and each is credited
at the code that uses it. None of that changes:

| source | where |
| --- | --- |
| Boris Vorontsov / ENBSeries | the host framework, its textures and pass contract; lens framework in `enblens.fx` |
| kingeric1992 | adaptation auto-exposure (ENB Forum, Nov 2016), in `enbadaptation.fx`; ALF lens flare in `enblens.fx` |
| LonelyKitsuune / Skratzer | Dynamic Gaussian Bloom 2.2, sunsprite, ADOF, in `enbbloom.fx`, `enbsunsprite.fx`, `enbdepthoffield.fx` |
| AMON ENB / Reforged | underwater volumetric basis, in `enbunderwater.fx` |
| Bjorn Ottosson | Oklab, in `Helper/EotE_FilmScience.fxh` |
| Hill, Sobotka, Lottes, Hable, Hejl-Burgess, Gran Turismo | tonemapping operators, in `Helper/EotE_Tonemappers.fxh` |
| Therrien / Levesque / Gilet, Jimenez, Karis | SSGI, multi-bounce AO, bloom threshold, in `enbeffectprepass.fx` and `enbbloom.fx` |

Of the six files here, none is derived from another preset. `enbeffect.fx` is the
compositor; the five headers are its libraries.

Three files carry no author line: `Helper/EotE_Tonemappers.fxh`,
`Helper/EotE_ThemeSystem.fxh`, and `enbglobals.fxh`. That is a gap in the files,
not a gap in the authorship, and worth closing next time they are edited.

## What Elder changed in enbeffect.fx

Two edits, in the external variable block and stage 18 of `PS_Draw`:

1. Declared `ElderRuntimeFramePulse`, the float4 the runtime plugin writes each
   BeginFrame.
2. Advanced the existing interleaved-gradient-noise dither by the frame counter,
   so the pattern moves instead of sitting still.

With no plugin the offset is exactly zero and the dither is bit-for-bit what it
was. Verified by compiling both with `fxc`: 44,936 bytes of bytecode with the
wiring against 44,592 without, and `ElderRuntimeFramePulse` survives compilation
rather than being dead-stripped. The attribution block added at the same time
changes no bytecode at all, checked the same way.

## Shipping

These ship in the release archive under `Optional-EotE-Compositor/`, not under
`Root/enbseries/`.

The EotE stack is nine `.fx` files and this is one of them. Copying it into an
`enbseries` folder belonging to a different preset replaces that preset's main
compositor, which changes the whole look rather than just its dithering. The
folder is opt-in with a README saying so, and users of other presets are pointed
at `docs/PRESET-INTEGRATION.md` to make the same two edits themselves.
