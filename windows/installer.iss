[Setup]
AppName=WHPH
AppVersion=0.7.1
AppPublisher=Ahmet Çetinkaya
AppPublisherURL=https://github.com/ahmet-cetinkaya/whph
AppSupportURL=https://github.com/ahmet-cetinkaya/whph/issues
AppUpdatesURL=https://github.com/ahmet-cetinkaya/whph/releases
AppComments={cm:AppDescription}
DefaultDirName={autopf}\WHPH
DefaultGroupName=WHPH
AllowNoIcons=yes
LicenseFile=..\LICENSE
OutputDir=build\windows\installer
OutputBaseFilename=whph-setup
SetupIconFile=runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[CustomMessages]
; English
english.AppDescription=A comprehensive productivity app designed to help you manage tasks, develop new habits, and optimize your time.
english.LaunchAfterInstall=Launch WHPH after installation
english.CreateDesktopShortcut=Create a &desktop shortcut
english.CreateQuickLaunchShortcut=Create a &Quick Launch shortcut

; Turkish
turkish.AppDescription=Görevlerinizi yönetmenize, yeni alışkanlıklar geliştirmenize ve zamanınızı optimize etmenize yardımcı olan kapsamlı bir verimlilik uygulamasıdır.
turkish.LaunchAfterInstall=Kurulumdan sonra WHPH'yi başlat
turkish.CreateDesktopShortcut=&Masaüstü kısayolu oluştur
turkish.CreateQuickLaunchShortcut=&Hızlı Başlatma kısayolu oluştur

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopShortcut}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchShortcut}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\WHPH"; Filename: "{app}\whph.exe"
Name: "{group}\{cm:UninstallProgram,WHPH}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\WHPH"; Filename: "{app}\whph.exe"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\WHPH"; Filename: "{app}\whph.exe"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\whph.exe"; Description: "{cm:LaunchAfterInstall}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\WHPH"
