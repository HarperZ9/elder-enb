# Script to reverse UIGroups numbering for descending sort order
# ENB sorts groups in descending order, so higher numbers appear first

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Define the mapping - reversed numbering (14 = first, 01 = last)
$groupMappings = @{
    "01 - Environment Lighting" = "14 - Environment Lighting"
    "02 - Quality" = "13 - Quality"
    "03 - Preferences" = "12 - Preferences"
    "04 - Lighting" = "11 - Lighting"
    "05 - KreatE Presets" = "10 - KreatE Presets"
    "06 - Depth of Field" = "09 - Depth of Field"
    "07 - Bloom Styles" = "08 - Bloom Styles"
    "08 - Cinematic Borders" = "07 - Cinematic Borders"
    "09 - Ambient Occlusion" = "06 - Ambient Occlusion"
    "10 - LUT Looks" = "05 - LUT Looks"
    "11 - Film Grain" = "04 - Film Grain"
    "12 - Lens Distortion" = "03 - Lens Distortion"
    "13 - Vignette" = "02 - Vignette"
    "14 - Blur Suite" = "01 - Blur Suite"
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
Write-Host ""
Write-Host "New ordering (descending sort = correct display):"
Write-Host "14 - Environment Lighting (first)"
Write-Host "13 - Quality"
Write-Host "12 - Preferences"
Write-Host "11 - Lighting"
Write-Host "10 - KreatE Presets"
Write-Host "09 - Depth of Field"
Write-Host "08 - Bloom Styles"
Write-Host "07 - Cinematic Borders"
Write-Host "06 - Ambient Occlusion"
Write-Host "05 - LUT Looks"
Write-Host "04 - Film Grain"
Write-Host "03 - Lens Distortion"
Write-Host "02 - Vignette"
Write-Host "01 - Blur Suite (last)"
