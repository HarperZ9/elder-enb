unit GenerateLocationWeatherINI;

{
  Generate _locationweather.ini Entries
  =====================================
  Exports mod-added locations in ready-to-use _locationweather.ini format

  Output: LocationWeather_ModName.ini (one file per selected plugin)

  Usage:
  1. Load your plugins in xEdit (SSEEdit/TES5Edit)
  2. Select ONLY the mod plugin(s) you want to export
  3. Right-click -> Apply Script -> GenerateLocationWeatherINI
  4. Copy the output content into your _locationweather.ini

  Note: WeatherIDs are placeholder values (XXXXXX) - replace with your
  custom 6-digit hex codes and create matching .ini files
}

uses SysUtils, Classes;

var
  slOutput: TStringList;
  slWorldspaces: TStringList;
  dictLocations: TStringList;  // WorldspaceID -> Locations list
  iCount: Integer;
  currentPlugin: string;
  baseWeatherID: Integer;

function Initialize: Integer;
begin
  slOutput := TStringList.Create;
  slWorldspaces := TStringList.Create;
  dictLocations := TStringList.Create;
  iCount := 0;
  currentPlugin := '';
  baseWeatherID := $200000;  // Start at 200000 for mod locations

  AddMessage('');
  AddMessage('========================================');
  AddMessage('Generate Location Weather INI');
  AddMessage('========================================');

  Result := 0;
end;

function FormatFormID(rec: IInterface): string;
var
  formID: Cardinal;
begin
  if not Assigned(rec) then begin
    Result := '00000000';
    Exit;
  end;
  formID := GetLoadOrderFormID(rec);
  Result := IntToHex(formID, 8);
end;

function GetLocationName(rec: IInterface): string;
begin
  Result := GetElementEditValues(rec, 'FULL');
  if Result = '' then
    Result := EditorID(rec);
  if Result = '' then
    Result := 'Location_' + FormatFormID(rec);
  // Clean for comments
  Result := StringReplace(Result, ';', '-', [rfReplaceAll]);
end;

function GetWorldspaceForLocation(rec: IInterface): IInterface;
var
  wnam: IInterface;
begin
  Result := nil;
  wnam := ElementBySignature(rec, 'WNAM');
  if Assigned(wnam) then
    Result := LinksTo(wnam);
end;

function GetWorldspaceName(ws: IInterface): string;
begin
  if not Assigned(ws) then begin
    Result := 'Tamriel & Standard Interiors';
    Exit;
  end;

  Result := GetElementEditValues(ws, 'FULL');
  if Result = '' then
    Result := EditorID(ws);
  if Result = '' then
    Result := 'Worldspace_' + FormatFormID(ws);
end;

function IsVanillaFile(fileName: string): Boolean;
var
  lowerName: string;
begin
  lowerName := LowerCase(fileName);
  Result := (Pos('skyrim.esm', lowerName) > 0) or
            (Pos('update.esm', lowerName) > 0) or
            (Pos('dawnguard.esm', lowerName) > 0) or
            (Pos('hearthfires.esm', lowerName) > 0) or
            (Pos('dragonborn.esm', lowerName) > 0);
end;

function DetermineCategory(rec: IInterface): string;
var
  keywords, edid: string;
  kwda: IInterface;
  i: Integer;
  kw: IInterface;
  kwEdid: string;
begin
  Result := 'LOCATIONS';
  edid := LowerCase(EditorID(rec));

  // Check keywords
  kwda := ElementBySignature(rec, 'KWDA');
  if Assigned(kwda) then begin
    for i := 0 to ElementCount(kwda) - 1 do begin
      kw := LinksTo(ElementByIndex(kwda, i));
      if Assigned(kw) then begin
        kwEdid := LowerCase(EditorID(kw));
        if Pos('locdwelling', kwEdid) > 0 then begin Result := 'DWELLINGS'; Exit; end;
        if Pos('locsetdungeon', kwEdid) > 0 then begin Result := 'DUNGEONS'; Exit; end;
        if Pos('locsetdwarvenruin', kwEdid) > 0 then begin Result := 'DWARVEN RUINS'; Exit; end;
        if Pos('locsetmilitaryfort', kwEdid) > 0 then begin Result := 'FORTS'; Exit; end;
        if Pos('locsetinn', kwEdid) > 0 then begin Result := 'INNS'; Exit; end;
        if Pos('locsetmine', kwEdid) > 0 then begin Result := 'MINES'; Exit; end;
        if Pos('locsetnordicruinworldinteraction', kwEdid) > 0 then begin Result := 'NORDIC RUINS'; Exit; end;
        if Pos('locsetcave', kwEdid) > 0 then begin Result := 'CAVES'; Exit; end;
        if Pos('loccity', kwEdid) > 0 then begin Result := 'CITIES'; Exit; end;
        if Pos('loctown', kwEdid) > 0 then begin Result := 'TOWNS'; Exit; end;
        if Pos('locsettlement', kwEdid) > 0 then begin Result := 'SETTLEMENTS'; Exit; end;
      end;
    end;
  end;

  // Fallback to EditorID patterns
  if Pos('dungeon', edid) > 0 then Result := 'DUNGEONS'
  else if Pos('cave', edid) > 0 then Result := 'CAVES'
  else if Pos('fort', edid) > 0 then Result := 'FORTS'
  else if Pos('mine', edid) > 0 then Result := 'MINES'
  else if Pos('inn', edid) > 0 then Result := 'INNS'
  else if Pos('barrow', edid) > 0 then Result := 'NORDIC RUINS'
  else if Pos('dwarven', edid) > 0 then Result := 'DWARVEN RUINS'
  else if Pos('dwemer', edid) > 0 then Result := 'DWARVEN RUINS'
  else if Pos('ruin', edid) > 0 then Result := 'RUINS';
end;

function Process(e: IInterface): Integer;
var
  sig, fileName: string;
  ws: IInterface;
  wsID, locID, locName, category: string;
  wsIndex: Integer;
  locList: TStringList;
  weatherID: string;
begin
  Result := 0;
  sig := Signature(e);

  // Only process Location records
  if sig <> 'LCTN' then
    Exit;

  fileName := GetFileName(GetFile(e));

  // Skip vanilla files
  if IsVanillaFile(fileName) then
    Exit;

  // Track current plugin
  if currentPlugin <> fileName then begin
    currentPlugin := fileName;
    AddMessage('Processing: ' + fileName);
  end;

  // Get worldspace
  ws := GetWorldspaceForLocation(e);
  if Assigned(ws) then
    wsID := FormatFormID(ws)
  else
    wsID := '00000000';

  // Get or create location list for this worldspace
  wsIndex := slWorldspaces.IndexOf(wsID);
  if wsIndex < 0 then begin
    locList := TStringList.Create;
    slWorldspaces.AddObject(wsID, locList);
    // Store worldspace name
    if Assigned(ws) then
      dictLocations.Add(wsID + '=' + GetWorldspaceName(ws))
    else
      dictLocations.Add(wsID + '=Tamriel & Standard Interiors');
  end else begin
    locList := TStringList(slWorldspaces.Objects[wsIndex]);
  end;

  // Format location entry
  locID := FormatFormID(e);
  locName := GetLocationName(e);
  category := DetermineCategory(e);

  // Generate placeholder WeatherID
  weatherID := IntToHex(baseWeatherID + iCount, 6);

  // Add to list: Category|LocationName|LocationID|WeatherID
  locList.Add(Format('%s|%s|%s|%s', [category, locName, locID, weatherID]));

  Inc(iCount);
end;

function CompareCategories(List: TStringList; Index1, Index2: Integer): Integer;
var
  cat1, cat2: string;
  parts1, parts2: TStringList;
begin
  parts1 := TStringList.Create;
  parts2 := TStringList.Create;
  try
    parts1.Delimiter := '|';
    parts1.StrictDelimiter := True;
    parts1.DelimitedText := List[Index1];

    parts2.Delimiter := '|';
    parts2.StrictDelimiter := True;
    parts2.DelimitedText := List[Index2];

    // Compare by category first, then by name
    Result := CompareText(parts1[0], parts2[0]);
    if Result = 0 then
      Result := CompareText(parts1[1], parts2[1]);
  finally
    parts1.Free;
    parts2.Free;
  end;
end;

function Finalize: Integer;
var
  i, j: Integer;
  wsID, wsName: string;
  locList: TStringList;
  parts: TStringList;
  currentCat, locCat, locName, locID, weatherID: string;
  outputPath: string;
begin
  if iCount = 0 then begin
    AddMessage('');
    AddMessage('No mod-added locations found!');
    AddMessage('Make sure you selected a mod plugin (not vanilla .esm files)');
    slOutput.Free;
    slWorldspaces.Free;
    dictLocations.Free;
    Result := 0;
    Exit;
  end;

  // Build output
  slOutput.Add(';=============================================================================;');
  slOutput.Add(';              MOD LOCATION WEATHER - ' + UpperCase(currentPlugin));
  slOutput.Add(';=============================================================================;');
  slOutput.Add(';');
  slOutput.Add('; Exported by xEdit GenerateLocationWeatherINI script');
  slOutput.Add('; Copy this content into your _locationweather.ini');
  slOutput.Add('; Replace XXXXXX WeatherIDs with your custom 6-digit hex codes');
  slOutput.Add('; Create matching .ini files in enbseries/Interiors/ folder');
  slOutput.Add(';');
  slOutput.Add(';=============================================================================;');
  slOutput.Add('');

  // Process each worldspace
  for i := 0 to slWorldspaces.Count - 1 do begin
    wsID := slWorldspaces[i];
    wsName := dictLocations.Values[wsID];
    locList := TStringList(slWorldspaces.Objects[i]);

    // Sort locations by category then name
    locList.CustomSort(@CompareCategories);

    // Write worldspace header
    slOutput.Add(';==============================================================================;');
    slOutput.Add(';                              ' + UpperCase(wsName));
    slOutput.Add(';==============================================================================;');
    slOutput.Add('');
    slOutput.Add('[' + wsID + ']');
    slOutput.Add('');

    // Write locations grouped by category
    currentCat := '';
    parts := TStringList.Create;
    try
      parts.Delimiter := '|';
      parts.StrictDelimiter := True;

      for j := 0 to locList.Count - 1 do begin
        parts.DelimitedText := locList[j];
        locCat := parts[0];
        locName := parts[1];
        locID := parts[2];
        weatherID := parts[3];

        // Category header
        if locCat <> currentCat then begin
          if currentCat <> '' then
            slOutput.Add('');
          slOutput.Add(';----------------------------------------');
          slOutput.Add('; ' + locCat);
          slOutput.Add(';----------------------------------------');
          currentCat := locCat;
        end;

        // Location entry
        slOutput.Add('//' + locName);
        slOutput.Add(locID + '=' + weatherID);
      end;
    finally
      parts.Free;
    end;

    slOutput.Add('');
    locList.Free;
  end;

  // Add summary
  slOutput.Add('');
  slOutput.Add(';=============================================================================;');
  slOutput.Add('; Total locations: ' + IntToStr(iCount));
  slOutput.Add('; WeatherID range: ' + IntToHex(baseWeatherID, 6) + ' - ' + IntToHex(baseWeatherID + iCount - 1, 6));
  slOutput.Add(';=============================================================================;');

  // Save file
  outputPath := ProgramPath + 'LocationWeather_' + ChangeFileExt(currentPlugin, '') + '.ini';

  try
    slOutput.SaveToFile(outputPath);
    AddMessage('');
    AddMessage('========================================');
    AddMessage('Export Complete');
    AddMessage('========================================');
    AddMessage(Format('Locations exported: %d', [iCount]));
    AddMessage(Format('Output file: %s', [outputPath]));
    AddMessage('');
    AddMessage('Next steps:');
    AddMessage('1. Copy content into _locationweather.ini');
    AddMessage('2. Create .ini files for each WeatherID');
    AddMessage('3. Add entries to _weatherlist.ini');
    AddMessage('========================================');
  except
    on E: Exception do
      AddMessage('Error saving file: ' + E.Message);
  end;

  slOutput.Free;
  slWorldspaces.Free;
  dictLocations.Free;

  Result := 0;
end;

end.
