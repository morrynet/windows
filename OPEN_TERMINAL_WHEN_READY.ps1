# OPEN_TERMINAL_WHEN_READY.ps1 -- MorryNet V67 terminal-window opener.
#
# Waits (up to ~4 minutes) for the bridge's health endpoint at
# http://127.0.0.1:8766/health to answer, then opens the MorryNet terminal
# window:
#   * Preferred: Microsoft Edge in --app mode with a PERSISTENT profile
#     folder (browser_profile\) -- the window looks like a desktop app and
#     keeps its tuned settings/localStorage across restarts and freshness
#     recycles.
#   * Fallback: your default browser.
#
# After a freshness recycle the already-open terminal page reconnects to
# the bridge automatically, so this script only opens a window when none
# was opened for THIS start of MorryNet.
$ErrorActionPreference = 'SilentlyContinue'
$root = $PSScriptRoot
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$openLog = Join-Path $logs 'terminal_open.log'
$healthUrl = 'http://127.0.0.1:8766/health'
$terminalUrl = 'http://127.0.0.1:8766/'
$profileDir = Join-Path $root 'browser_profile'

function Log($m) {
  $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m"
  Add-Content -LiteralPath $openLog -Value $line
}

Log "waiting for bridge health at $healthUrl ..."
$ready = $false
for ($i = 0; $i -lt 160; $i++) {
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 $healthUrl
    if ($resp -and $resp.StatusCode -eq 200) { $ready = $true; break }
  } catch {}
  Start-Sleep -Milliseconds 1500
}

if (-not $ready) {
  Log "health endpoint never answered - giving up (bridge may still be starting; open $terminalUrl manually)"
  exit 1
}
Log "bridge is UP - opening the terminal window"

$edgePaths = @(
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
)
$edge = $null
foreach ($p in $edgePaths) { if ($p -and (Test-Path -LiteralPath $p)) { $edge = $p; break } }

if ($edge) {
  New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
  $args_ = "--app=$terminalUrl --user-data-dir=`"$profileDir`" --no-first-run --no-default-browser-check"
  Start-Process -FilePath $edge -ArgumentList $args_
  Log "terminal window opened (Edge app mode, persistent profile: $profileDir)"
} else {
  Start-Process $terminalUrl
  Log "terminal window opened (default browser; Edge not found for app mode)"
}
