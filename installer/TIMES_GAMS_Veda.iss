; Product name. Also used for the AppId, the default install folder, the Start menu group
; and the installer file name, so it must be valid in file names.
; Never change it after the first release, or upgrades will install side by side.
#define MyAppName="TIMES_GAMS_Veda"
; Product name shown in the wizard texts, the window title and Apps & features.
; Not valid in file names, so MyAppName is used for those.
#define MyAppDisplayName="TIMES/GAMS/Veda"
; The product version is the TIMES version that comes with Veda,
; passed by the pipeline (ISCC /DMyAppVersion=4.9.7)
#ifndef MyAppVersion
  #error MyAppVersion is not defined. Pass it to the compiler with /DMyAppVersion=<TIMES version>.
#endif
; GAMS system that comes with GAMSPy in the bundled Python (build\python from the pipeline)
#define GamsSysDir="{app}\python\Lib\site-packages\gamspy_base"
; Environment variable that points to GamsSysDir and is added to PATH (TIMES_GAMS_VEDA_GAMSDIR).
; Not GAMSDIR, which belongs to regular GAMS installations.
#define GamsDirVar=Uppercase(MyAppName) + "_GAMSDIR"
; Veda version, passed by the pipeline from versions.txt (ISCC /DVedaVersion=5.0.0.0)
#ifndef VedaVersion
  #error VedaVersion is not defined. Pass it to the compiler with /DVedaVersion=<version>.
#endif
#define VedaDir="{app}\Veda\Veda2.0_localhost_" + VedaVersion

[Setup]
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
AppName={#MyAppDisplayName}
AppVerName={#MyAppDisplayName} {#MyAppVersion}
; TODO: Add AppPublisher. It is shown in the Publisher column of Apps & features and is also
; used for VersionInfoCompany in the setup file's properties.
ChangesEnvironment=yes
DefaultDirName=C:\{#MyAppName}
DefaultGroupName={#MyAppName}
; Installs for the current user only, without admin rights. [Registry] and UpdatePath write GamsDirVar
; and PATH to the user environment (HKCU), and shortcuts and the uninstall entry are per user.
PrivilegesRequired=lowest
OutputBaseFilename={#MyAppName}-setup

; Warn if the chosen folder already exists, except for the folder of a previous installation
DirExistsWarning=auto

SolidCompression=true
Compression=lzma/ultra
AppId={#MyAppName}
AppVersion={#MyAppVersion}
; Together with DisableDirPage=auto: an upgrade always goes into the folder of the previous
; installation (found via AppId), so two versions cannot be installed side by side
UsePreviousAppDir=yes
InternalCompressLevel=ultra
VersionInfoTextVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
VersionInfoDescription={#MyAppDisplayName} installer
OutputDir=.
SetupIconFile=assets\setup.ico

WizardImageFile = assets\wizard.bmp
WizardSmallImageFile = assets\wizard_small.bmp
WizardSizePercent = 130

DisableWelcomePage=no
; Skip the folder selection if a previous installation was found (see UsePreviousAppDir)
DisableDirPage=auto
DisableProgramGroupPage=yes

[Files]
Source: ..\build\python\*; DestDir: {app}\python; Flags: ignoreversion recursesubdirs createallsubdirs
; createallsubdirs also creates the empty folders from the Veda zip. Without them, PostgreSQL
; fails to start and Veda cannot connect to it.
Source: ..\build\Veda\*; DestDir: {app}\Veda; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: {group}\Uninstall {#MyAppName}; Filename: {uninstallexe}
; {autodesktop} is the desktop of the current user in non-admin mode
Name: {autodesktop}\Veda2.0; Filename: {#VedaDir}\Veda2.0.exe

[Run]
Filename: {#VedaDir}\Veda2.0.exe; Description: Launch Veda2.0; Flags: nowait postinstall

[Registry]
; User environment variable that points to the GAMS system. The uninstaller deletes it.
; Its PATH entry is added by UpdatePath and removed by RemovePath in [Code].
Root: HKCU; Subkey: Environment; ValueType: string; ValueName: {#GamsDirVar}; ValueData: {#GamsSysDir}; Flags: uninsdeletevalue

[Code]

{global variables}
var
   CertificateFile: String;
   LicenseStr: AnsiString;
   L_Intro: TNewStaticText;
   L_PortalHint: TNewStaticText;
   L_PortalLink: TNewStaticText;
   wpGamsLicense: Integer;
   ST_License: TNewStaticText;
   TE_AccessCode: TEdit;
   TE_Server: TEdit;
   TE_Certificate: TEdit;
   TB_GetLicense: TButton;
   TB_Certificate: TButton;
   ST_AccessCode: TNewStaticText;
   ST_Server: TNewStaticText;
   ST_Certificate: TNewStaticText;
   ALPSuccess, IsOnPrem: Boolean;


procedure OpenPortal(Sender: TObject);
var
  ErrorCode: Integer;
begin
  ShellExecAsOriginalUser('open', 'https://portal.gams.com', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
end;

procedure BrowseCertificateFile(Sender: TObject);
var
  Success: Boolean;
begin
  Success := GetSaveFileName('Choose certificate file', CertificateFile, ExpandConstant('{userdesktop}'),
                            'certificate |*.crt', '*.crt');
  if Success then TE_Certificate.Text := CertificateFile;
end;

{Write the fetched license. Replaces the demo license that ships with gamspy_base.}
procedure WriteLicenseFile();
begin
  if not SaveStringToFile(ExpandConstant('{#GamsSysDir}\gamslice.txt'), LicenseStr, False) then MsgBox('Could not write license to file', mbInformation, MB_OK);
end;

procedure CheckOnPremServer();
var
  URL: String;
begin
  URL := LowerCase(Trim(TE_Server.Text));
  TB_GetLicense.Enabled := ((Pos('http://', URL) = 1) or (Pos('https://', URL) = 1));
end;

procedure OnTEServerChange(Sender: TObject);
begin
  CheckOnPremServer();
end;

procedure CheckOnPrem(Sender: TObject);
var
  Prefix: String;
begin
  Prefix := 'abcdef12-';
  IsOnPrem := Copy(TEdit(Sender).Text, 1, Length(Prefix)) = Prefix;
  if (IsOnPrem) then
  begin
    ST_Server.Show();
    ST_Certificate.Show();
    TE_Server.Show();
    TE_Certificate.Show();
    TB_Certificate.Show();
    CheckOnPremServer();
    ST_License.Top := ST_Certificate.Top + ST_Certificate.Height + ScaleY(6);
  end
  else
  begin
    ST_Server.Hide();
    ST_Certificate.Hide();
    TE_Server.Hide();
    TE_Certificate.Hide();
    TB_Certificate.Hide();
    TB_GetLicense.Enabled := True;
    ST_License.Top := TE_AccessCode.Top + TE_AccessCode.Height + ScaleY(10);
  end;
end;

{Add %{#GamsDirVar}% to the user PATH variable. The variable itself is written by [Registry].}
procedure UpdatePath();
var
    Hive: Integer;
    SubKey, PathStr: String;
begin
   Hive := HKCU
   SubKey := 'Environment'
   // A new Path is created as REG_EXPAND_SZ, so %{#GamsDirVar}% is expanded. An existing Path keeps
   // its type, since that is the user's setting (RegWriteStringValue keeps REG_EXPAND_SZ).
   if not RegQueryStringValue(Hive, SubKey, 'Path', PathStr) then RegWriteExpandStringValue(Hive, SubKey, 'Path', '%{#GamsDirVar}%;')
   else if Pos('%{#GamsDirVar}%', PathStr) = 0 then RegWriteStringValue(Hive, SubKey, 'Path', '%{#GamsDirVar}%;' + PathStr);
end;

{Undo UpdatePath, but only if {#GamsDirVar} still points to this installation.
 Called before the uninstaller deletes {#GamsDirVar} ([Registry]), so the variable can still be checked.}
procedure RemovePath();
var
    Hive: Integer;
    SubKey, GamsDir, PathStr: String;
begin
   Hive := HKCU
   SubKey := 'Environment'
   if RegQueryStringValue(Hive, SubKey, '{#GamsDirVar}', GamsDir) and (GamsDir = ExpandConstant('{#GamsSysDir}')) then
   begin
      if RegQueryStringValue(Hive, SubKey, 'Path', PathStr) and (StringChangeEx(PathStr, '%{#GamsDirVar}%;', '', True) > 0) then
         RegWriteStringValue(Hive, SubKey, 'Path', PathStr);
   end;
end;

procedure GetALPLicense(Sender: TObject);
var
  ErrorLevel: Integer;
  ALPLogFile: String;
  ALPLogString: AnsiString;
  ALPLicenseFile: String;
  ArgString: String;
begin
  WizardForm.NextButton.Enabled := False;
  LicenseStr := '';
  ALPSuccess := False;
  ALPLicenseFile := ExpandConstant('{app}\_alp_license_tmp.txt');
  ALPLogFile := ExpandConstant('{app}\_gams_get_key_log.txt');
  ArgString := ExpandConstant('/C ""{#GamsSysDir}\gamsgetkey.exe" ') + TE_AccessCode.Text + ' -o "' + ALPLicenseFile + '"';
  if (IsOnPrem) then
  begin
    ArgString := ArgString + ' -s ' + Trim(TE_Server.Text);
    if Trim(TE_Certificate.Text) <> '' then ArgString := ArgString + ' -g "' + Trim(TE_Certificate.Text) + '"';
  end;
  ArgString := ArgString + ' > "' + ALPLogFile + '" 2>&1"';
  if Exec(ExpandConstant('{cmd}'), ArgString, ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, ErrorLevel) then
  begin
    if ErrorLevel = 0 then
    begin
      if LoadStringFromFile(ALPLicenseFile, LicenseStr) then
      begin
        ST_License.Caption := LicenseStr;
        DeleteFile(ALPLicenseFile);
        ALPSuccess := True;
      end;
    end
    else
    begin
      LoadStringFromFile(ALPLogFile, ALPLogString);
      ST_License.Caption := ALPLogString;
    end;
  end
  else
  begin
    ST_License.Caption := 'Error(' + IntToStr(ErrorLevel) + ')';
  end;
  DeleteFile(ALPLogFile);
  WizardForm.NextButton.Enabled := True;
end;

{Create License Page}
function CreateLicensePage(): Integer;
var
  Page: TWizardPage;
  RowTop: Integer;
begin
  Page := CreateCustomPage(wpInstalling, 'GAMS License', 'Retrieve a license using your Access Code');

  L_Intro := TNewStaticText.Create(Page);
  L_Intro.Caption := 'Please enter your Access Code to retrieve a GAMS license.';
  L_Intro.AutoSize := True;
  L_Intro.Top := ScaleY(0);
  L_Intro.Parent := Page.Surface;

  L_PortalHint := TNewStaticText.Create(Page);
  L_PortalHint.Caption := 'If you do not have an Access Code yet, register and create one at';
  L_PortalHint.AutoSize := True;
  L_PortalHint.Top := L_Intro.Top + L_Intro.Height + ScaleY(6);
  L_PortalHint.Parent := Page.Surface;

  L_PortalLink := TNewStaticText.Create(Page);
  L_PortalLink.Caption := 'portal.gams.com';
  L_PortalLink.AutoSize := True;
  L_PortalLink.Top := L_PortalHint.Top;
  L_PortalLink.Left := L_PortalHint.Left + L_PortalHint.Width + ScaleX(3);
  L_PortalLink.Font.Color := clBlue;
  L_PortalLink.Font.Style := [fsUnderline];
  L_PortalLink.Cursor := crHand;
  L_PortalLink.OnClick := @OpenPortal;
  L_PortalLink.Parent := Page.Surface;

  // Row with the Access Code
  RowTop := L_PortalHint.Top + L_PortalHint.Height + ScaleY(15);

  ST_AccessCode := TNewStaticText.Create(Page);
  ST_AccessCode.Caption := 'Access Code:';
  ST_AccessCode.Top := RowTop + ScaleY(3);
  ST_AccessCode.Parent := Page.Surface;

  TE_AccessCode := TEdit.Create(Page);
  TE_AccessCode.Font.Name := 'Courier New';
  TE_AccessCode.Width := ScaleX(300);
  TE_AccessCode.Top := RowTop;
  TE_AccessCode.Left := ST_AccessCode.Left + ST_AccessCode.Width + ScaleX(5);
  TE_AccessCode.Parent := Page.Surface;
  TE_AccessCode.OnChange := @CheckOnPrem;

  TE_Server := TEdit.Create(Page);
  TE_Server.Font.Name := 'Courier New';
  TE_Server.Width := ScaleX(300);
  TE_Server.Top := TE_AccessCode.Top + TE_AccessCode.Height;
  TE_Server.Left := TE_AccessCode.Left;
  TE_Server.Parent := Page.Surface;
  TE_Server.OnChange := @OnTEServerChange;
  TE_Server.Hide();

  ST_Server := TNewStaticText.Create(Page);
  ST_Server.Caption := 'Server URL:';
  ST_Server.Top := TE_Server.Top + ScaleY(3);
  ST_Server.Parent := Page.Surface;
  ST_Server.Hide();

  TB_GetLicense := TButton.Create(Page);
  TB_GetLicense.Caption := 'Get License';
  TB_GetLicense.Width := ScaleX(100);
  TB_GetLicense.Height := TE_AccessCode.Height + ScaleY(2);
  TB_GetLicense.Top := RowTop - ScaleY(1);
  TB_GetLicense.Left := TE_AccessCode.Left + TE_AccessCode.Width + ScaleX(5);
  TB_GetLicense.Parent := Page.Surface;
  TB_GetLicense.OnClick := @GetALPLicense;

  TE_Certificate := TEdit.Create(Page);
  TE_Certificate.Font.Name := 'Courier New';
  TE_Certificate.Width := ScaleX(300);
  TE_Certificate.Top := TE_Server.Top + TE_Server.Height;
  TE_Certificate.Left := TE_Server.Left;
  TE_Certificate.Parent := Page.Surface;
  TE_Certificate.Hide();

  TB_Certificate := TButton.Create(Page);
  TB_Certificate.Caption := 'Browse...';
  TB_Certificate.Width := ScaleX(100);
  TB_Certificate.Height := TE_Certificate.Height + ScaleY(2);
  TB_Certificate.Top := TE_Certificate.Top - ScaleY(1);
  TB_Certificate.Left := TB_GetLicense.Left;
  TB_Certificate.Parent := Page.Surface;
  TB_Certificate.Hide();
  TB_Certificate.OnClick := @BrowseCertificateFile;

  ST_Certificate := TNewStaticText.Create(Page);
  ST_Certificate.Caption := 'Certificate:';
  ST_Certificate.Top := TE_Certificate.Top + ScaleY(3);
  ST_Certificate.Parent := Page.Surface;
  ST_Certificate.Hide();

  ST_License := TNewStaticText.Create(Page);
  ST_License.Font.Name := 'Courier New';
  ST_License.Font.Height := ScaleY(13);
  ST_License.Top := TE_AccessCode.Top + TE_AccessCode.Height + ScaleY(10);
  ST_License.Height := ScaleY(78);
  ST_License.Parent := Page.Surface;

  Result := Page.ID;
end;

{called when a wizard page changes}
procedure CurPageChanged(CurPage: Integer);
begin
  if wpReady = CurPage then
  begin
    Wizardform.ReadyMemo.Lines.Add(#13#10 + 'Setup will also:');
    Wizardform.ReadyMemo.Lines.Add('    Add GAMS directory to PATH environment variable');
    Wizardform.ReadyMemo.Lines.Add('    Create a desktop icon for Veda2.0');
  end;
  
  // {app} is only known after the folder selection, so the default certificate is set here
  if wpGamsLicense = CurPage then
    TE_Certificate.Text := ExpandConstant('{#GamsSysDir}\gamslice.crt');

  if wpFinished = CurPage then
    WriteLicenseFile();
end;

{called during installation}
procedure CurStepChanged(CurStep: TSetupStep);
begin
  // Right after the files and [Registry] entries, so the change is part of the
  // environment refresh at the end of the installation (ChangesEnvironment)
  if ssPostInstall = CurStep then
    UpdatePath();
end;

function NextButtonClick(CurPage: Integer): Boolean;
var
  dirRes: Integer;
  dir1, dir2: String;
  dirAnsi: AnsiString;
begin
  Result:=True;
  if wpSelectDir = CurPage then
  begin
    dir1 := ExpandConstant('{app}');
    dirAnsi := dir1;
    dir2 := dirAnsi;
    if dir1 <> dir2 then
    begin
      dirRes := MsgBox('The chosen installation directory contains non-ANSI characters that will lead to problems when using GAMS. It is highly recommended to use a location that consists of ANSI characters only.' + #13#10#13#10 +
                       'Would you like to install to that folder anyway?',
                        mbConfirmation, MB_YESNO);
      if dirRes = IDNO then
        Result := False;
    end;
  end
  else if wpGamsLicense = CurPage then
  begin
    if not ALPSuccess then
    begin
      MsgBox('Please fetch a license by clicking on the "Get License" button first.', mbConfirmation, MB_OK);
      Result := False;
    end;
  end;
end;

{called for each step of the uninstallation}
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
   if usUninstall = CurUninstallStep
   then
   begin
      RemovePath();
   end;
end;

{Silent installs are not supported, since the license page needs an Access Code from the user}
function InitializeSetup(): Boolean;
begin
  Result := not WizardSilent;
  if not Result then
    MsgBox('{#MyAppDisplayName} cannot be installed silently, since a GAMS license has to be retrieved with an Access Code during the installation.' + #13#10#13#10 +
           'Please run Setup without /SILENT or /VERYSILENT.', mbError, MB_OK);
end;

{initialize the wizard}
procedure InitializeWizard();
begin
  wpGamsLicense := CreateLicensePage;
end;
