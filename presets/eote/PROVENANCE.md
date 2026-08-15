# Provenance: the EotE preset shaders in this directory

These are preset shaders, not Elder's own. They are here because Elder's runtime
frame pulse has to be read by a live shader to do anything, and this is the
shader that reads it. Without this directory the pulse integration exists only
as a description.

Read this before redistributing any of it.

## What these files are

The "ENB of the Elders" (EotE) preset shader stack, adapted by Zain Dana Harper
in March 2026. Per the lineage record in `shader-handoff/HANDOFF.md`, the EotE
base preset is the upstream author of Elder's installed `.fx` stack and its
`Addons/*.fxh` effect library; only the theme system and the SkyrimBridge sync
are Elder-authored.

The full stack is nine `.fx` files. Six files are here: `enbeffect.fx` and the
five headers it includes, which is the closure needed to compile it. The other
eight shaders are not, because nothing in Elder's work touches them.

## Attribution, file by file

| file | attribution as it stands |
| --- | --- |
| `enbeffect.fx` | EotE base for the stages its own header marks `(existing)`; Boris Vorontsov / ENBSeries for the framework and host textures. Added 2026-08-15, having previously carried an "Adapted for" line naming no prior author. |
| `Helper/EotE_FilmScience.fxh` | `References:` block; Ottosson for Oklab, plus H&D curves and ASC-CDL cited per section. |
| `Helper/EotE_Tonemappers.fxh` | Per-operator references: Hill, Sobotka, Lottes, Gran Turismo, Hable, Hejl-Burgess. **No author line.** |
| `Helper/EotE_ThemeSystem.fxh` | **No author line.** The lineage credits the theme system to Elder, so this is most likely Elder-authored, but the file does not say so and I have not assumed it. |
| `Addons/Effect_ColorGrading.fxh` | `Author: Zain Dana Harper — March 2026`. |
| `enbglobals.fxh` | Declares the theme selector shared by all nine shaders. **No author line.** |

Three files carry no author line. That is recorded rather than fixed, because
filling it in would mean asserting authorship the record does not establish, and
a wrong credit is worse than a missing one. Anyone who knows the answer should
add it.

## The unresolved question

The EotE base preset's individual upstream author is not named anywhere in the
lineage record, only the preset itself. Until that is resolved, treat this
directory the way `skyrimbridge/CREDITS.md` treats the Kitsuune-derived suite:
readable source is not a licence and not a release.

Concretely, these files are **not** in Elder's release package. `scripts/package.py`
does not copy this directory, and that is deliberate. Committing source to a
public repository and shipping a mod are different acts, and only the first has
happened here.

## What Elder actually changed in enbeffect.fx

Two edits, both in `PS_Draw`'s stage 18 and the external variable block:

1. Declared `ElderRuntimeFramePulse`, the float4 the runtime plugin writes each
   BeginFrame.
2. Advanced the existing interleaved-gradient-noise dither by the frame counter,
   so the pattern moves instead of sitting still.

When the plugin is absent the offset is exactly zero and the dither is
bit-for-bit what it was. Verified by compiling both with `fxc`: 44,936 bytes of
bytecode with the wiring against 44,592 without, and `ElderRuntimeFramePulse`
survives compilation rather than being dead-stripped.

The attribution block added at the same time changes no bytecode at all, which
was checked the same way.

`docs/PRESET-INTEGRATION.md` describes the same integration for other presets,
and that document does ship.
