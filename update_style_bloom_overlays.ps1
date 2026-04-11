# Script to update STYLE and BLOOM overlays
# Removes invalid ENBEFFECTPREPASS.FX references and cleans up formatting

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Get all STYLE files
$styleFiles = Get-ChildItem -Path $overlayPath -Filter "*.ini" | Where-Object { $_.Name -match '\. STYLE -' }

Write-Host "Found $($styleFiles.Count) STYLE files"
$cleanedCount = 0

foreach ($file in $styleFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content

    # Remove ENBEFFECTPREPASS.FX parameter blocks (they don't exist)
    # Match pattern: [OVERLAYPARAM##] followed by Category = ENBEFFECTPREPASS.FX block until next section
    $pattern = '\[OVERLAYPARAM\d+\]\r?\nCategory = ENBEFFECTPREPASS\.FX\r?\nName = [^\r\n]+\r?\nOperation = "[^"]+"\r?\n\r?\n'
    $content = [regex]::Replace($content, $pattern, '')

    # Also remove comment sections that reference PREPASS
    $content = $content -replace '; ============================================\r?\n; PREPASS[^\r\n]*\r?\n; ============================================\r?\n\r?\n', ''

    # Clean up any double blank lines
    $content = $content -replace '\r?\n\r?\n\r?\n+', "`r`n`r`n"

    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Cleaned: $($file.Name)"
        $cleanedCount++
    }
}

Write-Host ""
Write-Host "Cleaned $cleanedCount STYLE files (removed ENBEFFECTPREPASS.FX references)"

# Renumber OVERLAYPARAM sections in cleaned files
Write-Host ""
Write-Host "Renumbering parameters in cleaned files..."

foreach ($file in $styleFiles) {
    $lines = Get-Content -Path $file.FullName
    $paramNum = 1
    $modified = $false
    $newLines = @()

    foreach ($line in $lines) {
        if ($line -match '^\[OVERLAYPARAM\d+\]$') {
            $newLines += "[OVERLAYPARAM$paramNum]"
            $paramNum++
            $modified = $true
        } else {
            $newLines += $line
        }
    }

    if ($modified) {
        Set-Content -Path $file.FullName -Value ($newLines -join "`r`n")
    }
}

Write-Host "Parameter renumbering complete"
Write-Host ""
Write-Host "====================================="
Write-Host "STYLE overlay update complete"
Write-Host "====================================="
