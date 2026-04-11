{
  Export Weather Cloud Settings - Simple & Robust

  Exports cloud data from WTHR records in a simple, reliable format.
  Tests path structures and adapts to your xEdit version.

  Output columns per cloud layer:
  - Cloud texture path
  - X/Y speeds
  - RGBA colors for Sunrise, Day, Sunset, Night
  - Alpha values for each time of day

  Author: KreatE ENB Tools
  Version: 1.2
}
unit ExportWeatherClouds;

var
  slOutput: TStringList;
  sFileName: string;
  iCount: integer;

function Initialize: integer;
begin
  slOutput := TStringList.Create;
  iCount := 0;

  // Header
  slOutput.Add('FormID,EditorID,Plugin,Layer,' +
    'Texture,' +
    'SpeedX,SpeedY,' +
    'Sunrise_R,Sunrise_G,Sunrise_B,Sunrise_A,' +
    'Day_R,Day_G,Day_B,Day_A,' +
    'Sunset_R,Sunset_G,Sunset_B,Sunset_A,' +
    'Night_R,Night_G,Night_B,Night_A');

  sFileName := ProgramPath + 'WeatherClouds_Export.csv';
  Result := 0;
end;

function TryGetElement(e: IInterface; path: string): IInterface;
begin
  Result := ElementByPath(e, path);
end;

function SafeValue(e: IInterface; path: string): string;
var
  el: IInterface;
begin
  Result := '';
  el := ElementByPath(e, path);
  if Assigned(el) then
    Result := GetEditValue(el);
end;

function GetArrayValue(e: IInterface; sig: string; idx: integer): string;
var
  arr, el: IInterface;
begin
  Result := '';
  arr := ElementBySignature(e, sig);
  if not Assigned(arr) then Exit;
  if idx >= ElementCount(arr) then Exit;
  el := ElementByIndex(arr, idx);
  if Assigned(el) then
    Result := GetEditValue(el);
end;

function GetCloudTexture(e: IInterface; layer: integer): string;
var
  textures, tex: IInterface;
  layerStr: string;
begin
  Result := '';

  // Try "Cloud Textures" container first
  textures := ElementByPath(e, 'Cloud Textures');
  if Assigned(textures) then begin
    if layer < 10 then
      layerStr := '0' + IntToStr(layer)
    else
      layerStr := IntToStr(layer);

    tex := ElementByPath(textures, layerStr + ' - Layer');
    if Assigned(tex) then begin
      Result := GetEditValue(tex);
      Exit;
    end;

    // Try index-based access
    if layer < ElementCount(textures) then begin
      tex := ElementByIndex(textures, layer);
      if Assigned(tex) then
        Result := GetEditValue(tex);
    end;
  end;
end;

function GetColorValue(e: IInterface; layer: integer; tod: string; comp: string): string;
var
  colors, layerColors, todColors, compEl: IInterface;
begin
  Result := '0';

  // Try "PNAM - Cloud Colors" path
  colors := ElementByPath(e, 'PNAM - Cloud Colors');
  if not Assigned(colors) then
    colors := ElementBySignature(e, 'PNAM');
  if not Assigned(colors) then Exit;

  // Try named layer access
  layerColors := ElementByPath(colors, 'Layer #' + IntToStr(layer));
  if not Assigned(layerColors) then begin
    // Try indexed access
    if layer < ElementCount(colors) then
      layerColors := ElementByIndex(colors, layer);
  end;
  if not Assigned(layerColors) then Exit;

  // Get time of day
  todColors := ElementByPath(layerColors, tod);
  if not Assigned(todColors) then Exit;

  // Get component
  compEl := ElementByPath(todColors, comp);
  if Assigned(compEl) then
    Result := GetEditValue(compEl);
end;

function GetAlphaValue(e: IInterface; layer: integer; tod: string): string;
var
  alphas, layerAlphas, todAlpha: IInterface;
begin
  Result := '0';

  // Try "JNAM - Cloud Alphas" path
  alphas := ElementByPath(e, 'JNAM - Cloud Alphas');
  if not Assigned(alphas) then
    alphas := ElementBySignature(e, 'JNAM');
  if not Assigned(alphas) then Exit;

  // Try named layer access
  layerAlphas := ElementByPath(alphas, 'Layer #' + IntToStr(layer));
  if not Assigned(layerAlphas) then begin
    // Try indexed access
    if layer < ElementCount(alphas) then
      layerAlphas := ElementByIndex(alphas, layer);
  end;
  if not Assigned(layerAlphas) then Exit;

  // Get time of day
  todAlpha := ElementByPath(layerAlphas, tod);
  if Assigned(todAlpha) then
    Result := GetEditValue(todAlpha);
end;

function GetFormIDStr(rec: IInterface): string;
begin
  Result := IntToHex64(GetLoadOrderFormID(rec), 8);
end;

function ProcessWeather(e: IInterface): integer;
var
  sFormID, editorID, plugin: string;
  layer: integer;
  texture, speedX, speedY: string;
  sr, sg, sb, sa, dr, dg, db, da: string;
  ssr, ssg, ssb, ssa, nr, ng, nb, na: string;
  speedXArr, speedYArr: IInterface;
  line: string;
begin
  Result := 0;

  // Get FormID as hex string
  sFormID := GetFormIDStr(e);
  editorID := EditorID(e);
  plugin := GetFileName(GetFile(e));

  // Get speed arrays
  speedXArr := ElementBySignature(e, 'QNAM');
  speedYArr := ElementBySignature(e, 'RNAM');

  // Process up to 32 cloud layers
  for layer := 0 to 31 do begin
    texture := GetCloudTexture(e, layer);

    // Skip layers without textures
    if texture = '' then Continue;

    // Get speeds
    speedX := '0';
    speedY := '0';
    if Assigned(speedXArr) and (layer < ElementCount(speedXArr)) then
      speedX := GetEditValue(ElementByIndex(speedXArr, layer));
    if Assigned(speedYArr) and (layer < ElementCount(speedYArr)) then
      speedY := GetEditValue(ElementByIndex(speedYArr, layer));

    // Sunrise colors
    sr := GetColorValue(e, layer, 'Sunrise', 'Red');
    sg := GetColorValue(e, layer, 'Sunrise', 'Green');
    sb := GetColorValue(e, layer, 'Sunrise', 'Blue');
    sa := GetAlphaValue(e, layer, 'Sunrise');

    // Day colors
    dr := GetColorValue(e, layer, 'Day', 'Red');
    dg := GetColorValue(e, layer, 'Day', 'Green');
    db := GetColorValue(e, layer, 'Day', 'Blue');
    da := GetAlphaValue(e, layer, 'Day');

    // Sunset colors
    ssr := GetColorValue(e, layer, 'Sunset', 'Red');
    ssg := GetColorValue(e, layer, 'Sunset', 'Green');
    ssb := GetColorValue(e, layer, 'Sunset', 'Blue');
    ssa := GetAlphaValue(e, layer, 'Sunset');

    // Night colors
    nr := GetColorValue(e, layer, 'Night', 'Red');
    ng := GetColorValue(e, layer, 'Night', 'Green');
    nb := GetColorValue(e, layer, 'Night', 'Blue');
    na := GetAlphaValue(e, layer, 'Night');

    // Escape commas in texture path
    if Pos(',', texture) > 0 then
      texture := '"' + texture + '"';

    // Build CSV line
    line := sFormID + ',' + editorID + ',' + plugin + ',' + IntToStr(layer) + ',' +
            texture + ',' + speedX + ',' + speedY + ',' +
            sr + ',' + sg + ',' + sb + ',' + sa + ',' +
            dr + ',' + dg + ',' + db + ',' + da + ',' +
            ssr + ',' + ssg + ',' + ssb + ',' + ssa + ',' +
            nr + ',' + ng + ',' + nb + ',' + na;

    slOutput.Add(line);
    Inc(iCount);
  end;
end;

function Process(e: IInterface): integer;
begin
  Result := 0;
  if Signature(e) <> 'WTHR' then Exit;
  ProcessWeather(e);
end;

function Finalize: integer;
begin
  AddMessage('');
  AddMessage('=== Cloud Settings Export Complete ===');
  AddMessage('Output: ' + sFileName);
  AddMessage('Cloud layers exported: ' + IntToStr(iCount));
  AddMessage('');

  slOutput.SaveToFile(sFileName);
  slOutput.Free;
  Result := 0;
end;

end.
