$folder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'
$files = Get-ChildItem "$folder\*.ini"

# Build a list of unique presets (by base name, keeping one copy)
$uniquePresets = @{}
$duplicatesToDelete = @()

foreach ($f in $files) {
    if ($f.Name -match '^\d+\.\s*(.+)$') {
        $baseName = $matches[1]
        if (-not $uniquePresets[$baseName]) {
            $uniquePresets[$baseName] = $f
        } else {
            # This is a duplicate - mark for deletion
            $duplicatesToDelete += $f
        }
    }
}

Write-Host "=== DUPLICATE FILES TO DELETE ($($duplicatesToDelete.Count) files) ===" -ForegroundColor Red
foreach ($f in ($duplicatesToDelete | Sort-Object Name)) {
    Write-Host "  $($f.Name)"
}

# Define the category order
$categoryOrder = @(
    "OPTIONAL",
    "QUALITY",
    "PREFERENCES",
    "LIGHTING",
    "STYLE",
    "DOF",
    "BLOOM",
    "CINEMATIC BORDERS",
    "SSAO",
    "LOOK",
    "GRAIN",
    "LENS",
    "VIGNETTE",
    "BLUR",
    "ENV",
    "CREATIVE"
)

# Group unique presets by category
$categorized = @{}
foreach ($cat in $categoryOrder) {
    $categorized[$cat] = @()
}

foreach ($baseName in $uniquePresets.Keys) {
    $matched = $false
    foreach ($cat in $categoryOrder) {
        if ($baseName -like "$cat -*" -or $baseName -like "$cat-*") {
            $categorized[$cat] += $baseName
            $matched = $true
            break
        }
    }
    if (-not $matched) {
        Write-Host "WARNING: Uncategorized preset: $baseName" -ForegroundColor Magenta
    }
}

# Build the new numbering
$newNames = @{}
$currentNum = 0

Write-Host "`n=== FINAL NUMBERING (after duplicates removed) ===" -ForegroundColor Green

foreach ($cat in $categoryOrder) {
    $presets = $categorized[$cat] | Sort-Object
    if ($presets.Count -gt 0) {
        Write-Host "`n$cat ($($presets.Count) presets):" -ForegroundColor Cyan
        foreach ($baseName in $presets) {
            $newName = "$currentNum. $baseName"
            $newNames[$baseName] = $newName
            $oldName = $uniquePresets[$baseName].Name
            if ($oldName -ne $newName) {
                Write-Host "  $oldName -> $newName" -ForegroundColor Yellow
            } else {
                Write-Host "  $newName (no change)"
            }
            $currentNum++
        }
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total unique presets to keep: $($uniquePresets.Count)"
Write-Host "Duplicate files to delete: $($duplicatesToDelete.Count)"
Write-Host "Final numbering range: 0 to $($currentNum - 1)"
