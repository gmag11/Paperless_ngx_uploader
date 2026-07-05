; Inno Setup script for Paperless-NGX Uploader
[Setup]
AppName=Paperless-NGX Uploader
AppVersion=1.8.4
DefaultDirName={autopf}\Paperless-NGX Uploader
DefaultGroupName=Paperless-NGX Uploader
OutputBaseFilename=PaperlessNGX_Uploader_Installer_Windows_x64
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
AllowNoIcons=yes
UsePreviousAppDir=yes
AppPublisher=gmartin
AppPublisherURL=https://github.com/gmag11/Paperless_ngx_uploader
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\Paperless-NGX Uploader"; Filename: "{app}\\paperlessngx_uploader.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\\Paperless-NGX Uploader"; Filename: "{app}\\paperlessngx_uploader.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Dirs]
Name: "{app}"; Permissions: users-full

[Run]
Filename: "{app}\\paperlessngx_uploader.exe"; Description: "Launch Paperless-NGX Uploader"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard();
begin
end;

function IsNonAdminInstallMode: Boolean;
begin
  Result := not IsAdminInstallMode;
end;

function GetInstallModeString(Param: String): String;
begin
  if IsNonAdminInstallMode then
    Result := 'Current User'
  else
    Result := 'All Users';
end;
