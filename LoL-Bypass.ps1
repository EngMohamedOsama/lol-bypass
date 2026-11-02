param([switch]$Silent)
# LoL Bypass - GoodbyeDPI (TCP: login / chat / Vanguard / store) + zapret winws (UDP: match servers)
# Covers League of Legends (all modes), TFT, Legends of Runeterra and VALORANT.
# -Silent : start hidden in the tray (used at Windows logon)
# no args : open the window (used by the desktop / Start menu shortcut)
# Runs elevated through the "LoL Bypass" / "LoL Bypass UI" scheduled tasks created by Install.bat.

$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSCommandPath

# ---------- single instance: a second launch just opens the window of the first ----------
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\LoLBypassTray', [ref]$created)
$showEvt = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Global\LoLBypassShow')
if (-not $created) { if (-not $Silent) { [void]$showEvt.Set() }; exit }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$cfgPath  = Join-Path $root 'config.ini'
$gdpiExe  = Join-Path $root 'goodbyedpi\goodbyedpi.exe'
$winwsExe = Join-Path $root 'zapret\winws.exe'
$ipset    = Join-Path $root 'riot-game-ips.txt'
$logPath  = Join-Path $root 'bypass.log'
$icoPath  = Join-Path $root 'icon.ico'
$TaskLogon = 'LoL Bypass'

$gdpiArgs = '-1 --port 8443 --port 5222 --port 5223 --port 2099 --port 8088 --port 8393 --port 8394 --port 8400'
$udpModes = @{
  1 = '--dpi-desync=fake --dpi-desync-repeats=6'
  2 = '--dpi-desync=fake --dpi-desync-repeats=12'
  3 = '--dpi-desync=ipfrag2'
  4 = '--dpi-desync=fake,ipfrag2 --dpi-desync-repeats=6'
}
$udpNames = @{ 1 = 'Fake packets x6'; 2 = 'Fake packets x12'; 3 = 'IP fragmentation'; 4 = 'Fake + IP fragmentation' }

$script:paused = $false

# ---------- engine ----------
function Write-Log($msg) {
  Add-Content -Path $logPath -Value ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg)
  if ((Get-Item $logPath).Length -gt 512KB) { Get-Content $logPath -Tail 500 | Set-Content $logPath }
}
function Get-Strategy {
  $s = 1
  if (Test-Path $cfgPath) {
    $l = Get-Content $cfgPath | Where-Object { $_ -match '^\s*Strategy\s*=\s*([1-4])' } | Select-Object -First 1
    if ($l -and $l -match '([1-4])') { $s = [int]$Matches[1] }
  }
  return $s
}
function Set-Strategy([int]$n) { Set-Content -Path $cfgPath -Value "Strategy=$n" -Encoding ASCII }
function Get-WinwsArgs {
  # profile 1: League / TFT match servers (any port 5000-9999, Riot's own IP ranges only)
  # profile 2: VALORANT match servers (UDP 7000-8999, any IP - some are hosted outside Riot's ranges)
  $m = $udpModes[(Get-Strategy)]
  "--wf-udp=5000-9999 " +
  "--filter-udp=5000-9999 --ipset=`"$ipset`" --dpi-desync-any-protocol=1 --dpi-desync-cutoff=n3 $m --new " +
  "--filter-udp=7000-8999 --dpi-desync-any-protocol=1 --dpi-desync-cutoff=n3 $m"
}
function Test-Running([string]$name) { [bool](Get-Process -Name $name -ErrorAction SilentlyContinue) }
function Start-Gdpi {
  Start-Process -FilePath $gdpiExe -ArgumentList $gdpiArgs -WorkingDirectory (Split-Path $gdpiExe) -WindowStyle Hidden
  Write-Log "goodbyedpi started: $gdpiArgs"
}
function Start-Winws {
  $a = Get-WinwsArgs
  Start-Process -FilePath $winwsExe -ArgumentList $a -WorkingDirectory (Split-Path $winwsExe) -WindowStyle Hidden
  Write-Log "winws started (strategy $(Get-Strategy)): $a"
}
function Stop-Bypass {
  Get-Process -Name goodbyedpi, winws -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Milliseconds 800
}
function Restart-Vanguard {
  $v = Get-Service vgc
  if ($v -and $v.Status -eq 'Running') { Restart-Service vgc -Force; Write-Log 'vgc restarted behind the bypass' }
}
function Start-Bypass([bool]$restartVgc = $true) {
  Stop-Bypass; Start-Gdpi; Start-Winws
  Start-Sleep -Seconds 2
  if ($restartVgc) { Restart-Vanguard }
  $script:paused = $false
  Write-Log 'bypass ON'
}
function Stop-ByUser { $script:paused = $true; Stop-Bypass; Write-Log 'bypass OFF (user)' }

function Get-StartupEnabled {
  $t = Get-ScheduledTask -TaskName $TaskLogon -ErrorAction SilentlyContinue
  return ($t -and $t.State -ne 'Disabled')
}
function Set-StartupEnabled([bool]$on) {
  $t = Get-ScheduledTask -TaskName $TaskLogon -ErrorAction SilentlyContinue
  if ($on) {
    if ($t) { Enable-ScheduledTask -TaskName $TaskLogon | Out-Null }
    else {
      $user = "$env:USERDOMAIN\$env:USERNAME"
      $act  = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$root\Launch-Silent.vbs`""
      $trg  = New-ScheduledTaskTrigger -AtLogOn -User $user; $trg.Delay = 'PT10S'
      $prn  = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
      $set  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
      Register-ScheduledTask -TaskName $TaskLogon -Action $act -Trigger $trg -Principal $prn -Settings $set -Force | Out-Null
    }
  } elseif ($t) { Disable-ScheduledTask -TaskName $TaskLogon | Out-Null }
  Write-Log "start with Windows: $on"
}

# ---------- Riot-style palette ----------
function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$cBg      = C '#010A13'
$cPanel   = C '#0A1428'
$cGold    = C '#C8AA6E'
$cGoldDk  = C '#785A28'
$cGoldLt  = C '#F0E6D2'
$cText    = C '#CDBE91'
$cMuted   = C '#A09B8C'
$cTeal    = C '#0AC8B9'
$cRed     = C '#BE1E37'
$cBtn     = C '#1E2328'
$fTitle   = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$fState   = New-Object System.Drawing.Font('Segoe UI Semibold', 16)
$fBody    = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5)
$fSmall   = New-Object System.Drawing.Font('Segoe UI', 8.5)
$fBtn     = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$fRing    = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)

$appIcon = if (Test-Path $icoPath) { New-Object System.Drawing.Icon($icoPath) } else { [System.Drawing.SystemIcons]::Shield }

function New-Label($text, $x, $y, $w, $h, $font, $color, $align = 'MiddleLeft') {
  $l = New-Object System.Windows.Forms.Label
  $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y); $l.Size = New-Object System.Drawing.Size($w, $h)
  $l.Font = $font; $l.ForeColor = $color; $l.BackColor = [System.Drawing.Color]::Transparent
  $l.TextAlign = [System.Drawing.ContentAlignment]::$align
  return $l
}

# ---------- window ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'LoL Bypass'
$form.FormBorderStyle = 'None'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(400, 540)
$form.BackColor = $cBg
$form.Icon = $appIcon
$form.ShowInTaskbar = $true
$form.Add_Paint({
  param($s, $e)
  $g = $e.Graphics
  $pen = New-Object System.Drawing.Pen($cGoldDk, 2)
  $g.DrawRectangle($pen, 1, 1, $form.ClientSize.Width - 2, $form.ClientSize.Height - 2)
  $g.DrawLine($pen, 0, 42, $form.ClientSize.Width, 42)
  $pen2 = New-Object System.Drawing.Pen($cGoldDk, 1)
  $g.DrawLine($pen2, 60, 300, 340, 300)
})

# title bar (drag to move)
$lblTitle = New-Label 'LOL BYPASS' 16 8 220 26 $fTitle $cGold
$lblMin   = New-Label ([string][char]0x2014) 318 6 30 30 $fTitle $cMuted 'MiddleCenter'
$lblClose = New-Label ([string][char]0x2715) 352 6 30 30 $fTitle $cMuted 'MiddleCenter'
foreach ($l in $lblMin, $lblClose) {
  $l.Cursor = [System.Windows.Forms.Cursors]::Hand
  $l.Add_MouseEnter({ param($s, $e) $s.ForeColor = $cGoldLt })
  $l.Add_MouseLeave({ param($s, $e) $s.ForeColor = $cMuted })
}
$lblMin.Add_Click({ $form.Hide() })
$lblClose.Add_Click({ $form.Hide(); $icon.ShowBalloonTip(2500, 'LoL Bypass', 'Still running in the tray. Right-click the icon to exit.', 'Info') })
$script:drag = $false
$dragDown = { param($s, $e) $script:drag = $true; $script:dragPt = $e.Location }
$dragMove = { param($s, $e) if ($script:drag) { $form.Location = New-Object System.Drawing.Point(($form.Left + $e.X - $script:dragPt.X), ($form.Top + $e.Y - $script:dragPt.Y)) } }
$dragUp   = { $script:drag = $false }
foreach ($c in $form, $lblTitle) { $c.Add_MouseDown($dragDown); $c.Add_MouseMove($dragMove); $c.Add_MouseUp($dragUp) }

# status ring
$ring = New-Object System.Windows.Forms.Panel
$ring.Location = New-Object System.Drawing.Point(125, 58); $ring.Size = New-Object System.Drawing.Size(150, 150)
$ring.BackColor = $cBg
$ring.Add_Paint({
  param($s, $e)
  $g = $e.Graphics; $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $on = (-not $script:paused) -and (Test-Running 'goodbyedpi') -and (Test-Running 'winws')
  $accent = if ($on) { $cTeal } elseif ($script:paused) { $cMuted } else { $cGold }
  $g.DrawEllipse((New-Object System.Drawing.Pen($cGoldDk, 3)), 4, 4, 141, 141)
  $g.DrawEllipse((New-Object System.Drawing.Pen($cGold, 2)), 14, 14, 121, 121)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush($cPanel)), 22, 22, 105, 105)
  $g.DrawEllipse((New-Object System.Drawing.Pen($accent, 4)), 26, 26, 97, 97)
  $txt = if ($on) { 'ON' } elseif ($script:paused) { 'OFF' } else { '...' }
  $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $g.DrawString($txt, $fRing, (New-Object System.Drawing.SolidBrush($accent)), (New-Object System.Drawing.RectangleF(0, 0, 150, 150)), $sf)
})

$lblState = New-Label 'BYPASS ACTIVE' 0 214 400 30 $fState $cTeal 'MiddleCenter'

# status rows
$dot1 = New-Label ([string][char]0x25CF) 66 250 18 22 $fBody $cTeal
$row1 = New-Label 'LOGIN  /  CHAT  /  VANGUARD  /  LOR' 86 250 290 22 $fBody $cText
$dot2 = New-Label ([string][char]0x25CF) 66 274 18 22 $fBody $cTeal
$row2 = New-Label 'MATCH SERVERS  (LOL / TFT / VALORANT)' 86 274 290 22 $fBody $cText

# strategy
$lblStrat = New-Label 'MATCH STRATEGY' 60 312 280 20 $fSmall $cMuted
$cmb = New-Object System.Windows.Forms.ComboBox
$cmb.DropDownStyle = 'DropDownList'; $cmb.FlatStyle = 'Flat'
$cmb.Location = New-Object System.Drawing.Point(60, 334); $cmb.Size = New-Object System.Drawing.Size(280, 26)
$cmb.BackColor = $cBtn; $cmb.ForeColor = $cText; $cmb.Font = $fBody
foreach ($n in 1..4) { [void]$cmb.Items.Add("$n  -  $($udpNames[$n])") }
$cmb.SelectedIndex = (Get-Strategy) - 1

# big button
$btn = New-Object System.Windows.Forms.Button
$btn.Location = New-Object System.Drawing.Point(60, 382); $btn.Size = New-Object System.Drawing.Size(280, 56)
$btn.FlatStyle = 'Flat'; $btn.FlatAppearance.BorderSize = 2; $btn.FlatAppearance.BorderColor = $cGold
$btn.FlatAppearance.MouseOverBackColor = C '#1E282D'; $btn.FlatAppearance.MouseDownBackColor = C '#0A323C'
$btn.BackColor = $cBtn; $btn.ForeColor = $cGoldLt; $btn.Font = $fBtn
$btn.Cursor = [System.Windows.Forms.Cursors]::Hand
$btn.Text = 'START BYPASS'

# start with windows
$chk = New-Object System.Windows.Forms.CheckBox
$chk.Text = 'Start with Windows (hidden in tray)'
$chk.Location = New-Object System.Drawing.Point(62, 454); $chk.Size = New-Object System.Drawing.Size(280, 24)
$chk.ForeColor = $cMuted; $chk.Font = $fSmall; $chk.FlatStyle = 'Flat'; $chk.BackColor = $cBg
$chk.Checked = Get-StartupEnabled

$lblFoot = New-Label 'Closing this window keeps the bypass running in the tray' 0 500 400 22 $fSmall $cGoldDk 'MiddleCenter'

$form.Controls.AddRange(@($lblTitle, $lblMin, $lblClose, $ring, $lblState, $dot1, $row1, $dot2, $row2, $lblStrat, $cmb, $btn, $chk, $lblFoot))

# ---------- tray ----------
$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Icon = $appIcon
$icon.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen    = $menu.Items.Add('Open LoL Bypass')
$miOpen.Font = New-Object System.Drawing.Font($miOpen.Font, [System.Drawing.FontStyle]::Bold)
[void]$menu.Items.Add('-')
$miToggle  = $menu.Items.Add('Stop bypass')
$miRestart = $menu.Items.Add('Restart bypass')
$miLog     = $menu.Items.Add('Open log')
[void]$menu.Items.Add('-')
$miExit    = $menu.Items.Add('Exit (stop bypass)')
$icon.ContextMenuStrip = $menu

function Show-Window {
  Update-Ui
  $form.Show(); $form.WindowState = 'Normal'; $form.Activate(); $form.BringToFront()
}

function Update-Ui {
  $g = Test-Running 'goodbyedpi'; $w = Test-Running 'winws'
  if ($script:paused)  { $state = 'BYPASS OFF';      $col = $cMuted }
  elseif ($g -and $w)  { $state = 'BYPASS ACTIVE';   $col = $cTeal }
  else                 { $state = 'STARTING...';     $col = $cGold }
  $lblState.Text = $state; $lblState.ForeColor = $col
  $dot1.ForeColor = if ($g) { $cTeal } else { $cRed }
  $dot2.ForeColor = if ($w) { $cTeal } else { $cRed }
  $btn.Text = if ($script:paused) { 'START BYPASS' } else { 'STOP BYPASS' }
  $btn.FlatAppearance.BorderColor = if ($script:paused) { $cGold } else { $cGoldDk }
  $miToggle.Text = if ($script:paused) { 'Start bypass' } else { 'Stop bypass' }
  $tip = "LoL Bypass - $($state.ToLower()) - strategy $(Get-Strategy)"
  $icon.Text = $tip.Substring(0, [Math]::Min(63, $tip.Length))
  $ring.Invalidate()
}

function Toggle-Bypass {
  if ($script:paused) { $lblState.Text = 'STARTING...'; $lblState.ForeColor = $cGold; $form.Refresh(); Start-Bypass $true }
  else { Stop-ByUser }
  Update-Ui
}

$btn.Add_Click({ Toggle-Bypass })
$cmb.Add_SelectionChangeCommitted({
  Set-Strategy ($cmb.SelectedIndex + 1)
  if (-not $script:paused) { Start-Bypass $false }
  Update-Ui
})
$chk.Add_CheckedChanged({ Set-StartupEnabled $chk.Checked })

$icon.Add_MouseClick({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-Window } })
$miOpen.Add_Click({ Show-Window })
$miToggle.Add_Click({ Toggle-Bypass })
$miRestart.Add_Click({ Start-Bypass $true; Update-Ui; $icon.ShowBalloonTip(2500, 'LoL Bypass', 'Bypass restarted', 'Info') })
$miLog.Add_Click({ Start-Process notepad.exe $logPath })
$miExit.Add_Click({
  Stop-ByUser
  Write-Log 'exited by user'
  $timer.Stop(); $fast.Stop(); $icon.Visible = $false; $icon.Dispose()
  $script:exiting = $true; $form.Close()
  [System.Windows.Forms.Application]::Exit()
})
$form.Add_FormClosing({ param($s, $e) if (-not $script:exiting) { $e.Cancel = $true; $form.Hide() } })

# watchdog (10 s): restart whichever part died
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 10000
$timer.Add_Tick({
  if (-not $script:paused) {
    if (-not (Test-Running 'goodbyedpi')) { Write-Log 'goodbyedpi not running - restarting'; Start-Gdpi }
    if (-not (Test-Running 'winws'))      { Write-Log 'winws not running - restarting';      Start-Winws }
  }
  Update-Ui
})
# second launch -> show this window
$fast = New-Object System.Windows.Forms.Timer
$fast.Interval = 400
$fast.Add_Tick({ if ($showEvt.WaitOne(0)) { Show-Window } })

# ---------- go ----------
Write-Log "=== LoL Bypass starting from $root (silent=$Silent) ==="
if (-not (Test-Path $gdpiExe) -or -not (Test-Path $winwsExe)) {
  Write-Log 'missing goodbyedpi.exe or winws.exe (antivirus may have removed it)'
  $icon.ShowBalloonTip(8000, 'LoL Bypass', 'winws.exe or goodbyedpi.exe is missing - your antivirus may have removed it. Add an exclusion for this folder and run Install.bat again.', 'Error')
}
Start-Bypass $true
Update-Ui
if ($Silent) { $icon.ShowBalloonTip(2500, 'LoL Bypass', 'Bypass active. Click the tray icon to open.', 'Info') }
else { Show-Window }
$timer.Start(); $fast.Start()
[System.Windows.Forms.Application]::Run()
