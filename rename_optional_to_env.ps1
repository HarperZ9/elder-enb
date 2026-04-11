$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

Write-Host "=== Renaming OPTIONAL files to ENV ===" -ForegroundColor Cyan

$optionalFiles = Get-ChildItem -Path $overlayPath -Filter "*.ini" | Where-Object { $_.Name -match '^\d{3}\. OPTIONAL' } | Sort-Object Name
Write-Host "Found $($optionalFiles.Count) OPTIONAL files" -ForegroundColor Yellow

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

Write-Host "`n=== Verifying ENV files ===" -ForegroundColor Cyan
$envFiles = Get-ChildItem -Path $overlayPath -Filter "*.ini" | Where-Object { $_.Name -match '^\d{3}\. ENV' } | Sort-Object Name
Write-Host "Total ENV files: $($envFiles.Count)" -ForegroundColor Yellow
$envFiles | ForEach-Object { Write-Host "  $($_.Name)" }
