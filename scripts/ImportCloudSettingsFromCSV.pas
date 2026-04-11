{
  Import Cloud Settings from CSV

  This xEdit script restores cloud settings from a previously exported CSV file.
  Use this in conjunction with ExportAllCloudSettings.pas to revert cloud
  modifications back to their original weather record values.

  CSV Format Expected (from ExportAllCloudSettings.pas):
  FormID,EditorID,SourcePlugin,CloudLayer,Texture,SpeedX,SpeedY,
  Sunrise_Red,Sunrise_Green,Sunrise_Blue,Day_Red,Day_Green,Day_Blue,
  Sunset_Red,Sunset_Green,Sunset_Blue,Night_Red,Night_Green,Night_Blue,
  Alpha_Sunrise,Alpha_Day,Alpha_Sunset,Alpha_Night,Disabled

  To use:
  1. Export your original cloud settings FIRST using ExportAllCloudSettings
  2. Make any modifications to weather records
  3. To revert: Load plugins, select weather records, apply this script
  4. Script will prompt for CSV file location

  Author: KreatE ENB Tools
  Version: 1.0
}
unit ImportCloudSettingsFromCSV;

uses mteFunctions;

var
  slCSV: TStringList;
  dictCloudData: TStringList;
  iUpdatedRecords: integer;
  iUpdatedLayers: integer;

function Initialize: integer;
var
  sFileName: string;
  i: integer;
  sLine, sKey: string;
  slParts: TStringList;
begin
  Result := 0;
  iUpdatedRecords := 0;
  iUpdatedLayers := 0;

  // Prompt for CSV file
  sFileName := ProgramPath + 'CloudSettings_Full_Export.csv';
  if not InputQuery('Import Cloud Settings', 'Enter path to CSV file:', sFileName) then begin
    AddMessage('Import cancelled.');
    Result := 1;
    Exit;
  end;

  if not FileExists(sFileName) then begin
    AddMessage('ERROR: File not found: ' + sFileName);
    Result := 1;
    Exit;
  end;

  slCSV := TStringList.Create;
  dictCloudData := TStringList.Create;
  slParts := TStringList.Create;

  try
    slCSV.LoadFromFile(sFileName);
    AddMessage('Loaded ' + IntToStr(slCSV.Count) + ' lines from CSV');

    // Build dictionary: Key = FormID_Layer, Value = full CSV line
    for i := 1 to slCSV.Count - 1 do begin  // Skip header
      sLine := slCSV[i];
      if sLine = '' then Continue;

      // Parse first two fields (FormID and skip to Layer)
      slParts.Clear;
      slParts.Delimiter := ',';
      slParts.StrictDelimiter := True;
      slParts.DelimitedText := sLine;

      if slParts.Count >= 4 then begin
        // Key = FormID_CloudLayer
        sKey := slParts[0] + '_' + slParts[3];
        dictCloudData.AddObject(sKey, TObject(i));
      end;
    end;

    AddMessage('Indexed ' + IntToStr(dictCloudData.Count) + ' cloud layer entries');

  finally
    slParts.Free;
  end;
end;

function ParseCSVLine(sLine: string): TStringList;
var
  slResult: TStringList;
  i, iStart: integer;
  bInQuotes: boolean;
  sField: string;
  c: char;
begin
  slResult := TStringList.Create;
  bInQuotes := False;
  sField := '';
  iStart := 1;

  for i := 1 to Length(sLine) do begin
    c := sLine[i];

    if c = '"' then begin
      bInQuotes := not bInQuotes;
    end
    else if (c = ',') and (not bInQuotes) then begin
      slResult.Add(sField);
      sField := '';
    end
    else begin
      sField := sField + c;
    end;
  end;

  // Add last field
  slResult.Add(sField);
  Result := slResult;
end;

function SetCloudTexture(e: IInterface; layer: integer; value: string): boolean;
var
  cloudTextures: IInterface;
  textureEl: IInterface;
  layerStr: string;
begin
  Result := False;
  if value = '' then Exit;

  if layer < 10 then
    layerStr := '0' + IntToStr(layer)
  else
    layerStr := IntToStr(layer);

  // Try direct path first
  textureEl := ElementByPath(e, 'Cloud Textures\' + layerStr + ' - Layer');
  if Assigned(textureEl) then begin
    SetEditValue(textureEl, value);
    Result := True;
    Exit;
  end;

  // Try NNAM array
  cloudTextures := ElementBySignature(e, 'NNAM');
  if Assigned(cloudTextures) then begin
    if layer < ElementCount(cloudTextures) then begin
      textureEl := ElementByIndex(cloudTextures, layer);
      if Assigned(textureEl) then begin
        SetEditValue(textureEl, value);
        Result := True;
      end;
    end;
  end;
end;

function SetCloudSpeedX(e: IInterface; layer: integer; value: string): boolean;
var
  speedArray: IInterface;
  speedEl: IInterface;
begin
  Result := False;

  speedArray := ElementBySignature(e, 'QNAM');
  if Assigned(speedArray) then begin
    if layer < ElementCount(speedArray) then begin
      speedEl := ElementByIndex(speedArray, layer);
      if Assigned(speedEl) then begin
        SetEditValue(speedEl, value);
        Result := True;
      end;
    end;
  end;
end;

function SetCloudSpeedY(e: IInterface; layer: integer; value: string): boolean;
var
  speedArray: IInterface;
  speedEl: IInterface;
begin
  Result := False;

  speedArray := ElementBySignature(e, 'RNAM');
  if Assigned(speedArray) then begin
    if layer < ElementCount(speedArray) then begin
      speedEl := ElementByIndex(speedArray, layer);
      if Assigned(speedEl) then begin
        SetEditValue(speedEl, value);
        Result := True;
      end;
    end;
  end;
end;

function SetCloudColor(e: IInterface; layer: integer; timeOfDay: string; component: string; value: string): boolean;
var
  colorPath: string;
  colorEl: IInterface;
begin
  Result := False;

  colorPath := 'PNAM - Cloud Colors\Layer #' + IntToStr(layer) + '\' + timeOfDay + '\' + component;
  colorEl := ElementByPath(e, colorPath);
  if Assigned(colorEl) then begin
    SetEditValue(colorEl, value);
    Result := True;
    Exit;
  end;

  // Alternative path
  colorPath := 'PNAM\[' + IntToStr(layer) + ']\' + timeOfDay + '\' + component;
  colorEl := ElementByPath(e, colorPath);
  if Assigned(colorEl) then begin
    SetEditValue(colorEl, value);
    Result := True;
  end;
end;

function SetCloudAlpha(e: IInterface; layer: integer; timeOfDay: string; value: string): boolean;
var
  alphaPath: string;
  alphaEl: IInterface;
  alphaArray: IInterface;
  timeIndex: integer;
begin
  Result := False;

  if timeOfDay = 'Sunrise' then timeIndex := 0
  else if timeOfDay = 'Day' then timeIndex := 1
  else if timeOfDay = 'Sunset' then timeIndex := 2
  else if timeOfDay = 'Night' then timeIndex := 3
  else timeIndex := 0;

  // Try path format
  alphaPath := 'JNAM - Cloud Alphas\Layer #' + IntToStr(layer) + '\' + timeOfDay;
  alphaEl := ElementByPath(e, alphaPath);
  if Assigned(alphaEl) then begin
    SetEditValue(alphaEl, value);
    Result := True;
    Exit;
  end;

  // Alternative: direct array access
  alphaArray := ElementBySignature(e, 'JNAM');
  if Assigned(alphaArray) then begin
    if (layer * 4 + timeIndex) < ElementCount(alphaArray) then begin
      alphaEl := ElementByIndex(alphaArray, layer * 4 + timeIndex);
      if Assigned(alphaEl) then begin
        SetEditValue(alphaEl, value);
        Result := True;
      end;
    end;
  end;
end;

function Process(e: IInterface): integer;
var
  sFormID: string;
  sKey: string;
  iLine, layer: integer;
  slValues: TStringList;
  sLine: string;
  bUpdated: boolean;
begin
  Result := 0;

  // Only process WTHR records
  if Signature(e) <> 'WTHR' then
    Exit;

  sFormID := IntToHex(FormID(e), 8);
  bUpdated := False;

  // Check each possible layer (0-31)
  for layer := 0 to 31 do begin
    sKey := sFormID + '_' + IntToStr(layer);

    // Find this layer in our dictionary
    iLine := dictCloudData.IndexOf(sKey);
    if iLine < 0 then Continue;

    // Get the CSV line index
    iLine := Integer(dictCloudData.Objects[dictCloudData.IndexOf(sKey)]);
    sLine := slCSV[iLine];

    slValues := ParseCSVLine(sLine);
    try
      if slValues.Count < 23 then begin
        AddMessage('WARNING: Invalid CSV line for ' + sKey);
        Continue;
      end;

      // CSV columns:
      // 0=FormID, 1=EditorID, 2=SourcePlugin, 3=CloudLayer
      // 4=Texture, 5=SpeedX, 6=SpeedY
      // 7=Sunrise_R, 8=Sunrise_G, 9=Sunrise_B
      // 10=Day_R, 11=Day_G, 12=Day_B
      // 13=Sunset_R, 14=Sunset_G, 15=Sunset_B
      // 16=Night_R, 17=Night_G, 18=Night_B
      // 19=Alpha_Sunrise, 20=Alpha_Day, 21=Alpha_Sunset, 22=Alpha_Night
      // 23=Disabled (optional)

      SetCloudTexture(e, layer, slValues[4]);
      SetCloudSpeedX(e, layer, slValues[5]);
      SetCloudSpeedY(e, layer, slValues[6]);

      // Sunrise colors
      SetCloudColor(e, layer, 'Sunrise', 'Red', slValues[7]);
      SetCloudColor(e, layer, 'Sunrise', 'Green', slValues[8]);
      SetCloudColor(e, layer, 'Sunrise', 'Blue', slValues[9]);

      // Day colors
      SetCloudColor(e, layer, 'Day', 'Red', slValues[10]);
      SetCloudColor(e, layer, 'Day', 'Green', slValues[11]);
      SetCloudColor(e, layer, 'Day', 'Blue', slValues[12]);

      // Sunset colors
      SetCloudColor(e, layer, 'Sunset', 'Red', slValues[13]);
      SetCloudColor(e, layer, 'Sunset', 'Green', slValues[14]);
      SetCloudColor(e, layer, 'Sunset', 'Blue', slValues[15]);

      // Night colors
      SetCloudColor(e, layer, 'Night', 'Red', slValues[16]);
      SetCloudColor(e, layer, 'Night', 'Green', slValues[17]);
      SetCloudColor(e, layer, 'Night', 'Blue', slValues[18]);

      // Alpha values
      SetCloudAlpha(e, layer, 'Sunrise', slValues[19]);
      SetCloudAlpha(e, layer, 'Day', slValues[20]);
      SetCloudAlpha(e, layer, 'Sunset', slValues[21]);
      SetCloudAlpha(e, layer, 'Night', slValues[22]);

      bUpdated := True;
      Inc(iUpdatedLayers);

    finally
      slValues.Free;
    end;
  end;

  if bUpdated then begin
    Inc(iUpdatedRecords);
    AddMessage('Updated: ' + EditorID(e) + ' (' + sFormID + ')');
  end;
end;

function Finalize: integer;
begin
  AddMessage('');
  AddMessage('=== Cloud Settings Import Complete ===');
  AddMessage('Weather records updated: ' + IntToStr(iUpdatedRecords));
  AddMessage('Cloud layers restored: ' + IntToStr(iUpdatedLayers));
  AddMessage('');
  AddMessage('IMPORTANT: Save your plugin to apply changes!');

  if Assigned(slCSV) then slCSV.Free;
  if Assigned(dictCloudData) then dictCloudData.Free;

  Result := 0;
end;

end.
