unit ExportLocationData;

{
  Export Location Data for ENB Location Weather
  =============================================
  Exports WorldspaceID, LocationID, and location information
  for use with ENB _locationweather.ini configuration.

  Usage:
  1. Load your plugins in xEdit (SSEEdit/TES5Edit)
  2. Select the plugin(s) you want to export from
  3. Right-click -> Apply Script -> ExportLocationData
  4. Check the output CSV in your xEdit directory

  Output: LocationExport.csv
}

uses SysUtils, Classes;

var
  slOutput: TStringList;
  iLocationCount: Integer;

function Initialize: Integer;
begin
  slOutput := TStringList.Create;
  // CSV Header
  slOutput.Add('SourcePlugin,FormID,LocalFormID,EditorID,FullName,ParentLocationID,ParentLocationName,WorldspaceID,WorldspaceName,Keywords');
  iLocationCount := 0;
  Result := 0;
end;

function GetKeywords(rec: IInterface): string;
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
    Result := kwList.CommaText;
  finally
    kwList.Free;
  end;
end;

function GetParentLocation(rec: IInterface): IInterface;
var
  pnam: IInterface;
begin
  Result := nil;
  pnam := ElementBySignature(rec, 'PNAM');
  if Assigned(pnam) then
    Result := LinksTo(pnam);
end;

function GetLocationWorldspace(rec: IInterface): IInterface;
var
  wnam: IInterface;
begin
  Result := nil;
  // Try WNAM (Worldspace/Cell reference)
  wnam := ElementBySignature(rec, 'WNAM');
  if Assigned(wnam) then
    Result := LinksTo(wnam);
end;

function FormatFormID(rec: IInterface): string;
var
  loadOrder: Integer;
  localID: Cardinal;
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
  // Mask out the load order to get local FormID
  localID := formID and $00FFFFFF;
  Result := IntToHex(localID, 8);
end;

function CleanString(s: string): string;
begin
  // Remove commas and quotes that would break CSV
  Result := StringReplace(s, ',', ';', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '''', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

function Process(e: IInterface): Integer;
var
  sig: string;
  sourcePlug: string;
  formID, localFormID: string;
  edid, fullName: string;
  parentLoc: IInterface;
  parentLocID, parentLocName: string;
  worldspace: IInterface;
  wsID, wsName: string;
  keywords: string;
  outputLine: string;
begin
  Result := 0;

  sig := Signature(e);

  // Only process Location records (LCTN)
  if sig <> 'LCTN' then
    Exit;

  // Get source plugin name
  sourcePlug := GetFileName(GetFile(e));

  // Get FormIDs
  formID := FormatFormID(e);
  localFormID := FormatLocalFormID(e);

  // Get EditorID and Full Name
  edid := EditorID(e);
  fullName := CleanString(GetElementEditValues(e, 'FULL'));

  // Get Parent Location
  parentLoc := GetParentLocation(e);
  if Assigned(parentLoc) then begin
    parentLocID := FormatFormID(parentLoc);
    parentLocName := CleanString(GetElementEditValues(parentLoc, 'FULL'));
    if parentLocName = '' then
      parentLocName := EditorID(parentLoc);
  end else begin
    parentLocID := '';
    parentLocName := '';
  end;

  // Get Worldspace reference
  worldspace := GetLocationWorldspace(e);
  if Assigned(worldspace) then begin
    wsID := FormatFormID(worldspace);
    wsName := EditorID(worldspace);
  end else begin
    wsID := '';
    wsName := '';
  end;

  // Get Keywords
  keywords := CleanString(GetKeywords(e));

  // Build output line
  outputLine := Format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s', [
    sourcePlug,
    formID,
    localFormID,
    edid,
    fullName,
    parentLocID,
    parentLocName,
    wsID,
    wsName,
    keywords
  ]);

  slOutput.Add(outputLine);
  Inc(iLocationCount);

  Result := 0;
end;

function Finalize: Integer;
var
  outputPath: string;
begin
  // Save to CSV file
  outputPath := ProgramPath + 'LocationExport.csv';

  AddMessage('');
  AddMessage('========================================');
  AddMessage('Location Export Complete');
  AddMessage('========================================');
  AddMessage(Format('Total locations exported: %d', [iLocationCount]));
  AddMessage(Format('Output file: %s', [outputPath]));
  AddMessage('');

  try
    slOutput.SaveToFile(outputPath);
    AddMessage('File saved successfully!');
  except
    on E: Exception do
      AddMessage('Error saving file: ' + E.Message);
  end;

  slOutput.Free;
  Result := 0;
end;

end.
