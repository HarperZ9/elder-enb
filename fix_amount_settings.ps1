# Fix missing AmountMin and AmountMax in overlay files

$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"
$files = Get-ChildItem -Path $overlayPath -Filter "*.ini"

$fixedCount = 0

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw

    # Check if AmountMin is already present
    if ($content -notmatch "AmountMin") {
        # Insert AmountMin and AmountMax after IncompatibleOverlays line
        $newContent = $content -replace "(IncompatibleOverlays\s*=\s*[^\r\n]*)", "`$1`r`nAmountMin = 0.00`r`nAmountMax = 1.00"

        if ($newContent -ne $content) {
            Set-Content -Path $file.FullName -Value $newContent -NoNewline
            Write-Host "Fixed: $($file.Name)"
            $fixedCount++
        }
    }
}

Write-Host "`nTotal files fixed: $fixedCount"
