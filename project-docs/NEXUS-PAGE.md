# Nexus mod page content: Elder ENB

Everything needed for the Nexus upload form. The description is BBCode, ready
to paste into the mod-page description field once the release gate below is
closed.

**Do not upload yet.** Upload remains blocked until:

- the final public archive and checksum are produced and inspected;
- live ENB 0.504 acceptance is recorded at minimum for Performance, Balanced,
  and Cinematic;
- selected no-runtime / missing-runtime fallback checks are recorded;
- credits and third-party notices are bundled with the archive.

## Form fields

- **Name**: Elder ENB
- **Summary** (one line): A restrained nine-stage ENBSeries 0.504 shader suite
  with five quality tiers, exact identity fallbacks, and optional runtime
  interoperability after live acceptance.
- **Category**: Visuals and Graphics
- **Version**: 1.0.0

## Requirements (add these on the mod page)

- Skyrim Special Edition or Anniversary Edition
- ENBSeries 0.504

Do not list SkyrimBridge, KreatE, Silent Horizons, AELAS/EVLaS, ELIF,
NativeEditorID Fix, ENBWorldspaceWeatherlists/KiLoader, or other
permission-gated / historical plugins as hard requirements for the independent
suite. If the final archive ships an optional runtime component with additional
requirements, list those requirements only for that optional component.

## Media and promotion rules

- Use this canonical caption for each generated promotional asset:
  `Generated promotional brand art — not an in-game screenshot.`
- Generated abstract artwork is promotional only, not gameplay. Mark it with
  Nexus's AI Media tag.
- Do not enter the current 25th Anniversary Mod Drive.
- Any visual-performance or visual-quality claim needs a labeled real in-game
  capture. Label tier, ENB version, game edition, location/weather/interior
  state, and whether the runtime plugin was present.

## Description (BBCode)

[size=5]Elder ENB[/size]

[size=4]Read this first[/size]

Elder ENB is a restrained ENBSeries 0.504 shader suite for Skyrim SE/AE. It is
built around a fixed nine-stage order, five quality tiers, bounded controls, and
exact identity fallbacks when a capability is unavailable.

Do not mark Special Edition or Anniversary Edition live acceptance complete
until those runs are actually recorded. The minimum upload gate is live ENB
0.504 coverage for Performance, Balanced, and Cinematic, plus selected
no-runtime fallback checks.

[size=4]The nine-stage suite[/size]

[list=1]
[*][font=Courier New]enbeffectprepass.fx[/font] — stage contract: depth
convention, masks, room-light reach, bounded current-frame AO, and far-depth
atmosphere fallback. No live fog behavior is claimed here.
[*][font=Courier New]enbdepthoffield.fx[/font] — lens focus only.
[*][font=Courier New]enbbloom.fx[/font] — radiance extraction and filtering.
[*][font=Courier New]enbadaptation.fx[/font] — bounded luminance metering.
[*][font=Courier New]enblens.fx[/font] — stage contract: restrained glare,
ghost, and halo behavior when final integration is accepted. There is no dirt
pass or dirt texture.
[*][font=Courier New]enbeffect.fx[/font] — scene, bloom, lens, exposure, color
core, tone mapping, and gamut compression.
[*][font=Courier New]enbeffectpostpass.fx[/font] — final LDR finishing, with
dithering last and sharpening disabled by default.
[*][font=Courier New]enbsunsprite.fx[/font] — bounded sun optical response.
[*][font=Courier New]enbunderwater.fx[/font] — one underwater medium model.
[/list]

The list above describes stage responsibilities, not accepted live behavior.
Unverified effects and runtime payloads remain conditional until the final
archive and live ENB 0.504 evidence accept them. The target look is professional
and cinematic without effect stacking. Elder is not advertised as a
permission-gated preset-port or a bundle of third-party shader implementations.

[size=4]Quality tiers[/size]

[list]
[*][b]Performance[/b] — essential color / room-light path, low sample budgets,
and SSR identity/unshipped.
[*][b]Balanced[/b] — the default tier; restrained DOF, low-cost AO budget,
simple lens response, and stable scene readability.
[*][b]Quality[/b] — standard optical budgets; SSR budget is reserved/configured
only and remains identity/unshipped until implemented and accepted.
[*][b]Ultra[/b] — higher optical and scene-space budgets.
[*][b]Cinematic[/b] — highest bounded budgets and photographic refinement
without effect stacking.
[/list]

Do not advertise a fixed generated-INI count unless the final release manifest
proves that exact count. The public promise is complete tier outputs generated
from the canonical tier manifest.

[size=4]Capability and fallback behavior[/size]

Each modern technique follows the same ladder:

[list=1]
[*]use a valid native ENB / Elder runtime input;
[*]use a versioned SkyrimBridge-compatible value or reconstruction when present;
[*]use a stable, bounded spatial fallback;
[*]return the exact Elder-authored identity when confidence is insufficient.
[/list]

Zero intensity is identity, disabled stages are identity, and missing runtime
data must not leave stale live values visible to shaders.

[size=4]Runtime status[/size]

The source tree contains an optional runtime path for
[font=Courier New]ElderRuntimeFramePulse[/font]. Treat it as conditional until
the final public archive proves that it is integrated and live ENB 0.504
acceptance records it. If the runtime plugin is absent, the suite must use the
documented no-runtime fallback or identity behavior.

[size=4]Credits and provenance[/size]

Elder's public implementation is independently authored and MIT licensed. That
does not waive prior shader-author attribution and does not grant rights to
third-party implementations. The archive must include
[font=Courier New]CREDITS-AND-PROVENANCE.md[/font] and
[font=Courier New]THIRD_PARTY_NOTICES.md[/font].

Credited historical and technical sources include Boris Vorontsov / ENBSeries,
kingeric1992, Kitsuune/LonelyKitsuune/Skratzer/T. Thanner, Adyss, TreyM,
l00ping / L00ping, TheSandvichMaker/ReforgedUI, Marty McFly / Pascal Gilcher,
AMON ENB/Reforged, and the other technique references recorded in the
repository notices. These credits are attribution and provenance, not evidence
that proprietary implementations are shipped.

[size=4]Install[/size]

[list=1]
[*]Install ENBSeries 0.504 into the game root first.
[*]Install the final Elder archive with a mod manager.
[*]Choose one tier. Balanced is the default starting point.
[*]Install an optional runtime component only if it is present in the final
archive and its requirements are listed on this page.
[/list]

[size=4]Source and license[/size]

MIT licensed for Elder-owned code and documentation:
https://github.com/HarperZ9/elder-enb

Third-party notices and historical credits remain in force. Do not redistribute
ENB binaries, protected evidence, recovered proprietary implementations, or
permission-dependent plugin replacements as part of Elder.

## Permissions (owned Elder files only)

- Users can modify this file: yes
- Users can convert owned Elder files to work with other games: yes
- Users can use owned Elder assets from this file with credit: yes
- Others can use owned Elder assets with credit, without permission: yes
- Upload to other sites: yes, with credit and with the same third-party
  exclusions/notices

State on the page: the MIT license applies to Elder-owned code and
documentation only. It does not grant rights to ENBSeries,
Kitsuune/LonelyKitsuune/Skratzer/T. Thanner implementations, ReforgedUI,
ReShade/ADOF work, protected evidence, recovered legacy material, or any other
third-party material.
