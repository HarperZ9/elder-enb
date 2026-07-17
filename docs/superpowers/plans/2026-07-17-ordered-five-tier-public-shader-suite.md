# Elder ENB Ordered Five-Tier Public Shader Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Elder's dense legacy-adapted shader surround with a restrained, artifact-resistant, nine-stage Elder-owned ENBSeries 0.504 suite and five complete quality presets.

**Architecture:** One modular HLSL tree consumes Elder's existing typed color and room-light cores and produces five compile-time quality permutations. A canonical CSV generates complete presets. The ENB plugin publishes validated parameters; normal ENB shader stages own rendering.

**Tech Stack:** Effects 11 / HLSL Shader Model 5, x64 FXC 10.0.26100, CMake 4.2+, C++23, D3D11 WARP, ENB SDK 1002, enb-runtime-core.

## Global Constraints

- Preserve the Elder native parameter ABI fingerprint contract.
- Preserve `ElderColorCore.fxh` and `ElderRoomLight.fxh` CPU/WARP parity.
- Preserve the `SB_Retain` contract in every SkyrimBridge-consuming stage.
- `ELDER_QUALITY_TIER` accepts exactly `0..4`; authored default is `1` (`Balanced`).
- Keep color linear/HDR until `enbeffect.fx`; LDR postpass dithers last.
- The runtime callback publishes parameters and never injects unsupported draw calls.
- Do not copy legacy shader source, private reversal material, or protected artifacts.
- Do not package ENB binaries, legacy shaders, recovered corpus, or permission-dependent replacement plugins.
- Kitsuune-compatible behavior is implemented through independently authored schemas/adapters and clearly credited.

---

### Task 1: Five-tier Elder quality contract and complete presets

**Files:**
- Create: `config/quality-tiers.csv`
- Create: `shaders/elder/ElderQuality.fxh`
- Create: `cmake/GenerateElderQualityPresets.cmake`
- Create: `cmake/CheckElderQualityPresets.cmake`
- Modify: `CMakeLists.txt`

**Interfaces:**
- Consumes: canonical CSV and CMake build root.
- Produces: `ELDER_QUALITY_TIER`, fixed sample constants, and five deterministic preset trees.

- [ ] **Step 1: Register a failing quality-preset test**

```cmake
add_test(
  NAME elder_quality_presets
  COMMAND "${CMAKE_COMMAND}"
    "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
    "-DELDER_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderQualityPresets.cmake")
set_tests_properties(elder_quality_presets PROPERTIES
  LABELS "shader;quality;presets;determinism")
```

- [ ] **Step 2: Run and confirm failure**

Run: `ctest --preset vs2026-debug -R "^elder_quality_presets$" --output-on-failure`

Expected: FAIL because the manifest/generator is absent.

- [ ] **Step 3: Add the canonical rows**

```csv
tier,id,label,ao_directions,ao_steps,ssr_steps,dof_rings,bloom_radius,lens_ghosts,room_light_refinement
0,performance,Performance,4,2,0,0,2,0,0
1,balanced,Balanced,6,3,0,2,3,1,1
2,quality,Quality,8,4,8,3,4,2,1
3,ultra,Ultra,12,5,12,4,5,2,2
4,cinematic,Cinematic,16,6,16,5,6,3,2
```

- [ ] **Step 4: Implement the compile-time include**

```hlsl
#ifndef ELDER_QUALITY_TIER
#define ELDER_QUALITY_TIER 1
#endif
#if ELDER_QUALITY_TIER < 0 || ELDER_QUALITY_TIER > 4
#error ELDER_QUALITY_TIER must be in [0,4]
#endif
static const uint ElderQualityTier = ELDER_QUALITY_TIER;
```

Define all row values as fixed constants in five preprocessor branches. Runtime controls may scale intensities but may not change loop bounds.

- [ ] **Step 5: Generate complete preset trees**

Each tier writes all nine `.fx.ini` files plus `elder-quality.ini`, begins with product/tier provenance comments, and includes master enable, bounded intensity, and advanced shape values for every stage. The checker generates twice and compares sorted paths and bytes; require exactly five directories and 50 INI files.

- [ ] **Step 6: Re-run**

Run: `ctest --preset vs2026-debug -R "^elder_quality_presets$" --output-on-failure`

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add config/quality-tiers.csv shaders/elder/ElderQuality.fxh cmake/GenerateElderQualityPresets.cmake cmake/CheckElderQualityPresets.cmake CMakeLists.txt
git commit -m "feat: add five Elder quality presets"
```

### Task 2: Shared Elder pipeline contract and 45-permutation compile matrix

**Files:**
- Create: `shaders/elder/ElderPipelineCommon.fxh`
- Create: `shaders/elder/ElderStageParameters.fxh`
- Create: `shaders/enbeffectprepass.fx`
- Create: `shaders/enbdepthoffield.fx`
- Create: `shaders/enbbloom.fx`
- Create: `shaders/enbadaptation.fx`
- Create: `shaders/enblens.fx`
- Create: `shaders/enbeffect.fx`
- Create: `shaders/enbeffectpostpass.fx`
- Create: `shaders/enbsunsprite.fx`
- Create: `shaders/enbunderwater.fx`
- Create: `cmake/CompileElderStage.cmake`
- Create: `cmake/CheckElderStageMatrix.cmake`
- Modify: `CMakeLists.txt`

**Interfaces:**
- Consumes: ENB stage inputs, `ElderQuality.fxh`, generated/native parameter include.
- Produces: shared finite/depth helpers and nine host-correct stages for five tiers.

- [ ] **Step 1: Register the failing compile matrix**

```cmake
add_test(
  NAME elder_stage_compile_matrix
  COMMAND "${CMAKE_COMMAND}"
    "-DELDER_FXC=${ELDER_FXC_EXECUTABLE}"
    "-DELDER_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
    "-DELDER_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/CheckElderStageMatrix.cmake")
set_tests_properties(elder_stage_compile_matrix PROPERTIES
  LABELS "shader;fxc;quality;matrix")
```

- [ ] **Step 2: Run and confirm missing-stage failure**

Run: `ctest --preset vs2026-debug -R "^elder_stage_compile_matrix$" --output-on-failure`

Expected: FAIL naming `shaders/enbeffectprepass.fx`.

- [ ] **Step 3: Implement the shared contract**

```hlsl
bool ElderFinite1(float value)
{
    return (asuint(value) & 0x7fffffffu) < 0x7f800000u;
}

float3 ElderFiniteOrBlack(float3 value)
{
    return all((asuint(value) & 0x7fffffffu) < 0x7f800000u.xxx)
        ? max(value, 0.0.xxx)
        : 0.0.xxx;
}

float ElderDepthMask(float raw_depth, float threshold, float feather)
{
    float edge = clamp(feather, 0.00001, 0.005);
    return smoothstep(clamp(threshold, 0.99, 1.0),
                      min(clamp(threshold, 0.99, 1.0) + edge, 1.0),
                      raw_depth);
}
```

- [ ] **Step 4: Add restrained ordered UI parameters**

Use `[Elder 00]` through `[Elder 90]`; expose master, tier/reset guidance, stage enable/intensity, then advanced shape. Defaults match Balanced. Every intensity zero is identity.

- [ ] **Step 5: Add nine identity stages**

All stages compile with their official ENB technique names and preserve input until subsequent tasks add owned behavior. `enbeffect.fx` includes and evaluates `ElderColorCore.fxh`; its disabled master path remains finite-safe.

- [ ] **Step 6: Implement and run the matrix**

Compile nine stages × five tiers using `/Ges /WX /O3`, with listings below `out/build/.../shader-matrix/<tier>/`.

Run: `ctest --preset vs2026-debug -R "^elder_stage_compile_matrix$" --output-on-failure`

Expected: PASS, 45 stage/tier compilations.

- [ ] **Step 7: Commit**

```powershell
git add shaders cmake/CompileElderStage.cmake cmake/CheckElderStageMatrix.cmake CMakeLists.txt
git commit -m "feat: establish ordered Elder shader stages"
```

### Task 3: HDR prepass, room-light publication, and restrained scene effects

**Files:**
- Create: `shaders/elder/ElderPrepassCore.fxh`
- Create: `shaders/elder/ElderRuntimeParameters.fxh`
- Modify: `shaders/enbeffectprepass.fx`
- Modify: `native/shaders/ElderRoomLight.fxh`
- Modify: `native/tests/RoomLightTests.cpp`
- Modify: `native/tests/RoomLightWarpTests.cpp`
- Modify: `CMakeLists.txt`

**Interfaces:**
- Consumes: scene/depth, interior factor, validated Elder room-light payload, tier constants.
- Produces: one HDR prepass result with room light, weather atmosphere, and optional AO/SSR composed once.

- [ ] **Step 1: Add failing room-light integration cases**

Cover:

```text
exterior-preserves-room-payload
sealed-room-keeps-ambient-floor
partial-aperture-is-bounded
invalid-runtime-preserves-scene
interior-transition-is-continuous
```

- [ ] **Step 2: Run focused tests**

Run: `ctest --preset vs2026-debug -R "elder_room_light_(cpp|warp)" --output-on-failure`

Expected: FAIL on missing published-payload integration cases.

- [ ] **Step 3: Add hidden runtime parameters**

```hlsl
float4 ElderRuntimeRoomLight
<
    string UIName = "Elder Runtime | Room Light";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};

float4 ElderRuntimeStatus
<
    string UIName = "Elder Runtime | Status";
    int UIHidden = 1;
> = {0.0, 0.0, 0.0, 0.0};
```

Room light `.x` is bounded luminance, `.y` is exterior daylight, `.z` is open fraction, `.w` is sealed. Status commits valid last.

- [ ] **Step 4: Implement one prepass compositor**

```hlsl
float3 ElderComposePrepass(
    float2 uv,
    float3 scene,
    float raw_depth,
    float interior_factor);
```

Invalid runtime returns finite scene exactly. Exterior never consumes room light. Interior blends a bounded luminance ratio without crushing the ambient floor. AO and SSR are disabled for tiers that specify zero loops.

- [ ] **Step 5: Run focused tests and matrix**

Run: `ctest --preset vs2026-debug -R "elder_(room_light_.*|stage_compile_matrix)" --output-on-failure`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add shaders native/shaders/ElderRoomLight.fxh native/tests CMakeLists.txt
git commit -m "feat: integrate Elder room light in HDR prepass"
```

### Task 4: Elder optical stages

**Files:**
- Create: `shaders/elder/ElderDepthOfField.fxh`
- Create: `shaders/elder/ElderBloom.fxh`
- Create: `shaders/elder/ElderAdaptation.fxh`
- Create: `shaders/elder/ElderLens.fxh`
- Modify: `shaders/enbdepthoffield.fx`
- Modify: `shaders/enbbloom.fx`
- Modify: `shaders/enbadaptation.fx`
- Modify: `shaders/enblens.fx`
- Create: `cmake/CheckElderOpticalContracts.cmake`
- Modify: `CMakeLists.txt`

**Interfaces:**
- Consumes: HDR scene/depth/aperture, adaptation history, tier constants.
- Produces: isolated DOF, bloom, adaptation, and lens outputs.

- [ ] **Step 1: Add failing tier/identity checks**

Require the exact tier budgets from `config/quality-tiers.csv`, zero-strength identity, no `discard`, bloom soft-knee extraction, and lens consumption of bloom rather than raw scene.

- [ ] **Step 2: Run and confirm failure**

Run: `ctest --preset vs2026-debug -R "^elder_optical_contracts$" --output-on-failure`

Expected: FAIL before optical modules exist.

- [ ] **Step 3: Implement bounded optical interfaces**

```hlsl
float3 ElderApplyDepthOfField(float2 uv, float3 scene, float linear_depth);
float3 ElderApplyBloom(float2 uv, float3 hdr_source);
float ElderUpdateAdaptedLuminance(float measured, float history, float delta_seconds);
float3 ElderApplyLens(float2 uv, float3 bloom, float3 scene);
```

Performance defaults DOF off. Adaptation validates history and clamps transition rates. Bloom and lens cannot invoke general scene blur or grading.

- [ ] **Step 4: Run optical, color, and matrix tests**

Run: `ctest --preset vs2026-debug -R "elder_(optical_contracts|color_.*|stage_compile_matrix)" --output-on-failure`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add shaders cmake/CheckElderOpticalContracts.cmake CMakeLists.txt
git commit -m "feat: add restrained Elder optical stages"
```

### Task 5: Main color, LDR finish, sun, and underwater stages

**Files:**
- Create: `shaders/elder/ElderPostFinish.fxh`
- Create: `shaders/elder/ElderSunSprite.fxh`
- Create: `shaders/elder/ElderUnderwater.fxh`
- Modify: `shaders/enbeffect.fx`
- Modify: `shaders/enbeffectpostpass.fx`
- Modify: `shaders/enbsunsprite.fx`
- Modify: `shaders/enbunderwater.fx`
- Create: `cmake/CheckElderCompositionContracts.cmake`
- Modify: `CMakeLists.txt`

**Interfaces:**
- Consumes: prepass scene, bloom/lens, generated Elder parameters, sun visibility, underwater mask.
- Produces: one color-core evaluation, minimal LDR finish, bounded celestial optics, exclusive underwater medium.

- [ ] **Step 1: Add failing composition ownership checks**

Require `ElderEvaluateColorCore` exactly once in `enbeffect.fx`; require dithering to be the final postpass color operation; reject bloom/lens/fog from postpass; reject air-atmosphere calls from underwater.

- [ ] **Step 2: Run and confirm failure**

Run: `ctest --preset vs2026-debug -R "^elder_composition_contracts$" --output-on-failure`

Expected: FAIL before completed stage ownership.

- [ ] **Step 3: Implement display-stage interfaces**

```hlsl
float3 ElderFinishLdr(float2 uv, float3 display_color);
float3 ElderEvaluateSunSprite(float2 uv, float3 sun_direction, float visibility);
float3 ElderEvaluateUnderwater(float2 uv, float3 scene, float linear_depth);
```

Finish order is vignette, fine grain, triangular dither. Alpha is always `1.0`. Underwater uses one absorption/scattering model and disables air fog, lens dirt, and duplicate god rays.

- [ ] **Step 4: Run composition, color parity, and matrix tests**

Run: `ctest --preset vs2026-debug -R "elder_(composition_contracts|color_.*|stage_compile_matrix)" --output-on-failure`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add shaders cmake/CheckElderCompositionContracts.cmake CMakeLists.txt
git commit -m "feat: complete ordered Elder display stages"
```

### Task 6: Elder ENB parameter-publication runtime

**Files:**
- Create: `native/runtime/include/elder/runtime/ShaderParameterBridge.hpp`
- Create: `native/runtime/src/ShaderParameterBridge.cpp`
- Create: `native/runtime/include/elder/runtime/RenderPayloadController.hpp`
- Create: `native/runtime/src/RenderPayloadController.cpp`
- Create: `native/runtime/tests/RenderPayloadControllerTests.cpp`
- Modify: `native/runtime/src/windows/PluginMain.cpp`
- Modify: `native/runtime/CMakeLists.txt`
- Modify: `shaders/elder/ElderRuntimeParameters.fxh`

**Interfaces:**
- Consumes: ENB SDK get/set parameter exports, validated Elder color profile/room-light state, callback lifecycle.
- Produces: transactional hidden shader parameters; status validity writes last and baseline restores on save/reset/exit.

- [ ] **Step 1: Add failing controller tests**

Test baseline capture, invalid status first, payload values second, valid status last, rollback on every injected write failure, baseline restore, missing-key failure, and non-finite rejection.

- [ ] **Step 2: Run focused runtime tests**

Run: `ctest --test-dir out/build/vs2026-x64 -C Debug -R "elder_runtime_render_payload" --output-on-failure`

Expected: FAIL because the bridge/controller do not exist.

- [ ] **Step 3: Define the payload**

```cpp
struct RenderPayload final {
    std::array<float, 4> room_light{};
    std::array<float, 4> exposure_color{};
    std::array<float, 4> status{};
};
```

Status `.x = 1.0F`, `.y = valid`, `.z = folded generation`, `.w = schema fingerprint tag`. Do not expose pointers or mutate game render state.

- [ ] **Step 4: Implement callback publication**

Replace the no-op callback with lifecycle dispatch that only enters ENB callback scope, captures/restores authored values, and publishes validated payloads. It must not issue D3D calls.

- [ ] **Step 5: Run runtime and shader tests**

Run: `ctest --preset vs2026-debug -R "elder_(runtime_.*|stage_compile_matrix|room_light_.*|color_.*)" --output-on-failure`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add native/runtime shaders/elder/ElderRuntimeParameters.fxh
git commit -m "feat: publish Elder render parameters through ENB"
```

### Task 7: Public package, licenses, credits, and focused acceptance

**Files:**
- Modify: `CMakeLists.txt`
- Create: `cmake/CheckElderPublicReleasePackage.cmake`
- Modify: `README.md`
- Modify: `native/README.md`
- Modify: `native/NOTICE.md`
- Modify: `docs/ARCHITECTURE.md`
- Create: `docs/release-validation.md`
- Create: `CREDITS-AND-PROVENANCE.md`
- Create: `THIRD_PARTY_NOTICES.md`

**Interfaces:**
- Consumes: nine Elder stages, five presets, runtime plugin, MIT license, provenance/exclusion rules.
- Produces: deterministic `Elder-ENB-1.0.0-win64.zip`, SHA-256 sidecar, exact manifest, public documentation.

- [ ] **Step 1: Add a failing public-package test**

Require nine `.fx` files, Elder includes, five complete presets, runtime plugin, README/license/credits/notices. Reject ENB binaries, legacy shader/Addons trees, recovered preset corpus, private/protected material, test/compiler binaries, `.pdb`, `RC`, and permission-dependent replacement plugins.

- [ ] **Step 2: Run and confirm failure**

Run: `ctest --preset vs2026-release -R "^elder_public_release_package$" --output-on-failure`

Expected: FAIL because only the native RC package exists.

- [ ] **Step 3: Add deterministic public packaging**

Use fixed archive timestamps and:

```cmake
set(ELDER_PUBLIC_PACKAGE_NAME "Elder-ENB-1.0.0-win64")
```

Build two archives independently, compare bytes, extract one, and hash every approved file.

- [ ] **Step 4: Correct licensing and provenance docs**

Replace stale “no license selected” text with the repository's MIT status. Credit Kitsuune/LonelyKitsuune for KreatE, AELAS/EVLaS, ELIF, NativeEditorID Fix, ENBWorldspaceWeatherlists/KiLoader, and relevant legacy shader lineage. State that binary-reversal history is not clean-room. Describe the public Elder implementation as independently authored and interoperable; exclude uncleared replacement components.

- [ ] **Step 5: Run targeted release gates**

Run:

```powershell
ctest --preset vs2026-release -R "elder_(quality_presets|stage_compile_matrix|optical_contracts|composition_contracts|color_.*|room_light_.*|runtime_.*|public_release_package)" --output-on-failure
cmake --build --preset vs2026-release --target elder_public_release_package
```

Expected: selected tests PASS and deterministic ZIP/checksum are produced.

- [ ] **Step 6: Record live acceptance honestly**

Validate Performance, Balanced, and Cinematic first through Computer control in the installed Mod Organizer profile. Record compile overlay, camera/FOV, weather, interior/exterior, menu, save/load, reload, missing-runtime fallback, underwater, and high-contrast artifact results. Do not mark SE/AE combinations passed unless actually run.

- [ ] **Step 7: Commit**

```powershell
git add CMakeLists.txt cmake README.md native/README.md native/NOTICE.md docs CREDITS-AND-PROVENANCE.md THIRD_PARTY_NOTICES.md
git commit -m "chore: prepare Elder ENB public shader release"
```
