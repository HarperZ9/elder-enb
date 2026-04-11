# Update LOOK files to use additive operations
$lookFiles = Get-ChildItem "C:\Users\Zain\ENB\enbseries\enbpresetoverlays\*LOOK*.ini"
$count = 0

foreach ($file in $lookFiles) {
    $content = Get-Content $file.FullName -Raw
    $updated = $content -replace 'Operation = "= 0\.5"', 'Operation = "+ 0.5"'
    if ($content -ne $updated) {
        $updated | Set-Content $file.FullName -Encoding UTF8 -NoNewline
        $count++
        Write-Host "Updated: $($file.Name)"
    }
}

Write-Host "`nTotal LOOK files updated: $count"
