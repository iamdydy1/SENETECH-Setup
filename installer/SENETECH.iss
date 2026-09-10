; SENETECH Setup - full Windows installer
; IMPORTANT: AppId is permanent. Never change it between Stable/Developer versions.

#ifndef AppVersion
  #define AppVersion "0.0.0.0"
#endif
#ifndef Channel
  #define Channel "DEV"
#endif
#ifndef SourceDir
  #define SourceDir "..\dist\runtime"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist\installer"
#endif

#define AppExeName "SENETECH-Setup.exe"
#define AppPublisher "SENETECH"
#define AppURL "https://github.com/iamdydy1/SENETECH-Setup"

[Setup]
AppId={{D57F5D8B-58E9-4D92-9D48-6EA0A2AC3F2E}
AppName=SENETECH Setup
AppVersion={#AppVersion}
AppVerName=SENETECH Setup {#AppVersion} ({#Channel})
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\SENETECH
DefaultGroupName=SENETECH
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir={#OutputDir}
OutputBaseFilename=SENETECH-Setup-{#AppVersion}-{#Channel}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=SENETECH-Setup.exe
RestartApplications=no
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousLanguage=yes
SetupLogging=yes
UninstallDisplayName=SENETECH Setup
UninstallDisplayIcon={app}\{#AppExeName}
VersionInfoVersion={#AppVersion}
VersionInfoProductVersion={#AppVersion}
VersionInfoCompany=SENETECH
VersionInfoDescription=SENETECH Setup Windows Installer
VersionInfoProductName=SENETECH Setup
MinVersion=10.0

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"; Flags: unchecked

; Remove only SENETECH-managed runtime files. Logs/settings in ProgramData are intentionally preserved.
; Deleting _SENETECH first guarantees that removed modules from an older build do not survive an upgrade.
[InstallDelete]
Type: filesandordirs; Name: "{app}\_SENETECH"
Type: files; Name: "{app}\SENETECH-Setup.exe"
Type: files; Name: "{app}\VERSION.txt"
Type: files; Name: "{app}\LISEZ-MOI.txt"
Type: files; Name: "{app}\CHANGELOG.txt"
Type: files; Name: "{app}\UPDATE-SENETECH.ps1"
Type: files; Name: "{app}\UPDATE-SENETECH-CHANNEL.ps1"
Type: files; Name: "{app}\SENETECH-DEV-DIAGNOSTIC.cmd"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "SENETECH-INSTALLED.flag"; DestDir: "{app}"; DestName: "SENETECH-INSTALLED.flag"; Flags: ignoreversion

[Icons]
Name: "{group}\SENETECH Setup"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\SENETECH Setup"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Lancer SENETECH Setup"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent runascurrentuser
