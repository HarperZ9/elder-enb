# Script to recreate Alternative Baseline overlay files
$overlaysFolder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'
$parentEnbseriesPath = 'C:\Users\Zain\ENB\enbseries\enbseries.ini'

# Source folders
$source1 = 'C:\Users\Zain\ENB\OLD ENB FILES TO MAKE PRESET OVERLAY WITH\enbseries --- for preset overlay 1'
$source2 = 'C:\Users\Zain\ENB\OLD ENB FILES TO MAKE PRESET OVERLAY WITH\enbseries --- for preset overlay 2'

function Parse-IniFile {
    param([string]$Path)
    $content = Get-Content $Path -Raw
    $result = @{}
    $currentSection = ""

    foreach ($line in $content -split "`r?`n") {
        $line = $line.Trim()
        if ($line -match '^\[(.+)\]$') {
            $currentSection = $matches[1]
            if (-not $result[$currentSection]) {
                $result[$currentSection] = @{}
            }
        }
        elseif ($line -match '^([^;=]+)=(.*)$' -and $currentSection) {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $result[$currentSection][$key] = $value
        }
    }
    return $result
}

function Create-OverlayFile {
    param(
        [string]$SourceFolder,
        [string]$OutputPath,
        [string]$ParentEnbseries
    )

    Write-Host "Creating overlay: $OutputPath" -ForegroundColor Cyan

    # Parse parent enbseries.ini
    $parent = Parse-IniFile $ParentEnbseries

    # Parse source files
    $sourceEnbseries = Join-Path $SourceFolder (Get-ChildItem $SourceFolder -Filter "enbseries*.ini" | Select-Object -First 1).Name
    $sourceAdaptation = Join-Path $SourceFolder "enbadaptation.fx.ini"
    $sourceEffect = Join-Path $SourceFolder "enbeffect.fx.ini"
    $sourcePostpass = Join-Path $SourceFolder "enbeffectpostpass.fx.ini"

    $source = Parse-IniFile $sourceEnbseries

    # Build overlay content
    $overlayLines = @()
    $paramNum = 1

    # Compare enbseries.ini sections and find differences
    foreach ($section in $source.Keys) {
        if ($parent[$section]) {
            foreach ($key in $source[$section].Keys) {
                $sourceVal = $source[$section][$key]
                $parentVal = $parent[$section][$key]

                # Compare values (normalize for comparison)
                $sourceNorm = $sourceVal -replace '\s+', ''
                $parentNorm = if ($parentVal) { $parentVal -replace '\s+', '' } else { "" }

                if ($sourceNorm -ne $parentNorm) {
                    $overlayLines += ""
                    $overlayLines += "[OVERLAYPARAM$paramNum]"
                    $overlayLines += "FileName = enbseries.ini"
                    $overlayLines += "Category = $section"
                    $overlayLines += "Name = $key"
                    $overlayLines += "Value = $sourceVal"
                    $paramNum++
                }
            }
        }
    }

    # Process FX files
    $fxFiles = @(
        @{ Path = $sourceAdaptation; Category = "ENBADAPTATION.FX" },
        @{ Path = $sourceEffect; Category = "ENBEFFECT.FX" },
        @{ Path = $sourcePostpass; Category = "ENBEFFECTPOSTPASS.FX" }
    )

    foreach ($fx in $fxFiles) {
        if (Test-Path $fx.Path) {
            $fxContent = Get-Content $fx.Path -Raw
            foreach ($line in $fxContent -split "`r?`n") {
                $line = $line.Trim()
                if ($line -match '^([^;=\[\]]+)=(.+)$' -and $line -notmatch '^\[' -and $line -notmatch '^;') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()

                    # Skip TECHNIQUE line and section headers
                    if ($key -ne "TECHNIQUE" -and $key -notmatch '^\[') {
                        $overlayLines += ""
                        $overlayLines += "[OVERLAYPARAM$paramNum]"
                        $overlayLines += "Category = $($fx.Category)"
                        $overlayLines += "Name = $key"
                        $overlayLines += "Value = $value"
                        $paramNum++
                    }
                }
            }
        }
    }

    # Write the overlay file
    $overlayContent = $overlayLines -join "`r`n"
    Set-Content -Path $OutputPath -Value $overlayContent -Encoding UTF8

    Write-Host "  Created with $($paramNum - 1) parameters" -ForegroundColor Green
    return $paramNum - 1
}

# Create Alternative Baseline 1
$output1 = Join-Path $overlaysFolder "0. OPTIONAL - Alternative Baseline 1.ini"
$count1 = Create-OverlayFile -SourceFolder $source1 -OutputPath $output1 -ParentEnbseries $parentEnbseriesPath

# Create Alternative Baseline 2
$output2 = Join-Path $overlaysFolder "1. OPTIONAL - Alternative Baseline 2.ini"
$count2 = Create-OverlayFile -SourceFolder $source2 -OutputPath $output2 -ParentEnbseries $parentEnbseriesPath

Write-Host "`n=== SUMMARY ===" -ForegroundColor Yellow
Write-Host "Alternative Baseline 1: $count1 parameters"
Write-Host "Alternative Baseline 2: $count2 parameters"
Write-Host "Files created successfully!" -ForegroundColor Green
