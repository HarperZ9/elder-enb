# Script to convert ENV overlay additive operations to absolute values
# Reads baseline from enbseries.ini and calculates absolute values

$enbseriesPath = "C:\Users\Zain\ENB\enbseries.ini"
$overlayPath = "C:\Users\Zain\ENB\enbseries\enbpresetoverlays"

# Parse enbseries.ini to get baseline values
$enbContent = Get-Content $enbseriesPath -Raw
$baselineValues = @{}
$currentSection = ""

foreach ($line in (Get-Content $enbseriesPath)) {
    $line = $line.Trim()
    if ($line -match '^\[(.+)\]$') {
        $currentSection = $matches[1]
    }
    elseif ($line -match '^([^=]+)=(.+)$' -and $currentSection) {
        $key = "$currentSection.$($matches[1].Trim())"
        $value = $matches[2].Trim()
        # Try to parse as number
        if ($value -match '^-?\d+\.?\d*$') {
            $baselineValues[$key] = [double]$value
        }
    }
}

Write-Host "Loaded $($baselineValues.Count) baseline values from enbseries.ini"
Write-Host ""

# Key baseline values for reference:
$keyParams = @(
    "VOLUMETRICFOG.IntensityDawn",
    "VOLUMETRICFOG.IntensityDay",
    "VOLUMETRICFOG.IntensityNight",
    "GAMEVOLUMETRICRAYS.IntensityNight",
    "GAMEVOLUMETRICRAYS.RangeFactorNight",
    "SKY.GradientIntensityNight",
    "SKY.MoonIntensityNight",
    "ENVIRONMENT.DirectLightingIntensityNight",
    "ENVIRONMENT.AmbientLightingIntensityNight",
    "ENVIRONMENT.ColorPowDay",
    "ENVIRONMENT.FogAmountMultiplierNight",
    "ENVIRONMENT.FogCurveMultiplierNight",
    "FIRE.IntensityDay",
    "FIRE.IntensityNight",
    "SSAO_SSIL.AOAmount",
    "SSAO_SSIL.AOAmountInterior",
    "SSAO_SSIL.AOIntensity",
    "SSAO_SSIL.ILAmount",
    "SSAO_SSIL.ILAmountInterior"
)

Write-Host "Key baseline values:"
foreach ($param in $keyParams) {
    if ($baselineValues.ContainsKey($param)) {
        Write-Host "  $param = $($baselineValues[$param])"
    }
}

Write-Host ""
Write-Host "Calculating absolute values for Alternative Baseline 1..."

# Alternative Baseline 1 calculations
$calculations = @(
    @{Section="VOLUMETRICFOG"; Name="IntensityDawn"; Additive=-0.55},
    @{Section="VOLUMETRICFOG"; Name="IntensityDay"; Additive=-0.55},
    @{Section="VOLUMETRICFOG"; Name="IntensitySunrise"; Additive=-0.55},
    @{Section="VOLUMETRICFOG"; Name="IntensitySunset"; Additive=-0.55},
    @{Section="VOLUMETRICFOG"; Name="IntensityDusk"; Additive=-0.55},
    @{Section="VOLUMETRICFOG"; Name="IntensityNight"; Additive=2},
    @{Section="GAMEVOLUMETRICRAYS"; Name="RangeFactorNight"; Additive=-0.95},
    @{Section="GAMEVOLUMETRICRAYS"; Name="IntensityNight"; Additive=-0.2},
    @{Section="SKY"; Name="GradientIntensityNight"; Additive=-1},
    @{Section="SKY"; Name="MoonIntensityNight"; Additive=0.75},
    @{Section="ENVIRONMENT"; Name="DirectLightingIntensityNight"; Additive=-0.8},
    @{Section="ENVIRONMENT"; Name="AmbientLightingIntensityNight"; Additive=-0.35},
    @{Section="ENVIRONMENT"; Name="FogAmountMultiplierNight"; Additive=-0.9},
    @{Section="ENVIRONMENT"; Name="FogCurveMultiplierNight"; Additive=2.35},
    @{Section="ENVIRONMENT"; Name="ColorPowDawn"; Additive=0.4},
    @{Section="ENVIRONMENT"; Name="ColorPowSunrise"; Additive=0.4},
    @{Section="ENVIRONMENT"; Name="ColorPowDay"; Additive=0.4},
    @{Section="ENVIRONMENT"; Name="ColorPowSunset"; Additive=0.4},
    @{Section="ENVIRONMENT"; Name="ColorPowDusk"; Additive=0.4},
    @{Section="ENVIRONMENT"; Name="ColorPowNight"; Additive=0.4},
    @{Section="ENVIRONMENT"; Name="ColorPowInteriorDay"; Additive=0.4},
    @{Section="ENVIRONMENT"; Name="ColorPowInteriorNight"; Additive=0.4},
    @{Section="FIRE"; Name="IntensityDawn"; Additive=-2.75},
    @{Section="FIRE"; Name="IntensitySunrise"; Additive=-3},
    @{Section="FIRE"; Name="IntensityDay"; Additive=-4},
    @{Section="FIRE"; Name="IntensitySunset"; Additive=-3},
    @{Section="FIRE"; Name="IntensityDusk"; Additive=-2.75},
    @{Section="FIRE"; Name="IntensityNight"; Additive=-2.5},
    @{Section="FIRE"; Name="IntensityInteriorDay"; Additive=-2.5},
    @{Section="FIRE"; Name="IntensityInteriorNight"; Additive=-2.5},
    @{Section="SSAO_SSIL"; Name="AOAmount"; Additive=-3},
    @{Section="SSAO_SSIL"; Name="AOAmountInterior"; Additive=-3},
    @{Section="SSAO_SSIL"; Name="AOIntensity"; Additive=0.2},
    @{Section="SSAO_SSIL"; Name="ILAmount"; Additive=0.15},
    @{Section="SSAO_SSIL"; Name="ILAmountInterior"; Additive=1.45},
    @{Section="SSAO_SSIL"; Name="AOMultiplierSSSInterior"; Additive=0.5},
    @{Section="SSAO_SSIL"; Name="ILMultiplierSSS"; Additive=-0.5},
    @{Section="SSAO_SSIL"; Name="ILMultiplierSSSInterior"; Additive=-0.8},
    @{Section="SSAO_SSIL"; Name="ILBrightnessCompressionDawn"; Additive=0},
    @{Section="SSAO_SSIL"; Name="ILBrightnessCompressionSunrise"; Additive=2.3},
    @{Section="SSAO_SSIL"; Name="ILBrightnessCompressionDay"; Additive=2.3},
    @{Section="SSAO_SSIL"; Name="ILBrightnessCompressionSunset"; Additive=2.3},
    @{Section="SSAO_SSIL"; Name="ILBrightnessCompressionDusk"; Additive=2.3},
    @{Section="RAYS"; Name="MoonType"; Additive=-1},
    @{Section="RAYS"; Name="MoonRaysMultiplierNight"; Additive=-0.5},
    @{Section="SKYLIGHTING"; Name="AmbientMinLevelDawn"; Additive=0.3},
    @{Section="SKYLIGHTING"; Name="AmbientMinLevelSunrise"; Additive=0.4},
    @{Section="SKYLIGHTING"; Name="AmbientMinLevelDay"; Additive=0.5},
    @{Section="SKYLIGHTING"; Name="AmbientMinLevelSunset"; Additive=0.4},
    @{Section="SKYLIGHTING"; Name="AmbientMinLevelDusk"; Additive=0.3}
)

Write-Host ""
Write-Host "Calculated absolute values:"
foreach ($calc in $calculations) {
    $key = "$($calc.Section).$($calc.Name)"
    if ($baselineValues.ContainsKey($key)) {
        $baseline = $baselineValues[$key]
        $absolute = $baseline + $calc.Additive
        Write-Host "  $key : $baseline + $($calc.Additive) = $absolute"
    } else {
        Write-Host "  $key : BASELINE NOT FOUND (additive was $($calc.Additive))"
    }
}
