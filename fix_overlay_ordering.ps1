# Fix ENB Preset Overlay Ordering
# This script renames overlay files with zero-padded numbers (e.g., 001. instead of 1.)
# to ensure proper alphabetical sorting in the ENB UI

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Get all .ini files in the main directory (not subfolders)
$files = Get-ChildItem -Path $overlayPath -Filter "*.ini" -File

$renamedCount = 0
$errorCount = 0

foreach ($file in $files) {
    # Match pattern: number followed by period and space
    if ($file.Name -match '^(\d+)\.\s+(.+)$') {
        $number = [int]$Matches[1]
        $restOfName = $Matches[2]

        # Create new name with 3-digit zero-padded number
        $newName = "{0:D3}. {1}" -f $number, $restOfName

        if ($file.Name -ne $newName) {
            $newPath = Join-Path $overlayPath $newName

            try {
                # Rename the file
                Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop

                # Update UIOrdering inside the file to use the same padded format
                $content = Get-Content -Path $newPath -Raw
                $content = $content -replace "UIOrdering = \d+", "UIOrdering = $number"
                Set-Content -Path $newPath -Value $content -NoNewline

                Write-Host "Renamed: $($file.Name) -> $newName"
                $renamedCount++
            }
            catch {
                Write-Host "ERROR: Failed to rename $($file.Name): $_" -ForegroundColor Red
                $errorCount++
            }
        }
    }
    else {
        Write-Host "SKIPPED: $($file.Name) (doesn't match expected pattern)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "===== Summary ====="
Write-Host "Files renamed: $renamedCount"
Write-Host "Errors: $errorCount"
