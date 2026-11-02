; LoL Bypass installer (NSIS 3, Modern UI 2)
; Build:  makensis -DVERSION=1.0.0 -DBUILD_DIR=<app build dir> -DPAYLOAD_DIR=<repo>/payload LoLBypass.nsi

Unicode true
SetCompressor /SOLID lzma
ManifestDPIAware true
RequestExecutionLevel admin

!ifndef VERSION
  !define VERSION "1.0.0"
!endif
!ifndef BUILD_DIR
  !define BUILD_DIR "..\build"
!endif
!ifndef PAYLOAD_DIR
  !define PAYLOAD_DIR "..\payload"
!endif

!define APPNAME   "LoL Bypass"
!define APPEXE    "LoLBypass.exe"
!define PUBLISHER "Mohamed Osama"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\LoLBypass"

Name "${APPNAME}"
OutFile "LoLBypass-Setup-${VERSION}.exe"
InstallDir "$PROGRAMFILES64\${APPNAME}"
InstallDirRegKey HKLM "${UNINSTKEY}" "InstallLocation"
BrandingText "${APPNAME} ${VERSION}"
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "FileDescription" "${APPNAME} Setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "LegalCopyright" "${PUBLISHER}"

!include "MUI2.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"

; ---------- look ----------
!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "wizard.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "wizard.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "header.bmp"
!define MUI_BGCOLOR "010A13"
!define MUI_TEXTCOLOR "F0E6D2"
!define MUI_ABORTWARNING

!define MUI_WELCOMEPAGE_TITLE "Welcome to ${APPNAME}"
!define MUI_WELCOMEPAGE_TEXT "Play League of Legends, TFT, VALORANT and Legends of Runeterra without a VPN.$\r$\n$\r$\n${APPNAME} runs GoodbyeDPI and zapret in the background to get past ISP blocking (login, chat, Vanguard and match servers). No VPN, so no extra ping.$\r$\n$\r$\nClick Next to continue."
!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APPEXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APPNAME} now"
!define MUI_FINISHPAGE_TITLE "${APPNAME} is installed"
!define MUI_FINISHPAGE_TEXT "Open it any time from the Start menu or Desktop shortcut.$\r$\n$\r$\nIf you kept 'Start with Windows' on, it starts hidden in the tray every time you sign in."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ---------- helpers ----------
!macro StopEverything
  ; old PowerShell edition + current app + bypass processes
  nsExec::Exec 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -Filter \"Name=''powershell.exe''\" | Where-Object { $$_.CommandLine -like ''*LoL-Bypass.ps1*'' } | ForEach-Object { Stop-Process -Id $$_.ProcessId -Force }"'
  nsExec::Exec 'taskkill /f /im ${APPEXE}'
  nsExec::Exec 'taskkill /f /im goodbyedpi.exe'
  nsExec::Exec 'taskkill /f /im winws.exe'
  Sleep 800
!macroend

; ---------- sections (run in this order) ----------
Section "Windows Defender exclusion (recommended)" SecDefender
  ; Runs BEFORE any file is extracted so Defender can't quarantine winws.exe / WinDivert.
  DetailPrint "Adding Windows Defender exclusion for $INSTDIR ..."
  nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-MpPreference -ExclusionPath ''$INSTDIR''"'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Could not add the Defender exclusion (another antivirus may be active)."
  ${EndIf}
  WriteRegDWORD HKLM "${UNINSTKEY}" "DefenderExclusion" 1
SectionEnd

Section "!${APPNAME} (required)" SecMain
  SectionIn RO
  !insertmacro StopEverything

  SetOutPath "$INSTDIR"
  File "${BUILD_DIR}\${APPEXE}"
  File "${BUILD_DIR}\${APPEXE}.config"
  File "${PAYLOAD_DIR}\riot-game-ips.txt"
  File "icon.ico"
  SetOutPath "$INSTDIR\bin\goodbyedpi"
  File "${PAYLOAD_DIR}\bin\goodbyedpi\*.*"
  SetOutPath "$INSTDIR\bin\zapret"
  File "${PAYLOAD_DIR}\bin\zapret\*.*"
  SetOutPath "$INSTDIR\licenses"
  File "${PAYLOAD_DIR}\licenses\*.*"
  SetOutPath "$INSTDIR"

  ; old PowerShell edition: remove its shortcut (the tasks get replaced below)
  Delete "$DESKTOP\LoL Bypass.lnk"
  Delete "$SMPROGRAMS\LoL Bypass.lnk"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\${APPNAME}.lnk" "$INSTDIR\${APPEXE}" "" "$INSTDIR\${APPEXE}" 0

  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr   HKLM "${UNINSTKEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr   HKLM "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\${APPEXE}"
  WriteRegStr   HKLM "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr   HKLM "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr   HKLM "${UNINSTKEY}" "URLInfoAbout" "https://github.com/EngMohamedOsama/lol-bypass"
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1
SectionEnd

Section "Start with Windows (hidden in tray)" SecStartup
  ; marker only - tasks are created in the last section
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${APPEXE}" "" "$INSTDIR\${APPEXE}" 0
SectionEnd

Section "-Tasks"
  ${If} ${SectionIsSelected} ${SecStartup}
    nsExec::ExecToLog '"$INSTDIR\${APPEXE}" --install-tasks'
  ${Else}
    nsExec::ExecToLog '"$INSTDIR\${APPEXE}" --install-tasks --no-startup'
  ${EndIf}
  Pop $0
  ${If} $0 != 0
    DetailPrint "Warning: could not create the scheduled tasks (code $0)."
  ${EndIf}
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDefender} "Antivirus apps often flag GoodbyeDPI / zapret (WinDivert packet driver) as a false positive. This excludes the install folder from Windows Defender so the files aren't deleted. Recommended."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain}     "The app, GoodbyeDPI and zapret."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartup}  "Start the bypass automatically, hidden in the tray, every time you sign in to Windows (no admin prompt)."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop}  "Add a ${APPNAME} shortcut to the Desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function .onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${Else}
    MessageBox MB_ICONSTOP "${APPNAME} needs 64-bit Windows 10 or 11."
    Abort
  ${EndIf}
FunctionEnd

; ---------- uninstall ----------
Function un.onInit
  SetRegView 64
FunctionEnd

Section "Uninstall"
  nsExec::Exec '"$INSTDIR\${APPEXE}" --remove-tasks'
  nsExec::Exec 'taskkill /f /im ${APPEXE}'
  nsExec::Exec 'taskkill /f /im goodbyedpi.exe'
  nsExec::Exec 'taskkill /f /im winws.exe'
  Sleep 1000
  nsExec::Exec 'sc stop WinDivert'

  ReadRegDWORD $0 HKLM "${UNINSTKEY}" "DefenderExclusion"
  ${If} $0 == 1
    nsExec::Exec 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Remove-MpPreference -ExclusionPath ''$INSTDIR''"'
  ${EndIf}

  Delete "$DESKTOP\${APPNAME}.lnk"
  Delete "$SMPROGRAMS\${APPNAME}.lnk"
  RMDir /r "$INSTDIR\bin"
  RMDir /r "$INSTDIR\licenses"
  Delete "$INSTDIR\${APPEXE}"
  Delete "$INSTDIR\${APPEXE}.config"
  Delete "$INSTDIR\riot-game-ips.txt"
  Delete "$INSTDIR\icon.ico"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  SetShellVarContext all
  RMDir /r "$APPDATA\LoL Bypass"
  SetShellVarContext current
  DeleteRegKey HKLM "${UNINSTKEY}"
SectionEnd
