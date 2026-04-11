$files = Get-ChildItem 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays\*.ini'
$numbered = @{}

foreach ($f in $files) {
    if ($f.Name -match '^(\d+)\.') {
        $num = [int]$matches[1]
        if (-not $numbered[$num]) {
            $numbered[$num] = @()
        }
        $numbered[$num] += $f.Name
    }
}

Write-Host "=== DUPLICATE NUMBERED FILES ===" -ForegroundColor Yellow
Write-Host ""

foreach ($key in ($numbered.Keys | Sort-Object)) {
    if ($numbered[$key].Count -gt 1) {
        Write-Host "Number $key has $($numbered[$key].Count) files:" -ForegroundColor Cyan
        foreach ($name in $numbered[$key]) {
            Write-Host "  $name"
        }
        Write-Host ""
    }
}

Write-Host "=== SUMMARY ===" -ForegroundColor Yellow
$totalDuplicateNumbers = ($numbered.Keys | Where-Object { $numbered[$_].Count -gt 1 }).Count
$totalDuplicateFiles = ($numbered.Values | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Count }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
Write-Host "Total numbers with duplicates: $totalDuplicateNumbers"
Write-Host "Total files involved in duplicates: $totalDuplicateFiles"
