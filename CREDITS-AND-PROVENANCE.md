# Elder ENB credits and provenance

This file records attribution and release boundaries for the public Elder ENB
copy. It is not a license grant. The root `LICENSE` grants MIT rights only to
Elder-owned code and documentation.

## Elder-owned work

The public Elder implementation is independently authored by Zain Dana Harper:

- the nine-stage Elder shader suite under `shaders/` and `shaders/elder/`;
- the five-tier quality manifest and generated-preset infrastructure;
- the typed native parameter ABI, color/room-light helpers, artifact publication
  code, and optional runtime source under `native/`;
- the transactional profile, metadata/audit, first-five bundle, and weather
  migration tooling under `src/`, `include/`, `config/`, and `cmake/`;
- the public documentation in this repository.

These parts are MIT licensed unless a file says otherwise.

## Provenance sources reviewed for this release copy

- Current tracked source: `LICENSE`, `config/quality-tiers.csv`,
  `shaders/`, `shaders/elder/`, `native/README.md`, `native/NOTICE.md`,
  `docs/superpowers/specs/2026-07-17-ordered-five-tier-public-shader-suite-design.md`,
  and `docs/superpowers/plans/2026-07-17-ordered-five-tier-public-shader-suite.md`.
- Current tracked EotE provenance: `presets/eote/PROVENANCE.md` and the
  headers in `presets/eote/`.
- Historical, non-shipped shader/header evidence from commit
  `6aab23483c389321d0fe72f0293de67543743e7d`.
- Historical, non-shipped Nexus/page-copy special-thanks evidence from commit
  `8b01e0b490c968064436ec5e3a27b6c5fdfedc9e`.

Historical commits are evidence and attribution references. They are not part
of the public release archive and do not make proprietary implementations
available under Elder's MIT license.

## Third-party and historical technical credits

Preserve these credits in public release surfaces where relevant:

| Party / project | Provenance role recorded in this repository |
| --- | --- |
| Boris Vorontsov / ENBSeries | ENB host framework, shader pass contract, textures/resources, and historical lens-framework credit. ENB binaries are external and are not redistributed. |
| kingeric1992 / KingEric1992 | Historical adaptation auto-exposure and lens-flare/bicubic-filtering credits. |
| Kitsuune / LonelyKitsuune / Skratzer / T. Thanner | Historical KreatE and Kitsuune shader/UI/helper lineage, AELAS/EVLaS, ELIF, NativeEditorID Fix, ENBWorldspaceWeatherlists/KiLoader, and legacy shader-technique dependencies where recorded. Elder credits this lineage but does not ship proprietary Kitsuune implementations. |
| Marty McFly / Pascal Gilcher | Historical Advanced Depth of Field / ReShade ADOF credit recorded in legacy headers. |
| TheSandvichMaker / ReforgedUI | Historical ReforgedUI and shared include/UI credit. |
| TreyM | Historical shared include and blending/global helper credit. |
| l00ping / L00ping | Historical special-thanks / shader-community credit in legacy page copy. |
| Adyss | Historical special-thanks / shader-community credit in legacy page copy. |
| AMON ENB / Reforged | Historical underwater volumetric basis credit in the EotE provenance file. |
| Bjorn Ottosson | Oklab color-space reference in EotE film-science helpers. |
| ASC Technology Committee | ASC CDL reference in EotE film-science helpers. |
| Stephen Hill, Troy Sobotka, Timothy Lottes, John Hable, Hejl-Burgess, Gran Turismo | Tone-mapping and display-transform references in EotE tonemapper helpers. |
| Sébastien Hillaire and Maxime Heckel | Atmosphere technique/reference guidance adapted to ENB's budget and stage order. |
| Therrien, Levesque, Gilet, Jimenez, Karis | Historical SSGI, multi-bounce AO, and bloom-threshold technique references in EotE provenance. |

If a future archive includes a file, binary, texture, or linked component from a
third party, add its exact license/notice before release.

## Interoperability and deferral statement

Elder may expose independently authored typed schemas and adapters for public
formats and workflows. That interoperability does not imply that Elder includes,
reimplements, or grants rights to proprietary plugin code.

Components whose distribution requires permission remain outside the public
archive until that permission is recorded. Binary-reversal history, protected
evidence, recovered corpus files, and non-clean-room implementation details are
release evidence only; they are not shipped and are not a source license.

## Upload gate

Do not publish a public Elder archive until all of the following are recorded:

- final public archive name, manifest, and checksum;
- `CREDITS-AND-PROVENANCE.md` and `THIRD_PARTY_NOTICES.md` included in the
  archive;
- live ENB 0.504 acceptance for Performance, Balanced, and Cinematic;
- selected no-runtime / missing-runtime fallback checks;
- media proof for any visual claim, using labeled real in-game captures.
