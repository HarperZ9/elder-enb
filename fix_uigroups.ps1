# Fix ENB Preset Overlay UIGroups
# This script simplifies complex UIGroups to fix ordering issues

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Get all .ini files
$files = Get-ChildItem -Path $overlayPath -Filter "*.ini" -File

$updatedCount = 0

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    $changed = $false

    # LOOK files: Change "LUT Looks, Custom LUTs" or "LUT Looks, Voyager LUTs" to "LUT Looks"
    if ($content -match "UIGroups = LUT Looks, (Custom|Voyager) LUTs") {
        $content = $content -replace "UIGroups = LUT Looks, (Custom|Voyager) LUTs", "UIGroups = LUT Looks"
        $changed = $true
    }

    # GRAIN files: Change "Film Grain (Future: Silent Horizons - New Dawn)" to "Film Grain"
    if ($content -match "UIGroups = Film Grain \(Future: Silent Horizons - New Dawn\)") {
        $content = $content -replace "UIGroups = Film Grain \(Future: Silent Horizons - New Dawn\)", "UIGroups = Film Grain"
        $changed = $true
    }

    # LENS files: Change "Lens Distortion (Future: Silent Horizons - New Dawn)" to "Lens Distortion"
    if ($content -match "UIGroups = Lens Distortion \(Future: Silent Horizons - New Dawn\)") {
        $content = $content -replace "UIGroups = Lens Distortion \(Future: Silent Horizons - New Dawn\)", "UIGroups = Lens Distortion"
        $changed = $true
    }

    # BLUR files: Change "Blur Suite (Future: Silent Horizons - New Dawn)" to "Blur Suite"
    if ($content -match "UIGroups = Blur Suite \(Future: Silent Horizons - New Dawn\)") {
        $content = $content -replace "UIGroups = Blur Suite \(Future: Silent Horizons - New Dawn\)", "UIGroups = Blur Suite"
        $changed = $true
    }

    if ($changed) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Updated: $($file.Name)"
        $updatedCount++
    }
}

Write-Host ""
Write-Host "===== Summary ====="
Write-Host "Files updated: $updatedCount"
