# Script to add number prefixes to UIGroups for correct ordering in ENB GUI
# Categories should appear in this order:
# 01 - Environment Lighting (000-011)
# 02 - Quality (012-017)
# 03 - Preferences (018-019)
# 04 - Lighting (020-025)
# 05 - KreatE Presets (026-060)
# 06 - Depth of Field (061-078)
# 07 - Bloom Styles (079-093)
# 08 - Cinematic Borders (094-098)
# 09 - Ambient Occlusion (099-100)
# 10 - LUT Looks (101-138)
# 11 - Film Grain (139-144)
# 12 - Lens Distortion (145-150)
# 13 - Vignette (151-156)
# 14 - Blur Suite (157-162)

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Define the mapping of old group names to new numbered group names
$groupMappings = @{
    "Environment Lighting" = "01 - Environment Lighting"
    "Quality" = "02 - Quality"
    "Preferences" = "03 - Preferences"
    "Lighting" = "04 - Lighting"
    "KreatE Presets" = "05 - KreatE Presets"
    "Depth of Field" = "06 - Depth of Field"
    "Bloom Styles" = "07 - Bloom Styles"
    "Cinematic Borders" = "08 - Cinematic Borders"
    "Ambient Occlusion" = "09 - Ambient Occlusion"
    "LUT Looks" = "10 - LUT Looks"
    "Film Grain" = "11 - Film Grain"
    "Lens Distortion" = "12 - Lens Distortion"
    "Vignette" = "13 - Vignette"
    "Blur Suite" = "14 - Blur Suite"
}

$files = Get-ChildItem -Path $overlayPath -Filter "*.ini"
$updatedCount = 0

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $modified = $false

    foreach ($oldGroup in $groupMappings.Keys) {
        $newGroup = $groupMappings[$oldGroup]
        $pattern = "UIGroups = $oldGroup"
        $replacement = "UIGroups = $newGroup"

        if ($content -match [regex]::Escape($pattern)) {
            $content = $content -replace [regex]::Escape($pattern), $replacement
            $modified = $true
        }
    }

    if ($modified) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Updated: $($file.Name)"
        $updatedCount++
    }
}

Write-Host ""
Write-Host "====================================="
Write-Host "Updated $updatedCount files"
Write-Host "====================================="
