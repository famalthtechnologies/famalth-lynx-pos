[Setup]
AppName=Famalth Lynx
AppId={{8C07A1B8-7BE7-4F73-9A89-42D8F7B9D322}
AppVersion=1.1.32
AppPublisher=Famalth Technologies
DefaultDirName={sd}\FamalthLynx
UsePreviousAppDir=yes
DefaultGroupName=Famalth Lynx
OutputBaseFilename=Famalth_Lynx_Installer
OutputDir=Output
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=no
RestartApplications=no


[Types]
Name: "server"; Description: "Main Server (Database & User Interface)"
Name: "client"; Description: "Network Terminal (User Interface Only)"

[Components]
Name: "ui"; Description: "Famalth Lynx POS Interface"; Types: server client; Flags: fixed
Name: "backend"; Description: "Local Backend Server Services"; Types: server

[Files]
; UI Files (Installed on both Server and Client)
Source: "D:\inventorynew\RetailSale new\RetailSale\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: ui
Source: "D:\inventorynew\RetailSale new\RetailSale\windows\runner\resources\app_icon.ico"; DestDir: "{app}\resources"; Flags: ignoreversion; Components: ui
Source: "D:\inventorynew\RetailSale new\RetailSale\installer\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; Backend Files (Installed ONLY on the Server)
Source: "D:\inventorynew\RetailSale new\RetailSale\backend\server.exe"; DestDir: "{app}"; Flags: ignoreversion; Components: backend
Source: "D:\inventorynew\RetailSale new\RetailSale\backend\license.key"; DestDir: "{app}"; Flags: ignoreversion; Components: backend
Source: "D:\inventorynew\RetailSale new\RetailSale\backend\sysConfig.enc"; DestDir: "{app}"; Flags: ignoreversion; Components: backend
Source: "D:\inventorynew\RetailSale new\RetailSale\backend\run_hidden.vbs"; DestDir: "{app}"; Flags: ignoreversion; Components: backend

[InstallDelete]
Type: files; Name: "{app}\sync_status.json"
Type: files; Name: "{app}\client.json"

[Icons]
Name: "{group}\Famalth Lynx"; Filename: "{app}\FamalthLynx.exe"; IconFilename: "{app}\resources\app_icon.ico"
Name: "{commondesktop}\Famalth Lynx"; Filename: "{app}\FamalthLynx.exe"; IconFilename: "{app}\resources\app_icon.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Registry]
; Auto-start server on boot (ONLY on the Server)
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "FamalthLynxBackendServer"; ValueData: "wscript.exe ""{app}\run_hidden.vbs"""; Flags: uninsdeletevalue; Components: backend

[Run]
; VC++ Redist is required for both Flutter Windows apps and Node.js
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: NeedsVC

; Launch Flutter UI (On both)
Filename: "{app}\FamalthLynx.exe"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[Code]
function EscapePowerShell(Value: String): String;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(Value) do
  begin
    if Value[i] = #39 then Result := Result + #39 + #39
    else Result := Result + Value[i];
  end;
end;

function StopOwnedBackend(): Boolean;
var
  ScriptPath, ScriptText: String;
  ResultCode: Integer;
begin
  ScriptPath := ExpandConstant('{tmp}\famalth_stop_backend.ps1');
  ScriptText := '$target = ''' + EscapePowerShell(ExpandConstant('{app}\server.exe')) + '''' + #13#10 +
    '$p = Get-CimInstance Win32_Process -Filter "Name=''server.exe''" -ErrorAction SilentlyContinue | ' +
    'Where-Object { $_.ExecutablePath -and $_.ExecutablePath -ieq $target }' + #13#10 +
    'if ($p) { $p | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop }; Start-Sleep -Milliseconds 800 }' + #13#10 +
    '$left = Get-CimInstance Win32_Process -Filter "Name=''server.exe''" -ErrorAction SilentlyContinue | ' +
    'Where-Object { $_.ExecutablePath -and $_.ExecutablePath -ieq $target }' + #13#10 +
    'if ($left) { exit 5 } else { exit 0 }';
  if not SaveStringToFile(ScriptPath, ScriptText, False) then
  begin Result := False; Exit; end;
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  DeleteFile(ScriptPath);
  Sleep(500);
end;

function NeedsVC: Boolean;
var
  VCRuntimeInstalled: Cardinal;
begin
  if RegQueryDWordValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', VCRuntimeInstalled) or
     RegQueryDWordValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', VCRuntimeInstalled) then
  begin
    Result := (VCRuntimeInstalled <> 1);
  end
  else
  begin
    Result := True;
  end;
end;

{ Do not kill processes by executable name or remove scheduled tasks not created
  and owned by this installer. The app's own Run value starts its backend. }
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  NeedsRestart := False;
  if not StopOwnedBackend() then
    Result := 'Famalth Lynx could not stop its own backend process at ' +
      ExpandConstant('{app}\server.exe') + '. Close Famalth Lynx and retry setup.'
  else
    Result := '';
end;
