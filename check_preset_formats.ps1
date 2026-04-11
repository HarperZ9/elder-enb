$folder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'
$files = Get-ChildItem "$folder\*.ini"

$issues = @()

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $lines = Get-Content $file.FullName

    # Check for enbseries.ini entries without FileName
    # Look for Category = [section names that are in enbseries.ini] without FileName
    $enbseriesSections = @('SKY', 'ENVIRONMENT', 'SKYLIGHTING', 'SSAO_SSIL', 'VOLUMETRICFOG', 'FIRE', 'IMAGEBASEDLIGHTING',
                           'GAMEVOLUMETRICRAYS', 'RAYS', 'VOLUMETRICRAYS', 'CLOUDSHADOWS', 'SUBSURFACESCATTERING',
                           'EFFECT', 'GLOBAL', 'BLOOM', 'SHADOW', 'WATER', 'REFLECTION', 'RAIN', 'ANTIALIASING',
                           'COLORCORRECTION', 'DEPTHOFFIELD', 'LENS')

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\[OVERLAYPARAM\d+\]') {
            $blockStart = $i
            $hasFileName = $false
            $category = $null

            # Scan the block
            for ($j = $i + 1; $j -lt $lines.Count -and $lines[$j] -notmatch '^\['; $j++) {
                if ($lines[$j] -match 'FileName\s*=') {
                    $hasFileName = $true
                }
                if ($lines[$j] -match 'Category\s*=\s*(\S+)') {
                    $category = $matches[1]
                }
            }

            # Check if it's an enbseries section without FileName
            if ($category -and ($enbseriesSections -contains $category) -and -not $hasFileName) {
                $issues += [PSCustomObject]@{
                    File = $file.Name
                    Line = $i + 1
                    Category = $category
                    Issue = "Missing FileName = enbseries.ini"
                }
            }
        }
    }
}

if ($issues.Count -gt 0) {
    Write-Host "=== ISSUES FOUND ===" -ForegroundColor Red
    $issues | Group-Object File | ForEach-Object {
        Write-Host "`n$($_.Name):" -ForegroundColor Cyan
        $_.Group | ForEach-Object {
            Write-Host "  Line $($_.Line): Category=$($_.Category) - $($_.Issue)" -ForegroundColor Yellow
        }
    }
    Write-Host "`nTotal issues: $($issues.Count)"
} else {
    Write-Host "=== NO ISSUES FOUND ===" -ForegroundColor Green
    Write-Host "All preset overlay formats appear correct."
}

# Also check for any remaining "Section =" lines that might indicate old format
Write-Host "`n=== CHECKING FOR ORPHAN 'Section =' LINES ===" -ForegroundColor Yellow
$sectionIssues = @()
foreach ($file in $files) {
    $content = Get-Content $file.FullName
    for ($i = 0; $i -lt $content.Count; $i++) {
        if ($content[$i] -match '^Section\s*=') {
            $sectionIssues += [PSCustomObject]@{
                File = $file.Name
                Line = $i + 1
                Content = $content[$i]
            }
        }
    }
}

if ($sectionIssues.Count -gt 0) {
    Write-Host "Found orphan Section lines:" -ForegroundColor Red
    $sectionIssues | ForEach-Object {
        Write-Host "  $($_.File):$($_.Line) - $($_.Content)"
    }
} else {
    Write-Host "No orphan Section lines found." -ForegroundColor Green
}
