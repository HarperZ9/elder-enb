$files = Get-ChildItem 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays\*.ini'

# Extract unique preset names (removing number prefix)
$uniqueNames = @{}
foreach ($f in $files) {
    if ($f.Name -match '^\d+\.\s*(.+)$') {
        $baseName = $matches[1]
        if (-not $uniqueNames[$baseName]) {
            $uniqueNames[$baseName] = @()
        }
        $uniqueNames[$baseName] += $f.Name
    }
}

# Group by category
$categories = @{
    "OPTIONAL" = @()
    "QUALITY" = @()
    "PREFERENCES" = @()
    "LIGHTING" = @()
    "STYLE" = @()
    "DOF" = @()
    "BLOOM" = @()
    "CINEMATIC BORDERS" = @()
    "SSAO" = @()
    "LOOK" = @()
    "GRAIN" = @()
    "LENS" = @()
    "VIGNETTE" = @()
    "BLUR" = @()
    "ENV" = @()
    "CREATIVE" = @()
}

foreach ($name in $uniqueNames.Keys) {
    foreach ($cat in $categories.Keys) {
        if ($name -like "$cat -*" -or $name -like "$cat-*") {
            $categories[$cat] += $name
            break
        }
    }
}

Write-Host "=== UNIQUE PRESETS BY CATEGORY ===" -ForegroundColor Yellow

$order = @("OPTIONAL", "QUALITY", "PREFERENCES", "LIGHTING", "STYLE", "DOF", "BLOOM", "CINEMATIC BORDERS", "SSAO", "LOOK", "GRAIN", "LENS", "VIGNETTE", "BLUR", "ENV", "CREATIVE")

foreach ($cat in $order) {
    $sorted = $categories[$cat] | Sort-Object
    Write-Host "`n$cat ($($sorted.Count) presets):" -ForegroundColor Cyan
    foreach ($name in $sorted) {
        $count = $uniqueNames[$name].Count
        if ($count -gt 1) {
            Write-Host "  [DUP x$count] $name" -ForegroundColor Red
        } else {
            Write-Host "  $name"
        }
    }
}

Write-Host "`n=== TOTAL UNIQUE PRESET NAMES ===" -ForegroundColor Yellow
Write-Host "Total: $($uniqueNames.Count)"
