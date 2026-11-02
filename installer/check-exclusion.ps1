param([string]$Path)
# Exit 0 = exclusion present, 1 = Defender active but exclusion missing, 2 = Defender not the active AV.
# Tries to add it silently first (works only if Tamper Protection is off); then verifies.
$ErrorActionPreference = 'SilentlyContinue'
$s = Get-MpComputerStatus
if (-not $s -or -not $s.RealTimeProtectionEnabled) { exit 2 }
try { Add-MpPreference -ExclusionPath $Path -ErrorAction Stop } catch {}
$target = $Path.TrimEnd('\').ToLower()
$hit = @((Get-MpPreference).ExclusionPath) | Where-Object { $_ -and ($_.TrimEnd('\').ToLower() -eq $target) }
if ($hit) { exit 0 } else { exit 1 }
