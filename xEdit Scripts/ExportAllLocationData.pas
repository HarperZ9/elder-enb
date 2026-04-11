unit ExportAllLocationData;

{
  Export All Location Data for ENB Location Weather
  ==================================================
  Compatible with SSEEdit, TES5Edit, and EnderalSEEdit

  Output Files:
  1. LocationExport.csv - All location records with full details
  2. CellLocationExport.csv - Cell-to-Location mappings for interiors
  3. LocationWeather_[ModName].ini - Ready-to-use _locationweather.ini format

  Usage:
  1. Load your plugins in xEdit
  2. Select the mod plugin(s) you want to export
  3. Right-click -> Apply Script -> ExportAllLocationData
  4. Check output files in your xEdit directory
}

uses SysUtils, Classes;

var
  slLocationCSV: TStringList;
  slCellCSV: TStringList;
  slPluginNames: TStringList;
  dictWorldspaces: TStringList;
  dictWorldspaceNames: TStringList;
  iLocationCount: Integer;
  iCellCount: Integer;
  iModLocationCount: Integer;
  baseWeatherID: Integer;

function Initialize: Integer;
begin
  slLocationCSV := TStringList.Create;
  slCellCSV := TStringList.Create;
  slPluginNames := TStringList.Create;
  dictWorldspaces := TStringList.Create;
  dictWorldspaceNames := TStringList.Create;

  slLocationCSV.Add('SourcePlugin,FormID,LocalFormID,EditorID,FullName,ParentLocationFormID,ParentLocationEditorID,ParentLocationName,WorldspaceFormID,WorldspaceEditorID,LocationType,Keywords,IsInterior,IsModAdded');
  slCellCSV.Add('SourcePlugin,CellFormID,CellLocalFormID,CellEditorID,CellFullName,LocationFormID,LocationEditorID,LocationFullName,WorldspaceFormID,WorldspaceEditorID,IsInterior,IsModAdded');

  iLocationCount := 0;
  iCellCount := 0;
  iModLocationCount := 0;
  baseWeatherID := $200000;

  AddMessage('');
  AddMessage('================================================');
  AddMessage('  Export All Location Data for ENB');
  AddMessage('================================================');
  AddMessage('Processing records...');
  AddMessage('');

  Result := 0;
end;

function FormatFormID(rec: IInterface): string;
var
  fid: Cardinal;
begin
  if not Assigned(rec) then begin
    Result := '';
    Exit;
  end;
  fid := GetLoadOrderFormID(rec);
  Result := IntToHex(fid, 8);
end;

function FormatLocalFormID(rec: IInterface): string;
var
  fid: Cardinal;
  lid: Cardinal;
begin
  if not Assigned(rec) then begin
    Result := '';
    Exit;
  end;
  fid := FormID(rec);
  lid := fid and $00FFFFFF;
  Result := IntToHex(lid, 8);
end;

function CleanCSV(s: string): string;
begin
  Result := StringReplace(s, ',', ';', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '''', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

function CleanFileName(s: string): string;
begin
  Result := StringReplace(s, ' ', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '', [rfReplaceAll]);
  Result := StringReplace(Result, ':', '', [rfReplaceAll]);
  Result := StringReplace(Result, '/', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '\', '_', [rfReplaceAll]);
  Result := StringReplace(Result, '?', '', [rfReplaceAll]);
  Result := StringReplace(Result, '*', '', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '', [rfReplaceAll]);
  Result := StringReplace(Result, '|', '', [rfReplaceAll]);
end;

function IsVanillaFile(fileName: string): Boolean;
var
  lowerName: string;
begin
  lowerName := LowerCase(fileName);
  // Note: Enderal removed from vanilla check to allow exporting Enderal locations
  Result := (Pos('skyrim.esm', lowerName) > 0) or
            (Pos('update.esm', lowerName) > 0) or
            (Pos('dawnguard.esm', lowerName) > 0) or
            (Pos('hearthfires.esm', lowerName) > 0) or
            (Pos('dragonborn.esm', lowerName) > 0) or
            (Pos('skyui', lowerName) > 0) or
            (Pos('ccbgssse', lowerName) > 0) or
            (Pos('unofficial', lowerName) > 0);
end;

function GetKeywordList(rec: IInterface): string;
var
  kwda: IInterface;
  i: Integer;
  kw: IInterface;
  kwList: TStringList;
begin
  Result := '';
  kwList := TStringList.Create;
  try
    kwda := ElementBySignature(rec, 'KWDA');
    if Assigned(kwda) then begin
      for i := 0 to ElementCount(kwda) - 1 do begin
        kw := LinksTo(ElementByIndex(kwda, i));
        if Assigned(kw) then
          kwList.Add(EditorID(kw));
      end;
    end;
    Result := StringReplace(kwList.CommaText, ',', ';', [rfReplaceAll]);
  finally
    kwList.Free;
  end;
end;

function DetermineLocationType(rec: IInterface): string;
var
  edid: string;
  kwda: IInterface;
  i: Integer;
  kw: IInterface;
  kwEdid: string;
begin
  Result := 'Unknown';
  edid := LowerCase(EditorID(rec));

  kwda := ElementBySignature(rec, 'KWDA');
  if Assigned(kwda) then begin
    for i := 0 to ElementCount(kwda) - 1 do begin
      kw := LinksTo(ElementByIndex(kwda, i));
      if Assigned(kw) then begin
        kwEdid := LowerCase(EditorID(kw));
        if Pos('locsetdwarvenruin', kwEdid) > 0 then begin Result := 'DwarvenRuin'; Exit; end;
        if Pos('locsetnordicruin', kwEdid) > 0 then begin Result := 'NordicRuin'; Exit; end;
        if Pos('locsetdungeon', kwEdid) > 0 then begin Result := 'Dungeon'; Exit; end;
        if Pos('locsetmilitaryfort', kwEdid) > 0 then begin Result := 'Fort'; Exit; end;
        if Pos('locsetinn', kwEdid) > 0 then begin Result := 'Inn'; Exit; end;
        if Pos('locsetmine', kwEdid) > 0 then begin Result := 'Mine'; Exit; end;
        if Pos('locsetcave', kwEdid) > 0 then begin Result := 'Cave'; Exit; end;
        if Pos('locdwelling', kwEdid) > 0 then begin Result := 'Dwelling'; Exit; end;
        if Pos('loccity', kwEdid) > 0 then begin Result := 'City'; Exit; end;
        if Pos('loctown', kwEdid) > 0 then begin Result := 'Town'; Exit; end;
        if Pos('locsettlement', kwEdid) > 0 then begin Result := 'Settlement'; Exit; end;
        if Pos('lochabitation', kwEdid) > 0 then begin Result := 'Habitation'; Exit; end;
        if Pos('locsetclearable', kwEdid) > 0 then begin Result := 'Clearable'; Exit; end;
      end;
    end;
  end;

  if Pos('dwemer', edid) > 0 then Result := 'DwarvenRuin'
  else if Pos('dwarven', edid) > 0 then Result := 'DwarvenRuin'
  else if Pos('falmer', edid) > 0 then Result := 'FalmerHive'
  else if Pos('barrow', edid) > 0 then Result := 'NordicRuin'
  else if Pos('draugr', edid) > 0 then Result := 'NordicRuin'
  else if Pos('crypt', edid) > 0 then Result := 'NordicRuin'
  else if Pos('tomb', edid) > 0 then Result := 'NordicRuin'
  else if Pos('catacomb', edid) > 0 then Result := 'NordicRuin'
  else if Pos('dungeon', edid) > 0 then Result := 'Dungeon'
  else if Pos('cave', edid) > 0 then Result := 'Cave'
  else if Pos('grotto', edid) > 0 then Result := 'Cave'
  else if Pos('fort', edid) > 0 then Result := 'Fort'
  else if Pos('keep', edid) > 0 then Result := 'Fort'
  else if Pos('castle', edid) > 0 then Result := 'Fort'
  else if Pos('tower', edid) > 0 then Result := 'Fort'
  else if Pos('mine', edid) > 0 then Result := 'Mine'
  else if Pos('inn', edid) > 0 then Result := 'Inn'
  else if Pos('tavern', edid) > 0 then Result := 'Inn'
  else if Pos('apocrypha', edid) > 0 then Result := 'Apocrypha'
  else if Pos('soulcairn', edid) > 0 then Result := 'SoulCairn'
  else if Pos('sovngarde', edid) > 0 then Result := 'Sovngarde'
  else if Pos('blackreach', edid) > 0 then Result := 'Blackreach';
end;

function GetLocationName(rec: IInterface): string;
begin
  Result := GetElementEditValues(rec, 'FULL');
  if Result = '' then
    Result := EditorID(rec);
  if Result = '' then
    Result := 'Location_' + FormatFormID(rec);
end;

function GetWorldspaceName(ws: IInterface): string;
begin
  if not Assigned(ws) then begin
    Result := 'Tamriel (Standard Interiors)';
    Exit;
  end;
  Result := GetElementEditValues(ws, 'FULL');
  if Result = '' then
    Result := EditorID(ws);
  if Result = '' then
    Result := 'Worldspace_' + FormatFormID(ws);
end;

function GetOrCreateWorldspaceList(pluginName, wsID: string): TStringList;
var
  key: string;
  idx: Integer;
  newList: TStringList;
begin
  key := pluginName + '|' + wsID;
  idx := dictWorldspaces.IndexOf(key);
  if idx < 0 then begin
    newList := TStringList.Create;
    newList.Sorted := True;  // Auto-sort as items are added
    dictWorldspaces.AddObject(key, newList);
    Result := newList;
  end else begin
    Result := TStringList(dictWorldspaces.Objects[idx]);
  end;
end;

function ProcessLocation(e: IInterface): Integer;
var
  sourcePlug: string;
  fmID, localFmID: string;
  edid, fullName: string;
  parentLoc: IInterface;
  parentLocFormID, parentLocEditorID, parentLocName: string;
  worldspace: IInterface;
  wsFormID, wsEditorID: string;
  locType, keywords: string;
  isInterior, isModAdded: string;
  outputLine: string;
  pnam, wnam: IInterface;
  wsList: TStringList;
  weatherID: string;
  sortKey: string;
begin
  Result := 0;

  sourcePlug := GetFileName(GetFile(e));
  fmID := FormatFormID(e);
  localFmID := FormatLocalFormID(e);
  edid := EditorID(e);
  fullName := CleanCSV(GetElementEditValues(e, 'FULL'));

  parentLocFormID := '';
  parentLocEditorID := '';
  parentLocName := '';
  pnam := ElementBySignature(e, 'PNAM');
  if Assigned(pnam) then begin
    parentLoc := LinksTo(pnam);
    if Assigned(parentLoc) then begin
      parentLocFormID := FormatFormID(parentLoc);
      parentLocEditorID := EditorID(parentLoc);
      parentLocName := CleanCSV(GetElementEditValues(parentLoc, 'FULL'));
    end;
  end;

  wsFormID := '00000000';
  wsEditorID := '';
  wnam := ElementBySignature(e, 'WNAM');
  if Assigned(wnam) then begin
    worldspace := LinksTo(wnam);
    if Assigned(worldspace) then begin
      wsFormID := FormatFormID(worldspace);
      wsEditorID := EditorID(worldspace);
      if dictWorldspaceNames.IndexOfName(wsFormID) < 0 then
        dictWorldspaceNames.Add(wsFormID + '=' + GetWorldspaceName(worldspace));
    end;
  end;

  if dictWorldspaceNames.IndexOfName('00000000') < 0 then
    dictWorldspaceNames.Add('00000000=Tamriel (Standard Interiors)');

  locType := DetermineLocationType(e);
  keywords := GetKeywordList(e);

  if (wsFormID = '00000000') or (wsEditorID = '') then
    isInterior := 'Yes'
  else
    isInterior := 'No';

  if IsVanillaFile(sourcePlug) then
    isModAdded := 'No'
  else
    isModAdded := 'Yes';

  outputLine := Format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s', [
    sourcePlug,
    fmID,
    localFmID,
    edid,
    fullName,
    parentLocFormID,
    parentLocEditorID,
    parentLocName,
    wsFormID,
    wsEditorID,
    locType,
    keywords,
    isInterior,
    isModAdded
  ]);
  slLocationCSV.Add(outputLine);
  Inc(iLocationCount);

  if not IsVanillaFile(sourcePlug) then begin
    if slPluginNames.IndexOf(sourcePlug) < 0 then begin
      slPluginNames.Add(sourcePlug);
      AddMessage('  Found mod: ' + sourcePlug);
    end;

    wsList := GetOrCreateWorldspaceList(sourcePlug, wsFormID);
    weatherID := IntToHex(baseWeatherID + iModLocationCount, 6);

    // Use sortable key: Category + Name padded for proper sorting
    sortKey := Format('%s~%s~%s~%s~%s', [
      locType,
      GetLocationName(e),
      fmID,
      weatherID,
      edid
    ]);
    wsList.Add(sortKey);

    Inc(iModLocationCount);
  end;
end;

function ProcessCell(e: IInterface): Integer;
var
  sourcePlug: string;
  fmID, localFmID: string;
  edid, fullName: string;
  locRef: IInterface;
  locFormID, locEditorID, locFullName: string;
  worldspace: IInterface;
  wsFormID, wsEditorID: string;
  isInterior, isModAdded: string;
  outputLine: string;
  xlcn, data: IInterface;
  flags: Cardinal;
begin
  Result := 0;

  isInterior := 'No';
  data := ElementBySignature(e, 'DATA');
  if Assigned(data) then begin
    flags := GetNativeValue(data);
    if (flags and 1) = 1 then
      isInterior := 'Yes';
  end;

  xlcn := ElementBySignature(e, 'XLCN');
  if not Assigned(xlcn) then
    Exit;

  locRef := LinksTo(xlcn);
  if not Assigned(locRef) then
    Exit;

  sourcePlug := GetFileName(GetFile(e));
  fmID := FormatFormID(e);
  localFmID := FormatLocalFormID(e);
  edid := EditorID(e);
  fullName := CleanCSV(GetElementEditValues(e, 'FULL'));

  locFormID := FormatFormID(locRef);
  locEditorID := EditorID(locRef);
  locFullName := CleanCSV(GetElementEditValues(locRef, 'FULL'));

  wsFormID := '00000000';
  wsEditorID := 'Interior';
  worldspace := LinksTo(ElementByIndex(e, 0));
  if Assigned(worldspace) and (Signature(worldspace) = 'WRLD') then begin
    wsFormID := FormatFormID(worldspace);
    wsEditorID := EditorID(worldspace);
  end;

  if IsVanillaFile(sourcePlug) then
    isModAdded := 'No'
  else
    isModAdded := 'Yes';

  outputLine := Format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s', [
    sourcePlug,
    fmID,
    localFmID,
    edid,
    fullName,
    locFormID,
    locEditorID,
    locFullName,
    wsFormID,
    wsEditorID,
    isInterior,
    isModAdded
  ]);

  slCellCSV.Add(outputLine);
  Inc(iCellCount);
end;

function Process(e: IInterface): Integer;
var
  sig: string;
begin
  Result := 0;
  sig := Signature(e);

  if sig = 'LCTN' then
    ProcessLocation(e)
  else if sig = 'CELL' then
    ProcessCell(e);
end;

function ParseField(line: string; fieldNum: Integer): string;
var
  i, count, startPos: Integer;
  c: Char;
begin
  Result := '';
  count := 0;
  startPos := 1;

  for i := 1 to Length(line) do begin
    c := line[i];
    if c = '~' then begin
      if count = fieldNum then begin
        Result := Copy(line, startPos, i - startPos);
        Exit;
      end;
      Inc(count);
      startPos := i + 1;
    end;
  end;

  if count = fieldNum then
    Result := Copy(line, startPos, Length(line) - startPos + 1);
end;

procedure GenerateINIFile(pluginName: string);
var
  slINI: TStringList;
  i, j: Integer;
  key, wsID, wsName: string;
  wsList: TStringList;
  currentCat, locCat, locName, locID, weatherID, locEditorID: string;
  outputPath: string;
  wsIDs: TStringList;
  locCount: Integer;
  line: string;
begin
  slINI := TStringList.Create;
  wsIDs := TStringList.Create;

  try
    for i := 0 to dictWorldspaces.Count - 1 do begin
      key := dictWorldspaces[i];
      if Pos(pluginName + '|', key) = 1 then begin
        wsID := Copy(key, Length(pluginName) + 2, 8);
        wsIDs.Add(wsID);
      end;
    end;

    if wsIDs.Count = 0 then Exit;

    wsIDs.Sort;

    slINI.Add(';=============================================================================;');
    slINI.Add(';              MOD LOCATION WEATHER - ' + UpperCase(pluginName));
    slINI.Add(';=============================================================================;');
    slINI.Add(';');
    slINI.Add('; Exported by xEdit ExportAllLocationData script');
    slINI.Add('; Copy this content into your _locationweather.ini');
    slINI.Add(';');
    slINI.Add('; WeatherIDs are pre-generated 6-digit hex codes');
    slINI.Add('; Create matching .ini files in enbseries/Interiors/ or Weather/ folder');
    slINI.Add('; Add corresponding entries to _weatherlist.ini');
    slINI.Add(';');
    slINI.Add(';=============================================================================;');
    slINI.Add('');

    locCount := 0;

    for i := 0 to wsIDs.Count - 1 do begin
      wsID := wsIDs[i];
      key := pluginName + '|' + wsID;

      j := dictWorldspaces.IndexOf(key);
      if j < 0 then Continue;

      wsList := TStringList(dictWorldspaces.Objects[j]);
      if wsList.Count = 0 then Continue;

      wsName := dictWorldspaceNames.Values[wsID];
      if wsName = '' then wsName := 'Worldspace ' + wsID;

      slINI.Add(';==============================================================================;');
      slINI.Add(';                              ' + UpperCase(wsName));
      slINI.Add(';==============================================================================;');
      slINI.Add('');
      slINI.Add('[' + wsID + ']');
      slINI.Add('');

      currentCat := '';
      for j := 0 to wsList.Count - 1 do begin
        line := wsList[j];

        // Parse: Category~Name~FormID~WeatherID~EditorID
        locCat := ParseField(line, 0);
        locName := ParseField(line, 1);
        locID := ParseField(line, 2);
        weatherID := ParseField(line, 3);
        locEditorID := ParseField(line, 4);

        if locCat <> currentCat then begin
          if currentCat <> '' then
            slINI.Add('');
          slINI.Add(';----------------------------------------');
          slINI.Add('; ' + UpperCase(locCat));
          slINI.Add(';----------------------------------------');
          currentCat := locCat;
        end;

        slINI.Add('//' + locName);
        slINI.Add(locID + '=' + weatherID);
        Inc(locCount);
      end;

      slINI.Add('');
    end;

    slINI.Add(';=============================================================================;');
    slINI.Add('; Total locations: ' + IntToStr(locCount));
    slINI.Add(';=============================================================================;');

    outputPath := ProgramPath + 'LocationWeather_' + CleanFileName(ChangeFileExt(pluginName, '')) + '.ini';
    slINI.SaveToFile(outputPath);
    AddMessage('  Saved: ' + outputPath);

  finally
    slINI.Free;
    wsIDs.Free;
  end;
end;

function Finalize: Integer;
var
  locPath, cellPath: string;
  i: Integer;
  wsList: TStringList;
begin
  AddMessage('');
  AddMessage('================================================');
  AddMessage('  Saving Output Files');
  AddMessage('================================================');

  locPath := ProgramPath + 'LocationExport.csv';
  try
    slLocationCSV.SaveToFile(locPath);
    AddMessage('Saved: ' + locPath);
  except
    on E: Exception do
      AddMessage('Error saving locations CSV: ' + E.Message);
  end;

  cellPath := ProgramPath + 'CellLocationExport.csv';
  try
    slCellCSV.SaveToFile(cellPath);
    AddMessage('Saved: ' + cellPath);
  except
    on E: Exception do
      AddMessage('Error saving cells CSV: ' + E.Message);
  end;

  AddMessage('');
  AddMessage('Generating INI files for mods...');
  for i := 0 to slPluginNames.Count - 1 do begin
    GenerateINIFile(slPluginNames[i]);
  end;

  AddMessage('');
  AddMessage('================================================');
  AddMessage('  Export Complete');
  AddMessage('================================================');
  AddMessage(Format('Total locations: %d', [iLocationCount]));
  AddMessage(Format('Total cell mappings: %d', [iCellCount]));
  AddMessage(Format('Mod-added locations: %d', [iModLocationCount]));
  AddMessage(Format('Mod plugins processed: %d', [slPluginNames.Count]));
  AddMessage('');
  AddMessage('Output files:');
  AddMessage('  - LocationExport.csv (all locations)');
  AddMessage('  - CellLocationExport.csv (cell mappings)');
  for i := 0 to slPluginNames.Count - 1 do begin
    AddMessage('  - LocationWeather_' + ChangeFileExt(slPluginNames[i], '') + '.ini');
  end;
  AddMessage('');
  AddMessage('Next steps for mod locations:');
  AddMessage('1. Copy INI content into _locationweather.ini');
  AddMessage('2. Create .ini files for each WeatherID');
  AddMessage('3. Add entries to _weatherlist.ini');
  AddMessage('================================================');

  slLocationCSV.Free;
  slCellCSV.Free;
  slPluginNames.Free;
  dictWorldspaceNames.Free;

  for i := 0 to dictWorldspaces.Count - 1 do begin
    wsList := TStringList(dictWorldspaces.Objects[i]);
    if Assigned(wsList) then
      wsList.Free;
  end;
  dictWorldspaces.Free;

  Result := 0;
end;

end.
