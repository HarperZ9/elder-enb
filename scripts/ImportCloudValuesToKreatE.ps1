# ImportCloudValuesToKreatE.ps1
# Imports original cloud values from WeatherClouds_Export.csv into KreatE preset weather configs

param(
    [string]$CsvPath = "C:\Users\Zain\ENB\WeatherClouds_Export.csv",
    [string]$KreatEPath = "C:\Users\Zain\ENB\enbseries\KREATE\KreatE",
    [switch]$WhatIf = $false
)

Write-Host "=== Import Cloud Values to KreatE Presets ===" -ForegroundColor Cyan
Write-Host "CSV: $CsvPath"
Write-Host "KreatE Path: $KreatEPath"
Write-Host ""

# Load CSV and build lookup by FormID
# Priority order:
#   1. NAT-ENB.esp (baseline)
#   2. Vanilla plugins (Skyrim.esm, Update.esm, Dawnguard.esm, Dragonborn.esm)
#   3. Other weather mods for any remaining FormIDs

$primaryPlugin = "NAT-ENB.esp"
$vanillaPlugins = @(
    "Skyrim.esm",
    "Update.esm",
    "Dawnguard.esm",
    "Dragonborn.esm"
)
$otherWeatherMods = @(
    "Cathedral Weathers.esp",
    "Obsidian Weathers.esp",
    "Vivid WeathersSE.esp",
    "Azurite Weathers III.esp"
)

Write-Host "Loading CSV..." -ForegroundColor Yellow
$csv = Import-Csv $CsvPath

# Track which FormIDs are covered at each priority level
$coveredFormIDs = @{}

# Priority 1: NAT-ENB.esp (baseline)
$natCsv = $csv | Where-Object { $_.Plugin -eq $primaryPlugin }
foreach ($row in $natCsv) {
    $coveredFormIDs[$row.FormID.ToUpper()] = $true
}

# Priority 2: Vanilla plugins for FormIDs NOT covered by NAT
$vanillaCsv = $csv | Where-Object {
    ($vanillaPlugins -contains $_.Plugin) -and
    (-not $coveredFormIDs.ContainsKey($_.FormID.ToUpper()))
}
foreach ($row in $vanillaCsv) {
    $coveredFormIDs[$row.FormID.ToUpper()] = $true
}

# Priority 3: Other weather mods for any remaining FormIDs
$otherModsCsv = $csv | Where-Object {
    ($otherWeatherMods -contains $_.Plugin) -and
    (-not $coveredFormIDs.ContainsKey($_.FormID.ToUpper()))
}

# Combine all in priority order
$combinedCsv = @($natCsv) + @($vanillaCsv) + @($otherModsCsv)

$csvByFormID = @{}

foreach ($row in $combinedCsv) {
    $formID = $row.FormID.ToUpper()
    if (-not $csvByFormID.ContainsKey($formID)) {
        $csvByFormID[$formID] = @()
    }
    $csvByFormID[$formID] += $row
}

# Count unique FormIDs per source
$natCount = ($natCsv | Select-Object -Property FormID -Unique).Count
$vanillaCount = ($vanillaCsv | Select-Object -Property FormID -Unique).Count
$otherCount = ($otherModsCsv | Select-Object -Property FormID -Unique).Count

Write-Host "Loaded $($csvByFormID.Count) unique weather FormIDs:"
Write-Host "  1. NAT-ENB.esp (baseline): $natCount weathers, $($natCsv.Count) cloud layers" -ForegroundColor Cyan
Write-Host "  2. Vanilla fallback: $vanillaCount weathers, $($vanillaCsv.Count) cloud layers" -ForegroundColor White
Write-Host "  3. Other weather mods: $otherCount weathers, $($otherModsCsv.Count) cloud layers" -ForegroundColor Gray

# Show which other mods contributed
if ($otherModsCsv.Count -gt 0) {
    $otherModsCsv | Group-Object Plugin | ForEach-Object {
        Write-Host "     - $($_.Name): $(($_.Group | Select-Object -Property FormID -Unique).Count) weathers" -ForegroundColor DarkGray
    }
}
Write-Host ""

# Function to convert 0-255 RGB to 0-1 normalized
function ConvertTo-Normalized {
    param([string]$value)
    if ([string]::IsNullOrEmpty($value)) { return "0" }
    $num = [double]$value
    if ($num -gt 1) {
        # Assume 0-255 range, convert to 0-1
        return [math]::Round($num / 255.0, 6).ToString()
    }
    return [math]::Round($num, 6).ToString()
}

# Function to update cloud section in weather file
function Update-CloudSection {
    param(
        [string]$FilePath,
        [array]$CloudLayers,
        [switch]$WhatIf
    )

    $content = Get-Content $FilePath -Raw

    # Check if file has [Clouds] section
    if ($content -notmatch '\[Clouds\]') {
        Write-Host "    No [Clouds] section found, skipping" -ForegroundColor Gray
        return $false
    }

    $modified = $false

    foreach ($layer in $CloudLayers) {
        $layerNum = [int]$layer.Layer

        # Convert colors from CSV (0-255) to normalized (0-1)
        $sunriseR = ConvertTo-Normalized $layer.Sunrise_R
        $sunriseG = ConvertTo-Normalized $layer.Sunrise_G
        $sunriseB = ConvertTo-Normalized $layer.Sunrise_B
        $sunriseA = if ($layer.Sunrise_A) { [math]::Round([double]$layer.Sunrise_A, 6).ToString() } else { "1" }

        $dayR = ConvertTo-Normalized $layer.Day_R
        $dayG = ConvertTo-Normalized $layer.Day_G
        $dayB = ConvertTo-Normalized $layer.Day_B
        $dayA = if ($layer.Day_A) { [math]::Round([double]$layer.Day_A, 6).ToString() } else { "1" }

        $sunsetR = ConvertTo-Normalized $layer.Sunset_R
        $sunsetG = ConvertTo-Normalized $layer.Sunset_G
        $sunsetB = ConvertTo-Normalized $layer.Sunset_B
        $sunsetA = if ($layer.Sunset_A) { [math]::Round([double]$layer.Sunset_A, 6).ToString() } else { "1" }

        $nightR = ConvertTo-Normalized $layer.Night_R
        $nightG = ConvertTo-Normalized $layer.Night_G
        $nightB = ConvertTo-Normalized $layer.Night_B
        $nightA = if ($layer.Night_A) { [math]::Round([double]$layer.Night_A, 6).ToString() } else { "1" }

        # Build replacement values
        $sunriseColor = "$sunriseR, $sunriseG, $sunriseB, $sunriseA"
        $dayColor = "$dayR, $dayG, $dayB, $dayA"
        $sunsetColor = "$sunsetR, $sunsetG, $sunsetB, $sunsetA"
        $nightColor = "$nightR, $nightG, $nightB, $nightA"

        # Get texture path
        $texture = if ($layer.Texture) { "`"$($layer.Texture)`"" } else { '""' }

        # Update each layer property using regex
        $patterns = @(
            @{ Pattern = "Layer${layerNum}ColorSunrise\s*=\s*[^\r\n]+"; Replace = "Layer${layerNum}ColorSunrise = $sunriseColor" },
            @{ Pattern = "Layer${layerNum}ColorDay\s*=\s*[^\r\n]+"; Replace = "Layer${layerNum}ColorDay = $dayColor" },
            @{ Pattern = "Layer${layerNum}ColorSunset\s*=\s*[^\r\n]+"; Replace = "Layer${layerNum}ColorSunset = $sunsetColor" },
            @{ Pattern = "Layer${layerNum}ColorNight\s*=\s*[^\r\n]+"; Replace = "Layer${layerNum}ColorNight = $nightColor" },
            @{ Pattern = "Layer${layerNum}Texture\s*=\s*[^\r\n]+"; Replace = "Layer${layerNum}Texture = $texture" }
        )

        foreach ($p in $patterns) {
            if ($content -match $p.Pattern) {
                $content = $content -replace $p.Pattern, $p.Replace
                $modified = $true
            }
        }
    }

    if ($modified -and -not $WhatIf) {
        Set-Content -Path $FilePath -Value $content -NoNewline
    }

    return $modified
}

# Get all KreatE preset directories
$presetDirs = Get-ChildItem $KreatEPath -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "Weathers")
}

Write-Host "Found $($presetDirs.Count) presets with Weathers folders" -ForegroundColor Green
Write-Host ""

$totalUpdated = 0
$totalFiles = 0
$totalPresets = 0

foreach ($preset in $presetDirs) {
    $weatherPath = Join-Path $preset.FullName "Weathers"
    $weatherFiles = Get-ChildItem $weatherPath -Filter "*.ini" -ErrorAction SilentlyContinue

    if (-not $weatherFiles) { continue }

    $presetUpdated = 0

    foreach ($file in $weatherFiles) {
        $content = Get-Content $file.FullName -Raw

        # Extract FormID from file
        if ($content -match 'ID\s*=\s*0x([0-9A-Fa-f]+)') {
            $hexID = $matches[1].ToUpper().PadLeft(8, '0')

            if ($csvByFormID.ContainsKey($hexID)) {
                $cloudLayers = $csvByFormID[$hexID]

                if ($WhatIf) {
                    Write-Host "  [WhatIf] Would update: $($file.Name) (FormID: $hexID, $($cloudLayers.Count) layers)"
                } else {
                    $updated = Update-CloudSection -FilePath $file.FullName -CloudLayers $cloudLayers
                    if ($updated) {
                        $presetUpdated++
                        $totalUpdated++
                    }
                }
                $totalFiles++
            }
        }
    }

    if ($presetUpdated -gt 0) {
        Write-Host "[$($preset.Name)] Updated $presetUpdated weather files" -ForegroundColor Green
        $totalPresets++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Presets processed: $totalPresets"
Write-Host "Total files updated: $totalUpdated"
Write-Host "Total files with matching FormIDs: $totalFiles"

if ($WhatIf) {
    Write-Host ""
    Write-Host "This was a dry run. Run without -WhatIf to apply changes." -ForegroundColor Yellow
}
