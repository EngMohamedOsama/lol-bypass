$ErrorActionPreference = 'SilentlyContinue'
$dest = 'C:\LoL-Bypass'
Write-Host "`n  LOL BYPASS - UNINSTALL`n" -ForegroundColor Yellow
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*LoL-Bypass.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Get-Process goodbyedpi, winws | Stop-Process -Force
Unregister-ScheduledTask -TaskName 'LoL Bypass' -Confirm:$false
Unregister-ScheduledTask -TaskName 'LoL Bypass UI' -Confirm:$false
foreach ($dir in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) { Remove-Item (Join-Path $dir 'LoL Bypass.lnk') -Force }
Remove-MpPreference -ExclusionPath $dest
Start-Sleep -Seconds 1
Remove-Item $dest -Recurse -Force
if (Test-Path $dest) { Write-Host "  Could not delete $dest completely - delete it manually." -ForegroundColor Yellow }
Write-Host '  LoL Bypass removed.' -ForegroundColor Green
Start-Sleep -Seconds 3
