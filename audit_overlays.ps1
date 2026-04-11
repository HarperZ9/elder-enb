# Script to audit all overlay files for UI property consistency

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Define expected UIGroups mapping based on file number ranges
$groupMappings = @{
    "ENV" = "01 - Environment Lighting"
    "QUALITY" = "02 - Quality"
    "PREFERENCES" = "03 - Preferences"
    "LIGHTING" = "04 - Lighting"
    "STYLE" = "05 - KreatE Presets"
    "DOF" = "06 - Depth of Field"
    "BLOOM" = "07 - Bloom Styles"
    "CINEMATIC BORDERS" = "08 - Cinematic Borders"
    "SSAO" = "09 - Ambient Occlusion"
    "LOOK" = "10 - LUT Looks"
    "GRAIN" = "11 - Film Grain"
    "LENS" = "12 - Lens Distortion"
    "VIGNETTE" = "13 - Vignette"
    "BLUR" = "14 - Blur Suite"
}

$files = Get-ChildItem -Path $overlayPath -Filter "*.ini" | Sort-Object Name

Write-Host "Auditing $($files.Count) overlay files..."
Write-Host ""

$issues = @()

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw

    # Extract file number and category from filename
    # Pattern: "NNN. CATEGORY - Name.ini"
    if ($file.Name -match '^(\d{3})\.\s+([A-Z\s]+)\s+-\s+(.+)\.ini$') {
        $fileNum = [int]$matches[1]
        $fileCategory = $matches[2].Trim()
        $fileName = $matches[3].Trim()
        $expectedUIName = "$fileCategory - $fileName"
        $expectedUIOrdering = $fileNum
        $expectedUIGroups = $groupMappings[$fileCategory]
    } else {
        $issues += "FILENAME PARSE ERROR: $($file.Name)"
        continue
    }

    # Extract UI properties from file content
    $actualUIName = ""
    $actualUIGroups = ""
    $actualUIOrdering = ""
    $actualUIDesc = ""

    if ($content -match 'UIName\s*=\s*(.+?)[\r\n]') {
        $actualUIName = $matches[1].Trim()
    }
    if ($content -match 'UIGroups\s*=\s*(.+?)[\r\n]') {
        $actualUIGroups = $matches[1].Trim()
    }
    if ($content -match 'UIOrdering\s*=\s*(\d+)') {
        $actualUIOrdering = [int]$matches[1]
    }
    if ($content -match 'UIDesc\s*=\s*(.+?)[\r\n]') {
        $actualUIDesc = $matches[1].Trim()
    }

    # Check for issues
    $fileIssues = @()

    if ($actualUIName -ne $expectedUIName) {
        $fileIssues += "  UIName: '$actualUIName' should be '$expectedUIName'"
    }

    if ($expectedUIGroups -and $actualUIGroups -ne $expectedUIGroups) {
        $fileIssues += "  UIGroups: '$actualUIGroups' should be '$expectedUIGroups'"
    }

    if ($actualUIOrdering -ne $expectedUIOrdering) {
        $fileIssues += "  UIOrdering: '$actualUIOrdering' should be '$expectedUIOrdering'"
    }

    if ([string]::IsNullOrWhiteSpace($actualUIDesc)) {
        $fileIssues += "  UIDesc: MISSING or EMPTY"
    }

    if ($fileIssues.Count -gt 0) {
        $issues += "$($file.Name):"
        $issues += $fileIssues
        $issues += ""
    }
}

if ($issues.Count -eq 0) {
    Write-Host "All overlay files are correctly configured!"
} else {
    Write-Host "Found issues in the following files:"
    Write-Host ""
    foreach ($issue in $issues) {
        Write-Host $issue
    }
}

Write-Host ""
Write-Host "====================================="
Write-Host "Audit complete"
Write-Host "====================================="
