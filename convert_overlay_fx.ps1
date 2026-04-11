# Convert .FX parameters in overlay files to additive operations
# For .FX parameters, we assume:
# - Values of 0.0 mean "no adjustment" (baseline = 0.0)
# - Values of 1.0 often mean "no change" for multipliers (baseline = 1.0)
# - Booleans and integers (enums) remain absolute

param(
    [string]$OverlayFile
)

function Process-FXOverlay {
    param([string]$OverlayPath)

    $lines = Get-Content $OverlayPath
    $modified = $false
    $changes = @{
        ZeroConverted = 0
        OneConverted = 0
        BooleanSkipped = 0
        IntegerSkipped = 0
        OtherSkipped = 0
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Check for absolute operation without FileName (means .FX parameter)
        if ($line -match '^Operation = "= (.+)"$') {
            $value = $Matches[1].Trim()

            # Check if this is a .FX parameter (look back for no FileName line)
            $hasFileName = $false
            for ($j = $i - 1; $j -ge 0 -and $j -ge $i - 5; $j--) {
                if ($lines[$j] -match '^\[OVERLAYPARAM') { break }
                if ($lines[$j] -match '^FileName\s*=') { $hasFileName = $true; break }
            }

            # Only process .FX parameters (no FileName)
            if (-not $hasFileName) {
                # Handle boolean values - keep absolute
                if ($value -eq 'true' -or $value -eq 'false') {
                    $changes.BooleanSkipped++
                    continue
                }

                # Handle integer values (no decimal) - keep absolute
                if ($value -match '^-?\d+$') {
                    $changes.IntegerSkipped++
                    continue
                }

                # Handle 0.0 - convert to "+ 0.0"
                if ($value -eq '0.0' -or $value -eq '0' -or $value -eq '0.00') {
                    $lines[$i] = 'Operation = "+ 0.0"'
                    $modified = $true
                    $changes.ZeroConverted++
                    continue
                }

                # Handle 1.0 - for multiplier-type params, convert to "+ 0.0"
                # (assuming baseline is 1.0 for multipliers)
                if ($value -eq '1.0' -or $value -eq '1.00') {
                    $lines[$i] = 'Operation = "+ 0.0"'
                    $modified = $true
                    $changes.OneConverted++
                    continue
                }

                # For other numeric values, we need to decide based on context
                # For now, convert assuming baseline is either 0 or 1
                if ($value -match '^-?\d+\.?\d*$') {
                    $numValue = [double]$value

                    # Look at the parameter name for hints
                    $paramName = ""
                    for ($j = $i - 1; $j -ge 0 -and $j -ge $i - 5; $j--) {
                        if ($lines[$j] -match '^\[OVERLAYPARAM') { break }
                        if ($lines[$j] -match '^Name\s*=\s*(.+)$') {
                            $paramName = $Matches[1].Trim()
                            break
                        }
                    }

                    # For exposure, compensation, offset type params: baseline = 0
                    # For intensity, amount, multiplier type params: baseline = 1
                    $isMultiplier = $paramName -match '(Intensity|Amount|Multiplier|Scale|Saturation|Vibrance|Contrast|Gamma|Power|Curve|Strength)'

                    if ($isMultiplier) {
                        # Baseline is 1.0
                        $delta = $numValue - 1.0
                    }
                    else {
                        # Baseline is 0.0
                        $delta = $numValue
                    }

                    # Round and format
                    $deltaRounded = [math]::Round($delta, 6)
                    $deltaStr = $deltaRounded.ToString("0.######").TrimEnd('0').TrimEnd('.')
                    if ($deltaStr -eq "-0") { $deltaStr = "0" }

                    $lines[$i] = "Operation = `"+ $deltaStr`""
                    $modified = $true
                    $changes.OtherSkipped++
                }
            }
        }
    }

    if ($modified) {
        $lines | Set-Content $OverlayPath -Encoding UTF8
        Write-Host "Updated: $OverlayPath" -ForegroundColor Green
    }
    else {
        Write-Host "No .FX changes needed for: $OverlayPath" -ForegroundColor Yellow
    }

    Write-Host "  Zero values (0.0) converted: $($changes.ZeroConverted)"
    Write-Host "  One values (1.0) converted: $($changes.OneConverted)"
    Write-Host "  Other numerics converted: $($changes.OtherSkipped)"
    Write-Host "  Booleans skipped: $($changes.BooleanSkipped)"
    Write-Host "  Integers skipped: $($changes.IntegerSkipped)"

    return $changes
}

# Main execution
if ($OverlayFile) {
    Process-FXOverlay -OverlayPath $OverlayFile
}
else {
    # Process Alternative Baseline files
    $files = @(
        "C:\Users\Zain\ENB\enbseries\enbpresetoverlays\000. ENV - Alternative Baseline 1.ini",
        "C:\Users\Zain\ENB\enbseries\enbpresetoverlays\001. ENV - Alternative Baseline 2.ini"
    )

    foreach ($file in $files) {
        Write-Host "`nProcessing: $file" -ForegroundColor Yellow
        Process-FXOverlay -OverlayPath $file
    }
}
