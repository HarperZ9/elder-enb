# Fix Alternative Baseline files to use Operation format instead of Value format
$overlaysFolder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

$files = @(
    "$overlaysFolder\0. OPTIONAL - Alternative Baseline 1.ini",
    "$overlaysFolder\1. OPTIONAL - Alternative Baseline 2.ini"
)

foreach ($file in $files) {
    Write-Host "Processing: $file" -ForegroundColor Cyan

    $content = Get-Content $file -Raw

    # Replace "Value = X" with "Operation = `"= X`""
    # This regex matches: Value = followed by any value (numbers, decimals, booleans, color values)
    $content = $content -replace 'Value = (.+)$', 'Operation = "= $1"'

    Set-Content -Path $file -Value $content -Encoding UTF8
    Write-Host "  Converted Value to Operation format" -ForegroundColor Green
}

Write-Host "`nDone!" -ForegroundColor Yellow
