# Sync VolumetricLighting, LightingTemplates, ImageSpaces, and ShaderParticleGeometries
# to match each KreatE preset's thematic tone based on weather colors

$PresetsPath = "C:\Users\Zain\ENB\enbseries\KREATE\KreatE"

# Define preset themes with multipliers and adjustments
# Format: Saturation, Brightness, Contrast, TintR, TintG, TintB, TintAlpha, VLColorR, VLColorG, VLColorB
$PresetThemes = @{
    # Base/Reference presets - keep original values
    "10.28.16" = @{ Saturation = 1.0; Brightness = 1.0; Contrast = 1.0; TintR = 0.5; TintG = 0.5; TintB = 0.5; TintA = 0.0; VLR = 0.12; VLG = 0.12; VLB = 0.12 }
    "11.11.11" = @{ Saturation = 1.0; Brightness = 1.0; Contrast = 1.0; TintR = 0.5; TintG = 0.5; TintB = 0.5; TintA = 0.0; VLR = 0.12; VLG = 0.12; VLB = 0.12 }
    "Neutral" = @{ Saturation = 1.0; Brightness = 1.0; Contrast = 1.0; TintR = 0.5; TintG = 0.5; TintB = 0.5; TintA = 0.0; VLR = 0.12; VLG = 0.12; VLB = 0.12 }

    # Cold/Arctic themes - blue tint, slightly desaturated
    "Arctic Silence" = @{ Saturation = 0.92; Brightness = 1.02; Contrast = 0.98; TintR = 0.45; TintG = 0.52; TintB = 0.65; TintA = 0.08; VLR = 0.08; VLG = 0.14; VLB = 0.22 }
    "Jötunheimar" = @{ Saturation = 0.88; Brightness = 0.96; Contrast = 1.05; TintR = 0.42; TintG = 0.50; TintB = 0.62; TintA = 0.10; VLR = 0.06; VLG = 0.12; VLB = 0.20 }
    "Nordic Saga" = @{ Saturation = 0.94; Brightness = 0.98; Contrast = 1.02; TintR = 0.46; TintG = 0.52; TintB = 0.60; TintA = 0.06; VLR = 0.08; VLG = 0.13; VLB = 0.19 }
    "The Revenant" = @{ Saturation = 0.85; Brightness = 0.92; Contrast = 1.08; TintR = 0.44; TintG = 0.50; TintB = 0.58; TintA = 0.12; VLR = 0.07; VLG = 0.11; VLB = 0.18 }

    # Warm/Golden themes - orange/gold tint, high saturation
    "Golden Hour Extreme" = @{ Saturation = 1.15; Brightness = 1.04; Contrast = 1.02; TintR = 0.72; TintG = 0.55; TintB = 0.38; TintA = 0.10; VLR = 0.22; VLG = 0.16; VLB = 0.08 }
    "Arrival of Autumn" = @{ Saturation = 1.08; Brightness = 1.0; Contrast = 1.0; TintR = 0.68; TintG = 0.52; TintB = 0.40; TintA = 0.08; VLR = 0.20; VLG = 0.14; VLB = 0.08 }
    "Desert Mirage" = @{ Saturation = 1.12; Brightness = 1.06; Contrast = 0.98; TintR = 0.70; TintG = 0.58; TintB = 0.42; TintA = 0.08; VLR = 0.22; VLG = 0.18; VLB = 0.10 }
    "Poetic Sepia" = @{ Saturation = 0.88; Brightness = 0.98; Contrast = 1.0; TintR = 0.65; TintG = 0.52; TintB = 0.42; TintA = 0.15; VLR = 0.18; VLG = 0.14; VLB = 0.10 }
    "Samurai Epic" = @{ Saturation = 1.05; Brightness = 0.98; Contrast = 1.04; TintR = 0.62; TintG = 0.50; TintB = 0.42; TintA = 0.06; VLR = 0.18; VLG = 0.14; VLB = 0.10 }

    # Dark/Gothic themes - dark, high contrast, desaturated
    "Gothic Shadows" = @{ Saturation = 0.82; Brightness = 0.88; Contrast = 1.15; TintR = 0.48; TintG = 0.45; TintB = 0.52; TintA = 0.08; VLR = 0.08; VLG = 0.08; VLB = 0.12 }
    "Noir" = @{ Saturation = 0.75; Brightness = 0.92; Contrast = 1.18; TintR = 0.50; TintG = 0.50; TintB = 0.50; TintA = 0.05; VLR = 0.10; VLG = 0.10; VLB = 0.10 }
    "Maritime Noir" = @{ Saturation = 0.80; Brightness = 0.90; Contrast = 1.12; TintR = 0.45; TintG = 0.50; TintB = 0.58; TintA = 0.10; VLR = 0.08; VLG = 0.12; VLB = 0.16 }
    "Somber Tones" = @{ Saturation = 0.78; Brightness = 0.90; Contrast = 1.08; TintR = 0.48; TintG = 0.48; TintB = 0.52; TintA = 0.10; VLR = 0.09; VLG = 0.10; VLB = 0.12 }
    "Wretched" = @{ Saturation = 0.72; Brightness = 0.85; Contrast = 1.20; TintR = 0.46; TintG = 0.44; TintB = 0.48; TintA = 0.12; VLR = 0.06; VLG = 0.06; VLB = 0.08 }

    # Cinematic themes - high contrast with color grading
    "Blockbuster" = @{ Saturation = 1.08; Brightness = 1.0; Contrast = 1.10; TintR = 0.58; TintG = 0.52; TintB = 0.50; TintA = 0.05; VLR = 0.15; VLG = 0.13; VLB = 0.12 }
    "Dramatic Contrast" = @{ Saturation = 0.95; Brightness = 0.96; Contrast = 1.18; TintR = 0.52; TintG = 0.50; TintB = 0.52; TintA = 0.04; VLR = 0.12; VLG = 0.11; VLB = 0.12 }
    "Storm and Chaos" = @{ Saturation = 0.90; Brightness = 0.88; Contrast = 1.15; TintR = 0.48; TintG = 0.50; TintB = 0.55; TintA = 0.10; VLR = 0.08; VLG = 0.10; VLB = 0.14 }

    # Monochrome themes - very desaturated
    "Monochrome Classic" = @{ Saturation = 0.65; Brightness = 0.98; Contrast = 1.05; TintR = 0.50; TintG = 0.50; TintB = 0.50; TintA = 0.02; VLR = 0.11; VLG = 0.11; VLB = 0.11 }
    "Monochrome Dramatic" = @{ Saturation = 0.60; Brightness = 0.94; Contrast = 1.20; TintR = 0.50; TintG = 0.50; TintB = 0.50; TintA = 0.02; VLR = 0.10; VLG = 0.10; VLB = 0.10 }

    # Blue/Night themes
    "Moody Blue Hour" = @{ Saturation = 0.92; Brightness = 0.94; Contrast = 1.02; TintR = 0.42; TintG = 0.48; TintB = 0.62; TintA = 0.12; VLR = 0.06; VLG = 0.10; VLB = 0.18 }
    "Mystic Night" = @{ Saturation = 0.95; Brightness = 0.88; Contrast = 1.05; TintR = 0.48; TintG = 0.45; TintB = 0.60; TintA = 0.10; VLR = 0.08; VLG = 0.08; VLB = 0.16 }

    # Vibrant/Fantasy themes - high saturation
    "Vibrant Fantasy" = @{ Saturation = 1.20; Brightness = 1.02; Contrast = 1.02; TintR = 0.52; TintG = 0.52; TintB = 0.55; TintA = 0.03; VLR = 0.14; VLG = 0.14; VLB = 0.16 }
    "Neon Dreams" = @{ Saturation = 1.25; Brightness = 1.0; Contrast = 1.05; TintR = 0.55; TintG = 0.48; TintB = 0.60; TintA = 0.05; VLR = 0.15; VLG = 0.12; VLB = 0.18 }
    "Emerald Forest" = @{ Saturation = 1.12; Brightness = 1.0; Contrast = 1.0; TintR = 0.45; TintG = 0.58; TintB = 0.48; TintA = 0.08; VLR = 0.10; VLG = 0.18; VLB = 0.12 }

    # Soft/Dreamy themes - low contrast, bright
    "Pastel Dream" = @{ Saturation = 0.88; Brightness = 1.08; Contrast = 0.92; TintR = 0.58; TintG = 0.55; TintB = 0.60; TintA = 0.06; VLR = 0.15; VLG = 0.14; VLB = 0.16 }
    "High Key" = @{ Saturation = 0.92; Brightness = 1.12; Contrast = 0.90; TintR = 0.52; TintG = 0.52; TintB = 0.55; TintA = 0.04; VLR = 0.14; VLG = 0.14; VLB = 0.15 }
    "Contemplative" = @{ Saturation = 0.90; Brightness = 1.0; Contrast = 0.95; TintR = 0.52; TintG = 0.52; TintB = 0.54; TintA = 0.05; VLR = 0.12; VLG = 0.12; VLB = 0.13 }

    # Vintage/Film themes
    "Faded Film" = @{ Saturation = 0.82; Brightness = 1.02; Contrast = 0.95; TintR = 0.58; TintG = 0.54; TintB = 0.50; TintA = 0.12; VLR = 0.16; VLG = 0.14; VLB = 0.12 }
    "Elder Originals" = @{ Saturation = 0.95; Brightness = 0.98; Contrast = 1.02; TintR = 0.55; TintG = 0.52; TintB = 0.48; TintA = 0.06; VLR = 0.14; VLG = 0.13; VLB = 0.11 }

    # Natural/Documentary themes
    "Natural Documentary" = @{ Saturation = 1.02; Brightness = 1.0; Contrast = 1.0; TintR = 0.50; TintG = 0.50; TintB = 0.50; TintA = 0.02; VLR = 0.12; VLG = 0.12; VLB = 0.12 }
    "Wanderer" = @{ Saturation = 0.98; Brightness = 1.0; Contrast = 1.0; TintR = 0.52; TintG = 0.52; TintB = 0.52; TintA = 0.03; VLR = 0.12; VLG = 0.12; VLB = 0.12 }

    # Special themes
    "The Zone" = @{ Saturation = 0.75; Brightness = 0.92; Contrast = 1.08; TintR = 0.48; TintG = 0.52; TintB = 0.48; TintA = 0.10; VLR = 0.10; VLG = 0.12; VLB = 0.10 }
    "Rudy Inspired" = @{ Saturation = 1.05; Brightness = 0.98; Contrast = 1.04; TintR = 0.55; TintG = 0.50; TintB = 0.48; TintA = 0.05; VLR = 0.14; VLG = 0.12; VLB = 0.11 }
    "Ethqnm Edition" = @{ Saturation = 1.02; Brightness = 1.0; Contrast = 1.02; TintR = 0.52; TintG = 0.50; TintB = 0.52; TintA = 0.04; VLR = 0.12; VLG = 0.11; VLB = 0.12 }
}

# Get all preset folders
$Presets = Get-ChildItem -Path $PresetsPath -Directory

Write-Host "Found $($Presets.Count) presets"
Write-Host ""

$TotalVLUpdated = 0
$TotalISUpdated = 0
$TotalLTUpdated = 0

foreach ($Preset in $Presets) {
    $PresetName = $Preset.Name
    $Theme = $PresetThemes[$PresetName]

    if (-not $Theme) {
        Write-Host "No theme defined for: $PresetName - using neutral"
        $Theme = $PresetThemes["Neutral"]
    }

    Write-Host "Processing: $PresetName"
    Write-Host "  Theme: Sat=$($Theme.Saturation) Brt=$($Theme.Brightness) Con=$($Theme.Contrast)"

    # === Update VolumetricLighting ===
    $VLPath = Join-Path $Preset.FullName "VolumetricLighting"
    if (Test-Path $VLPath) {
        $VLFiles = Get-ChildItem -Path $VLPath -Filter "*.ini" -ErrorAction SilentlyContinue
        foreach ($VLFile in $VLFiles) {
            try {
                $Content = Get-Content -Path $VLFile.FullName -Raw

                # Update CustomColor with theme-appropriate values
                $NewColor = "CustomColor = $($Theme.VLR), $($Theme.VLG), $($Theme.VLB), 0.45"
                $Content = [regex]::Replace($Content, "CustomColor\s*=\s*[\d.,\s]+", $NewColor)

                Set-Content -Path $VLFile.FullName -Value $Content -NoNewline
                $TotalVLUpdated++
            }
            catch {
                Write-Warning "Error updating VL file $($VLFile.Name): $_"
            }
        }
    }

    # === Update ImageSpaces ===
    $ISPath = Join-Path $Preset.FullName "ImageSpaces"
    if (Test-Path $ISPath) {
        $ISFiles = Get-ChildItem -Path $ISPath -Filter "*.ini" -ErrorAction SilentlyContinue
        foreach ($ISFile in $ISFiles) {
            try {
                $Content = Get-Content -Path $ISFile.FullName -Raw
                $Modified = $false

                # Read current values and apply multipliers
                if ($Content -match "Saturation\s*=\s*([\d.]+)") {
                    $CurrentSat = [double]$Matches[1]
                    $NewSat = [Math]::Round($CurrentSat * $Theme.Saturation, 2)
                    $Content = [regex]::Replace($Content, "Saturation\s*=\s*[\d.]+", "Saturation = $NewSat")
                    $Modified = $true
                }

                if ($Content -match "Brightness\s*=\s*([\d.]+)") {
                    $CurrentBrt = [double]$Matches[1]
                    $NewBrt = [Math]::Round($CurrentBrt * $Theme.Brightness, 2)
                    $Content = [regex]::Replace($Content, "Brightness\s*=\s*[\d.]+", "Brightness = $NewBrt")
                    $Modified = $true
                }

                if ($Content -match "Contrast\s*=\s*([\d.]+)") {
                    $CurrentCon = [double]$Matches[1]
                    $NewCon = [Math]::Round($CurrentCon * $Theme.Contrast, 2)
                    $Content = [regex]::Replace($Content, "Contrast\s*=\s*[\d.]+", "Contrast = $NewCon")
                    $Modified = $true
                }

                # Update Tint with theme colors
                $NewTint = "Tint = $($Theme.TintR), $($Theme.TintG), $($Theme.TintB), $($Theme.TintA)"
                $Content = [regex]::Replace($Content, "Tint\s*=\s*[\d.,\s]+", $NewTint)

                if ($Modified) {
                    Set-Content -Path $ISFile.FullName -Value $Content -NoNewline
                    $TotalISUpdated++
                }
            }
            catch {
                Write-Warning "Error updating IS file $($ISFile.Name): $_"
            }
        }
    }

    # === Update LightingTemplates ===
    $LTPath = Join-Path $Preset.FullName "LightingTemplates"
    if (Test-Path $LTPath) {
        $LTFiles = Get-ChildItem -Path $LTPath -Filter "*.ini" -ErrorAction SilentlyContinue
        foreach ($LTFile in $LTFiles) {
            try {
                $Content = Get-Content -Path $LTFile.FullName -Raw
                $Modified = $false

                # Calculate fog color multiplier based on theme
                $FogR = [Math]::Round($Theme.TintR * 0.4, 3)
                $FogG = [Math]::Round($Theme.TintG * 0.4, 3)
                $FogB = [Math]::Round($Theme.TintB * 0.4, 3)

                # Update FogColorNear if present (only if not 0,0,0)
                if ($Content -match "FogColorNear\s*=\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)") {
                    $R = [double]$Matches[1]
                    $G = [double]$Matches[2]
                    $B = [double]$Matches[3]
                    if ($R -ne 0 -or $G -ne 0 -or $B -ne 0) {
                        $NewFogNear = "FogColorNear = $FogR, $FogG, $FogB"
                        $Content = [regex]::Replace($Content, "FogColorNear\s*=\s*[\d.,\s]+", $NewFogNear)
                        $Modified = $true
                    }
                }

                # Update FogColorFar if present (only if not 0,0,0)
                if ($Content -match "FogColorFar\s*=\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)") {
                    $R = [double]$Matches[1]
                    $G = [double]$Matches[2]
                    $B = [double]$Matches[3]
                    if ($R -ne 0 -or $G -ne 0 -or $B -ne 0) {
                        $NewFogFar = "FogColorFar = $FogR, $FogG, $FogB"
                        $Content = [regex]::Replace($Content, "FogColorFar\s*=\s*[\d.,\s]+", $NewFogFar)
                        $Modified = $true
                    }
                }

                if ($Modified) {
                    Set-Content -Path $LTFile.FullName -Value $Content -NoNewline
                    $TotalLTUpdated++
                }
            }
            catch {
                Write-Warning "Error updating LT file $($LTFile.Name): $_"
            }
        }
    }
}

Write-Host ""
Write-Host "==================================="
Write-Host "VolumetricLighting files updated: $TotalVLUpdated"
Write-Host "ImageSpaces files updated: $TotalISUpdated"
Write-Host "LightingTemplates files updated: $TotalLTUpdated"
Write-Host "Done!"
