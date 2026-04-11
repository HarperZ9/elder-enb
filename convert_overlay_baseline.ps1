# Convert ENB Overlay Absolute Operations to Additive Operations
# Based on new enbseries.ini baseline values

param(
    [string]$OverlayFile,
    [string]$BaselineFile = "C:\Users\Zain\ENB\enbseries.ini"
)

# Parse enbseries.ini baseline values into a dictionary
function Get-BaselineValues {
    param([string]$FilePath)

    $baseline = @{}
    $currentSection = ""

    foreach ($line in Get-Content $FilePath) {
        $line = $line.Trim()

        # Section header
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
            continue
        }

        # Key=Value
        if ($line -match '^([^=]+)=(.+)$' -and $currentSection) {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $fullKey = "$currentSection.$key"
            $baseline[$fullKey] = $value
        }
    }

    return $baseline
}

# Parse a numeric value from string
function Parse-NumericValue {
    param([string]$Value)

    # Remove surrounding quotes if present
    $Value = $Value.Trim('"', "'", ' ')

    # Handle color values (R, G, B)
    if ($Value -match ',') {
        return $null  # Can't do additive on color values
    }

    # Handle boolean
    if ($Value -eq 'true' -or $Value -eq 'false') {
        return $null  # Keep booleans as absolute
    }

    # Try parsing as number
    $num = 0.0
    if ([double]::TryParse($Value, [ref]$num)) {
        return $num
    }

    return $null
}

# Format a delta value
function Format-Delta {
    param([double]$Delta)

    # Round to avoid floating point issues
    $rounded = [math]::Round($Delta, 6)

    # Format with appropriate precision
    if ($rounded -eq [math]::Floor($rounded)) {
        return "$rounded"
    }
    else {
        $formatted = $rounded.ToString("0.######").TrimEnd('0').TrimEnd('.')
        if ($formatted -eq "-0") { $formatted = "0" }
        return $formatted
    }
}

# Process overlay file
function Convert-OverlayFile {
    param(
        [string]$OverlayPath,
        [hashtable]$Baseline
    )

    $content = Get-Content $OverlayPath -Raw
    $lines = Get-Content $OverlayPath
    $modified = $false
    $changes = @()

    $currentBlock = @{}
    $blockStart = -1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Start of a new overlay param block
        if ($line -match '^\[OVERLAYPARAM\d+\]') {
            $currentBlock = @{}
            $blockStart = $i
            continue
        }

        # Parse block properties
        if ($line -match '^(\w+)\s*=\s*(.+)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $currentBlock[$key] = @{ Value = $value; LineIndex = $i }
        }

        # Empty line or new section - process accumulated block
        if (($line.Trim() -eq '' -or $line -match '^\[') -and $currentBlock.Count -gt 0) {
            # Check if this is an enbseries.ini modification with absolute operation
            if ($currentBlock.ContainsKey('FileName') -and
                $currentBlock['FileName'].Value -match 'enbseries\.ini' -and
                $currentBlock.ContainsKey('Category') -and
                $currentBlock.ContainsKey('Name') -and
                $currentBlock.ContainsKey('Operation')) {

                $operation = $currentBlock['Operation'].Value

                # Check for absolute operation "= value"
                if ($operation -match '^"=\s*(.+)"$') {
                    $targetValue = $Matches[1].Trim()
                    $category = $currentBlock['Category'].Value.Trim()
                    $name = $currentBlock['Name'].Value.Trim()

                    # Build baseline key
                    $baselineKey = "$category.$name"

                    if ($Baseline.ContainsKey($baselineKey)) {
                        $baselineValue = $Baseline[$baselineKey]

                        $targetNum = Parse-NumericValue $targetValue
                        $baselineNum = Parse-NumericValue $baselineValue

                        if ($null -ne $targetNum -and $null -ne $baselineNum) {
                            $delta = $targetNum - $baselineNum
                            $deltaStr = Format-Delta $delta

                            # Update the line
                            $operationLine = $currentBlock['Operation'].LineIndex
                            $oldOperation = $lines[$operationLine]
                            $lines[$operationLine] = "Operation = `"+ $deltaStr`""
                            $modified = $true

                            $changes += [PSCustomObject]@{
                                Category = $category
                                Name = $name
                                Baseline = $baselineNum
                                Target = $targetNum
                                Delta = $deltaStr
                            }
                        }
                    }
                }
            }

            $currentBlock = @{}
        }
    }

    if ($modified) {
        $lines | Set-Content $OverlayPath -Encoding UTF8
        Write-Host "Updated: $OverlayPath" -ForegroundColor Green
        Write-Host "Changes made: $($changes.Count)" -ForegroundColor Cyan

        # Show first few changes as examples
        $changes | Select-Object -First 5 | ForEach-Object {
            Write-Host "  $($_.Category).$($_.Name): $($_.Baseline) -> $($_.Target) = + $($_.Delta)"
        }
        if ($changes.Count -gt 5) {
            Write-Host "  ... and $($changes.Count - 5) more changes"
        }
    }
    else {
        Write-Host "No changes needed for: $OverlayPath" -ForegroundColor Yellow
    }

    return $changes.Count
}

# Main execution
Write-Host "Loading baseline from: $BaselineFile" -ForegroundColor Cyan
$baseline = Get-BaselineValues -FilePath $BaselineFile
Write-Host "Loaded $($baseline.Count) baseline values" -ForegroundColor Cyan

if ($OverlayFile) {
    Convert-OverlayFile -OverlayPath $OverlayFile -Baseline $baseline
}
else {
    # Process all Alternative Baseline files
    $files = @(
        "C:\Users\Zain\ENB\enbseries\enbpresetoverlays\000. ENV - Alternative Baseline 1.ini",
        "C:\Users\Zain\ENB\enbseries\enbpresetoverlays\001. ENV - Alternative Baseline 2.ini"
    )

    $totalChanges = 0
    foreach ($file in $files) {
        Write-Host "`nProcessing: $file" -ForegroundColor Yellow
        $totalChanges += Convert-OverlayFile -OverlayPath $file -Baseline $baseline
    }

    Write-Host "`nTotal changes across all files: $totalChanges" -ForegroundColor Green
}
