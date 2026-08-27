# Elder ENB third-party notices

This notice is for the public Elder ENB copy. It distinguishes Elder-owned MIT
material from external tools, hosts, references, historical shader lineage, and
excluded proprietary components.

## License boundary

Elder-owned code and documentation are licensed under the MIT License in
`LICENSE`. That license does not apply to third-party projects, binaries,
textures, shader implementations, recovered legacy material, protected evidence,
or permission-dependent plugin replacements.

No public Elder archive may rely on this notice to redistribute material the
project does not own. If a future archive adds third-party content, update this
file with the exact license and attribution for that content before upload.

## External runtime requirements

- ENBSeries 0.504 is an external user-installed requirement for the public ENB
  shader suite. Elder does not redistribute ENB binaries.
- Skyrim Special Edition / Anniversary Edition is the target game family.
- SkyrimBridge and other bridge plugins are optional interoperability paths only
  when present. They are not hard requirements for the independent suite.
- KreatE, Silent Horizons, AELAS/EVLaS, ELIF, NativeEditorID Fix,
  ENBWorldspaceWeatherlists/KiLoader, and similar historical or permission-gated
  projects are not bundled or required by the independent public suite.

## Build and validation tools

CMake, Visual Studio/MSVC, FXC, and D3D11 WARP may be used by maintainers for
build and validation. Their binaries are not part of the Elder source license
and must not be redistributed inside the Elder archive.

The optional native runtime builds against a pinned `enb-runtime-core` source
dependency. Before shipping a runtime-linked public archive, verify and include
the applicable `enb-runtime-core` license/notice in the final package notices.

## Historical shader/source lineage not shipped

The repository preserves attribution to prior shader authors and technique
references, including Boris Vorontsov / ENBSeries, kingeric1992, Kitsuune /
LonelyKitsuune / Skratzer / T. Thanner, Marty McFly / Pascal Gilcher,
TheSandvichMaker / ReforgedUI, TreyM, l00ping / L00ping, Adyss, AMON ENB /
Reforged, Bjorn Ottosson, ASC, Stephen Hill, Troy Sobotka, Timothy Lottes, John
Hable, Hejl-Burgess, Gran Turismo, Sébastien Hillaire, Maxime Heckel, Therrien,
Levesque, Gilet, Jimenez, and Karis.

These credits preserve provenance. They do not mean their proprietary,
non-commercial, no-derivatives, binary, recovered, or otherwise restricted
implementations are included in Elder or relicensed under MIT.

## Excluded from public Elder archives

Public Elder archives must not include:

- ENBSeries binaries;
- protected evidence, private reverse-engineering notes, or recovered corpus
  material;
- legacy adapted shader/Addons trees that are not owned by Elder;
- proprietary Kitsuune/LonelyKitsuune/Skratzer/T. Thanner implementations or
  permission-dependent replacement plugins;
- compiler/test binaries, `.pdb` files, build intermediates, or local RC
  artifacts;
- third-party files whose redistribution rights have not been recorded here.

## Media notice

Generated abstract artwork used on a Nexus page is promotional only and is not
gameplay evidence. It must be tagged with Nexus's AI Media tag. Any visual claim
about Elder requires labeled real in-game captures identifying tier, ENB
version, game edition, location/weather/interior state, and runtime status.
