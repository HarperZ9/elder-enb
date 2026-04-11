$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

Write-Host "=== Shifting all non-ENV files (010+) by +2 ===" -ForegroundColor Cyan

# Get all files that are NOT ENV and have number >= 010
$filesToShift = Get-ChildItem -Path $overlayPath -Filter "*.ini" | Where-Object {
    $_.Name -match '^(\d{3})\.' -and $_.Name -notmatch 'ENV' -and [int]$Matches[1] -ge 10
} | Sort-Object { [int]($_.Name -replace '^(\d{3})\..*', '$1') } -Descending  # Sort descending to avoid conflicts

Write-Host "Found $($filesToShift.Count) files to shift" -ForegroundColor Yellow

foreach ($file in $filesToShift) {
    $oldName = $file.Name
    if ($oldName -match '^(\d{3})\.(.+)$') {
        $oldNum = [int]$Matches[1]
        $restOfName = $Matches[2]
        $newNum = $oldNum + 2
        $newName = "{0:D3}.{1}" -f $newNum, $restOfName
        $newPath = Join-Path $overlayPath $newName

        # Rename the file
        Rename-Item -Path $file.FullName -NewName $newName
        Write-Host "Shifted: $oldName -> $newName" -ForegroundColor Green

        # Update UIOrdering in the file
        $content = Get-Content -Path $newPath -Raw
        $content = $content -replace ('UIOrdering = ' + $oldNum), ('UIOrdering = ' + $newNum)
        Set-Content -Path $newPath -Value $content -NoNewline
    }
}

Write-Host "`n=== Verification ===" -ForegroundColor Cyan
Get-ChildItem -Path $overlayPath -Filter "*.ini" | Sort-Object Name | Select-Object -First 25 | ForEach-Object { Write-Host $_.Name }
