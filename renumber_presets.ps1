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

Write-Host "=== DUPLICATE FILES TO DELETE ===" -ForegroundColor Yellow
Write-Host "Found $($duplicatesToDelete.Count) duplicate files to delete:`n"
foreach ($f in $duplicatesToDelete) {
    Write-Host "  DELETE: $($f.Name)" -ForegroundColor Red
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
Write-Host "Total unique presets: $($uniquePresets.Count)"
Write-Host "Duplicates to delete: $($duplicatesToDelete.Count)"
Write-Host "Final numbering: 0 to $($currentNum - 1)"

# Ask for confirmation
Write-Host "`n" -NoNewline
$confirm = Read-Host "Do you want to proceed with renaming? (yes/no)"

if ($confirm -eq "yes") {
    # Step 1: Delete duplicates
    Write-Host "`nDeleting duplicates..." -ForegroundColor Yellow
    foreach ($f in $duplicatesToDelete) {
        Remove-Item $f.FullName -Force
        Write-Host "  Deleted: $($f.Name)" -ForegroundColor Red
    }

    # Step 2: Rename files to temp names first (to avoid conflicts)
    Write-Host "`nRenaming to temp names..." -ForegroundColor Yellow
    $tempMappings = @()
    foreach ($baseName in $uniquePresets.Keys) {
        $oldFile = $uniquePresets[$baseName]
        $tempName = "TEMP_$([guid]::NewGuid().ToString())_$baseName"
        $tempPath = Join-Path $folder $tempName
        Rename-Item $oldFile.FullName $tempPath
        $tempMappings += @{
            TempPath = $tempPath
            NewName = $newNames[$baseName]
        }
    }

    # Step 3: Rename temp files to final names
    Write-Host "Renaming to final names..." -ForegroundColor Yellow
    foreach ($mapping in $tempMappings) {
        $finalPath = Join-Path $folder $mapping.NewName
        Rename-Item $mapping.TempPath $finalPath
        Write-Host "  -> $($mapping.NewName)" -ForegroundColor Green
    }

    Write-Host "`nDone! All presets have been renumbered." -ForegroundColor Green
} else {
    Write-Host "`nOperation cancelled." -ForegroundColor Yellow
}
