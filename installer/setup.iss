#ifndef Workspace
#define Workspace "Z:"
#endif
#ifndef ProductVersion
#error ProductVersion must be supplied by build-installers.ps1
#endif
#define ProductName "movim"
#ifdef TestBuild
#define ProductId "WebNeovim-InstallerTest-2026"
#define OutputName "movim-Setup-TEST"
#else
#define ProductId "WebNeovim-Portable-2026"
#define OutputName "movim-Setup"
#endif
[Setup]
AppId={#ProductId}
AppName={#ProductName}
AppVersion={#ProductVersion}
AppPublisher=movim
DefaultDirName={localappdata}\Programs\movim
DefaultGroupName=movim
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..
OutputBaseFilename={#OutputName}
Compression=lzma2/fast
SolidCompression=no
WizardStyle=modern
ChangesEnvironment=yes
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\.tools\nvim-win64\bin\nvim.exe

[Tasks]
Name: addpath; Description: "Add movim to the current user's PATH (run movim or nvim in a new PowerShell window)"; Flags: checkedonce
Name: desktopicon; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "movim.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "nvim.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "start-webstorm.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Workspace}\neovim\CHANGELOG.md"; DestDir: "{app}\neovim"; Flags: ignoreversion
Source: "{#Workspace}\neovim\site\docs-en\README.md"; DestDir: "{app}\neovim\site\docs-en"; Flags: ignoreversion
Source: "{#Workspace}\neovim\release.json"; DestDir: "{app}\neovim"; Flags: ignoreversion
Source: "{#Workspace}\neovim\init.lua"; DestDir: "{app}\neovim"; Flags: ignoreversion
Source: "{#Workspace}\neovim\lazy-lock.json"; DestDir: "{app}\neovim"; Flags: ignoreversion
Source: "{#Workspace}\neovim\start-webstorm.cmd"; DestDir: "{app}\neovim"; Flags: ignoreversion
Source: "{#Workspace}\neovim\start-webstorm.ps1"; DestDir: "{app}\neovim"; Flags: ignoreversion
Source: "{#Workspace}\neovim\README.md"; DestDir: "{app}\neovim"; Flags: ignoreversion
Source: "{#Workspace}\neovim\LICENSE"; DestDir: "{app}\neovim"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#Workspace}\neovim\lua\*"; DestDir: "{app}\neovim\lua"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Workspace}\neovim\colors\*"; DestDir: "{app}\neovim\colors"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Workspace}\neovim\keymap\*"; DestDir: "{app}\neovim\keymap"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#Workspace}\neovim\docs\*"; DestDir: "{app}\neovim\docs"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; Persian-capable monospaced Nerd Font; selected in the terminal separately.
Source: "{#Workspace}\neovim\fonts\DejaVuSansMNerdFontMono-Regular.ttf"; DestDir: "{autofonts}"; FontInstall: "DejaVuSansM Nerd Font Mono"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#Workspace}\neovim\fonts\DejaVuSansMNerdFontMono-Bold.ttf"; DestDir: "{autofonts}"; FontInstall: "DejaVuSansM Nerd Font Mono Bold"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#Workspace}\neovim\fonts\DejaVuSansMNerdFontMono-Oblique.ttf"; DestDir: "{autofonts}"; FontInstall: "DejaVuSansM Nerd Font Mono Oblique"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#Workspace}\neovim\fonts\DejaVuSansMNerdFontMono-BoldOblique.ttf"; DestDir: "{autofonts}"; FontInstall: "DejaVuSansM Nerd Font Mono Bold Oblique"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "{#Workspace}\neovim\fonts\*"; DestDir: "{app}\neovim\fonts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Workspace}\.tools\nvim-win64\*"; DestDir: "{app}\.tools\nvim-win64"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Workspace}\.tools\node-v22.23.5-win-x64\*"; DestDir: "{app}\.tools\node-v22.23.5-win-x64"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Workspace}\.tools\lazygit\*"; DestDir: "{app}\.tools\lazygit"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Workspace}\.tools\compiler\node_modules\@ryoppippi\zig-win32-x64\*"; DestDir: "{app}\.tools\compiler\node_modules\@ryoppippi\zig-win32-x64"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Workspace}\.tools\bin\rg.exe"; DestDir: "{app}\.tools\bin"; Flags: ignoreversion
Source: "{#Workspace}\.isolated\data\nvim-data\lazy\*"; DestDir: "{app}\.isolated\data\nvim-data\lazy"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: ".git\*"
Source: "{#Workspace}\.isolated\data\nvim-data\site\*"; DestDir: "{app}\.isolated\data\nvim-data\site"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "{#GetEnv('LOCALAPPDATA')}\Microsoft\Windows\Fonts\JetBrainsMonoNLNerdFontMono-Regular.ttf"; DestDir: "{app}\fonts"; Flags: ignoreversion skipifsourcedoesntexist
Source: "WINDOWS-INSTALL.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme

Source: "{#Workspace}\.tools\installer-runtime.tar"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

[Icons]
Name: "{group}\movim"; Filename: "{app}\movim.cmd"; WorkingDir: "{userdocs}"
Name: "{autodesktop}\movim"; Filename: "{app}\movim.cmd"; WorkingDir: "{userdocs}"; Tasks: desktopicon

[Code]
const EnvKey = 'Environment';
const MarkerKey = 'Software\WebNeovim\{#ProductId}';
function HasPathEntry(Entries, Entry: String): Boolean;
var P: Integer; Item: String;
begin
  Result := False;
  Entries := Entries + ';';
  while Entries <> '' do begin
    P := Pos(';', Entries);
    Item := Trim(Copy(Entries, 1, P - 1));
    Delete(Entries, 1, P);
    if CompareText(RemoveBackslashUnlessRoot(Item), RemoveBackslashUnlessRoot(Entry)) = 0 then begin Result := True; exit; end;
  end;
end;
procedure CurStepChanged(CurStep: TSetupStep);
var OldPath, AppPath: String; ResultCode: Integer;
begin
  if CurStep = ssPostInstall then begin
    if not Exec(ExpandConstant('{sys}\tar.exe'), '-xf "' + ExpandConstant('{tmp}\installer-runtime.tar') + '" -C "' + ExpandConstant('{app}') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      RaiseException('Could not start Windows tar to extract language tools.');
    if ResultCode <> 0 then RaiseException('Could not extract language tools; tar exit code: ' + IntToStr(ResultCode));
  end;
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('addpath') then begin
    AppPath := ExpandConstant('{app}');
    RegQueryStringValue(HKCU, EnvKey, 'Path', OldPath);
    if not HasPathEntry(OldPath, AppPath) then begin
      if (OldPath <> '') and (OldPath[Length(OldPath)] <> ';') then OldPath := OldPath + ';';
      if RegWriteExpandStringValue(HKCU, EnvKey, 'Path', OldPath + AppPath) then
        RegWriteStringValue(HKCU, MarkerKey, 'AddedPath', AppPath);
    end;
  end;
end;
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var OldPath, AppPath, NewPath, Item: String; P: Integer;
begin
  if (CurUninstallStep = usPostUninstall) and RegQueryStringValue(HKCU, MarkerKey, 'AddedPath', AppPath) then begin
    RegQueryStringValue(HKCU, EnvKey, 'Path', OldPath);
    OldPath := OldPath + ';'; NewPath := '';
    while OldPath <> '' do begin
      P := Pos(';', OldPath); Item := Copy(OldPath, 1, P - 1); Delete(OldPath, 1, P);
      if (Trim(Item) <> '') and (CompareText(RemoveBackslashUnlessRoot(Trim(Item)), RemoveBackslashUnlessRoot(AppPath)) <> 0) then begin
        if NewPath <> '' then NewPath := NewPath + ';'; NewPath := NewPath + Item;
      end;
    end;
    RegWriteExpandStringValue(HKCU, EnvKey, 'Path', NewPath);
    RegDeleteKeyIncludingSubkeys(HKCU, MarkerKey);
  end;
end;
