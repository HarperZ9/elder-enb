# Fix Alternative Baseline files to use Operation format instead of Value format
$overlaysFolder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

$files = @(
    "$overlaysFolder\0. OPTIONAL - Alternative Baseline 1.ini",
    "$overlaysFolder\1. OPTIONAL - Alternative Baseline 2.ini"
)

foreach ($file in $files) {
    Write-Host "Processing: $file" -ForegroundColor Cyan

    $lines = Get-Content $file
    $newLines = @()

    foreach ($line in $lines) {
        if ($line -match '^Value = (.+)$') {
            $value = $matches[1]
            $newLine = "Operation = `"= $value`""
            $newLines += $newLine
            Write-Host "  Converted: $line -> $newLine" -ForegroundColor Gray
        } else {
            $newLines += $line
        }
    }

    # Also add AmountMin/AmountMax after IncompatibleOverlays if not present
    $content = $newLines -join "`r`n"
    if ($content -notmatch 'AmountMin') {
        $content = $content -replace '(IncompatibleOverlays =)', "`$1`r`nAmountMin = 0.00`r`nAmountMax = 1.00`r`n"
    }

    Set-Content -Path $file -Value $content -Encoding UTF8
    Write-Host "  Done!" -ForegroundColor Green
}

Write-Host "`nAll files fixed!" -ForegroundColor Yellow
