$files = Get-ChildItem 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays\*MLO2*.ini'
Write-Host "Found $($files.Count) MLO2 files:"
foreach ($f in $files) {
    $hash = Get-FileHash $f.FullName
    Write-Host "  $($f.Name) - Hash: $($hash.Hash)"
}

if ($files.Count -eq 2) {
    $hash1 = Get-FileHash $files[0].FullName
    $hash2 = Get-FileHash $files[1].FullName
    if ($hash1.Hash -eq $hash2.Hash) {
        Write-Host "`nFiles are IDENTICAL - one is a duplicate"
    } else {
        Write-Host "`nFiles are DIFFERENT - both should be kept"
    }
}
