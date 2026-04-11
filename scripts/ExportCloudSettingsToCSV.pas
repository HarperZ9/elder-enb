{
  Export Cloud Settings to CSV

  This xEdit script exports all cloud settings from weather records including:
  - Cloud layer textures (NNAM paths)
  - Cloud X/Y/Z speeds
  - Cloud colors (sunrise, day, sunset, night for each layer)
  - Cloud alpha values (sunrise, day, sunset, night for each layer)

  To use:
  1. Load your plugins in xEdit
  2. Select the weather records you want to export (or select the plugin to export all)
  3. Right-click and Apply Script
  4. Select this script
  5. CSV will be saved to the xEdit directory

  Author: KreatE ENB Tools
  Version: 1.0
}
unit ExportCloudSettingsToCSV;

var
  slOutput: TStringList;
  sFileName: string;

function Initialize: integer;
begin
  slOutput := TStringList.Create;

  // CSV Header
  slOutput.Add(
    'FormID,EditorID,SourcePlugin,' +
    'Cloud0_Texture,Cloud0_SpeedX,Cloud0_SpeedY,' +
    'Cloud0_Color_Sunrise_R,Cloud0_Color_Sunrise_G,Cloud0_Color_Sunrise_B,' +
    'Cloud0_Color_Day_R,Cloud0_Color_Day_G,Cloud0_Color_Day_B,' +
    'Cloud0_Color_Sunset_R,Cloud0_Color_Sunset_G,Cloud0_Color_Sunset_B,' +
    'Cloud0_Color_Night_R,Cloud0_Color_Night_G,Cloud0_Color_Night_B,' +
    'Cloud0_Alpha_Sunrise,Cloud0_Alpha_Day,Cloud0_Alpha_Sunset,Cloud0_Alpha_Night,' +
    'Cloud1_Texture,Cloud1_SpeedX,Cloud1_SpeedY,' +
    'Cloud1_Color_Sunrise_R,Cloud1_Color_Sunrise_G,Cloud1_Color_Sunrise_B,' +
    'Cloud1_Color_Day_R,Cloud1_Color_Day_G,Cloud1_Color_Day_B,' +
    'Cloud1_Color_Sunset_R,Cloud1_Color_Sunset_G,Cloud1_Color_Sunset_B,' +
    'Cloud1_Color_Night_R,Cloud1_Color_Night_G,Cloud1_Color_Night_B,' +
    'Cloud1_Alpha_Sunrise,Cloud1_Alpha_Day,Cloud1_Alpha_Sunset,Cloud1_Alpha_Night,' +
    'Cloud2_Texture,Cloud2_SpeedX,Cloud2_SpeedY,' +
    'Cloud2_Color_Sunrise_R,Cloud2_Color_Sunrise_G,Cloud2_Color_Sunrise_B,' +
    'Cloud2_Color_Day_R,Cloud2_Color_Day_G,Cloud2_Color_Day_B,' +
    'Cloud2_Color_Sunset_R,Cloud2_Color_Sunset_G,Cloud2_Color_Sunset_B,' +
    'Cloud2_Color_Night_R,Cloud2_Color_Night_G,Cloud2_Color_Night_B,' +
    'Cloud2_Alpha_Sunrise,Cloud2_Alpha_Day,Cloud2_Alpha_Sunset,Cloud2_Alpha_Night,' +
    'Cloud3_Texture,Cloud3_SpeedX,Cloud3_SpeedY,' +
    'Cloud3_Color_Sunrise_R,Cloud3_Color_Sunrise_G,Cloud3_Color_Sunrise_B,' +
    'Cloud3_Color_Day_R,Cloud3_Color_Day_G,Cloud3_Color_Day_B,' +
    'Cloud3_Color_Sunset_R,Cloud3_Color_Sunset_G,Cloud3_Color_Sunset_B,' +
    'Cloud3_Color_Night_R,Cloud3_Color_Night_G,Cloud3_Color_Night_B,' +
    'Cloud3_Alpha_Sunrise,Cloud3_Alpha_Day,Cloud3_Alpha_Sunset,Cloud3_Alpha_Night'
  );

  sFileName := ProgramPath + 'CloudSettings_Export.csv';
  Result := 0;
end;

function GetCloudTexture(e: IInterface; layer: integer): string;
var
  cloudTextures: IInterface;
begin
  Result := '';
  // Cloud textures are stored in NNAM - Cloud Textures array
  cloudTextures := ElementBySignature(e, 'NNAM');
  if Assigned(cloudTextures) then begin
    if layer < ElementCount(cloudTextures) then
      Result := GetEditValue(ElementByIndex(cloudTextures, layer));
  end;
end;

function GetCloudSpeed(e: IInterface; layer: integer; axis: string): string;
var
  cloudSpeeds: IInterface;
  speedEntry: IInterface;
begin
  Result := '0';
  // Cloud speeds stored in NAM0 or similar structure
  // X speeds in one array, Y speeds in another
  if axis = 'X' then begin
    cloudSpeeds := ElementByPath(e, 'Cloud Speed\QNAM');
    if Assigned(cloudSpeeds) then begin
      if layer < ElementCount(cloudSpeeds) then
        Result := GetEditValue(ElementByIndex(cloudSpeeds, layer));
    end;
  end
  else if axis = 'Y' then begin
    cloudSpeeds := ElementByPath(e, 'Cloud Speed\RNAM');
    if Assigned(cloudSpeeds) then begin
      if layer < ElementCount(cloudSpeeds) then
        Result := GetEditValue(ElementByIndex(cloudSpeeds, layer));
    end;
  end;
end;

function GetCloudColorComponent(e: IInterface; layer: integer; timeOfDay: string; component: string): string;
var
  cloudColors: IInterface;
  colorEntry: IInterface;
  colorStruct: IInterface;
  pathStr: string;
begin
  Result := '0';

  // Cloud colors are stored in PNAM - Cloud Colors
  // Structure: PNAM\[layer]\[timeOfDay]\[component]
  pathStr := 'PNAM\[' + IntToStr(layer) + ']\' + timeOfDay + '\' + component;

  colorStruct := ElementByPath(e, pathStr);
  if Assigned(colorStruct) then
    Result := GetEditValue(colorStruct);
end;

function GetCloudAlpha(e: IInterface; layer: integer; timeOfDay: string): string;
var
  cloudAlphas: IInterface;
  alphaEntry: IInterface;
  pathStr: string;
begin
  Result := '0';

  // Cloud alphas stored in JNAM - Cloud Alphas
  // Structure varies by game version
  pathStr := 'JNAM\[' + IntToStr(layer) + ']\' + timeOfDay;

  alphaEntry := ElementByPath(e, pathStr);
  if Assigned(alphaEntry) then
    Result := GetEditValue(alphaEntry);
end;

function BuildCloudLayerData(e: IInterface; layer: integer): string;
var
  texture, speedX, speedY: string;
  sunriseR, sunriseG, sunriseB: string;
  dayR, dayG, dayB: string;
  sunsetR, sunsetG, sunsetB: string;
  nightR, nightG, nightB: string;
  alphaSunrise, alphaDay, alphaSunset, alphaNight: string;
begin
  texture := GetCloudTexture(e, layer);
  speedX := GetCloudSpeed(e, layer, 'X');
  speedY := GetCloudSpeed(e, layer, 'Y');

  // Get colors for each time of day
  sunriseR := GetCloudColorComponent(e, layer, 'Sunrise', 'Red');
  sunriseG := GetCloudColorComponent(e, layer, 'Sunrise', 'Green');
  sunriseB := GetCloudColorComponent(e, layer, 'Sunrise', 'Blue');

  dayR := GetCloudColorComponent(e, layer, 'Day', 'Red');
  dayG := GetCloudColorComponent(e, layer, 'Day', 'Green');
  dayB := GetCloudColorComponent(e, layer, 'Day', 'Blue');

  sunsetR := GetCloudColorComponent(e, layer, 'Sunset', 'Red');
  sunsetG := GetCloudColorComponent(e, layer, 'Sunset', 'Green');
  sunsetB := GetCloudColorComponent(e, layer, 'Sunset', 'Blue');

  nightR := GetCloudColorComponent(e, layer, 'Night', 'Red');
  nightG := GetCloudColorComponent(e, layer, 'Night', 'Green');
  nightB := GetCloudColorComponent(e, layer, 'Night', 'Blue');

  // Get alpha values
  alphaSunrise := GetCloudAlpha(e, layer, 'Sunrise');
  alphaDay := GetCloudAlpha(e, layer, 'Day');
  alphaSunset := GetCloudAlpha(e, layer, 'Sunset');
  alphaNight := GetCloudAlpha(e, layer, 'Night');

  Result := texture + ',' + speedX + ',' + speedY + ',' +
            sunriseR + ',' + sunriseG + ',' + sunriseB + ',' +
            dayR + ',' + dayG + ',' + dayB + ',' +
            sunsetR + ',' + sunsetG + ',' + sunsetB + ',' +
            nightR + ',' + nightG + ',' + nightB + ',' +
            alphaSunrise + ',' + alphaDay + ',' + alphaSunset + ',' + alphaNight;
end;

function Process(e: IInterface): integer;
var
  sFormID, sEditorID, sSourcePlugin: string;
  sLine: string;
  i: integer;
begin
  Result := 0;

  // Only process WTHR records
  if Signature(e) <> 'WTHR' then
    Exit;

  sFormID := IntToHex(FormID(e), 8);
  sEditorID := EditorID(e);
  sSourcePlugin := GetFileName(GetFile(e));

  // Build CSV line
  sLine := sFormID + ',' + sEditorID + ',' + sSourcePlugin;

  // Add data for cloud layers 0-3 (most weathers use 4 layers)
  for i := 0 to 3 do begin
    sLine := sLine + ',' + BuildCloudLayerData(e, i);
  end;

  slOutput.Add(sLine);
end;

function Finalize: integer;
begin
  AddMessage('Saving cloud settings to: ' + sFileName);
  slOutput.SaveToFile(sFileName);
  AddMessage('Exported ' + IntToStr(slOutput.Count - 1) + ' weather records');
  slOutput.Free;
  Result := 0;
end;

end.
