$folder = 'C:\Users\Zain\ENB\enbseries\enbpresetoverlays'

# Find all files with "Category = ENBSERIES" (incorrect format)
$files = Get-ChildItem "$folder\*.ini" | Where-Object {
    $content = Get-Content $_.FullName -Raw
    $content -match 'Category\s*=\s*ENBSERIES'
}

Write-Host "=== FILES WITH INCORRECT ENBSERIES FORMAT ===" -ForegroundColor Yellow
Write-Host "Found $($files.Count) files to fix:`n"

foreach ($file in $files) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan

    $content = Get-Content $file.FullName -Raw
    $lines = Get-Content $file.FullName
    $newLines = @()
    $fixCount = 0
    $i = 0

    while ($i -lt $lines.Count) {
        $line = $lines[$i]

        # Check if this is a param block with Category = ENBSERIES
        if ($line -match '^\[OVERLAYPARAM\d+\]') {
            # Look ahead for Category = ENBSERIES and Section = ...
            $blockStart = $i
            $hasEnbseries = $false
            $sectionName = $null
            $blockEnd = $i

            # Scan the block
            for ($j = $i + 1; $j -lt $lines.Count -and $lines[$j] -notmatch '^\['; $j++) {
                if ($lines[$j] -match 'Category\s*=\s*ENBSERIES') {
                    $hasEnbseries = $true
                }
                if ($lines[$j] -match 'Section\s*=\s*(\w+)') {
                    $sectionName = $matches[1]
                }
                $blockEnd = $j
            }

            if ($hasEnbseries -and $sectionName) {
                # This block needs fixing
                $newLines += $line  # [OVERLAYPARAMn]
                $newLines += "FileName = enbseries.ini"

                # Copy remaining lines, fixing Category and removing Section
                for ($k = $blockStart + 1; $k -le $blockEnd; $k++) {
                    if ($lines[$k] -match 'Category\s*=\s*ENBSERIES') {
                        $newLines += "Category = $sectionName"
                    } elseif ($lines[$k] -match 'Section\s*=') {
                        # Skip Section line
                    } else {
                        $newLines += $lines[$k]
                    }
                }
                $i = $blockEnd + 1
                $fixCount++
            } else {
                $newLines += $line
                $i++
            }
        } else {
            $newLines += $line
            $i++
        }
    }

    if ($fixCount -gt 0) {
        # Write the fixed content
        $newLines | Set-Content $file.FullName -Encoding UTF8
        Write-Host "  Fixed $fixCount ENBSERIES entries" -ForegroundColor Green
    } else {
        Write-Host "  No fixes needed (unexpected)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== COMPLETE ===" -ForegroundColor Green
