# Nexus mod page content: Elder ENB

Everything needed for the Nexus upload form. The description is BBCode, ready
to paste into the mod-page description field.

**Read this before uploading.** The runtime payload is wired now: the plugin
publishes a per-frame pulse the shader stack can read. What it does not yet do
is change the image, because no shipped shader consumes the pulse to alter
output. The page below says that plainly rather than implying a visual upgrade.

## Form fields

- **Name**: Elder ENB
- **Summary** (one line): A five-tier ENB quality contract with complete,
  deterministically generated preset trees, a native colour pipeline, and a
  runtime plugin that publishes live frame state to the shader stack.
- **Category**: Visuals and Graphics
- **Version**: 1.0.0

## Requirements (add these on the mod page)

- Skyrim Special Edition or Anniversary Edition
- ENBSeries

## Description (BBCode)

[size=5]Elder ENB[/size]

[size=4]Read this first[/size]

The runtime plugin is live. It attaches to ENB, resolves the host, and on every
frame publishes a pulse the shader stack can read: a frame counter, the frame
delta, and the output dimensions, written as
[font=Courier New]ElderRuntimeFramePulse[/font].

What it does [b]not[/b] do yet is change the image. No shipped shader consumes
that pulse to alter output, so installing this will not make your game look
different. The bridge is built and running; what sits on top of it is next.

If you are looking for a preset that changes your visuals today, this is not
that yet. Nothing below oversells it.

[size=4]What is here and is real[/size]

[b]A five-tier quality contract with complete preset trees.[/b] Performance,
Balanced, Quality, Ultra, and Cinematic, each a full set of ten INI files: nine
[font=Courier New].fx.ini[/font] plus [font=Courier New]elder-quality.ini[/font].
Fifty files in total, and none of them a stub.

Every tier is generated from one canonical manifest with fixed sample counts per
tier: ambient-occlusion directions and steps, screen-space reflection steps,
depth-of-field rings, bloom radius, lens ghosts, and room-light refinement. The
tiers are a contract rather than a set of hand-tuned guesses, so a preset author
building on Elder knows exactly what each tier promises.

Generation is deterministic. The build generates the whole set twice and compares
sorted paths and bytes, so the tiers cannot drift between builds.

[b]A native colour pipeline schema[/b]: generated shader parameter definitions, a
compiled reference object, the parameter manifest, and a default profile. These
have CPU references and software-device parity, and they are the substrate the
rendering payload will bind to.

[b]A transactional profile and preset engine[/b] behind it, with hash-locked
catalogs, so a profile change is applied as a unit or not at all.

[size=4]What is verified[/size]

The native suite is 14 tests, all passing. The quality-preset gate proves exactly
five tier directories, exactly fifty INI files, and byte-identical output across
two generations. The release archive is deterministic, with fixed timestamps and
a SHA-256 sidecar, verified byte-identical across two runs.

The frame driver has its own suite: a first frame publishes inactive rather than
guessing a delta, a steady frame advances the counter exactly once, a lost render
info publishes inactive without advancing, and an out-of-range or non-finite
delta is rejected. The inactive payload is written rather than skipped, so a
stale live value can never sit in front of shaders after the bridge goes away.

What is not verified is anything visual, because nothing consumes the pulse to
change output yet. The live SE, AE, and ENB 0.504 acceptance gates are also ahead
of this release.

[size=4]Who this is for right now[/size]

Preset authors and people who want to build on the tier contract, rather than
players looking for a look. If you install it expecting a visual change, you will
be disappointed, and that is the honest position rather than a soft sell.

[size=4]Credits[/size]

Prior shader-author attribution is preserved in the shader headers and in
[font=Courier New]Docs/NOTICE.md[/font], and is not waived by the licence. No
third-party shader source, decompilation output, or ENB binary is redistributed
here.

[size=4]Install[/size]

[list=1]
[*]Install ENBSeries and its binaries into your game root first.
[*]Install this mod with a mod manager.
[*]Pick a tier from [font=Courier New]Presets[/font] and copy its contents into
your enbseries folder.
[*]Copy the runtime plugin from [font=Courier New]Root/enbseries[/font] into
your game-root enbseries folder if you want the frame pulse published.
[/list]

[size=4]Source and license[/size]

MIT licensed. Source, the tier manifest, and the generator:
https://github.com/HarperZ9/elder-enb

## Permissions (open, MIT-aligned)

- Users can modify this file: yes
- Users can convert this file to work with other games: yes
- Users can use assets from this file without permission with credit: yes
- Others can use assets in this file with credit, without permission: yes
- Upload to other sites: yes, with credit

State on the page: this mod is MIT licensed; use it, modify it, and build presets
on it, with credit. Prior shader-author attribution in the headers is not waived
by that licence and must be preserved.
