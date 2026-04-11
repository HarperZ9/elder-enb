$folder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'
$envFiles = Get-ChildItem "$folder\*ENV*.ini"

Write-Host "=== DELETING OLD ENV FILES ===" -ForegroundColor Yellow
Write-Host "Found $($envFiles.Count) ENV files to delete:`n"

foreach ($file in $envFiles) {
    Write-Host "  Deleting: $($file.Name)" -ForegroundColor Red
    Remove-Item $file.FullName -Force
}

Write-Host "`nDone! Deleted $($envFiles.Count) files." -ForegroundColor Green
