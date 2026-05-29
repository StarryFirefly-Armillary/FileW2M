[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName=FileW2M
AppVersion=1.0.0
AppPublisher=StarryFirefly
AppPublisherURL=https://github.com/StarryFirefly-Armillary/FileW2M
DefaultDirName={autopf}\FileW2M
DefaultGroupName=FileW2M
OutputDir=build_output\installer
OutputBaseFilename=FileW2M-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\FileW2M.exe
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标:"

[Files]
Source: "build_output\windows\FileW2M.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build_output\windows\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build_output\windows\dartjni.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build_output\windows\permission_handler_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build_output\windows\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build_output\windows\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\FileW2M"; Filename: "{app}\FileW2M.exe"
Name: "{group}\卸载 FileW2M"; Filename: "{uninstallexe}"
Name: "{autodesktop}\FileW2M"; Filename: "{app}\FileW2M.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\FileW2M.exe"; Description: "启动 FileW2M"; Flags: nowait postinstall skipifsilent
