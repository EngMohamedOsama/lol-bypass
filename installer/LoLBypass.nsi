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
!include "nsDialogs.nsh"
!include "WinMessages.nsh"

Var Dialog
Var PathBox
Var StatusLabel
Var AvOk

; ---------- look ----------
!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "wizard.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "wizard.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "header.bmp"
; (no MUI_BGCOLOR/TEXTCOLOR: the dark theme made the finish-page 'Run' checkbox
;  text unreadable; the welcome/finish pages use the default light background + the
;  themed side bitmap, so all text stays legible)
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
Page custom AvPageCreate AvPageLeave
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

; ---------- antivirus exclusion wizard page (runs before files are written) ----------
Function AvCopyPath
  nsExec::Exec 'cmd /c <nul set /p x=$INSTDIR| clip'
  ${NSD_SetText} $StatusLabel "Path copied. Now click 'Open exclusions page'."
FunctionEnd

Function AvOpenPage
  nsExec::Exec 'cmd /c <nul set /p x=$INSTDIR| clip'
  Exec 'cmd /c start windowsdefender://exclusions/'
  ${NSD_SetText} $StatusLabel "Add a Folder exclusion, paste (Ctrl+V), then click 'I added it'."
FunctionEnd

Function AvSetNext
  ; enable/disable the Next (Install) button - control id 1 on the wizard
  GetDlgItem $1 $HWNDPARENT 1
  EnableWindow $1 $AvOk
FunctionEnd

Function AvRefresh
  ; check-exclusion.ps1 exits 0 = present, 1 = Defender active but missing, 2 = Defender not active
  nsExec::Exec 'powershell -NoProfile -ExecutionPolicy Bypass -File "$PLUGINSDIR\check-exclusion.ps1" -Path "$INSTDIR"'
  Pop $0
  ${If} $0 == 0
    StrCpy $AvOk 1
    WriteRegDWORD HKLM "${UNINSTKEY}" "DefenderExclusion" 1
    ${NSD_SetText} $StatusLabel "Status: exclusion added. Click Next."
  ${ElseIf} $0 == 2
    StrCpy $AvOk 1
    ${NSD_SetText} $StatusLabel "Status: Defender isn't the active antivirus. If another AV flags the app, add this folder to its exclusions. You can click Next."
  ${Else}
    StrCpy $AvOk 0
    ${NSD_SetText} $StatusLabel "Status: not added yet - add the folder, then click 'I added it'."
  ${EndIf}
  Call AvSetNext
FunctionEnd

Function AvCheckClick
  Call AvRefresh
FunctionEnd

Function AvPageCreate
  !insertmacro MUI_HEADER_TEXT "Antivirus exclusion" "One quick step so your antivirus doesn't delete the app."
  CreateDirectory "$INSTDIR"
  InitPluginsDir
  File "/oname=$PLUGINSDIR\check-exclusion.ps1" "check-exclusion.ps1"
  StrCpy $AvOk 0
  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 34u "The app uses a network driver (WinDivert) that antivirus wrongly flags as a virus. It's safe and open-source. Add this folder as an exclusion so the files aren't deleted:"
  Pop $0

  ${NSD_CreateText} 0 38u 73% 13u "$INSTDIR"
  Pop $PathBox
  SendMessage $PathBox ${EM_SETREADONLY} 1 0

  ${NSD_CreateButton} 75% 37u 25% 14u "Copy path"
  Pop $0
  ${NSD_OnClick} $0 AvCopyPath

  ${NSD_CreateButton} 0 58u 49% 15u "Open exclusions page"
  Pop $0
  ${NSD_OnClick} $0 AvOpenPage

  ${NSD_CreateButton} 51% 58u 49% 15u "I added it"
  Pop $0
  ${NSD_OnClick} $0 AvCheckClick

  ${NSD_CreateLabel} 0 80u 100% 28u "1.  Open exclusions page   2.  Add an exclusion > Folder, paste (Ctrl+V), Select Folder   3.  Click 'I added it', then Next."
  Pop $0

  ${NSD_CreateLabel} 0 112u 100% 24u ""
  Pop $StatusLabel

  Call AvRefresh    ; auto-adds silently if Tamper Protection is off; otherwise shows "not added yet"
  nsDialogs::Show
FunctionEnd

Function AvPageLeave
  ${If} $AvOk != 1
    MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION "The exclusion isn't in place yet - your antivirus will delete the app without it.$\r$\n$\r$\nOK = go back and add it.      Cancel = install anyway." IDCANCEL av_continue
    Abort
    av_continue:
  ${EndIf}
FunctionEnd

; ---------- sections ----------
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
  CreateShortcut "$SMPROGRAMS\Uninstall ${APPNAME}.lnk" "$INSTDIR\Uninstall.exe" "" "$INSTDIR\icon.ico" 0

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
  Delete "$SMPROGRAMS\Uninstall ${APPNAME}.lnk"
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
