# Installs LoL Bypass to C:\LoL-Bypass, starts it at every Windows logon (hidden in tray),
# and adds Desktop + Start menu shortcuts that open the window without an admin prompt.
$ErrorActionPreference = 'Stop'
$src  = Split-Path -Parent $PSCommandPath
$dest = 'C:\LoL-Bypass'
$user = "$env:USERDOMAIN\$env:USERNAME"
function Say($t, $c = 'Gray') { Write-Host $t -ForegroundColor $c }
$Host.UI.RawUI.WindowTitle = 'LoL Bypass - Install'
Say "`n  LOL BYPASS - INSTALL`n" Yellow

# 1. stop anything already running (old bats, old install)
Say '[1/5] Stopping old copies...'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*LoL-Bypass.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-Process goodbyedpi, winws -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

# 2. copy files
Say "[2/5] Copying files to $dest ..."
New-Item -ItemType Directory -Path $dest -Force | Out-Null
if ((Resolve-Path $src).Path.TrimEnd('\') -ne $dest) {
  $keepCfg = Test-Path "$dest\config.ini"
  $skip = @('bypass.log')
  if ($keepCfg) { $skip += 'config.ini' }
  robocopy $src $dest /E /NFL /NDL /NJH /NJS /NP /XF @skip | Out-Null
  Copy-Item "$src\Uninstall.bat", "$src\Uninstall.ps1" $dest -Force
}
if (-not (Test-Path "$dest\zapret\winws.exe") -or -not (Test-Path "$dest\goodbyedpi\goodbyedpi.exe")) {
  Say "`n  winws.exe or goodbyedpi.exe is missing - your antivirus probably removed it." Red
  Say "  Add an exclusion for $dest (and the folder you copied from), restore the file, then run Install.bat again." Red
  Read-Host "`nPress Enter to exit"; exit 1
}

# 3. optional antivirus exclusion (your choice)
Say "`n[3/5] Windows Defender often flags GoodbyeDPI / zapret (WinDivert packet drivers) as a false positive."
$ans = Read-Host "      Add a Defender exclusion for $dest ? (Y/n)"
if ($ans -notmatch '^[nN]') {
  try { Add-MpPreference -ExclusionPath $dest; Say '      Exclusion added.' Green }
  catch { Say "      Could not add it (another antivirus?). Add $dest manually if files disappear." Yellow }
} else { Say '      Skipped.' }

# 4. scheduled tasks: logon (hidden) + on-demand window
Say '[4/5] Setting up auto-start...'
$prn = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$trg = New-ScheduledTaskTrigger -AtLogOn -User $user; $trg.Delay = 'PT10S'
Register-ScheduledTask -TaskName 'LoL Bypass' -Force -Principal $prn -Settings $set -Trigger $trg `
  -Action (New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$dest\Launch-Silent.vbs`"") | Out-Null
Register-ScheduledTask -TaskName 'LoL Bypass UI' -Force -Principal $prn -Settings $set `
  -Action (New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$dest\Launch-UI.vbs`"") | Out-Null

# 5. shortcuts
Say '[5/5] Creating shortcuts...'
$ws = New-Object -ComObject WScript.Shell
foreach ($dir in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) {
  $lnk = $ws.CreateShortcut((Join-Path $dir 'LoL Bypass.lnk'))
  $lnk.TargetPath = "$env:WINDIR\System32\wscript.exe"
  $lnk.Arguments = "`"$dest\OpenUI.vbs`""
  $lnk.IconLocation = "$dest\icon.ico"
  $lnk.WorkingDirectory = $dest
  $lnk.Description = 'Open LoL Bypass'
  $lnk.Save()
}

Start-ScheduledTask -TaskName 'LoL Bypass UI'
Say "`n  Done! LoL Bypass is open and will start hidden in the tray every time Windows starts." Green
Say '  Open it anytime from the "LoL Bypass" shortcut on your Desktop / Start menu.' Green
Start-Sleep -Seconds 4
