[Setup]
AppName=Famalth Lynx Backend
AppId={{8C07A1B8-7BE7-4F73-9A89-42D8F7B9D323}
AppVersion=1.1.41
AppPublisher=Famalth Technologies
DefaultDirName={sd}\FamalthLynx
UsePreviousAppDir=yes
DefaultGroupName=Famalth Lynx
OutputBaseFilename=backend_Installer
OutputDir=Output
Compression=lzma
SolidCompression=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
CloseApplications=no
RestartApplications=no

[Files]
Source: "Output\Famalth_Lynx_Installer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\backend\server.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\backend\encrypt.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\backend\license.key"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\backend\sysConfig.enc"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\backend\run_hidden.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "app_icon.ico"; DestDir: "{app}\resources"; Flags: ignoreversion
Source: "VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "postgresql-18.3-2-windows-x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]

; ------------------------------------------------------------
; Install Microsoft Visual C++ Runtime
; ------------------------------------------------------------

Filename: "{tmp}\VC_redist.x64.exe"; \
    Parameters: "/install /quiet /norestart"; \
    StatusMsg: "Installing Visual C++ Runtime..."; \
    Flags: waituntilterminated runhidden

; ------------------------------------------------------------
; Launch Famalth Lynx User Interface on finish
; ------------------------------------------------------------

Filename: "{app}\FamalthLynx.exe"; \
    WorkingDir: "{app}"; \
    Description: "Launch Famalth Lynx"; \
    Flags: nowait postinstall skipifsilent

[Registry]

; ------------------------------------------------------------
; Famalth Lynx Registry Keys
; ------------------------------------------------------------

Root: HKLM; \
    Subkey: "SOFTWARE\Famalth\Lynx\Backend"; \
    Flags: uninsdeletekey

Root: HKLM; \
    Subkey: "SOFTWARE\Famalth\Lynx"; \
    Flags: uninsdeletekeyifempty

Root: HKLM; \
    Subkey: "SOFTWARE\Famalth"; \
    Flags: uninsdeletekeyifempty

; ------------------------------------------------------------
; Auto-start Famalth Lynx backend on Windows startup
; ------------------------------------------------------------

Root: HKLM; \
    Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; \
    ValueType: string; \
    ValueName: "FamalthLynxBackendServer"; \
    ValueData: "wscript.exe ""{app}\run_hidden.vbs"""; \
    Flags: uninsdeletevalue

[UninstallDelete]

; ------------------------------------------------------------
; Delete Famalth Lynx application security & runtime files
; ------------------------------------------------------------

Type: files; \
    Name: "{commonappdata}\FamalthLynx\security.dat"

Type: files; \
    Name: "{app}\server_port.txt"

Type: files; \
    Name: "{app}\pg_bin.txt"

Type: files; \
    Name: "{app}\db_setup_log.txt"

Type: dirifempty; \
    Name: "{commonappdata}\FamalthLynx"

[UninstallRun]

; ------------------------------------------------------------
; Stop Famalth Lynx backend process
; ------------------------------------------------------------

Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -Command ""$target = Join-Path '{app}' 'server.exe'; Get-CimInstance Win32_Process -Filter \""Name='server.exe'\"" -ErrorAction SilentlyContinue | Where-Object {{ $_.ExecutablePath -and $_.ExecutablePath -ieq $target }} | ForEach-Object {{ Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }}"""; \
    Flags: runhidden waituntilterminated

; ------------------------------------------------------------
; Remove Windows Firewall rule for Famalth Lynx Backend API
; ------------------------------------------------------------

Filename: "netsh.exe"; \
    Parameters: "advfirewall firewall delete rule name=""Famalth Lynx Backend API"""; \
    Flags: runhidden waituntilterminated

; ------------------------------------------------------------
; Remove ONLY Famalth Lynx's Defender exclusion
; ------------------------------------------------------------

Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -Command ""try {{ Remove-MpPreference -ExclusionPath '{app}' -ErrorAction SilentlyContinue }} catch {{ }}"""; \
    Flags: runhidden waituntilterminated

; ------------------------------------------------------------
; Stop and remove ONLY Famalth Lynx's PostgreSQL service.
; Does NOT stop or delete another company's PostgreSQL.
; ------------------------------------------------------------

Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -Command ""$svc='FamalthLynxPostgreSQL18'; $s=Get-Service -Name $svc -ErrorAction SilentlyContinue; if($s){{ if($s.Status -ne 'Stopped'){{ Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }}; & sc.exe delete $svc | Out-Null }}"""; \
    Flags: runhidden waituntilterminated

; ------------------------------------------------------------
; Delete ONLY Famalth Lynx's PostgreSQL data directory.
; Existing company's PostgreSQL data is NOT touched.
; ------------------------------------------------------------

Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -Command ""$p=Join-Path $env:ProgramData 'FamalthLynx\PostgreSQL18Data'; if(Test-Path -LiteralPath $p){{ Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }}"""; \
    Flags: runhidden waituntilterminated

; ------------------------------------------------------------
; Delete ONLY PostgreSQL binaries installed by this Famalth Lynx
; backend installer.
; ------------------------------------------------------------

Filename: "powershell.exe"; \
    Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -Command ""$p=Join-Path '{app}' 'PostgreSQL18'; if(Test-Path -LiteralPath $p){{ Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }}; try {{ [Environment]::SetEnvironmentVariable('FAMALTH_PG_BIN', $null, 'Machine') }} catch {{ }}"""; \
    Flags: runhidden waituntilterminated

[Code]

const
  CRLF = #13#10;

  FAMALTH_PG_SERVICE = 'FamalthLynxPostgreSQL18';

  { PostgreSQL folds unquoted SQL identifiers to lowercase, and psql's
    -d value is case-sensitive. Keep the configured name lowercase so the
    CREATE DATABASE and subsequent connections refer to the same database. }
  FAMALTH_DB_NAME = 'famalth_lynx';

  FAMALTH_DB_USER = 'famalth_lynx_app';

var
  PgAuthPage: TInputQueryWizardPage;

  AutoDetectedMasterPassword: String;
  AutoDetectedPort: String;
  AutoDetectedBin: String;

  ConfiguredDbPort: String;
  ConfiguredDbName: String;
  ConfiguredDbUser: String;
  ConfiguredDbPassword: String;

  InstallSeparately: Boolean;

  SeparateInstallBtn: TButton;

  CreatedOurPostgres: Boolean;

  OurPostgresServiceName: String;
  OurPostgresPrefix: String;
  OurPostgresDataDir: String;

  OurPostgresPort: String;
  OurPostgresBin: String;

  OurPostgresMasterPassword: String;

{ ====================================================================== }
{ STRING ESCAPING                                                        }
{ ====================================================================== }

function EscapeForSQL(Value: String): String;
var
  i: Integer;
  C: String;
begin
  Result := '';

  for i := 1 to Length(Value) do
  begin
    C := Copy(Value, i, 1);

    if C = #39 then
      Result := Result + #39 + #39
    else
      Result := Result + C;
  end;
end;


function EscapeForJSON(Value: String): String;
var
  i: Integer;
  C: String;
begin
  Result := '';

  for i := 1 to Length(Value) do
  begin
    C := Copy(Value, i, 1);

    if C = '\' then
      Result := Result + '\' + '\'
    else if C = '"' then
      Result := Result + '\' + '"'
    else if C = #13 then
      Result := Result + '\' + 'r'
    else if C = #10 then
      Result := Result + '\' + 'n'
    else
      Result := Result + C;
  end;
end;


function EscapeForCMD(Value: String): String;
var
  i: Integer;
  C: String;
begin
  Result := '';

  for i := 1 to Length(Value) do
  begin
    C := Copy(Value, i, 1);

    if C = '"' then
      Result := Result + '\"'
    else
      Result := Result + C;
  end;
end;


function EscapePowerShell(Value: String): String;
var
  i: Integer;
begin
  Result := '';

  for i := 1 to Length(Value) do
  begin
    if Value[i] = #39 then
      Result := Result + #39 + #39
    else
      Result := Result + Value[i];
  end;
end;


{ ====================================================================== }
{ PASSWORD SCRAMBLING                                                     }
{ ====================================================================== }

function ScramblePassword(P: String): String;
var
  i: Integer;
begin
  Result := '';

  for i := 1 to Length(P) do
  begin
    Result := Result + Format('%.2x', [Ord(P[i]) xor 115]);
  end;
end;


function UnscramblePassword(H: String): String;
var
  i: Integer;
  Code: Integer;
begin
  Result := '';

  i := 1;

  while i <= Length(H) - 1 do
  begin
    Code := StrToIntDef('$' + Copy(H, i, 2), 0);

    Result := Result + Chr(Code xor 115);

    i := i + 2;
  end;
end;


{ ====================================================================== }
{ RANDOM PASSWORD                                                         }
{ ====================================================================== }

function GenerateSecurePassword(): String;
var
  i: Integer;
  chars: String;
begin
  chars :=
    'ABCDEFGHJKLMNPQRSTUVWXYZ' +
    'abcdefghijkmnopqrstuvwxyz' +
    '23456789';

  Result := '';

  for i := 1 to 20 do
  begin
    Result :=
      Result +
      chars[Random(Length(chars)) + 1];
  end;
end;


{ ====================================================================== }
{ JWT SECRET                                                              }
{ ====================================================================== }

function GenerateJWTSecret(): String;
var
  i: Integer;
  chars: String;
begin
  chars :=
    'abcdefghijklmnopqrstuvwxyz' +
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
    '0123456789';

  Result := '';

  for i := 1 to 64 do
  begin
    Result :=
      Result +
      chars[Random(Length(chars)) + 1];
  end;
end;


{ ====================================================================== }
{ CREATE APPLICATION CONFIGURATION                                       }
{ ====================================================================== }

procedure CreateConfigFile(
  DbHost,
  DbPort,
  DbName,
  DbUser,
  DbPassword: String);
var
  ConfigPath: String;
  Content: String;
  JwtSecret: String;
begin

  JwtSecret := GenerateJWTSecret();

  ConfigPath :=
    ExpandConstant('{app}\config.json');

  Content :=
    '{' +
      '"db_host":"' + EscapeForJSON(DbHost) + '",' +
      '"db_port":' + DbPort + ',' +
      '"db_database":"' + EscapeForJSON(DbName) + '",' +
      '"db_user":"' + EscapeForJSON(DbUser) + '",' +
      '"db_password":"' + EscapeForJSON(DbPassword) + '",' +
      '"JWT_SECRET":"' + EscapeForJSON(JwtSecret) + '"' +
    '}';

  SaveStringToFile(
    ConfigPath,
    Content,
    False
  );
end;


{ ====================================================================== }
{ CHECK WINDOWS SERVICE                                                  }
{ ====================================================================== }

function ServiceExists(ServiceName: String): Boolean;
var
  ResultCode: Integer;
begin

  Result :=
    Exec(
      'sc.exe',
      'query "' + ServiceName + '"',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );

  Result :=
    Result and
    (ResultCode = 0);
end;


{ ====================================================================== }
{ REMOVE ONLY A STALE FAMALTH POSTGRESQL SERVICE                         }
{ ====================================================================== }

function RemoveStaleFamalthPostgresService(): Boolean;
var
  ResultCode: Integer;
  Attempt: Integer;
begin
  Result := True;

  if not ServiceExists(FAMALTH_PG_SERVICE) then
    Exit;

  Exec(
    'sc.exe',
    'stop "' + FAMALTH_PG_SERVICE + '"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );

  Exec(
    'sc.exe',
    'delete "' + FAMALTH_PG_SERVICE + '"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );

  for Attempt := 1 to 15 do
  begin
    Sleep(1000);
    if not ServiceExists(FAMALTH_PG_SERVICE) then
      Exit;
  end;

  Result := False;
end;


{ ====================================================================== }
{ CHECK TCP PORT                                                         }
{ ====================================================================== }

function IsTcpPortInUse(Port: String): Boolean;
var
  TempFile: String;
  ResultCode: Integer;
  Content: AnsiString;
begin

  Result := False;

  TempFile :=
    ExpandConstant('{tmp}\port_check_' + Port + '.txt');

  DeleteFile(TempFile);

  Exec(
    'cmd.exe',
    '/C netstat -ano -p tcp | findstr /R /C:":' +
      Port +
      ' " > "' +
      TempFile +
      '"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );

  if LoadStringFromFile(
       TempFile,
       Content
     ) then
  begin
    if Trim(String(Content)) <> '' then
    begin
      Result := True;
    end;
  end;

  DeleteFile(TempFile);
end;


{ ====================================================================== }
{ FIND FREE POSTGRESQL PORT                                              }
{ ====================================================================== }

function FindFreePort(): String;
var
  Port: Integer;
begin

  Result := '';

  { Start from 5433.
    5432 is intentionally not preferred because it is
    normally used by an existing PostgreSQL installation. }

  for Port := 5433 to 5499 do
  begin

    if not IsTcpPortInUse(IntToStr(Port)) then
    begin
      Result := IntToStr(Port);
      Exit;
    end;

  end;

  { Fallback search }

  for Port := 5500 to 5999 do
  begin

    if not IsTcpPortInUse(IntToStr(Port)) then
    begin
      Result := IntToStr(Port);
      Exit;
    end;

  end;
end;


{ ====================================================================== }
{ FIND FREE API PORT                                                     }
{ ====================================================================== }

function FindFreeApiPort(): String;
var
  Port: Integer;
begin
  Result := '';

  for Port := 3000 to 3099 do
  begin
    if not IsTcpPortInUse(IntToStr(Port)) then
    begin
      Result := IntToStr(Port);
      Exit;
    end;
  end;

  for Port := 3100 to 3199 do
  begin
    if not IsTcpPortInUse(IntToStr(Port)) then
    begin
      Result := IntToStr(Port);
      Exit;
    end;
  end;
end;


{ ====================================================================== }
{ FIND EXISTING POSTGRESQL                                                }
{ ====================================================================== }

function FindPostgresBinPath(
  var OutBinPath,
  OutPort: String): Boolean;

var
  Versions: array[0..9] of String;
  Drives: array[0..2] of String;

  i: Integer;
  j: Integer;
  k: Integer;

  Candidate: String;

  RegKey: String;
  RegBaseDir: String;
  RegPort: String;

  SubKeys: TArrayOfString;

begin

  Result := False;

  OutBinPath := '';

  OutPort := '5432';


  { ------------------------------------------------------------ }
  { Check Famalth-owned PostgreSQL first                        }
  { ------------------------------------------------------------ }

  Candidate := ExpandConstant('{app}\PostgreSQL18\bin\');
  if FileExists(Candidate + 'psql.exe') and FileExists(Candidate + 'initdb.exe') then
  begin
    OutBinPath := Candidate;
    Result := True;
    Exit;
  end;


  { ------------------------------------------------------------ }
  { Registry: 64-bit PostgreSQL installations                   }
  { ------------------------------------------------------------ }

  if RegGetSubkeyNames(
       HKEY_LOCAL_MACHINE,
       'SOFTWARE\PostgreSQL\Installations',
       SubKeys
     ) then
  begin

    for k := 0 to GetArrayLength(SubKeys) - 1 do
    begin

      RegKey :=
        'SOFTWARE\PostgreSQL\Installations\' +
        SubKeys[k];

      if RegQueryStringValue(
           HKEY_LOCAL_MACHINE,
           RegKey,
           'Base Directory',
           RegBaseDir
         ) then
      begin

        Candidate :=
          AddBackslash(RegBaseDir) +
          'bin\';

        if FileExists(
             Candidate + 'psql.exe'
           ) then
        begin

          OutBinPath := Candidate;

          if RegQueryStringValue(
               HKEY_LOCAL_MACHINE,
               'SOFTWARE\PostgreSQL\Services\' +
               SubKeys[k],
               'Port',
               RegPort
             ) then
          begin

            if RegPort <> '' then
              OutPort := RegPort;

          end;

          Result := True;

          Exit;
        end;

      end;

    end;

  end;


  { ------------------------------------------------------------ }
  { Registry: 32-bit/WOW6432Node PostgreSQL installations       }
  { ------------------------------------------------------------ }

  if RegGetSubkeyNames(
       HKEY_LOCAL_MACHINE,
       'SOFTWARE\WOW6432Node\PostgreSQL\Installations',
       SubKeys
     ) then
  begin

    for k := 0 to GetArrayLength(SubKeys) - 1 do
    begin

      RegKey :=
        'SOFTWARE\WOW6432Node\PostgreSQL\Installations\' +
        SubKeys[k];

      if RegQueryStringValue(
           HKEY_LOCAL_MACHINE,
           RegKey,
           'Base Directory',
           RegBaseDir
         ) then
      begin

        Candidate :=
          AddBackslash(RegBaseDir) +
          'bin\';

        if FileExists(
             Candidate + 'psql.exe'
           ) then
        begin

          OutBinPath := Candidate;

          if RegQueryStringValue(
               HKEY_LOCAL_MACHINE,
               'SOFTWARE\WOW6432Node\PostgreSQL\Services\' +
               SubKeys[k],
               'Port',
               RegPort
             ) then
          begin

            if RegPort <> '' then
              OutPort := RegPort;

          end;

          Result := True;

          Exit;
        end;

      end;

    end;

  end;


  { ------------------------------------------------------------ }
  { Standard PostgreSQL installation directories                 }
  { ------------------------------------------------------------ }

  Versions[0] := '19';
  Versions[1] := '18';
  Versions[2] := '17';
  Versions[3] := '16';
  Versions[4] := '15';
  Versions[5] := '14';
  Versions[6] := '13';
  Versions[7] := '12';
  Versions[8] := '11';
  Versions[9] := '10';


  Drives[0] := ExpandConstant('{sd}');
  Drives[1] := 'C:';
  Drives[2] := 'D:';


  for j := 0 to 2 do
  begin

    for i := 0 to 9 do
    begin

      { Program Files }

      Candidate :=
        Drives[j] +
        '\Program Files\PostgreSQL\' +
        Versions[i] +
        '\bin\';

      if FileExists(
           Candidate + 'psql.exe'
         ) then
      begin

        OutBinPath := Candidate;

        Result := True;

        Exit;
      end;


      { Program Files x86 }

      Candidate :=
        Drives[j] +
        '\Program Files (x86)\PostgreSQL\' +
        Versions[i] +
        '\bin\';

      if FileExists(
           Candidate + 'psql.exe'
         ) then
      begin

        OutBinPath := Candidate;

        Result := True;

        Exit;
      end;


      { Custom PostgreSQL directory }

      Candidate :=
        Drives[j] +
        '\PostgreSQL\' +
        Versions[i] +
        '\bin\';

      if FileExists(
           Candidate + 'psql.exe'
         ) then
      begin

        OutBinPath := Candidate;

        Result := True;

        Exit;
      end;

    end;

  end;

end;


{ ====================================================================== }
{ POSTGRESQL INSTALLED?                                                  }
{ ====================================================================== }

function IsPostgresInstalled(): Boolean;
var
  FoundBin: String;
  FoundPort: String;
begin

  Result :=
    FindPostgresBinPath(
      FoundBin,
      FoundPort
    );

end;


{ ====================================================================== }
{ START ONLY SPECIFIC POSTGRESQL SERVICE                                  }
{ ====================================================================== }

function StartSpecificPostgresService(
  ServiceName: String): Boolean;
var
  ResultCode: Integer;
begin

  Result :=
    Exec(
      'sc.exe',
      'start "' + ServiceName + '"',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );

  Sleep(5000);

  Result :=
    Result and
    (ResultCode = 0);
end;


{ ====================================================================== }
{ ENSURE EXISTING SPECIFIC POSTGRES SERVICE RUNNING                       }
{ ====================================================================== }

procedure EnsureSpecificPostgresServiceRunning(
  ServiceName: String);
var
  ResultCode: Integer;
begin

  if ServiceExists(ServiceName) then
  begin

    Exec(
      'sc.exe',
      'start "' + ServiceName + '"',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );

    Sleep(5000);

  end;

end;


{ ====================================================================== }
{ TEST POSTGRES AUTHENTICATION                                            }
{ ====================================================================== }

function TestPostgresAuth(
  PgBin,
  PgPort,
  DbName,
  UserId,
  Password: String): Boolean;
var
  BatPath: String;
  BatContent: String;
  LogPath: String;
  ResultCode: Integer;
begin
  Result := False;

  if PgBin = '' then
    Exit;

  if PgPort = '' then
    Exit;

  if UserId = '' then
    Exit;

  BatPath := ExpandConstant('{tmp}\test_pg.bat');
  LogPath := ExpandConstant('{tmp}\test_pg.log');

  DeleteFile(BatPath);
  DeleteFile(LogPath);

  BatContent :=
    '@echo off' + CRLF +
    'set "PGPASSWORD=' + Password + '"' + CRLF;

  if DbName <> '' then
  begin
    BatContent := BatContent +
      '"' + PgBin + 'psql.exe" -h 127.0.0.1 -p ' +
      PgPort + ' -U ' + UserId + ' -d ' + DbName + ' -w -c "SELECT 1;" > "' +
      LogPath + '" 2>&1' + CRLF +
      'if not errorlevel 1 exit /b 0' + CRLF;
  end;

  BatContent := BatContent +
    '"' + PgBin + 'psql.exe" -h 127.0.0.1 -p ' +
    PgPort + ' -U ' + UserId + ' -d postgres -w -c "SELECT 1;" > "' +
    LogPath + '" 2>&1' + CRLF +
    'if not errorlevel 1 exit /b 0' + CRLF +
    '"' + PgBin + 'psql.exe" -h 127.0.0.1 -p ' +
    PgPort + ' -U ' + UserId + ' -d template1 -w -c "SELECT 1;" > "' +
    LogPath + '" 2>&1' + CRLF +
    'exit /b %ERRORLEVEL%';

  SaveStringToFile(
    BatPath,
    BatContent,
    False
  );

  ResultCode := -1;

  Exec(
    BatPath,
    '',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );

  DeleteFile(BatPath);
  DeleteFile(LogPath);

  Result := (ResultCode = 0);
end;


{ ====================================================================== }
{ READ SAVED FAMALTH PASSWORD                                            }
{ ====================================================================== }

function ResolveSavedMasterPassword(
  PgBin,
  PgPort: String;
  var MasterPassword: String): Boolean;

var
  TokenFile: String;
  FileString: AnsiString;
  EncodedPassword: String;

begin

  Result := False;
  MasterPassword := '';

  { ------------------------------------------------------------ }
  { Registry token                                               }
  { ------------------------------------------------------------ }

  if RegQueryStringValue(
       HKEY_LOCAL_MACHINE,
       'SOFTWARE\Famalth\Lynx\Backend',
       'DbToken',
       EncodedPassword
     ) or
     RegQueryStringValue(
       HKEY_LOCAL_MACHINE,
       'SOFTWARE\Famalth\Lynx\Backend',
       'PgMaster',
       EncodedPassword
     ) or
     RegQueryStringValue(
       HKEY_LOCAL_MACHINE,
       'SOFTWARE\Famalth\Lynx',
       'DbToken',
       EncodedPassword
     ) then
  begin

    MasterPassword :=
      UnscramblePassword(
        EncodedPassword
      );

    if TestPostgresAuth(
         PgBin,
         PgPort,
         FAMALTH_DB_NAME,
         'postgres',
         MasterPassword
       ) then
    begin
      Result := True;
      Exit;
    end;

  end;


  { ------------------------------------------------------------ }
  { security.dat                                                  }
  { ------------------------------------------------------------ }

  TokenFile :=
    ExpandConstant(
      '{commonappdata}\FamalthLynx\security.dat'
    );

  if LoadStringFromFile(
       TokenFile,
       FileString
     ) then
  begin

    MasterPassword :=
      UnscramblePassword(
        String(FileString)
      );

    if TestPostgresAuth(
         PgBin,
         PgPort,
         FAMALTH_DB_NAME,
         'postgres',
         MasterPassword
       ) then
    begin
      Result := True;
      Exit;
    end;

  end;

end;


{ ====================================================================== }
{ CREATE DEDICATED DATABASE CONFIGURATION                                }
{ ====================================================================== }

procedure SetupDedicatedDatabase(
  PgBin,
  PgPort,
  MasterPassword,
  DbName,
  AppUser,
  AppPassword: String);
var
  ResultCode: Integer;
  BatPath: String;
  BatContent: String;
  LogPath: String;
  DbExistsFile: String;
begin

  BatPath :=
    ExpandConstant('{tmp}\setup_famalth_db.bat');

  LogPath :=
    ExpandConstant('{app}\db_setup_log.txt');

  DbExistsFile :=
    ExpandConstant('{tmp}\famalth_db_exists.txt');

  DeleteFile(BatPath);
  DeleteFile(LogPath);
  DeleteFile(DbExistsFile);

  BatContent :=
    '@echo off' + CRLF +

    'set "PGPASSWORD=' +
    MasterPassword +
    '"' + CRLF +

    'cd /d "' +
    PgBin +
    '"' + CRLF +

    'echo ======================================== > "' +
    LogPath +
    '" 2>&1' + CRLF +

    'echo FAMALTH LYNX DATABASE SETUP >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'echo ======================================== >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'echo Waiting for Famalth Lynx PostgreSQL service on port ' + PgPort + ' to accept connections... >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'set ATTEMPT=0' + CRLF +
    ':wait_loop' + CRLF +
    'set /a ATTEMPT+=1' + CRLF +
    'psql.exe -h 127.0.0.1 -p ' + PgPort + ' -U postgres -d postgres -w -c "SELECT 1;" >nul 2>&1' + CRLF +
    'if not errorlevel 1 goto pg_ready' + CRLF +
    'if %ATTEMPT% GEQ 30 (' + CRLF +
    '  echo Diagnostic connection error detail: >> "' + LogPath + '" 2>&1' + CRLF +
    '  psql.exe -h 127.0.0.1 -p ' + PgPort + ' -U postgres -d postgres -w -c "SELECT 1;" >> "' + LogPath + '" 2>&1' + CRLF +
    '  goto pg_timeout' + CRLF +
    ')' + CRLF +
    'ping 127.0.0.1 -n 2 >nul' + CRLF +
    'goto wait_loop' + CRLF +

    ':pg_timeout' + CRLF +
    'echo ERROR: PostgreSQL service on port ' + PgPort + ' did not respond within 30 seconds. >> "' +
    LogPath +
    '" 2>&1' + CRLF +
    'exit /b 1' + CRLF +

    ':pg_ready' + CRLF +
    'echo PostgreSQL service is online and accepting connections! >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'echo 1. Creating or updating application user... >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'psql.exe -h 127.0.0.1 -p ' +
    PgPort +
    ' -U postgres -d postgres -w -c "DO $$ BEGIN ' +
    'IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = ''' +
    AppUser +
    ''') THEN ' +
    'CREATE ROLE ' +
    AppUser +
    ' WITH LOGIN PASSWORD ''' +
    AppPassword +
    '''; ' +
    'ELSE ' +
    'ALTER ROLE ' +
    AppUser +
    ' WITH LOGIN PASSWORD ''' +
    AppPassword +
    '''; ' +
    'END IF; ' +
    'END $$;" >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'if errorlevel 1 exit /b 1' + CRLF +

    'echo 2. Checking database existence... >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'psql.exe -h 127.0.0.1 -p ' +
    PgPort +
    ' -U postgres -d postgres -w -tAc "SELECT 1 FROM pg_database WHERE lower(datname)=lower(''' +
    DbName +
    ''');" > "' +
    DbExistsFile +
    '" 2>&1' + CRLF +

    'findstr /C:"1" "' +
    DbExistsFile +
    '" >nul 2>&1' + CRLF +

    'if errorlevel 1 (' + CRLF +

    '  echo 3. Creating database ' + DbName + '... >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    '  psql.exe -h 127.0.0.1 -p ' +
    PgPort +
    ' -U postgres -d postgres -w -c "CREATE DATABASE ' +
    DbName +
    ' OWNER ' +
    AppUser +
    ';" >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    '  if errorlevel 1 exit /b 1' + CRLF +

    ') else (' + CRLF +

    '  echo 3. Database ' + DbName + ' already exists. >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    ')' + CRLF +

    'echo 4. Granting database privileges... >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'psql.exe -h 127.0.0.1 -p ' +
    PgPort +
    ' -U postgres -d postgres -w -c "GRANT ALL PRIVILEGES ON DATABASE ' +
    DbName +
    ' TO ' +
    AppUser +
    ';" >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'if errorlevel 1 exit /b 1' + CRLF +

    'echo 5. Setting database owner... >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'psql.exe -h 127.0.0.1 -p ' +
    PgPort +
    ' -U postgres -d postgres -w -c "ALTER DATABASE ' +
    DbName +
    ' OWNER TO ' +
    AppUser +
    ';" >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'if errorlevel 1 exit /b 1' + CRLF +

    'echo 6. Configuring schema privileges... >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'psql.exe -h 127.0.0.1 -p ' +
    PgPort +
    ' -U postgres -d ' +
    DbName +
    ' -w -c "GRANT ALL ON SCHEMA public TO ' +
    AppUser +
    '; ALTER SCHEMA public OWNER TO ' +
    AppUser +
    '; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ' +
    AppUser +
    '; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ' +
    AppUser +
    '; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ' +
    AppUser +
    '; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ' +
    AppUser +
    ';" >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'if errorlevel 1 exit /b 1' + CRLF +

    'echo ======================================== >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'echo DATABASE SETUP COMPLETE >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'echo ======================================== >> "' +
    LogPath +
    '" 2>&1' + CRLF +

    'exit /b 0';

  SaveStringToFile(
    BatPath,
    BatContent,
    False
  );

  ResultCode := -1;

  Exec(
    BatPath,
    '',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );

  DeleteFile(BatPath);
  DeleteFile(DbExistsFile);

  if ResultCode <> 0 then
  begin
    MsgBox(
      'Famalth Lynx database configuration failed.' + CRLF +
      'Please check:' + CRLF +
      '1. PostgreSQL service is running.' + CRLF +
      '2. PostgreSQL authentication is valid.' + CRLF +
      '3. Check db_setup_log.txt inside the application folder.',
      mbError,
      MB_OK
    );
  end;

end;


{ ====================================================================== }
{ SETUP EXISTING DATABASE                                                }
{ ====================================================================== }

procedure SetupExistingDatabase(
  PgBin,
  PgPort,
  DbName,
  AppUser,
  AppPassword: String);
var
  ResultCode: Integer;
  BatPath: String;
  BatContent: String;
  LogPath: String;
  DbExistsFile: String;
begin

  BatPath :=
    ExpandConstant('{tmp}\setup_famalth_db.bat');

  LogPath :=
    ExpandConstant('{app}\db_setup_log.txt');

  DbExistsFile :=
    ExpandConstant('{tmp}\famalth_db_exists.txt');

  DeleteFile(BatPath);
  DeleteFile(LogPath);
  DeleteFile(DbExistsFile);

  BatContent :=
    '@echo off' + CRLF +
    'set "PGPASSWORD=' + AppPassword + '"' + CRLF +
    'cd /d "' + PgBin + '"' + CRLF +
    'echo ======================================== > "' + LogPath + '" 2>&1' + CRLF +
    'echo FAMALTH LYNX EXISTING DATABASE CONFIGURATION >> "' + LogPath + '" 2>&1' + CRLF +
    'echo ======================================== >> "' + LogPath + '" 2>&1' + CRLF +
    'echo User: ' + AppUser + ' Port: ' + PgPort + ' Database: ' + DbName + ' >> "' + LogPath + '" 2>&1' + CRLF +

    'echo 1. Checking if database exists... >> "' + LogPath + '" 2>&1' + CRLF +
    'psql.exe -h 127.0.0.1 -p ' + PgPort + ' -U ' + AppUser + ' -d postgres -w -tAc "SELECT 1 FROM pg_database WHERE lower(datname)=lower(''' + DbName + ''');" > "' + DbExistsFile + '" 2>&1' + CRLF +
    'findstr /C:"1" "' + DbExistsFile + '" >nul 2>&1' + CRLF +
    'if errorlevel 1 (' + CRLF +
    '  echo 2. Database ' + DbName + ' does not exist. Creating database... >> "' + LogPath + '" 2>&1' + CRLF +
    '  psql.exe -h 127.0.0.1 -p ' + PgPort + ' -U ' + AppUser + ' -d postgres -w -c "CREATE DATABASE ' + DbName + ' OWNER ' + AppUser + ';" >> "' + LogPath + '" 2>&1' + CRLF +
    ') else (' + CRLF +
    '  echo 2. Database ' + DbName + ' already exists. Using existing database. >> "' + LogPath + '" 2>&1' + CRLF +
    ')' + CRLF +
    'echo 3. Ensuring schema privileges... >> "' + LogPath + '" 2>&1' + CRLF +
    'psql.exe -h 127.0.0.1 -p ' + PgPort + ' -U ' + AppUser + ' -d ' + DbName + ' -w -c "GRANT ALL ON SCHEMA public TO ' + AppUser + ';" >> "' + LogPath + '" 2>&1' + CRLF +
    'echo ======================================== >> "' + LogPath + '" 2>&1' + CRLF +
    'echo DATABASE SETUP COMPLETE >> "' + LogPath + '" 2>&1' + CRLF +
    'echo ======================================== >> "' + LogPath + '" 2>&1' + CRLF +
    'exit /b 0';

  SaveStringToFile(
    BatPath,
    BatContent,
    False
  );

  ResultCode := -1;

  Exec(
    BatPath,
    '',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );

  DeleteFile(BatPath);
  DeleteFile(DbExistsFile);

end;


{ ====================================================================== }
{ ENSURE LOCALHOST TRUST IN PG_HBA.CONF                                  }
{ ====================================================================== }

procedure EnsurePgHbaTrust(DataDir: String);
var
  HbaPath: String;
  HbaContent: AnsiString;
  HbaStr: String;
begin
  HbaPath := AddBackslash(DataDir) + 'pg_hba.conf';
  if FileExists(HbaPath) then
  begin
    if LoadStringFromFile(HbaPath, HbaContent) then
    begin
      HbaStr := String(HbaContent);
      if Pos('host all all 127.0.0.1/32 trust', HbaStr) = 0 then
      begin
        HbaStr :=
          '# Famalth Lynx Localhost Trust' + CRLF +
          'host    all             all             127.0.0.1/32            trust' + CRLF +
          'host    all             all             ::1/128                 trust' + CRLF +
          CRLF + HbaStr;
        SaveStringToFile(HbaPath, HbaStr, False);
      end;
    end;
  end;
end;


{ ====================================================================== }
{ ENSURE POSTGRESQL PORT CONFIGURED IN POSTGRESQL.CONF                   }
{ ====================================================================== }

procedure EnsurePostgresPortConfig(DataDir, Port: String);
var
  ConfPath: String;
  ConfContent: AnsiString;
  ConfStr: String;
begin
  ConfPath := AddBackslash(DataDir) + 'postgresql.conf';
  if FileExists(ConfPath) then
  begin
    if LoadStringFromFile(ConfPath, ConfContent) then
    begin
      ConfStr := String(ConfContent);
      if Pos('port = ' + Port, ConfStr) = 0 then
      begin
        ConfStr := ConfStr + CRLF +
          '# Famalth Lynx Configuration' + CRLF +
          'port = ' + Port + CRLF +
          'listen_addresses = ''127.0.0.1''' + CRLF;
        SaveStringToFile(ConfPath, ConfStr, False);
      end;
    end;
  end;
end;


{ ====================================================================== }
{ STOP OWNED BACKEND PROCESS                                             }
{ ====================================================================== }

procedure StopOwnedBackend();
var
  ScriptPath, ScriptText: String;
  Code: Integer;
begin
  ScriptPath := ExpandConstant('{tmp}\famalth_stop_backend.ps1');
  ScriptText :=
    '$target = ''' + EscapePowerShell(ExpandConstant('{app}\server.exe')) + '''' + CRLF +
    'Get-CimInstance Win32_Process -Filter "Name=''server.exe''" -ErrorAction SilentlyContinue | ' +
    'Where-Object { $_.ExecutablePath -and $_.ExecutablePath -ieq $target } | ' +
    'ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }';

  SaveStringToFile(ScriptPath, ScriptText, False);

  Exec(
    ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
    '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '"',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    Code
  );

  DeleteFile(ScriptPath);
  Sleep(1000);
end;


{ ====================================================================== }
{ WRITE SERVER CONFIG (baseUrl)                                          }
{ ====================================================================== }

function WriteServerConfig(ApiPort: String): Boolean;
var
  ScriptPath, ScriptText, ConfigPath, BaseUrl: String;
  Code: Integer;
begin
  ScriptPath := ExpandConstant('{tmp}\famalth_update_server_config.ps1');
  ConfigPath := EscapePowerShell(ExpandConstant('{app}\server_config.json'));
  BaseUrl := 'http://127.0.0.1:' + ApiPort;

  ScriptText :=
    '$ErrorActionPreference = ''Stop''' + CRLF +
    '$p = ''' + ConfigPath + '''' + CRLF +
    'if (Test-Path -LiteralPath $p) { $c = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json } ' + CRLF +
    'else { $c = [pscustomobject]@{ outlets = @() } }' + CRLF +
    'if ($null -eq $c) { throw ''server_config.json is not valid JSON'' }' + CRLF +
    'if ($null -eq $c.outlets) { $c | Add-Member -MemberType NoteProperty -Name outlets -Value @() -Force }' + CRLF +
    '$cleanOutlets = @($c.outlets | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })' + CRLF +
    '$c | Add-Member -MemberType NoteProperty -Name outlets -Value $cleanOutlets -Force' + CRLF +
    '$c | Add-Member -MemberType NoteProperty -Name baseUrl -Value ''' + BaseUrl + ''' -Force' + CRLF +
    '$j = $c | ConvertTo-Json -Depth 100' + CRLF +
    '$enc = New-Object System.Text.UTF8Encoding -ArgumentList $false' + CRLF +
    '[IO.File]::WriteAllText($p, $j, $enc)';

  if not SaveStringToFile(ScriptPath, ScriptText, False) then
  begin
    Result := False;
    Exit;
  end;

  Result :=
    Exec(
      ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '"',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      Code
    ) and (Code = 0);

  DeleteFile(ScriptPath);
end;


{ ====================================================================== }
{ INSTALL DEDICATED POSTGRESQL                                           }
{ ====================================================================== }

function InstallPostgres(
  MasterPassword: String;
  var InstalledBin,
  InstalledPort: String): Boolean;

var
  ResultCode: Integer;
  FreePort: String;
  ExistingClusterPort: String;
  PgInstaller: String;
  InstallPrefix: String;
  DataDirectory: String;
  ServiceName: String;
  Parameters: String;
  DebugTrace: String;
  ExistingBin: String;
  ExistingPort: String;
  PwFile: String;
  PidLines: TArrayOfString;
  PidStr: String;

begin

  Result := False;

  { ------------------------------------------------------------ }
  { Unique Famalth Lynx PostgreSQL locations                     }
  { ------------------------------------------------------------ }

  InstallPrefix :=
    ExpandConstant(
      '{app}\PostgreSQL18'
    );

  DataDirectory :=
    ExpandConstant(
      '{commonappdata}\FamalthLynx\PostgreSQL18Data'
    );

  ServiceName :=
    FAMALTH_PG_SERVICE;

  { ------------------------------------------------------------ }
  { Port selection: On reinstall, keep existing configured port  }
  { ------------------------------------------------------------ }

  if FileExists(AddBackslash(DataDirectory) + 'PG_VERSION') then
  begin
    { Reinstall scenario: retain existing cluster port }
    if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PostgresPort', ExistingClusterPort) and (ExistingClusterPort <> '') then
      FreePort := ExistingClusterPort
    else
      FreePort := '5433';
  end
  else
  begin
    FreePort := FindFreePort();
    if FreePort = '' then
    begin
      MsgBox(
        'Unable to find an available PostgreSQL TCP port.',
        mbError,
        MB_OK
      );
      Exit;
    end;
  end;

  { ------------------------------------------------------------ }
  { Check if PostgreSQL binaries already exist on this system    }
  { If yes, initialize our separate cluster using initdb!        }
  { (Avoids EDB installer refusing to install parallel versions) }
  { ------------------------------------------------------------ }

  ExistingBin := AddBackslash(InstallPrefix) + 'bin\';

  if not FileExists(ExistingBin + 'initdb.exe') then
  begin
    ExistingBin := '';

    if FindPostgresBinPath(ExistingBin, ExistingPort) then
    begin
      ExistingBin := AddBackslash(ExistingBin);
    end;
  end;

  if (ExistingBin <> '') and FileExists(ExistingBin + 'initdb.exe') then
  begin
    WizardForm.StatusLabel.Caption :=
      'Initializing dedicated Famalth Lynx database cluster on port ' + FreePort + '...';
    WizardForm.Refresh;

    InstalledBin := AddBackslash(ExistingBin);
    InstalledPort := FreePort;

    OurPostgresPrefix := ExistingBin;
    OurPostgresDataDir := DataDirectory;
    OurPostgresServiceName := ServiceName;
    OurPostgresPort := FreePort;
    OurPostgresBin := InstalledBin;

    PwFile := ExpandConstant('{tmp}\famalth_init_pw.txt');
    SaveStringToFile(PwFile, MasterPassword, False);

    { Ensure data directory is empty before running initdb }
    if not FileExists(AddBackslash(DataDirectory) + 'PG_VERSION') then
    begin
      if DirExists(DataDirectory) then
      begin
        DelTree(DataDirectory, True, True, True);
      end;
      ForceDirectories(DataDirectory);

      Exec(
        InstalledBin + 'initdb.exe',
        '-D "' + DataDirectory + '" -U postgres -A scram-sha-256 --pwfile="' + PwFile + '" -E UTF8',
        '',
        SW_HIDE,
        ewWaitUntilTerminated,
        ResultCode
      );
      DeleteFile(PwFile);

      if ResultCode <> 0 then
      begin
        MsgBox(
          'Database cluster initialization failed (initdb exit code: ' + IntToStr(ResultCode) + ').',
          mbError,
          MB_OK
        );
        Exit;
      end;
    end
    else
    begin
      DeleteFile(PwFile);
    end;

    { Configure custom port and listen_addresses in postgresql.conf }
    EnsurePostgresPortConfig(DataDirectory, FreePort);

    { Ensure pg_hba.conf trusts localhost loopback for zero-friction service and migrations }
    EnsurePgHbaTrust(DataDirectory);

    { Stop existing service cleanly and unregister old service }
    if ServiceExists(ServiceName) then
    begin
      Exec('net.exe', 'stop "' + ServiceName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Exec(InstalledBin + 'pg_ctl.exe', 'stop -D "' + DataDirectory + '" -m fast', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(2000);
      Exec(InstalledBin + 'pg_ctl.exe', 'unregister -N "' + ServiceName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(1000);
    end;

    { Check for any stale lock file in DataDirectory and clean up }
    if FileExists(AddBackslash(DataDirectory) + 'postmaster.pid') then
    begin
      if LoadStringsFromFile(AddBackslash(DataDirectory) + 'postmaster.pid', PidLines) and (GetArrayLength(PidLines) > 0) then
      begin
        PidStr := Trim(PidLines[0]);
        if (PidStr <> '') and (StrToIntDef(PidStr, 0) > 0) then
        begin
          Exec('taskkill.exe', '/F /T /PID ' + PidStr, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
          Sleep(1000);
        end;
      end;
      DeleteFile(AddBackslash(DataDirectory) + 'postmaster.pid');
    end;

    Exec(
      InstalledBin + 'pg_ctl.exe',
      'register -N "' + ServiceName + '" -D "' + DataDirectory + '" -w -o "-p ' + FreePort + '"',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );

    { Start the dedicated service }
    Exec('net.exe', 'start "' + ServiceName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(3000);

    CreatedOurPostgres := True;

    RegWriteStringValue(
      HKEY_LOCAL_MACHINE,
      'SOFTWARE\Famalth\Lynx\Backend',
      'CreatedPostgres',
      '1'
    );

    RegWriteStringValue(
      HKEY_LOCAL_MACHINE,
      'SOFTWARE\Famalth\Lynx\Backend',
      'PostgresServiceName',
      ServiceName
    );

    RegWriteStringValue(
      HKEY_LOCAL_MACHINE,
      'SOFTWARE\Famalth\Lynx\Backend',
      'PostgresPrefix',
      InstallPrefix
    );

    RegWriteStringValue(
      HKEY_LOCAL_MACHINE,
      'SOFTWARE\Famalth\Lynx\Backend',
      'PostgresDataDir',
      DataDirectory
    );

    RegWriteStringValue(
      HKEY_LOCAL_MACHINE,
      'SOFTWARE\Famalth\Lynx\Backend',
      'PostgresPort',
      FreePort
    );

    RegWriteStringValue(
      HKEY_LOCAL_MACHINE,
      'SOFTWARE\Famalth\Lynx\Backend',
      'PgBin',
      InstalledBin
    );

    Result := True;
    Exit;
  end;

  { ------------------------------------------------------------ }
  { Fallback: Fresh full installer if no PG installed on machine }
  { ------------------------------------------------------------ }

  PgInstaller :=
    ExpandConstant(
      '{tmp}\postgresql-18.3-2-windows-x64.exe'
    );

  if not FileExists(PgInstaller) then
  begin

    MsgBox(
      'PostgreSQL installer was not found:' + CRLF +
      PgInstaller,
      mbError,
      MB_OK
    );

    Exit;

  end;

  { ------------------------------------------------------------ }
  { Create directories                                           }
  { ------------------------------------------------------------ }

  if FileExists(AddBackslash(DataDirectory) + 'PG_VERSION') then
  begin
    MsgBox(
      'The Famalth Lynx PostgreSQL data directory exists, but its PostgreSQL binaries were not found.' + CRLF + CRLF +
      'The existing database was preserved. Restore the PostgreSQL18 folder or contact support before retrying.',
      mbError,
      MB_OK
    );
    Exit;
  end;

  if not RemoveStaleFamalthPostgresService() then
  begin
    MsgBox(
      'The Famalth Lynx PostgreSQL service is still registered after cleanup was attempted.' + CRLF + CRLF +
      'No database files were removed. Restart Windows and run setup again.',
      mbError,
      MB_OK
    );
    Exit;
  end;

  if DirExists(DataDirectory) then
    DelTree(DataDirectory, True, True, True);

  if DirExists(InstallPrefix) then
    DelTree(InstallPrefix, True, True, True);

  ForceDirectories(
    InstallPrefix
  );

  ForceDirectories(
    DataDirectory
  );

  { ------------------------------------------------------------ }
  { PostgreSQL unattended installation                          }
  { ------------------------------------------------------------ }

  Parameters :=
    '--mode unattended ' +

    '--unattendedmodeui none ' +

    '--prefix "' +
    InstallPrefix +
    '" ' +

    '--datadir "' +
    DataDirectory +
    '" ' +

    '--serverport ' +
    FreePort +
    ' ' +

    '--servicename "' +
    ServiceName +
    '" ' +

    '--superaccount postgres ' +

    '--superpassword "' +
    MasterPassword +
    '" ' +

    '--enable-components server ' +

    '--disable-components pgAdmin,stackbuilder ' +

    '--install_runtimes 0';

  DebugTrace :=
    ExpandConstant(
      '{commonappdata}\FamalthLynx\PostgreSQLInstaller.log'
    );

  ForceDirectories(ExpandConstant('{commonappdata}\FamalthLynx'));
  DeleteFile(DebugTrace);

  Parameters :=
    Parameters +
    ' --debugtrace "' + DebugTrace + '" --debuglevel 4';

  WizardForm.StatusLabel.Caption :=
    'Installing dedicated Famalth Lynx PostgreSQL 18...';

  WizardForm.Refresh;

  ResultCode := -1;

  Exec(
    PgInstaller,
    Parameters,
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );

  if ResultCode <> 0 then
  begin

    MsgBox(
      'Famalth Lynx PostgreSQL installation failed.' +
      CRLF +
      'Installer exit code: ' +
      IntToStr(ResultCode) +
      CRLF + CRLF +
      'Diagnostic log: ' + DebugTrace,
      mbError,
      MB_OK
    );

    Exit;

  end;

  { ------------------------------------------------------------ }
  { Save our PostgreSQL details                                 }
  { ------------------------------------------------------------ }

  InstalledBin :=
    AddBackslash(
      InstallPrefix
    ) +
    'bin\';

  InstalledPort :=
    FreePort;

  OurPostgresPrefix :=
    InstallPrefix;

  OurPostgresDataDir :=
    DataDirectory;

  OurPostgresServiceName :=
    ServiceName;

  OurPostgresPort :=
    FreePort;

  OurPostgresBin :=
    InstalledBin;

  { ------------------------------------------------------------ }
  { Mark PostgreSQL as OUR installation                         }
  { ------------------------------------------------------------ }

  CreatedOurPostgres := True;

  RegWriteStringValue(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\Famalth\Lynx\Backend',
    'CreatedPostgres',
    '1'
  );

  RegWriteStringValue(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\Famalth\Lynx\Backend',
    'PostgresServiceName',
    ServiceName
  );

  RegWriteStringValue(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\Famalth\Lynx\Backend',
    'PostgresPrefix',
    InstallPrefix
  );

  RegWriteStringValue(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\Famalth\Lynx\Backend',
    'PostgresDataDir',
    DataDirectory
  );

  RegWriteStringValue(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\Famalth\Lynx\Backend',
    'PostgresPort',
    FreePort
  );

  RegWriteStringValue(
    HKEY_LOCAL_MACHINE,
    'SOFTWARE\Famalth\Lynx\Backend',
    'PgBin',
    InstalledBin
  );

  Result := True;

end;


{ ====================================================================== }
{ INSTALL SEPARATELY BUTTON CLICK                                         }
{ ====================================================================== }

procedure SeparateInstallBtnClick(Sender: TObject);
begin
  InstallSeparately := True;

  AutoDetectedMasterPassword := '';
  AutoDetectedPort := '';
  AutoDetectedBin := '';

  ConfiguredDbPort := '';
  ConfiguredDbName := '';
  ConfiguredDbUser := '';
  ConfiguredDbPassword := '';

  { Advance to next wizard page }
  WizardForm.NextButton.OnClick(WizardForm.NextButton);
end;


{ ====================================================================== }
{ INITIALIZE WIZARD                                                      }
{ ====================================================================== }

procedure InitializeWizard();
begin
  InstallSeparately := False;
  CreatedOurPostgres := False;

  AutoDetectedMasterPassword := '';
  AutoDetectedPort := '';
  AutoDetectedBin := '';

  ConfiguredDbPort := '';
  ConfiguredDbName := '';
  ConfiguredDbUser := '';
  ConfiguredDbPassword := '';

  OurPostgresServiceName := FAMALTH_PG_SERVICE;

  { ------------------------------------------------------------ }
  { PostgreSQL database configuration page                       }
  { ------------------------------------------------------------ }
  PgAuthPage :=
    CreateInputQueryPage(
      wpSelectDir,
      'PostgreSQL Database Connection',
      'An existing PostgreSQL server was detected on this computer.',
      'Enter your database credentials, or click "Install Separately" for a dedicated database:'
    );

  PgAuthPage.Add('PostgreSQL Port:', False);
  PgAuthPage.Add('Database Name:', False);
  PgAuthPage.Add('User ID / Username:', False);
  PgAuthPage.Add('Password:', True);

  PgAuthPage.Values[0] := '5432';
  PgAuthPage.Values[1] := FAMALTH_DB_NAME;
  PgAuthPage.Values[2] := 'postgres';
  PgAuthPage.Values[3] := '';

  { Adjust field positions to guarantee all 4 input boxes fit comfortably }
  PgAuthPage.PromptLabels[0].Top := ScaleY(26);
  PgAuthPage.Edits[0].Top := ScaleY(42);

  PgAuthPage.PromptLabels[1].Top := ScaleY(70);
  PgAuthPage.Edits[1].Top := ScaleY(86);

  PgAuthPage.PromptLabels[2].Top := ScaleY(114);
  PgAuthPage.Edits[2].Top := ScaleY(130);

  PgAuthPage.PromptLabels[3].Top := ScaleY(158);
  PgAuthPage.Edits[3].Top := ScaleY(174);

  { ------------------------------------------------------------ }
  { Install Separately button (placed at bottom-left)           }
  { ------------------------------------------------------------ }
  SeparateInstallBtn := TButton.Create(WizardForm);
  SeparateInstallBtn.Parent := WizardForm;
  SeparateInstallBtn.Caption := 'Install Separately';
  SeparateInstallBtn.Left := ScaleX(15);
  SeparateInstallBtn.Top := WizardForm.CancelButton.Top;
  SeparateInstallBtn.Width := ScaleX(140);
  SeparateInstallBtn.Height := WizardForm.CancelButton.Height;
  SeparateInstallBtn.OnClick := @SeparateInstallBtnClick;
  SeparateInstallBtn.Visible := False;
end;


{ ====================================================================== }
{ SHOULD SKIP PAGE                                                        }
{ ====================================================================== }

function ShouldSkipPage(PageID: Integer): Boolean;
var
  ExistingBin: String;
  ExistingPort: String;
  SavedPassword: String;
begin
  Result := False;

  { ------------------------------------------------------------ }
  { Install Separately button visibility                         }
  { ------------------------------------------------------------ }
  if SeparateInstallBtn <> nil then
  begin
    SeparateInstallBtn.Visible :=
      (PgAuthPage <> nil) and
      (PageID = PgAuthPage.ID) and
      (not InstallSeparately);
  end;

  { ------------------------------------------------------------ }
  { PostgreSQL authentication page                               }
  { ------------------------------------------------------------ }
  if (PgAuthPage <> nil) and (PageID = PgAuthPage.ID) then
  begin
    { User selected separate installation }
    if InstallSeparately then
    begin
      Result := True;
      Exit;
    end;

    { Detect existing PostgreSQL }
    if not FindPostgresBinPath(ExistingBin, ExistingPort) then
    begin
      { No PostgreSQL exists. Skip page. Isolated install will run. }
      Result := True;
      Exit;
    end;

    AutoDetectedBin := ExistingBin;
    AutoDetectedPort := ExistingPort;

    { Check if we already have valid saved Famalth credentials }
    SavedPassword := '';
    if ResolveSavedMasterPassword(ExistingBin, ExistingPort, SavedPassword) then
    begin
      AutoDetectedMasterPassword := SavedPassword;
      ConfiguredDbPort := ExistingPort;
      ConfiguredDbName := FAMALTH_DB_NAME;
      ConfiguredDbUser := 'postgres';
      ConfiguredDbPassword := SavedPassword;
      Result := True;
      Exit;
    end;

    { Existing third-party PostgreSQL detected without saved Famalth credentials.
      To ensure 100% zero-configuration ("Next-Next-Next") installation for non-technical clients,
      automatically proceed with dedicated isolated PostgreSQL on a free port (e.g. 5433).
      Client is never prompted for passwords. }
    InstallSeparately := True;
    Result := True;
    Exit;
  end;
end;


{ ====================================================================== }
{ CURRENT PAGE CHANGED                                                    }
{ ====================================================================== }

procedure CurPageChanged(CurPageID: Integer);
begin
  if SeparateInstallBtn <> nil then
  begin
    SeparateInstallBtn.Visible :=
      (PgAuthPage <> nil) and
      (CurPageID = PgAuthPage.ID) and
      (not InstallSeparately);
  end;
end;


{ ====================================================================== }
{ NEXT BUTTON CLICK                                                       }
{ ====================================================================== }

function NextButtonClick(CurPageID: Integer): Boolean;
var
  UserPort: String;
  UserDb: String;
  UserRole: String;
  UserPass: String;
begin
  Result := True;

  if (PgAuthPage <> nil) and (CurPageID = PgAuthPage.ID) then
  begin
    { Separate installation selected }
    if InstallSeparately then
    begin
      Result := True;
      Exit;
    end;

    UserPort := Trim(PgAuthPage.Values[0]);
    UserDb   := Trim(PgAuthPage.Values[1]);
    UserRole := Trim(PgAuthPage.Values[2]);
    UserPass := PgAuthPage.Values[3];

    if UserPort = '' then
      UserPort := '5432';

    if UserDb = '' then
      UserDb := FAMALTH_DB_NAME;

    if UserRole = '' then
      UserRole := 'postgres';

    if UserPass = '' then
    begin
      MsgBox(
        'Please enter the password for user "' + UserRole + '".' + CRLF + CRLF +
        'If you do not know the database password, click "Install Separately" to install an isolated database engine.',
        mbError,
        MB_OK
      );
      Result := False;
      Exit;
    end;

    { Verify authentication against the database engine }
    if TestPostgresAuth(AutoDetectedBin, UserPort, UserDb, UserRole, UserPass) then
    begin
      ConfiguredDbPort := UserPort;
      ConfiguredDbName := UserDb;
      ConfiguredDbUser := UserRole;
      ConfiguredDbPassword := UserPass;

      AutoDetectedPort := UserPort;
      AutoDetectedMasterPassword := UserPass;

      Result := True;
    end
    else
    begin
      MsgBox(
        'Database authentication failed for user "' + UserRole + '" on port ' + UserPort + '.' + CRLF + CRLF +
        'Please verify:' + CRLF +
        '1. PostgreSQL Port (e.g. ' + UserPort + ').' + CRLF +
        '2. Database Name (e.g. ' + UserDb + ').' + CRLF +
        '3. User ID / Username (e.g. ' + UserRole + ').' + CRLF +
        '4. Password.' + CRLF + CRLF +
        'Or click "Install Separately" to create a completely isolated database installation.',
        mbError,
        MB_OK
      );

      Result := False;
    end;
  end;
end;


{ ====================================================================== }
{ BEFORE INSTALL                                                         }
{ ====================================================================== }

function PrepareToInstall(
  var NeedsRestart: Boolean): String;
begin
  { Stop only backend process running from this exact application directory }
  StopOwnedBackend();

  NeedsRestart := False;
  Result := '';
end;


{ ====================================================================== }
{ INSTALL STEP                                                           }
{ ====================================================================== }

procedure CurStepChanged(
  CurStep: TSetupStep);

var
  ResultCode: Integer;

  DbHost: String;
  DbPort: String;
  DbName: String;

  MasterPassword: String;

  AppUser: String;
  AppPassword: String;

  TokenFile: String;

  PgBin: String;

  ExistingBin: String;
  ExistingPort: String;

  InstallOK: Boolean;

  ApiPort: String;
  ExistingApiPort: String;

begin

  { ==================================================================== }
  { ssInstall                                                            }
  { ==================================================================== }

  if CurStep = ssInstall then
  begin

    { -------------------------------------------------------------- }
    { Create application directory early                             }
    { -------------------------------------------------------------- }

    ForceDirectories(
      ExpandConstant('{app}')
    );

    { -------------------------------------------------------------- }
    { Add Defender exclusion ONLY for Famalth application directory  }
    { -------------------------------------------------------------- }

    WizardForm.StatusLabel.Caption :=
      'Configuring Famalth Lynx Security Exclusion...';

    WizardForm.Refresh;

    Exec(
      'powershell.exe',

      '-ExecutionPolicy Bypass ' +
      '-WindowStyle Hidden ' +
      '-Command "try { ' +
      'Add-MpPreference -ExclusionPath ''' +
      ExpandConstant('{app}') +
      ''' -ErrorAction Stop ' +
      '} catch {}"',

      '',

      SW_HIDE,

      ewWaitUntilTerminated,

      ResultCode
    );

  end;


  { ==================================================================== }
  { ssPostInstall                                                        }
  { ==================================================================== }

  if CurStep = ssPostInstall then
  begin

    DbHost :=
      '127.0.0.1';

    DbName :=
      FAMALTH_DB_NAME;

    AppUser :=
      FAMALTH_DB_USER;

    TokenFile :=
      ExpandConstant(
        '{commonappdata}\FamalthLynx\security.dat'
      );

    PgBin := '';
    DbPort := '';
    MasterPassword := '';

    InstallOK := False;


    { ================================================================ }
    { SCENARIO 1: Dedicated Isolated PostgreSQL                        }
    { ================================================================ }
    if InstallSeparately then
    begin
      MasterPassword := GenerateSecurePassword();
      DbName := FAMALTH_DB_NAME;
      AppUser := FAMALTH_DB_USER;
      AppPassword := GenerateSecurePassword();

      WizardForm.StatusLabel.Caption := 'Installing dedicated Famalth Lynx PostgreSQL 18...';
      WizardForm.Refresh;

      InstallOK := InstallPostgres(MasterPassword, PgBin, DbPort);
      if not InstallOK then
      begin
        MsgBox(
          'Famalth Lynx PostgreSQL installation could not be completed.' + CRLF +
          'The existing PostgreSQL installation has not been modified.',
          mbError,
          MB_OK
        );
        Exit;
      end;

      WizardForm.StatusLabel.Caption := 'Starting Famalth Lynx PostgreSQL service...';
      WizardForm.Refresh;
      EnsureSpecificPostgresServiceRunning(FAMALTH_PG_SERVICE);

      WizardForm.StatusLabel.Caption := 'Configuring Famalth Lynx database environment...';
      WizardForm.Refresh;
      SetupDedicatedDatabase(PgBin, DbPort, MasterPassword, DbName, AppUser, AppPassword);

      WizardForm.StatusLabel.Caption := 'Applying application configuration and security...';
      WizardForm.Refresh;
      CreateConfigFile(DbHost, DbPort, DbName, AppUser, AppPassword);

      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'DbToken', ScramblePassword(MasterPassword));
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgMaster', ScramblePassword(MasterPassword));
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'AppPassword', ScramblePassword(AppPassword));
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgPort', DbPort);
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgBin', PgBin);
      ForceDirectories(ExpandConstant('{commonappdata}\FamalthLynx'));
      SaveStringToFile(TokenFile, ScramblePassword(MasterPassword), False);
    end

    { ================================================================ }
    { SCENARIO 2: Existing PostgreSQL with verified credentials        }
    { ================================================================ }
    else if (ConfiguredDbUser <> '') and (ConfiguredDbPassword <> '') then
    begin
      WizardForm.StatusLabel.Caption := 'Configuring connection to existing PostgreSQL database...';
      WizardForm.Refresh;

      PgBin := AutoDetectedBin;
      DbPort := ConfiguredDbPort;
      DbName := ConfiguredDbName;
      AppUser := ConfiguredDbUser;
      AppPassword := ConfiguredDbPassword;

      if DbPort = '' then DbPort := '5432';

      SetupExistingDatabase(PgBin, DbPort, DbName, AppUser, AppPassword);

      WizardForm.StatusLabel.Caption := 'Applying application configuration and security...';
      WizardForm.Refresh;
      CreateConfigFile(DbHost, DbPort, DbName, AppUser, AppPassword);

      if AppUser = 'postgres' then
      begin
        RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'DbToken', ScramblePassword(AppPassword));
        RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgMaster', ScramblePassword(AppPassword));
        RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgPort', DbPort);
        RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgBin', PgBin);
        ForceDirectories(ExpandConstant('{commonappdata}\FamalthLynx'));
        SaveStringToFile(TokenFile, ScramblePassword(AppPassword), False);
      end;
    end

    { ================================================================ }
    { SCENARIO 3: No PostgreSQL exists at all                          }
    { ================================================================ }
    else
    begin
      MasterPassword := GenerateSecurePassword();
      DbName := FAMALTH_DB_NAME;
      AppUser := FAMALTH_DB_USER;
      AppPassword := GenerateSecurePassword();

      WizardForm.StatusLabel.Caption := 'Installing Famalth Lynx PostgreSQL 18...';
      WizardForm.Refresh;

      InstallOK := InstallPostgres(MasterPassword, PgBin, DbPort);
      if not InstallOK then
      begin
        Exit;
      end;

      WizardForm.StatusLabel.Caption := 'Starting Famalth Lynx PostgreSQL service...';
      WizardForm.Refresh;
      EnsureSpecificPostgresServiceRunning(FAMALTH_PG_SERVICE);

      WizardForm.StatusLabel.Caption := 'Configuring Famalth Lynx database environment...';
      WizardForm.Refresh;
      SetupDedicatedDatabase(PgBin, DbPort, MasterPassword, DbName, AppUser, AppPassword);

      WizardForm.StatusLabel.Caption := 'Applying application configuration and security...';
      WizardForm.Refresh;
      CreateConfigFile(DbHost, DbPort, DbName, AppUser, AppPassword);

      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'DbToken', ScramblePassword(MasterPassword));
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgMaster', ScramblePassword(MasterPassword));
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'AppPassword', ScramblePassword(AppPassword));
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgPort', DbPort);
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'PgBin', PgBin);
      ForceDirectories(ExpandConstant('{commonappdata}\FamalthLynx'));
      SaveStringToFile(TokenFile, ScramblePassword(MasterPassword), False);
    end;


    { ================================================================== }
    { Encrypt configuration                                                }
    { ================================================================== }

    if FileExists(
         ExpandConstant(
           '{app}\encrypt.exe'
         )
       ) then
    begin

      Exec(
        ExpandConstant(
          '{app}\encrypt.exe'
        ),

        '',

        ExpandConstant(
          '{app}'
        ),

        SW_HIDE,

        ewWaitUntilTerminated,

        ResultCode
      );

    end
    else
    begin

      MsgBox(
        'encrypt.exe was not found.' + CRLF +
        'The application configuration could not be encrypted.',
        mbError,
        MB_OK
      );

    end;


    { ================================================================== }
    { Delete plaintext configuration                                     }
    { ================================================================== }

    DeleteFile(
      ExpandConstant(
        '{app}\config.json'
      )
    );


    { ================================================================== }
    { Save PostgreSQL Tools Path for Backend Operations / Backups        }
    { ================================================================== }

    if PgBin <> '' then
    begin
      SaveStringToFile(
        ExpandConstant('{app}\pg_bin.txt'),
        PgBin,
        False
      );

      RegWriteStringValue(
        HKEY_LOCAL_MACHINE,
        'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
        'FAMALTH_PG_BIN',
        PgBin
      );
    end;


    { ================================================================== }
    { Configure API Port & Firewall for Famalth Lynx Backend             }
    { ================================================================== }

    StopOwnedBackend();

    ApiPort := '';
    if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Famalth\Lynx\Backend', 'ApiPort', ExistingApiPort) and
       (not IsTcpPortInUse(ExistingApiPort)) then
    begin
      ApiPort := ExistingApiPort;
    end;

    if ApiPort = '' then
      ApiPort := FindFreeApiPort();

    if ApiPort = '' then
      ApiPort := '3000';

    SaveStringToFile(
      ExpandConstant('{app}\server_port.txt'),
      ApiPort,
      False
    );

    WriteServerConfig(ApiPort);

    RegWriteStringValue(
      HKEY_LOCAL_MACHINE,
      'SOFTWARE\Famalth\Lynx\Backend',
      'ApiPort',
      ApiPort
    );

    Exec(
      'netsh.exe',
      'advfirewall firewall delete rule name="Famalth Lynx Backend API"',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );

    Exec(
      'netsh.exe',
      'advfirewall firewall add rule name="Famalth Lynx Backend API" dir=in action=allow protocol=TCP localport=' + ApiPort,
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );


    { ================================================================== }
    { Install Famalth Lynx User Interface application                    }
    { ================================================================== }

    WizardForm.StatusLabel.Caption :=
      'Installing Famalth Lynx User Interface...';

    WizardForm.Refresh;

    if FileExists(
         ExpandConstant(
           '{app}\Famalth_Lynx_Installer.exe'
         )
       ) then
    begin

      Exec(
        ExpandConstant(
          '{app}\Famalth_Lynx_Installer.exe'
        ),

        '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR="' + ExpandConstant('{app}') + '"',

        '',

        SW_HIDE,

        ewWaitUntilTerminated,

        ResultCode
      );

      { Re-apply server_config.json after UI installer completes }
      WriteServerConfig(ApiPort);

    end
    else
    begin

      MsgBox(
        'Famalth_Lynx_Installer.exe was not found in application directory.',
        mbError,
        MB_OK
      );

    end;


    { ================================================================== }
    { Start Famalth Lynx Backend Server                                  }
    { ================================================================== }

    WizardForm.StatusLabel.Caption :=
      'Starting Famalth Lynx Backend Server...';

    WizardForm.Refresh;

    if FileExists(
         ExpandConstant(
           '{app}\run_hidden.vbs'
         )
       ) then
    begin

      Exec(
        'wscript.exe',

        '"' + ExpandConstant('{app}\run_hidden.vbs') + '"',

        ExpandConstant(
          '{app}'
        ),

        SW_HIDE,

        ewNoWait,

        ResultCode
      );

    end;


    { ================================================================== }
    { Final status                                                       }
    { ================================================================== }

    WizardForm.StatusLabel.Caption :=
      'Famalth Lynx Backend installation completed.';

    WizardForm.Refresh;

  end;

end;
