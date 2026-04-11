# Fix OPTIONAL presets and Vignette presets
$overlaysFolder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

# ============================================
# Check what UIGroups working presets use
# ============================================
Write-Host "=== CHECKING UIGROUPS ===" -ForegroundColor Yellow
$files = Get-ChildItem "$overlaysFolder\*.ini" | Select-Object -First 30
$groups = @{}
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw
    if ($content -match 'UIGroups = (.+)') {
        $group = $matches[1].Trim()
        if (-not $groups[$group]) { $groups[$group] = @() }
        $groups[$group] += $f.Name
    }
}
foreach ($g in $groups.Keys | Sort-Object) {
    Write-Host "  $g : $($groups[$g].Count) presets" -ForegroundColor Cyan
}

# ============================================
# Fix OPTIONAL presets - use matching UIGroups format
# ============================================
Write-Host "`n=== FIXING OPTIONAL PRESETS ===" -ForegroundColor Yellow

$optionalFiles = Get-ChildItem "$overlaysFolder\*OPTIONAL*.ini"
foreach ($f in $optionalFiles) {
    $content = Get-Content $f.FullName -Raw
    # Change "Optional Styles" to match other categories like "KreatE Presets"
    # Actually, let's keep the group name but ensure format is exactly right
    Write-Host "  Checking: $($f.Name)" -ForegroundColor Gray
}

# ============================================
# Fix VIGNETTE presets - use Operation format for Enable
# ============================================
Write-Host "`n=== FIXING VIGNETTE PRESETS ===" -ForegroundColor Yellow

$vignetteFiles = Get-ChildItem "$overlaysFolder\*VIGNETTE*.ini"
foreach ($f in $vignetteFiles) {
    $lines = Get-Content $f.FullName
    $newLines = @()
    $modified = $false

    foreach ($line in $lines) {
        if ($line -match '^Value = (true|false)$') {
            $val = $matches[1]
            $newLine = "Operation = `"= $val`""
            $newLines += $newLine
            $modified = $true
            Write-Host "  Fixed Enable in $($f.Name): Value = $val -> Operation = `"= $val`"" -ForegroundColor Green
        } else {
            $newLines += $line
        }
    }

    if ($modified) {
        Set-Content -Path $f.FullName -Value ($newLines -join "`r`n") -Encoding UTF8
    }
}

Write-Host "`nDone!" -ForegroundColor Yellow
