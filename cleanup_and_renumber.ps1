$folder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

# Step 1: Clean up temp files and rename Alternative Baselines properly
Write-Host "=== CLEANING UP ===" -ForegroundColor Yellow

# Delete temp files
$tempFiles = Get-ChildItem "$folder\TEMP*"
foreach ($f in $tempFiles) {
    Write-Host "  Deleting temp: $($f.Name)" -ForegroundColor Red
    Remove-Item $f.FullName -Force
}

# Check if Alternative Baseline files exist with old names and rename them
$altBase1 = Get-ChildItem "$folder\*Alternative Baseline 1*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "TEMP*" }
$altBase2 = Get-ChildItem "$folder\*Alternative Baseline 2*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "TEMP*" }

# Now get fresh file list
$files = Get-ChildItem "$folder\*.ini"

# Build a list of unique presets
$uniquePresets = @{}

foreach ($f in $files) {
    if ($f.Name -match '^\d+\.\s*(.+)$') {
        $baseName = $matches[1]
        if (-not $uniquePresets[$baseName]) {
            $uniquePresets[$baseName] = $f
        }
    }
}

Write-Host "`nFound $($uniquePresets.Count) unique presets" -ForegroundColor Cyan

# Define the category order - include both OPTIONAL and OPTIONAL STYLES patterns
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
        # Match both "OPTIONAL -" and "OPTIONAL STYLES -" as OPTIONAL category
        if ($cat -eq "OPTIONAL") {
            if ($baseName -like "OPTIONAL -*" -or $baseName -like "OPTIONAL STYLES -*") {
                $categorized[$cat] += $baseName
                $matched = $true
                break
            }
        } elseif ($baseName -like "$cat -*" -or $baseName -like "$cat-*") {
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

Write-Host "`n=== NEW NUMBERING SCHEME ===" -ForegroundColor Yellow

foreach ($cat in $categoryOrder) {
    $presets = $categorized[$cat] | Sort-Object
    if ($presets.Count -gt 0) {
        Write-Host "`n$cat ($($presets.Count) presets, starting at $currentNum):" -ForegroundColor Cyan
        foreach ($baseName in $presets) {
            $newName = "$currentNum. $baseName"
            $newNames[$baseName] = $newName
            Write-Host "  $currentNum. $baseName"
            $currentNum++
        }
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Total presets: $($uniquePresets.Count)"
Write-Host "Final numbering: 0 to $($currentNum - 1)"

# Step 2: Rename files to temp names first
Write-Host "`nRenaming to temp names..." -ForegroundColor Yellow
$tempMappings = @()
foreach ($baseName in $uniquePresets.Keys) {
    $oldFile = $uniquePresets[$baseName]
    $guid = [guid]::NewGuid().ToString().Substring(0,8)
    $tempName = "TEMP_${guid}_$baseName"
    $tempPath = Join-Path $folder $tempName
    Rename-Item $oldFile.FullName $tempPath
    $tempMappings += @{
        TempPath = $tempPath
        NewName = $newNames[$baseName]
        BaseName = $baseName
    }
}

# Step 3: Rename temp files to final names
Write-Host "Renaming to final names..." -ForegroundColor Yellow
$errors = @()
foreach ($mapping in $tempMappings) {
    $finalPath = Join-Path $folder $mapping.NewName
    try {
        if (Test-Path $finalPath) {
            # File already exists, delete it first
            Remove-Item $finalPath -Force
        }
        Rename-Item $mapping.TempPath $finalPath
        Write-Host "  -> $($mapping.NewName)" -ForegroundColor Green
    } catch {
        $errors += "Failed: $($mapping.BaseName) - $($_.Exception.Message)"
    }
}

if ($errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  $_" }
}

Write-Host "`nDone! Renumbered $($tempMappings.Count) presets." -ForegroundColor Green
