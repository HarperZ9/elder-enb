# Fix UIGroups for OPTIONAL presets and renumber all presets
$overlaysFolder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

# ============================================
# 1. FIX UIGROUPS FOR OPTIONAL PRESETS
# ============================================
Write-Host "=== FIXING UIGROUPS FOR OPTIONAL PRESETS ===" -ForegroundColor Yellow

$optionalFiles = Get-ChildItem "$overlaysFolder\*OPTIONAL*.ini"
foreach ($f in $optionalFiles) {
    $content = Get-Content $f.FullName -Raw
    $content = $content -replace 'UIGroups = Optional Styles', 'UIGroups = KreatE Presets'
    Set-Content -Path $f.FullName -Value $content -Encoding UTF8
    Write-Host "  Changed UIGroups to 'KreatE Presets': $($f.Name)" -ForegroundColor Green
}

# ============================================
# 2. RENUMBER ALL PRESETS
# ============================================
Write-Host "`n=== RENUMBERING ALL PRESETS ===" -ForegroundColor Yellow

# Get all ini files
$files = Get-ChildItem "$overlaysFolder\*.ini"

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

Write-Host "Found $($uniquePresets.Count) unique presets" -ForegroundColor Cyan

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

# Step 1: Rename files to temp names first
Write-Host "`nRenaming to temp names..." -ForegroundColor Yellow
$tempMappings = @()
foreach ($baseName in $uniquePresets.Keys) {
    $oldFile = $uniquePresets[$baseName]
    $guid = [guid]::NewGuid().ToString().Substring(0,8)
    $tempName = "TEMP_${guid}_$baseName"
    $tempPath = Join-Path $overlaysFolder $tempName
    Rename-Item $oldFile.FullName $tempPath
    $tempMappings += @{
        TempPath = $tempPath
        NewName = $newNames[$baseName]
        BaseName = $baseName
    }
}

# Step 2: Rename temp files to final names and update UIOrdering
Write-Host "Renaming to final names and updating UIOrdering..." -ForegroundColor Yellow
$errors = @()
foreach ($mapping in $tempMappings) {
    $finalPath = Join-Path $overlaysFolder $mapping.NewName
    try {
        if (Test-Path $finalPath) {
            Remove-Item $finalPath -Force
        }
        Rename-Item $mapping.TempPath $finalPath

        # Extract the new number and update UIOrdering in the file
        if ($mapping.NewName -match '^(\d+)\.') {
            $newNumber = $matches[1]
            $content = Get-Content $finalPath -Raw
            $content = $content -replace 'UIOrdering\s*=\s*\d+', "UIOrdering = $newNumber"
            Set-Content -Path $finalPath -Value $content -Encoding UTF8
        }

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
