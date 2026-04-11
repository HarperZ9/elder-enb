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
            $duplicatesToDelete += $f
        }
    }
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
    foreach ($cat in $categoryOrder) {
        if ($baseName -like "$cat -*" -or $baseName -like "$cat-*") {
            $categorized[$cat] += $baseName
            break
        }
    }
}

# Build the new numbering
$newNames = @{}
$currentNum = 0

foreach ($cat in $categoryOrder) {
    $presets = $categorized[$cat] | Sort-Object
    foreach ($baseName in $presets) {
        $newNames[$baseName] = "$currentNum. $baseName"
        $currentNum++
    }
}

# Step 1: Delete duplicates
Write-Host "Step 1: Deleting $($duplicatesToDelete.Count) duplicate files..." -ForegroundColor Yellow
$deleteCount = 0
foreach ($f in $duplicatesToDelete) {
    Remove-Item $f.FullName -Force
    $deleteCount++
}
Write-Host "  Deleted $deleteCount files" -ForegroundColor Green

# Step 2: Rename files to temp names first (to avoid conflicts)
Write-Host "`nStep 2: Renaming to temporary names..." -ForegroundColor Yellow
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
Write-Host "  Created $($tempMappings.Count) temp files" -ForegroundColor Green

# Step 3: Rename temp files to final names
Write-Host "`nStep 3: Renaming to final names..." -ForegroundColor Yellow
$renameCount = 0
foreach ($mapping in $tempMappings) {
    $finalPath = Join-Path $folder $mapping.NewName
    Rename-Item $mapping.TempPath $finalPath
    $renameCount++
}
Write-Host "  Renamed $renameCount files" -ForegroundColor Green

Write-Host "`n=== COMPLETE ===" -ForegroundColor Cyan
Write-Host "Deleted duplicates: $deleteCount"
Write-Host "Renamed presets: $renameCount"
Write-Host "Final numbering: 0 to $($currentNum - 1)"
