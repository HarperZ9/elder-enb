$files = Get-ChildItem "C:\Users\Zain\ENB\enbseries\enbpresetoverlays\*.ini" | Sort-Object Name
Write-Host "Total files: $($files.Count)" -ForegroundColor Cyan
Write-Host ""

# Group by category
$categories = @{}
foreach ($f in $files) {
    if ($f.Name -match '^\d{3}\. (\w+)') {
        $cat = $Matches[1]
        if (-not $categories.ContainsKey($cat)) {
            $categories[$cat] = @()
        }
        $categories[$cat] += $f.Name
    }
}

Write-Host "=== Category Breakdown ===" -ForegroundColor Yellow
$sortedCats = $categories.GetEnumerator() | Sort-Object {
    $firstFile = $_.Value | Select-Object -First 1
    if ($firstFile -match '^(\d{3})') { [int]$Matches[1] } else { 999 }
}

foreach ($entry in $sortedCats) {
    $cat = $entry.Key
    $catFiles = $entry.Value
    $first = $catFiles | Select-Object -First 1
    $last = $catFiles | Select-Object -Last 1
    $firstNum = if ($first -match '^(\d{3})') { $Matches[1] } else { "?" }
    $lastNum = if ($last -match '^(\d{3})') { $Matches[1] } else { "?" }
    Write-Host ("{0}: {1}-{2} ({3} files)" -f $cat.ToUpper(), $firstNum, $lastNum, $catFiles.Count)
}
