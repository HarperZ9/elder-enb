$folder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'
$files = Get-ChildItem "$folder\*.ini"

# Build a list of unique presets (by base name, keeping one copy)
$uniquePresets = @{}

foreach ($f in $files) {
    if ($f.Name -match '^\d+\.\s*(.+)$') {
        $baseName = $matches[1]
        if (-not $uniquePresets[$baseName]) {
            $uniquePresets[$baseName] = $f
        }
    }
}

# Define the category order (OPTIONAL now comes first)
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

Write-Host "=== NEW NUMBERING SCHEME ===" -ForegroundColor Yellow

foreach ($cat in $categoryOrder) {
    $presets = $categorized[$cat] | Sort-Object
    if ($presets.Count -gt 0) {
        Write-Host "`n$cat ($($presets.Count) presets, starting at $currentNum):" -ForegroundColor Cyan
        foreach ($baseName in $presets) {
            $newNames[$baseName] = "$currentNum. $baseName"
            $currentNum++
        }
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Total presets: $($uniquePresets.Count)"
Write-Host "Final numbering: 0 to $($currentNum - 1)"

# Step 1: Rename files to temp names first (to avoid conflicts)
Write-Host "`nRenaming to temp names..." -ForegroundColor Yellow
$tempMappings = @()
foreach ($baseName in $uniquePresets.Keys) {
    $oldFile = $uniquePresets[$baseName]
    $tempName = "TEMP_$([guid]::NewGuid().ToString().Substring(0,8))_$baseName"
    $tempPath = Join-Path $folder $tempName
    Rename-Item $oldFile.FullName $tempPath
    $tempMappings += @{
        TempPath = $tempPath
        NewName = $newNames[$baseName]
    }
}

# Step 2: Rename temp files to final names
Write-Host "Renaming to final names..." -ForegroundColor Yellow
foreach ($mapping in $tempMappings) {
    $finalPath = Join-Path $folder $mapping.NewName
    Rename-Item $mapping.TempPath $finalPath
}

Write-Host "`nDone! Renumbered $($uniquePresets.Count) presets." -ForegroundColor Green
