# Script to fix BLOOM overlay headers - ensure AmountMin/AmountMax are present

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Get all BLOOM files
$bloomFiles = Get-ChildItem -Path $overlayPath -Filter "*.ini" | Where-Object { $_.Name -match '\. BLOOM -' }

Write-Host "Found $($bloomFiles.Count) BLOOM files"
$fixedCount = 0

foreach ($file in $bloomFiles) {
    $content = Get-Content -Path $file.FullName -Raw

    # Check if AmountMin is missing
    if ($content -notmatch 'AmountMin\s*=') {
        # Add AmountMin and AmountMax after IncompatibleOverlays line
        $content = $content -replace '(IncompatibleOverlays\s*=\s*[^\r\n]*)', "`$1`r`nAmountMin = 0.00`r`nAmountMax = 1.00"
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Fixed: $($file.Name)"
        $fixedCount++
    }
}

Write-Host ""
Write-Host "====================================="
Write-Host "Fixed $fixedCount BLOOM files"
Write-Host "====================================="
