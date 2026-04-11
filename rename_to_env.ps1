$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Step 1: Rename OPTIONAL files to ENV (000-009)
Write-Host "=== Renaming OPTIONAL files to ENV ===" -ForegroundColor Cyan
$optionalFiles = Get-ChildItem -Path $overlayPath -Filter "0*.OPTIONAL*.ini" | Sort-Object Name

foreach ($file in $optionalFiles) {
    $oldName = $file.Name
    $newName = $oldName -replace 'OPTIONAL', 'ENV'
    $newPath = Join-Path $overlayPath $newName

    # Rename the file
    Rename-Item -Path $file.FullName -NewName $newName
    Write-Host "Renamed: $oldName -> $newName" -ForegroundColor Green

    # Update contents
    $content = Get-Content -Path $newPath -Raw
    $content = $content -replace 'UIName = OPTIONAL', 'UIName = ENV'
    $content = $content -replace 'UIGroups = KreatE Presets', 'UIGroups = Environment Lighting'
    Set-Content -Path $newPath -Value $content -NoNewline
}

# Step 2: Rename CREATIVE files to ENV and renumber to 010-011
Write-Host "`n=== Moving CREATIVE files to ENV category ===" -ForegroundColor Cyan

$creativeFiles = @(
    @{Old = "161. CREATIVE - Infrared Film.ini"; New = "010. ENV - Infrared Film.ini"; Order = 10},
    @{Old = "162. CREATIVE - Miniature World.ini"; New = "011. ENV - Miniature World.ini"; Order = 11}
)

foreach ($mapping in $creativeFiles) {
    $oldPath = Join-Path $overlayPath $mapping.Old
    $newPath = Join-Path $overlayPath $mapping.New

    if (Test-Path $oldPath) {
        # Read content and update
        $content = Get-Content -Path $oldPath -Raw
        $content = $content -replace 'UIName = CREATIVE', 'UIName = ENV'
        $content = $content -replace 'UIGroups = Creative Effects', 'UIGroups = Environment Lighting'
        $content = $content -replace ('UIOrdering = \d+'), ('UIOrdering = ' + $mapping.Order)

        # Write to new file
        Set-Content -Path $newPath -Value $content -NoNewline

        # Remove old file
        Remove-Item -Path $oldPath

        Write-Host "Moved: $($mapping.Old) -> $($mapping.New)" -ForegroundColor Green
    } else {
        Write-Host "File not found: $($mapping.Old)" -ForegroundColor Red
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$envFiles = Get-ChildItem -Path $overlayPath -Filter "*.ENV*.ini" | Sort-Object Name
Write-Host "Total ENV files: $($envFiles.Count)" -ForegroundColor Yellow
$envFiles | ForEach-Object { Write-Host "  $_" }
