# Script to properly fix BLOOM overlay headers

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Get all BLOOM files
$bloomFiles = Get-ChildItem -Path $overlayPath -Filter "*.ini" | Where-Object { $_.Name -match '\. BLOOM -' }

Write-Host "Found $($bloomFiles.Count) BLOOM files"

foreach ($file in $bloomFiles) {
    $lines = Get-Content -Path $file.FullName
    $newLines = @()
    $inOverlayInfo = $false
    $addedAmount = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^\[OVERLAYINFO\]') {
            $inOverlayInfo = $true
            $addedAmount = $false
        }

        if ($inOverlayInfo -and $line -match '^IncompatibleOverlays\s*=') {
            $newLines += $line
            # Check if next line is NOT AmountMin
            if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -notmatch '^AmountMin') {
                $newLines += "AmountMin = 0.00"
                $newLines += "AmountMax = 1.00"
                $addedAmount = $true
            }
            continue
        }

        # Skip any misplaced AmountMin/AmountMax lines inside comments
        if ($line -match '^AmountMin\s*=' -and $addedAmount) {
            continue
        }
        if ($line -match '^AmountMax\s*=' -and $addedAmount) {
            continue
        }

        if ($line -match '^\[OVERLAYPARAM') {
            $inOverlayInfo = $false
        }

        $newLines += $line
    }

    Set-Content -Path $file.FullName -Value ($newLines -join "`r`n")
    Write-Host "Processed: $($file.Name)"
}

Write-Host ""
Write-Host "====================================="
Write-Host "BLOOM headers fixed"
Write-Host "====================================="
