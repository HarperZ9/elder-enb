# Effects 11 conflict audit

**Date:** 2026-08-15
**Question:** Does Elder ENB double-process under Effects 11, and does it need a host axis?
**Answer:** No, and no. The default install has no conflicting stage.

## Why the question exists

Effects 11 is a Community Shaders feature that reimplements ENBSeries and cannot
coexist with it. It force-disables competing post effects through a blocklist,
`SettingsPatches.json`, matched on exact variable-name strings harvested from
popular presets. The blocklist carries 115 entries and knows none of Elder's
names, so anything Elder runs that Community Shaders also runs would stack:
sharpening on sharpening, grain on grain, with Community Shaders upscaling and
TAA underneath.

Four Elder fields looked like candidates. All four turn out to be inert.

## Finding 1: the theme fields are declared and never read

`Helper/EotE_ThemeSystem.fxh:73-76` declares four `ThemeParams` fields:

```hlsl
    float vignetteEnable;       // 0/1
    float vignetteStr;          // Optical vignette strength
    float grainIntensity;       // Film grain intensity
    float sharpenStr;           // CAS sharpening intensity
```

A search across every `.fx` and `.fxh` in the preset finds no reader. They exist
in the struct and in the eight theme presets that populate it, and nothing
consumes them. They cost nothing today and they conflict with nothing.

They are latent, not harmless. Wiring any of them up later reintroduces exactly
the question this audit closes, and the blocklist still will not know their
names. Anyone connecting them should revisit this document.

## Finding 2: clarity is live but ships disabled

`CG_Clarity` in `Addons/Effect_ColorGrading.fxh:374` is a nine-tap wide-radius
unsharp mask with midtone bias. It is real local-contrast sharpening, it is
reachable, and `Addons/Effect_ColorGrading.fxh` is included by `enbeffect.fx:109`.

It is called once, at `enbeffect.fx:1244`:

```hlsl
        if (ui_ClarityEnable)  color.rgb = CG_Clarity(color.rgb, txcoord);
```

`ui_ClarityEnable` is declared at `Addons/Effect_ColorGrading.fxh:161` with a
default of `false`. A default install therefore runs no sharpening at all.

This is the one genuine conflict in the preset, and it is opt-in. A user who
enables clarity under Effects 11 gets Elder's unsharp mask on top of whatever
Community Shaders is doing, with no warning. The blocklist contains no entry
matching `GRADE | Clarity Enable`, confirmed by search.

## Consequence

Elder ENB needs no host axis. Truth ENB needed one because its vignette and
grain run by default and could not be disabled without also losing dithering.
Elder's equivalent stages are either dead code or off by default, so a second
generated variant would differ from the first in nothing.

Two things are worth doing instead, both cheap:

1. Add `GRADE | Clarity Enable` to the upstream `SettingsPatches.json`
   contribution already being raised for Truth. One line, and it protects the
   user who turns clarity on without knowing what else is running.
2. Leave the four theme fields alone and leave this document where the next
   person to touch them will find it.

## Method

Every claim here came from a search of the preset sources and a read of the
Community Shaders `dev` branch, not from the Effects 11 mod description. The
description says presets are auto-patched and does not mention that the patch
table is name-matched, which is the detail that decides this question.
