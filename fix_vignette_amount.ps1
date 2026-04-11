# Add AmountMin/AmountMax to vignette presets
$overlaysFolder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

$vignetteFiles = Get-ChildItem "$overlaysFolder\*VIGNETTE*.ini"

foreach ($f in $vignetteFiles) {
    $content = Get-Content $f.FullName -Raw

    # Check if AmountMin is already present
    if ($content -notmatch 'AmountMin') {
        # Add AmountMin and AmountMax after IncompatibleOverlays
        $content = $content -replace '(IncompatibleOverlays\s*=\s*)', "`$1`r`nAmountMin = 0.00`r`nAmountMax = 1.00"
        Set-Content -Path $f.FullName -Value $content -Encoding UTF8
        Write-Host "Added AmountMin/AmountMax to: $($f.Name)" -ForegroundColor Green
    } else {
        Write-Host "Already has AmountMin: $($f.Name)" -ForegroundColor Cyan
    }
}

Write-Host "`nDone!" -ForegroundColor Yellow
