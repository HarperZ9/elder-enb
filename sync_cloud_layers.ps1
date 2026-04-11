# Sync Cloud Layer settings from source to all KreatE presets
# This script copies LayerXEnabled and Alpha values from the source 10.28.16 exports
# to all 37 KreatE presets, preserving the RGB color values in each preset.

$SourcePath = "C:\Users\Zain\ENB\enbseries\KREATE\Weather Mod Record Exports\GUIDE COLORS AND VALUES\KreatE\10.28.16\Weathers"
$PresetsPath = "C:\Users\Zain\ENB\enbseries\KREATE\KreatE"

# Get all preset folders (excluding files)
$Presets = Get-ChildItem -Path $PresetsPath -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "Weathers")
}

Write-Host "Found $($Presets.Count) presets with Weathers folders"
Write-Host "Source: $SourcePath"
Write-Host ""

$TotalFilesUpdated = 0
$TotalFilesSkipped = 0

foreach ($Preset in $Presets) {
    $PresetName = $Preset.Name
    $PresetWeathersPath = Join-Path $Preset.FullName "Weathers"

    Write-Host "Processing preset: $PresetName"

    $PresetWeatherFiles = Get-ChildItem -Path $PresetWeathersPath -Filter "*.ini" -ErrorAction SilentlyContinue
    $FilesUpdated = 0

    foreach ($WeatherFile in $PresetWeatherFiles) {
        $SourceFile = Join-Path $SourcePath $WeatherFile.Name

        if (-not (Test-Path $SourceFile)) {
            # Skip files without source
            continue
        }

        try {
            $SourceContent = Get-Content -Path $SourceFile -Raw
            $PresetContent = Get-Content -Path $WeatherFile.FullName -Raw

            $Modified = $false

            # Extract and sync Layer settings (Layer0 through Layer28)
            for ($i = 0; $i -le 28; $i++) {
                # Sync LayerXEnabled
                $EnabledPattern = "Layer${i}Enabled\s*=\s*(true|false)"
                $SourceMatch = [regex]::Match($SourceContent, $EnabledPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

                if ($SourceMatch.Success) {
                    $SourceEnabled = $SourceMatch.Value
                    $PresetContent = [regex]::Replace($PresetContent, $EnabledPattern, $SourceEnabled, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    $Modified = $true
                }

                # Sync Alpha values in LayerXColorSunrise/Day/Sunset/Night
                foreach ($TimeOfDay in @("Sunrise", "Day", "Sunset", "Night")) {
                    $ColorKey = "Layer${i}Color${TimeOfDay}"

                    # Pattern to match color with 4 components (R, G, B, Alpha)
                    $SourceColorPattern = "${ColorKey}\s*=\s*([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)"
                    $PresetColorPattern = "${ColorKey}\s*=\s*([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)"

                    $SourceColorMatch = [regex]::Match($SourceContent, $SourceColorPattern)
                    $PresetColorMatch = [regex]::Match($PresetContent, $PresetColorPattern)

                    if ($SourceColorMatch.Success -and $PresetColorMatch.Success) {
                        # Get source alpha value
                        $SourceAlpha = $SourceColorMatch.Groups[4].Value

                        # Get preset RGB values (keep these)
                        $PresetR = $PresetColorMatch.Groups[1].Value
                        $PresetG = $PresetColorMatch.Groups[2].Value
                        $PresetB = $PresetColorMatch.Groups[3].Value

                        # Create new color string with preset RGB and source Alpha
                        $NewColor = "${ColorKey} = ${PresetR}, ${PresetG}, ${PresetB}, ${SourceAlpha}"

                        # Replace in preset content
                        $PresetContent = [regex]::Replace($PresetContent, $PresetColorPattern, $NewColor)
                        $Modified = $true
                    }
                }
            }

            if ($Modified) {
                Set-Content -Path $WeatherFile.FullName -Value $PresetContent -NoNewline
                $FilesUpdated++
            }
        }
        catch {
            Write-Warning "Error processing $($WeatherFile.Name): $_"
        }
    }

    Write-Host "  Updated $FilesUpdated weather files"
    $TotalFilesUpdated += $FilesUpdated
}

Write-Host ""
Write-Host "==================================="
Write-Host "Total files updated: $TotalFilesUpdated"
Write-Host "Done!"
