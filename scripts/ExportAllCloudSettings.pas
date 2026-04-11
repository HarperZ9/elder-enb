{
  Export All Cloud Settings to CSV (Comprehensive)

  This xEdit script exports ALL cloud settings from weather records including:
  - Cloud layer textures (00-31)
  - Cloud X/Y speeds
  - Cloud colors for all times of day (Sunrise, Day, Sunset, Night)
  - Cloud alpha values for all times of day
  - Disabled cloud flags

  Skyrim SE supports up to 32 cloud layers per weather record.

  Output: Creates a detailed CSV with one row per weather per cloud layer
  This format makes it easier to compare and restore individual layer settings.

  To use:
  1. Load your plugins in xEdit
  2. Select weather records or entire plugins
  3. Right-click -> Apply Script -> ExportAllCloudSettings
  4. CSV saved to xEdit directory

  Author: KreatE ENB Tools
  Version: 1.1
}
unit ExportAllCloudSettings;

var
  slOutput: TStringList;
  sFileName: string;
  iRecordCount: integer;

function Initialize: integer;
begin
  slOutput := TStringList.Create;
  iRecordCount := 0;

  // CSV Header - One row per cloud layer per weather
  slOutput.Add(
    'FormID,' +
    'EditorID,' +
    'SourcePlugin,' +
    'CloudLayer,' +
    'Texture,' +
    'SpeedX,' +
    'SpeedY,' +
    'Sunrise_Red,' +
    'Sunrise_Green,' +
    'Sunrise_Blue,' +
    'Day_Red,' +
    'Day_Green,' +
    'Day_Blue,' +
    'Sunset_Red,' +
    'Sunset_Green,' +
    'Sunset_Blue,' +
    'Night_Red,' +
    'Night_Green,' +
    'Night_Blue,' +
    'Alpha_Sunrise,' +
    'Alpha_Day,' +
    'Alpha_Sunset,' +
    'Alpha_Night,' +
    'Disabled'
  );

  sFileName := ProgramPath + 'CloudSettings_Full_Export.csv';
  Result := 0;
end;

function EscapeCSV(s: string): string;
begin
  // Escape commas and quotes in CSV fields
  if (Pos(',', s) > 0) or (Pos('"', s) > 0) then begin
    s := StringReplace(s, '"', '""', [rfReplaceAll]);
    Result := '"' + s + '"';
  end
  else
    Result := s;
end;

function SafeGetValue(e: IInterface; path: string): string;
var
  el: IInterface;
begin
  Result := '';
  el := ElementByPath(e, path);
  if Assigned(el) then
    Result := GetEditValue(el);
end;

function GetCloudTexture(e: IInterface; layer: integer): string;
var
  cloudTextures: IInterface;
  textureEl: IInterface;
  layerStr: string;
begin
  Result := '';

  // Format layer number with leading zero for paths
  if layer < 10 then
    layerStr := '0' + IntToStr(layer)
  else
    layerStr := IntToStr(layer);

  // Try direct path first (Skyrim SE structure)
  cloudTextures := ElementByPath(e, 'Cloud Textures\' + layerStr + ' - Layer');
  if Assigned(cloudTextures) then begin
    Result := GetEditValue(cloudTextures);
    Exit;
  end;

  // Try NNAM array structure
  cloudTextures := ElementBySignature(e, 'NNAM');
  if Assigned(cloudTextures) then begin
    if layer < ElementCount(cloudTextures) then begin
      textureEl := ElementByIndex(cloudTextures, layer);
      if Assigned(textureEl) then
        Result := GetEditValue(textureEl);
    end;
  end;
end;

function GetCloudSpeedX(e: IInterface; layer: integer): string;
var
  speedArray: IInterface;
  speedEl: IInterface;
begin
  Result := '0';

  // Try QNAM structure (Cloud X Speeds)
  speedArray := ElementBySignature(e, 'QNAM');
  if Assigned(speedArray) then begin
    if layer < ElementCount(speedArray) then begin
      speedEl := ElementByIndex(speedArray, layer);
      if Assigned(speedEl) then
        Result := GetEditValue(speedEl);
    end;
  end;
end;

function GetCloudSpeedY(e: IInterface; layer: integer): string;
var
  speedArray: IInterface;
  speedEl: IInterface;
begin
  Result := '0';

  // Try RNAM structure (Cloud Y Speeds)
  speedArray := ElementBySignature(e, 'RNAM');
  if Assigned(speedArray) then begin
    if layer < ElementCount(speedArray) then begin
      speedEl := ElementByIndex(speedArray, layer);
      if Assigned(speedEl) then
        Result := GetEditValue(speedEl);
    end;
  end;
end;

function GetCloudColor(e: IInterface; layer: integer; timeOfDay: string; component: string): string;
var
  colorPath: string;
  colorEl: IInterface;
  layerStr: string;
begin
  Result := '0';

  if layer < 10 then
    layerStr := '0' + IntToStr(layer)
  else
    layerStr := IntToStr(layer);

  // PNAM structure for cloud colors
  // Path: PNAM\[index]\TimeOfDay\Component
  colorPath := 'PNAM - Cloud Colors\Layer #' + IntToStr(layer) + '\' + timeOfDay + '\' + component;
  colorEl := ElementByPath(e, colorPath);
  if Assigned(colorEl) then begin
    Result := GetEditValue(colorEl);
    Exit;
  end;

  // Alternative path structure
  colorPath := 'PNAM\[' + IntToStr(layer) + ']\' + timeOfDay + '\' + component;
  colorEl := ElementByPath(e, colorPath);
  if Assigned(colorEl) then
    Result := GetEditValue(colorEl);
end;

function GetCloudAlpha(e: IInterface; layer: integer; timeOfDay: string): string;
var
  alphaPath: string;
  alphaEl: IInterface;
  alphaArray: IInterface;
  timeIndex: integer;
begin
  Result := '0';

  // JNAM structure for cloud alphas
  // Structure: JNAM\[layer]\[timeIndex] where timeIndex is 0=Sunrise, 1=Day, 2=Sunset, 3=Night
  if timeOfDay = 'Sunrise' then timeIndex := 0
  else if timeOfDay = 'Day' then timeIndex := 1
  else if timeOfDay = 'Sunset' then timeIndex := 2
  else if timeOfDay = 'Night' then timeIndex := 3
  else timeIndex := 0;

  // Try path format
  alphaPath := 'JNAM - Cloud Alphas\Layer #' + IntToStr(layer) + '\' + timeOfDay;
  alphaEl := ElementByPath(e, alphaPath);
  if Assigned(alphaEl) then begin
    Result := GetEditValue(alphaEl);
    Exit;
  end;

  // Alternative: direct array access
  alphaArray := ElementBySignature(e, 'JNAM');
  if Assigned(alphaArray) then begin
    // Each layer has 4 alpha values (sunrise, day, sunset, night)
    if (layer * 4 + timeIndex) < ElementCount(alphaArray) then begin
      alphaEl := ElementByIndex(alphaArray, layer * 4 + timeIndex);
      if Assigned(alphaEl) then
        Result := GetEditValue(alphaEl);
    end;
  end;
end;

function IsCloudLayerDisabled(e: IInterface; layer: integer): string;
var
  disabledFlags: IInterface;
  flagEl: IInterface;
begin
  Result := 'false';

  // NAM1 contains disabled cloud layer flags
  disabledFlags := ElementBySignature(e, 'NAM1');
  if Assigned(disabledFlags) then begin
    // Check if this layer's bit is set
    // The value is a bitmask where each bit represents a layer
    // For now, return the full flag value and let user interpret
    Result := GetEditValue(disabledFlags);
  end;
end;

function HasCloudData(e: IInterface; layer: integer): boolean;
var
  texture: string;
begin
  texture := GetCloudTexture(e, layer);
  Result := (texture <> '');
end;

function Process(e: IInterface): integer;
var
  sFormID, sEditorID, sSourcePlugin: string;
  sLine: string;
  i: integer;
  texture, speedX, speedY: string;
  srR, srG, srB, dayR, dayG, dayB, ssR, ssG, ssB, ntR, ntG, ntB: string;
  alphaSR, alphaDay, alphaSS, alphaNT: string;
  disabled: string;
begin
  Result := 0;

  // Only process WTHR records
  if Signature(e) <> 'WTHR' then
    Exit;

  sFormID := IntToHex(FormID(e), 8);
  sEditorID := EditorID(e);
  sSourcePlugin := GetFileName(GetFile(e));

  Inc(iRecordCount);

  // Process each cloud layer (0-31)
  for i := 0 to 31 do begin
    // Only export layers that have texture data
    texture := GetCloudTexture(e, i);
    if texture = '' then
      Continue;

    speedX := GetCloudSpeedX(e, i);
    speedY := GetCloudSpeedY(e, i);

    // Sunrise colors
    srR := GetCloudColor(e, i, 'Sunrise', 'Red');
    srG := GetCloudColor(e, i, 'Sunrise', 'Green');
    srB := GetCloudColor(e, i, 'Sunrise', 'Blue');

    // Day colors
    dayR := GetCloudColor(e, i, 'Day', 'Red');
    dayG := GetCloudColor(e, i, 'Day', 'Green');
    dayB := GetCloudColor(e, i, 'Day', 'Blue');

    // Sunset colors
    ssR := GetCloudColor(e, i, 'Sunset', 'Red');
    ssG := GetCloudColor(e, i, 'Sunset', 'Green');
    ssB := GetCloudColor(e, i, 'Sunset', 'Blue');

    // Night colors
    ntR := GetCloudColor(e, i, 'Night', 'Red');
    ntG := GetCloudColor(e, i, 'Night', 'Green');
    ntB := GetCloudColor(e, i, 'Night', 'Blue');

    // Alpha values
    alphaSR := GetCloudAlpha(e, i, 'Sunrise');
    alphaDay := GetCloudAlpha(e, i, 'Day');
    alphaSS := GetCloudAlpha(e, i, 'Sunset');
    alphaNT := GetCloudAlpha(e, i, 'Night');

    // Disabled flag
    disabled := IsCloudLayerDisabled(e, i);

    // Build CSV line
    sLine := sFormID + ',' +
             EscapeCSV(sEditorID) + ',' +
             EscapeCSV(sSourcePlugin) + ',' +
             IntToStr(i) + ',' +
             EscapeCSV(texture) + ',' +
             speedX + ',' +
             speedY + ',' +
             srR + ',' + srG + ',' + srB + ',' +
             dayR + ',' + dayG + ',' + dayB + ',' +
             ssR + ',' + ssG + ',' + ssB + ',' +
             ntR + ',' + ntG + ',' + ntB + ',' +
             alphaSR + ',' + alphaDay + ',' + alphaSS + ',' + alphaNT + ',' +
             disabled;

    slOutput.Add(sLine);
  end;
end;

function Finalize: integer;
begin
  AddMessage('');
  AddMessage('=== Cloud Settings Export Complete ===');
  AddMessage('Output file: ' + sFileName);
  AddMessage('Weather records processed: ' + IntToStr(iRecordCount));
  AddMessage('Cloud layer entries exported: ' + IntToStr(slOutput.Count - 1));
  AddMessage('');

  slOutput.SaveToFile(sFileName);
  slOutput.Free;
  Result := 0;
end;

end.
