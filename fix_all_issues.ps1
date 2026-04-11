# Fix all issues: Alternative Baseline headers, UIOrdering, and Vignette strength
$overlaysFolder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

# ============================================
# 1. FIX ALTERNATIVE BASELINE FILES
# ============================================
Write-Host "=== FIXING ALTERNATIVE BASELINE FILES ===" -ForegroundColor Yellow

$altBaseline1 = "$overlaysFolder\0. OPTIONAL - Alternative Baseline 1.ini"
$altBaseline2 = "$overlaysFolder\1. OPTIONAL - Alternative Baseline 2.ini"

# Read existing content and add header
foreach ($file in @(
    @{ Path = $altBaseline1; Name = "Alternative Baseline 1"; Desc = "Your handcrafted alternative preset profile 1. Comprehensive tuning of volumetric fog, lighting, SSAO, and visual atmosphere."; Order = 0 },
    @{ Path = $altBaseline2; Name = "Alternative Baseline 2"; Desc = "Your handcrafted alternative preset profile 2. Extended tuning with additional environment and effect adjustments."; Order = 1 }
)) {
    if (Test-Path $file.Path) {
        $content = Get-Content $file.Path -Raw

        # Check if already has OVERLAYINFO
        if ($content -notmatch '\[OVERLAYINFO\]') {
            $header = @"
[OVERLAYINFO]
UIName = OPTIONAL - $($file.Name)
UIGroups = Optional Styles
UIDesc = $($file.Desc)
UIOrdering = $($file.Order)
NeedsNoApply = false
IncompatibleOverlays =

"@
            # Remove BOM if present and add header
            $content = $content -replace '^\xEF\xBB\xBF', ''
            $content = $content.TrimStart()
            $newContent = $header + $content
            Set-Content -Path $file.Path -Value $newContent -Encoding UTF8
            Write-Host "  Added OVERLAYINFO to: $($file.Name)" -ForegroundColor Green
        } else {
            Write-Host "  Already has OVERLAYINFO: $($file.Name)" -ForegroundColor Cyan
        }
    }
}

# ============================================
# 2. FIX UIORDERING FOR ALL OPTIONAL PRESETS
# ============================================
Write-Host "`n=== FIXING UIORDERING FOR OPTIONAL PRESETS ===" -ForegroundColor Yellow

$optionalPresets = @(
    @{ File = "0. OPTIONAL - Alternative Baseline 1.ini"; Order = 0 },
    @{ File = "1. OPTIONAL - Alternative Baseline 2.ini"; Order = 1 },
    @{ File = "2. OPTIONAL - Cinematic Drama.ini"; Order = 2 },
    @{ File = "3. OPTIONAL - Deep Contrast.ini"; Order = 3 },
    @{ File = "4. OPTIONAL - Fantasy Vivid.ini"; Order = 4 },
    @{ File = "5. OPTIONAL - Golden Hour.ini"; Order = 5 },
    @{ File = "6. OPTIONAL - Lifted Shadows.ini"; Order = 6 },
    @{ File = "7. OPTIONAL - Linear Light 1.8.ini"; Order = 7 },
    @{ File = "8. OPTIONAL - Natural Documentary.ini"; Order = 8 },
    @{ File = "9. OPTIONAL - Nordic Light.ini"; Order = 9 }
)

foreach ($preset in $optionalPresets) {
    $path = Join-Path $overlaysFolder $preset.File
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        # Update UIOrdering value
        $content = $content -replace 'UIOrdering\s*=\s*\d+', "UIOrdering = $($preset.Order)"
        Set-Content -Path $path -Value $content -Encoding UTF8
        Write-Host "  Set UIOrdering = $($preset.Order) for $($preset.File)" -ForegroundColor Green
    }
}

# ============================================
# 3. FIX VIGNETTE PRESETS - MAKE MORE IMPACTFUL
# ============================================
Write-Host "`n=== STRENGTHENING VIGNETTE PRESETS ===" -ForegroundColor Yellow

# Baseline values from enbeffectpostpass.fx.ini:
# Enable=false, Inner Radius=0.3, Outer Radius=0.9, Width=0.35, Height=0.6, Curve=1.0, Roundness=0.35

$vignettePresets = @{
    "149. VIGNETTE - Cinema Wide.ini" = @"
[OVERLAYINFO]
UIName = VIGNETTE - Cinema Wide
UIGroups = Vignette
UIDesc = Wide cinematic vignette with horizontal emphasis. Creates immersive widescreen atmosphere.
UIOrdering = 149
NeedsNoApply = false
IncompatibleOverlays =

; ============================================
; Cinema Wide - Horizontal widescreen vignette
; ============================================

[OVERLAYPARAM1]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Enable
Value = true

[OVERLAYPARAM2]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Inner Radius
Operation = "= 0.45"

[OVERLAYPARAM3]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Outer Radius
Operation = "= 0.85"

[OVERLAYPARAM4]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Width
Operation = "= 0.65"

[OVERLAYPARAM5]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Height
Operation = "= 0.35"

[OVERLAYPARAM6]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Roundness
Operation = "= 0.15"

[OVERLAYPARAM7]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Curve
Operation = "= 1.5"
"@

    "150. VIGNETTE - Classic Portrait.ini" = @"
[OVERLAYINFO]
UIName = VIGNETTE - Classic Portrait
UIGroups = Vignette
UIDesc = Traditional rounded vignette that draws focus to the center. Classic photographic look.
UIOrdering = 150
NeedsNoApply = false
IncompatibleOverlays =

; ============================================
; Classic Portrait - Traditional rounded vignette
; ============================================

[OVERLAYPARAM1]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Enable
Value = true

[OVERLAYPARAM2]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Inner Radius
Operation = "= 0.35"

[OVERLAYPARAM3]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Outer Radius
Operation = "= 0.75"

[OVERLAYPARAM4]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Width
Operation = "= 0.5"

[OVERLAYPARAM5]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Height
Operation = "= 0.5"

[OVERLAYPARAM6]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Roundness
Operation = "= 0.7"

[OVERLAYPARAM7]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Curve
Operation = "= 1.8"
"@

    "151. VIGNETTE - Heavy Dramatic.ini" = @"
[OVERLAYINFO]
UIName = VIGNETTE - Heavy Dramatic
UIGroups = Vignette
UIDesc = Strong dramatic vignette with deep corner darkening. Maximum atmospheric impact.
UIOrdering = 151
NeedsNoApply = false
IncompatibleOverlays =

; ============================================
; Heavy Dramatic - Strong corner darkening
; ============================================

[OVERLAYPARAM1]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Enable
Value = true

[OVERLAYPARAM2]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Inner Radius
Operation = "= 0.2"

[OVERLAYPARAM3]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Outer Radius
Operation = "= 0.65"

[OVERLAYPARAM4]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Width
Operation = "= 0.45"

[OVERLAYPARAM5]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Height
Operation = "= 0.45"

[OVERLAYPARAM6]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Roundness
Operation = "= 0.5"

[OVERLAYPARAM7]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Curve
Operation = "= 2.2"
"@

    "152. VIGNETTE - None (Disabled).ini" = @"
[OVERLAYINFO]
UIName = VIGNETTE - None (Disabled)
UIGroups = Vignette
UIDesc = Disables vignette effect completely for a clean, unobstructed view.
UIOrdering = 152
NeedsNoApply = false
IncompatibleOverlays =

; ============================================
; Disabled - No vignette
; ============================================

[OVERLAYPARAM1]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Enable
Value = false
"@

    "153. VIGNETTE - Soft Vintage.ini" = @"
[OVERLAYINFO]
UIName = VIGNETTE - Soft Vintage
UIGroups = Vignette
UIDesc = Gentle vintage-style vignette with soft falloff. Nostalgic film photography feel.
UIOrdering = 153
NeedsNoApply = false
IncompatibleOverlays =

; ============================================
; Soft Vintage - Gentle nostalgic vignette
; ============================================

[OVERLAYPARAM1]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Enable
Value = true

[OVERLAYPARAM2]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Inner Radius
Operation = "= 0.5"

[OVERLAYPARAM3]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Outer Radius
Operation = "= 0.95"

[OVERLAYPARAM4]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Width
Operation = "= 0.55"

[OVERLAYPARAM5]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Height
Operation = "= 0.55"

[OVERLAYPARAM6]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Roundness
Operation = "= 0.6"

[OVERLAYPARAM7]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Curve
Operation = "= 0.7"
"@

    "154. VIGNETTE - Subtle Frame.ini" = @"
[OVERLAYINFO]
UIName = VIGNETTE - Subtle Frame
UIGroups = Vignette
UIDesc = Light edge framing that adds depth without being obvious. Natural look.
UIOrdering = 154
NeedsNoApply = false
IncompatibleOverlays =

; ============================================
; Subtle Frame - Light natural vignette
; ============================================

[OVERLAYPARAM1]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Enable
Value = true

[OVERLAYPARAM2]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Inner Radius
Operation = "= 0.55"

[OVERLAYPARAM3]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Outer Radius
Operation = "= 0.98"

[OVERLAYPARAM4]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Width
Operation = "= 0.5"

[OVERLAYPARAM5]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Height
Operation = "= 0.5"

[OVERLAYPARAM6]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Roundness
Operation = "= 0.45"

[OVERLAYPARAM7]
Category = ENBEFFECTPOSTPASS.FX
Name = Vignette.|- Curve
Operation = "= 1.2"
"@
}

foreach ($preset in $vignettePresets.GetEnumerator()) {
    $path = Join-Path $overlaysFolder $preset.Key
    Set-Content -Path $path -Value $preset.Value -Encoding UTF8
    Write-Host "  Rewrote: $($preset.Key)" -ForegroundColor Green
}

Write-Host "`n=== ALL FIXES COMPLETE ===" -ForegroundColor Yellow
Write-Host "1. Alternative Baseline files now have proper OVERLAYINFO headers"
Write-Host "2. OPTIONAL presets have correct UIOrdering (0-9)"
Write-Host "3. Vignette presets now ENABLE the effect and have stronger values"
