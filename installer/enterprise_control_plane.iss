[Setup]
AppName=Famalth Enterprise Control Plane
AppId={{9D38C2A1-8EF4-4C55-9B21-7A39B214C988}}
AppVersion=1.0.0
AppPublisher=Famalth Technologies
DefaultDirName={sd}\FamalthEnterpriseConsole
UsePreviousAppDir=yes
DefaultGroupName=Famalth Enterprise Control Plane
OutputBaseFilename=Famalth_Enterprise_Console_Installer
OutputDir=Output
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=no
RestartApplications=no

[Files]
; Standalone Enterprise Control Plane Executable and Flutter runtime dependencies
Source: "..\build\enterprise_console\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\windows\runner\resources\app_icon.ico"; DestDir: "{app}\resources"; Flags: ignoreversion
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\Famalth Enterprise Control Plane"; Filename: "{app}\FamalthEnterpriseConsole.exe"; IconFilename: "{app}\resources\app_icon.ico"
Name: "{commondesktop}\Famalth Enterprise Control Plane"; Filename: "{app}\FamalthEnterpriseConsole.exe"; IconFilename: "{app}\resources\app_icon.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
; Install VC++ Redistributable silently if missing
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: NeedsVC; StatusMsg: "Verifying Visual C++ Runtime..."

; Launch Enterprise Control Plane post-install
Filename: "{app}\FamalthEnterpriseConsole.exe"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent; Description: "Launch Famalth Enterprise Control Plane"

[Code]
function NeedsVC: Boolean;
var
  VCRuntimeInstalled: Cardinal;
begin
  if RegQueryDWordValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Installed', VCRuntimeInstalled) then
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
  Exec('taskkill.exe', '/F /IM FamalthEnterpriseConsole.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1000);
  Result := '';
end;
