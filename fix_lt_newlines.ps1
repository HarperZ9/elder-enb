# Fix missing newlines in LightingTemplates files

$PresetsPath = "C:\Users\Zain\ENB\enbseries\KREATE\KreatE"

$Presets = Get-ChildItem -Path $PresetsPath -Directory

$TotalFixed = 0

foreach ($Preset in $Presets) {
    $LTPath = Join-Path $Preset.FullName "LightingTemplates"
    if (Test-Path $LTPath) {
        $LTFiles = Get-ChildItem -Path $LTPath -Filter "*.ini" -ErrorAction SilentlyContinue
        foreach ($LTFile in $LTFiles) {
            try {
                $Content = Get-Content -Path $LTFile.FullName -Raw
                $Modified = $false

                # Fix FogColorNear line - add newline before FogColorFar if missing
                if ($Content -match "(\d+\.?\d*)FogColorFar") {
                    $Content = $Content -replace "(\d+\.?\d*)FogColorFar", "`$1`r`nFogColorFar"
                    $Modified = $true
                }

                # Fix FogColorFar line - add newline before FogNear if missing
                if ($Content -match "(\d+\.?\d*)FogNear\s*=") {
                    $Content = $Content -replace "(\d+\.?\d*)FogNear\s*=", "`$1`r`nFogNear ="
                    $Modified = $true
                }

                if ($Modified) {
                    Set-Content -Path $LTFile.FullName -Value $Content -NoNewline
                    $TotalFixed++
                }
            }
            catch {
                Write-Warning "Error fixing LT file $($LTFile.Name): $_"
            }
        }
    }
}

Write-Host "Fixed $TotalFixed LightingTemplates files"
