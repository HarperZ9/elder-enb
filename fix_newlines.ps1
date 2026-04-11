# Fix missing newlines in VolumetricLighting and ImageSpaces files

$PresetsPath = "C:\Users\Zain\ENB\enbseries\KREATE\KreatE"

$Presets = Get-ChildItem -Path $PresetsPath -Directory

$TotalFixed = 0

foreach ($Preset in $Presets) {
    # Fix VolumetricLighting files
    $VLPath = Join-Path $Preset.FullName "VolumetricLighting"
    if (Test-Path $VLPath) {
        $VLFiles = Get-ChildItem -Path $VLPath -Filter "*.ini" -ErrorAction SilentlyContinue
        foreach ($VLFile in $VLFiles) {
            try {
                $Content = Get-Content -Path $VLFile.FullName -Raw

                # Fix CustomColor line - add newline before Density if missing
                $Content = $Content -replace "(\d+\.\d+)Density", "`$1`r`nDensity"

                Set-Content -Path $VLFile.FullName -Value $Content -NoNewline
                $TotalFixed++
            }
            catch {
                Write-Warning "Error fixing VL file $($VLFile.Name): $_"
            }
        }
    }

    # Fix ImageSpaces files
    $ISPath = Join-Path $Preset.FullName "ImageSpaces"
    if (Test-Path $ISPath) {
        $ISFiles = Get-ChildItem -Path $ISPath -Filter "*.ini" -ErrorAction SilentlyContinue
        foreach ($ISFile in $ISFiles) {
            try {
                $Content = Get-Content -Path $ISFile.FullName -Raw

                # Fix Tint line - add newline before [DepthOfField] if missing
                $Content = $Content -replace "(\d+\.\d+)\[DepthOfField\]", "`$1`r`n`r`n[DepthOfField]"

                # Also fix any cases where Tint ate the next line
                $Content = $Content -replace "(\d+\.\d+)(\r?\n)?\[", "`$1`r`n`r`n["

                Set-Content -Path $ISFile.FullName -Value $Content -NoNewline
                $TotalFixed++
            }
            catch {
                Write-Warning "Error fixing IS file $($ISFile.Name): $_"
            }
        }
    }
}

Write-Host "Fixed $TotalFixed files"
