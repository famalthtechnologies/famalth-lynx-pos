[Setup]
AppName=Famalth Lynx
AppId={{8C07A1B8-7BE7-4F73-9A89-42D8F7B9D322}
AppVersion=1.1.31
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
; Clean up legacy autorun value if present
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "RetailposBackendServer"; Flags: deletevalue; Components: backend
; Auto-start server on boot (ONLY on the Server)
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "FamalthLynxBackendServer"; ValueData: "wscript.exe ""{app}\run_hidden.vbs"""; Flags: uninsdeletevalue; Components: backend

[Run]
; VC++ Redist is required for both Flutter Windows apps and Node.js
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: NeedsVC

; Firewall and Server start (ONLY on the Server)
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Famalth Lynx API Port 3000"" dir=in action=allow protocol=TCP localport=3000"; Flags: runhidden; Components: backend
Filename: "wscript.exe"; Parameters: """{app}\run_hidden.vbs"""; WorkingDir: "{app}"; Flags: nowait; Components: backend

; Launch Flutter UI (On both)
Filename: "{app}\FamalthLynx.exe"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Remove Firewall rule (ONLY if it was a Server)
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Famalth Lynx API Port 3000"""; Flags: runhidden; RunOnceId: "DelFwFamalth"; Components: backend
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Retailpos API Port 3000"""; Flags: runhidden; RunOnceId: "DelFwRetailpos"; Components: backend
Filename: "{sys}\schtasks.exe"; Parameters: "/delete /tn ""FamalthLynx_Server"" /f"; Flags: runhidden; RunOnceId: "DelTaskFamalth"; Components: backend
Filename: "{sys}\schtasks.exe"; Parameters: "/delete /tn ""INVINS_Server"" /f"; Flags: runhidden; RunOnceId: "DelTaskInvins"; Components: backend

[Code]
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

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec('taskkill.exe', '/F /IM FamalthLynx.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill.exe', '/F /IM Retailpos.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('taskkill.exe', '/F /IM server.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1000);
  Result := '';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Safely delete legacy/existing tasks without crashing installer on permission issues
    Exec(ExpandConstant('{sys}\schtasks.exe'), '/delete /tn "INVINS_Server" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec(ExpandConstant('{sys}\schtasks.exe'), '/delete /tn "FamalthLynx_Server" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    // Register auto-start task only if backend server component was installed
    if WizardIsComponentSelected('backend') then
    begin
      Exec(ExpandConstant('{sys}\schtasks.exe'),
        '/create /tn "FamalthLynx_Server" /tr "wscript.exe \""' + ExpandConstant('{app}') + '\run_hidden.vbs\"""" /sc onlogon /rl highest /f',
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;
