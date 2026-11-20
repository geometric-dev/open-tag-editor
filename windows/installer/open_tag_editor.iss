; Inno Setup script for Open Tag Editor (Windows, per-user install).
;
; This produces a per-user installer that installs into %LOCALAPPDATA%\Programs\OpenTagEditor
; — matching the Chrome model: no admin rights, writable so the in-app updater
; can swap files without elevation.
;
; Build (from repo root, after `flutter build windows --release`):
;   iscc /DMyAppVersion=0.7.0 /DMySourceDir=<abs path to build\windows\x64\runner\Release> ^
;         windows\installer\open_tag_editor.iss
;
; MySourceDir and the output dir are passed as absolute paths by CI. When run
; by hand, pass the absolute path to the Flutter release bundle too (relative
; Source paths resolve against this script's directory, not the repo root).
;
; CI compiles this and attaches the resulting setup .exe to the GitHub release.

#define MyAppName "Open Tag Editor"
#define MyAppPublisher "Geometric Dev"
#define MyAppURL "https://github.com/geometric-dev/open-tag-editor"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MySourceDir
  #define MySourceDir "build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{8F3A1C2E-6B4D-4E9A-9C1F-7A2B3C4D5E6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\OpenTagEditor
DefaultGroupName={#MyAppName}
; Per-user install: no admin elevation, and the install dir is writable so the
; in-app updater can replace files without a UAC prompt.
PrivilegesRequired=lowest
OutputBaseFilename=open_tag_editor-{#MyAppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\open_tag_editor.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\open_tag_editor.exe"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\open_tag_editor.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\open_tag_editor.exe"; Description: "{#MyAppName}"; Flags: nowait postinstall skipifsilent