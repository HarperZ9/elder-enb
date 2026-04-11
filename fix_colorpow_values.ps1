# Fix OPTIONAL presets with invalid ColorPow values (below 1.0)
$overlaysFolder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

$filesToFix = @(
    @{
        Path = "$overlaysFolder\0. OPTIONAL - Cinematic Drama.ini"
        OldValue = "0.85"
        NewValue = "1.0"
        OldDesc = "Hollywood blockbuster aesthetic with crushed blacks, punchy highlights, and theatrical contrast. High-impact visual drama."
        NewDesc = "Hollywood blockbuster aesthetic with neutral gamma and enhanced contrast through lighting ratio. High-impact visual drama through direct/ambient balance."
        OldTarget = "; Target: 0.85 (strong contrast, crushed blacks)"
        NewTarget = "; Target: 1.0 (neutral gamma, contrast via lighting)"
    },
    @{
        Path = "$overlaysFolder\1. OPTIONAL - Deep Contrast.ini"
        OldValue = "0.9"
        NewValue = "1.0"
        OldDesc = "Punchy, contrasty look with deeper blacks and vivid highlights. Gamma at 0.9 for increased midtone contrast without crushing detail."
        NewDesc = "Punchy, contrasty look with deeper blacks and vivid highlights. Neutral gamma with enhanced contrast through HDR and lighting settings."
        OldTarget = "; Target: 0.9 (increased contrast)"
        NewTarget = "; Target: 1.0 (neutral gamma, contrast via HDR)"
    },
    @{
        Path = "$overlaysFolder\7. OPTIONAL - Nordic Light.ini"
        OldValue = "0.95"
        NewValue = "1.0"
        OldDesc = "Cool, desaturated northern atmosphere with crisp shadows and blue-tinted ambient. Evokes Scandinavian winter light."
        NewDesc = "Cool, desaturated northern atmosphere with crisp shadows and blue-tinted ambient. Evokes Scandinavian winter light with neutral gamma."
        OldTarget = "; Target: 0.95 (crisp, slightly contrasty)"
        NewTarget = "; Target: 1.0 (neutral gamma, crispness via lighting)"
    }
)

foreach ($file in $filesToFix) {
    Write-Host "Fixing: $($file.Path)" -ForegroundColor Cyan

    $content = Get-Content $file.Path -Raw

    # Replace all gamma/colorpow values
    $content = $content -replace [regex]::Escape("= $($file.OldValue)`""), "= $($file.NewValue)`""

    # Update description
    $content = $content -replace [regex]::Escape($file.OldDesc), $file.NewDesc

    # Update target comment
    $content = $content -replace [regex]::Escape($file.OldTarget), $file.NewTarget

    Set-Content -Path $file.Path -Value $content -Encoding UTF8

    Write-Host "  Changed ColorPow/Gamma from $($file.OldValue) to $($file.NewValue)" -ForegroundColor Green
}

Write-Host "`nAll files fixed!" -ForegroundColor Yellow
