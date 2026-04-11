unit ExportLocationWeatherData;

{
  Export Location Weather Data for ENB Configuration
  ==================================================
  Comprehensive export of WorldspaceID, LocationID, and cell information
  for configuring ENB _locationweather.ini

  Exports two files:
  1. LocationExport.csv - All location records with hierarchy
  2. CellLocationExport.csv - Cell-to-Location mappings for interiors

  Usage:
  1. Load your plugins in xEdit (SSEEdit/TES5Edit)
  2. Select the mod plugin(s) you want to export
  3. Right-click -> Apply Script -> ExportLocationWeatherData
  4. Check output CSVs in your xEdit directory

  The LocationID in _locationweather.ini corresponds to the Location FormID
  The WorldspaceID is the section header [XXXXXXXX] in _locationweather.ini
}

uses SysUtils, Classes;

var
  slLocations: TStringList;
  slCells: TStringList;
  iLocationCount: Integer;
  iCellCount: Integer;
  processedFiles: TStringList;

function Initialize: Integer;
begin
  slLocations := TStringList.Create;
  slCells := TStringList.Create;
  processedFiles := TStringList.Create;

  // CSV Headers
  slLocations.Add('SourcePlugin,FormID,LocalFormID,EditorID,FullName,ParentLocationFormID,ParentLocationEditorID,ParentLocationName,WorldspaceFormID,WorldspaceEditorID,LocationType,Keywords,IsModAdded');
  slCells.Add('SourcePlugin,CellFormID,CellLocalFormID,CellEditorID,CellFullName,LocationFormID,LocationEditorID,LocationFullName,WorldspaceFormID,WorldspaceEditorID,IsInterior,IsModAdded');

  iLocationCount := 0;
  iCellCount := 0;

  AddMessage('');
  AddMessage('========================================');
  AddMessage('Export Location Weather Data');
  AddMessage('========================================');
  AddMessage('Processing records...');

  Result := 0;
end;

function FormatFormID(rec: IInterface): string;
var
  formID: Cardinal;
begin
  if not Assigned(rec) then begin
    Result := '';
    Exit;
  end;
  formID := GetLoadOrderFormID(rec);
  Result := IntToHex(formID, 8);
end;

function FormatLocalFormID(rec: IInterface): string;
var
  formID: Cardinal;
  localID: Cardinal;
begin
  if not Assigned(rec) then begin
    Result := '';
    Exit;
  end;
  formID := FormID(rec);
  localID := formID and $00FFFFFF;
  Result := IntToHex(localID, 8);
end;

function CleanCSV(s: string): string;
begin
  Result := StringReplace(s, ',', ';', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '''', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := Trim(Result);
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
    // Join with semicolons since commas are CSV delimiters
    Result := StringReplace(kwList.CommaText, ',', ';', [rfReplaceAll]);
  finally
    kwList.Free;
  end;
end;

function DetermineLocationType(rec: IInterface): string;
var
  keywords: string;
  edid: string;
begin
  Result := 'Unknown';
  keywords := LowerCase(GetKeywordList(rec));
  edid := LowerCase(EditorID(rec));

  // Check keywords first
  if Pos('locdwelling', keywords) > 0 then Result := 'Dwelling'
  else if Pos('locsetdungeon', keywords) > 0 then Result := 'Dungeon'
  else if Pos('locsetdwarvenruin', keywords) > 0 then Result := 'DwarvenRuin'
  else if Pos('locsetmilitaryfort', keywords) > 0 then Result := 'Fort'
  else if Pos('locsetinn', keywords) > 0 then Result := 'Inn'
  else if Pos('locsetmine', keywords) > 0 then Result := 'Mine'
  else if Pos('locsetnordicruinworldinteraction', keywords) > 0 then Result := 'NordicRuin'
  else if Pos('locsetcave', keywords) > 0 then Result := 'Cave'
  else if Pos('locsetclearable', keywords) > 0 then Result := 'Clearable'
  else if Pos('loccity', keywords) > 0 then Result := 'City'
  else if Pos('loctown', keywords) > 0 then Result := 'Town'
  else if Pos('locsettlement', keywords) > 0 then Result := 'Settlement'
  else if Pos('lochabitation', keywords) > 0 then Result := 'Habitation'
  // Fallback to EditorID patterns
  else if Pos('dungeon', edid) > 0 then Result := 'Dungeon'
  else if Pos('cave', edid) > 0 then Result := 'Cave'
  else if Pos('fort', edid) > 0 then Result := 'Fort'
  else if Pos('mine', edid) > 0 then Result := 'Mine'
  else if Pos('inn', edid) > 0 then Result := 'Inn'
  else if Pos('barrow', edid) > 0 then Result := 'NordicRuin'
  else if Pos('ruin', edid) > 0 then Result := 'Ruin'
  else if Pos('dwarven', edid) > 0 then Result := 'DwarvenRuin'
  else if Pos('dwemer', edid) > 0 then Result := 'DwarvenRuin';
end;

function IsModAddedRecord(rec: IInterface): Boolean;
var
  fileName: string;
begin
  fileName := LowerCase(GetFileName(GetFile(rec)));
  // Check if from vanilla game files
  Result := (Pos('skyrim.esm', fileName) = 0) and
            (Pos('update.esm', fileName) = 0) and
            (Pos('dawnguard.esm', fileName) = 0) and
            (Pos('hearthfires.esm', fileName) = 0) and
            (Pos('dragonborn.esm', fileName) = 0) and
            (Pos('unofficial', fileName) = 0);
end;

function ProcessLocation(e: IInterface): Integer;
var
  sourcePlug: string;
  formID, localFormID: string;
  edid, fullName: string;
  parentLoc: IInterface;
  parentLocFormID, parentLocEditorID, parentLocName: string;
  worldspace: IInterface;
  wsFormID, wsEditorID: string;
  locType, keywords: string;
  isModAdded: string;
  outputLine: string;
  pnam, wnam: IInterface;
begin
  Result := 0;

  sourcePlug := GetFileName(GetFile(e));
  formID := FormatFormID(e);
  localFormID := FormatLocalFormID(e);
  edid := EditorID(e);
  fullName := CleanCSV(GetElementEditValues(e, 'FULL'));

  // Parent Location (PNAM)
  pnam := ElementBySignature(e, 'PNAM');
  if Assigned(pnam) then begin
    parentLoc := LinksTo(pnam);
    if Assigned(parentLoc) then begin
      parentLocFormID := FormatFormID(parentLoc);
      parentLocEditorID := EditorID(parentLoc);
      parentLocName := CleanCSV(GetElementEditValues(parentLoc, 'FULL'));
    end;
  end;

  // Worldspace reference
  wnam := ElementBySignature(e, 'WNAM');
  if Assigned(wnam) then begin
    worldspace := LinksTo(wnam);
    if Assigned(worldspace) then begin
      wsFormID := FormatFormID(worldspace);
      wsEditorID := EditorID(worldspace);
    end;
  end;

  locType := DetermineLocationType(e);
  keywords := GetKeywordList(e);

  if IsModAddedRecord(e) then
    isModAdded := 'Yes'
  else
    isModAdded := 'No';

  outputLine := Format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s', [
    sourcePlug,
    formID,
    localFormID,
    edid,
    fullName,
    parentLocFormID,
    parentLocEditorID,
    parentLocName,
    wsFormID,
    wsEditorID,
    locType,
    keywords,
    isModAdded
  ]);

  slLocations.Add(outputLine);
  Inc(iLocationCount);
end;

function ProcessCell(e: IInterface): Integer;
var
  sourcePlug: string;
  formID, localFormID: string;
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

  // Get DATA flags to check if interior
  data := ElementBySignature(e, 'DATA');
  if Assigned(data) then begin
    flags := GetNativeValue(data);
    if (flags and 1) = 1 then
      isInterior := 'Yes'
    else
      isInterior := 'No';
  end else
    isInterior := 'Unknown';

  // Get Location reference (XLCN)
  xlcn := ElementBySignature(e, 'XLCN');
  if not Assigned(xlcn) then
    Exit; // Skip cells without location reference

  locRef := LinksTo(xlcn);
  if not Assigned(locRef) then
    Exit;

  sourcePlug := GetFileName(GetFile(e));
  formID := FormatFormID(e);
  localFormID := FormatLocalFormID(e);
  edid := EditorID(e);
  fullName := CleanCSV(GetElementEditValues(e, 'FULL'));

  locFormID := FormatFormID(locRef);
  locEditorID := EditorID(locRef);
  locFullName := CleanCSV(GetElementEditValues(locRef, 'FULL'));

  // Get worldspace for exterior cells
  worldspace := LinksTo(ElementByIndex(e, 0));
  if Assigned(worldspace) and (Signature(worldspace) = 'WRLD') then begin
    wsFormID := FormatFormID(worldspace);
    wsEditorID := EditorID(worldspace);
  end else begin
    // Interior cells use worldspace 00000000
    wsFormID := '00000000';
    wsEditorID := 'Tamriel (Interior)';
  end;

  if IsModAddedRecord(e) then
    isModAdded := 'Yes'
  else
    isModAdded := 'No';

  outputLine := Format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s', [
    sourcePlug,
    formID,
    localFormID,
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

  slCells.Add(outputLine);
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

function Finalize: Integer;
var
  locPath, cellPath: string;
begin
  locPath := ProgramPath + 'LocationExport.csv';
  cellPath := ProgramPath + 'CellLocationExport.csv';

  AddMessage('');
  AddMessage('========================================');
  AddMessage('Export Complete');
  AddMessage('========================================');
  AddMessage(Format('Locations exported: %d', [iLocationCount]));
  AddMessage(Format('Cell mappings exported: %d', [iCellCount]));
  AddMessage('');

  try
    slLocations.SaveToFile(locPath);
    AddMessage(Format('Location data saved to: %s', [locPath]));
  except
    on E: Exception do
      AddMessage('Error saving locations: ' + E.Message);
  end;

  try
    slCells.SaveToFile(cellPath);
    AddMessage(Format('Cell data saved to: %s', [cellPath]));
  except
    on E: Exception do
      AddMessage('Error saving cells: ' + E.Message);
  end;

  AddMessage('');
  AddMessage('Usage for _locationweather.ini:');
  AddMessage('  [WorldspaceFormID]');
  AddMessage('  LocationFormID=YourWeatherID');
  AddMessage('');
  AddMessage('For interiors, use WorldspaceID 00000000');
  AddMessage('========================================');

  slLocations.Free;
  slCells.Free;
  processedFiles.Free;

  Result := 0;
end;

end.
