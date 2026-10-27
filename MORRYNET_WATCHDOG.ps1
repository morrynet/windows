$ErrorActionPreference = 'SilentlyContinue'
Set-Location -LiteralPath $PSScriptRoot
$root = $PSScriptRoot
$py = Join-Path $root 'runtime\python\python.exe'
$bridge = Join-Path $root 'app\mt5_bridge.py'
# Pick the newest MorryNet*.html in the folder instead of hardcoding the V31
# filename -- dropping in a newer terminal (e.g. MorryNet-Terminal-V45_EMBEDDED_BRIDGE.html)
# used to leave the watchdog pointing at a file that no longer exists.
$html = (Get-ChildItem -LiteralPath $root -Filter 'MorryNet*.html' -File |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
if (-not $html) { $html = Join-Path $root 'MorryNet_Super_Terminal_V31_WATCHLIST_ONCHART_MT5.html' }
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$log = Join-Path $logs 'morrynet_watchdog.log'
$pkg = Join-Path $root 'site-packages'
$bridgeLog = Join-Path $logs 'bridge_watchdog.log'
$bridgeErrLog = Join-Path $logs 'bridge_watchdog.err.log'
$port = 8765
$bridgeRestartCooldown = 15
$lastBridgeStart = Get-Date '2000-01-01'
$bridgeDownSince = $null
$browser = $null
$browserExe = $null

function Log($m) {
  $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $m"
  Add-Content -LiteralPath $log -Value $line
}

function Find-Browser {
  $candidates = @(
    @{Name='msedge.exe'; Paths=@("$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe", "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe")},
    @{Name='chrome.exe'; Paths=@("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")}
  )
  foreach ($c in $candidates) { foreach ($p in $c.Paths) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } } }
  return $null
}

function Start-Bridge {
  if (-not (Test-Path -LiteralPath $py) -or -not (Test-Path -LiteralPath $bridge)) { Log 'FATAL: portable Python or bridge script missing.'; return $false }
  try {
    # CONNECT FIX: the bundled wheels live in .\site-packages, which the
    # portable Python does not look in by itself. START_APEX_BRIDGE.bat sets
    # PYTHONPATH before launching; this watchdog did not, so every bridge it
    # started died instantly on "import MetaTrader5" / "import websockets",
    # port 8765 never opened, and the watchdog just respawned the same broken
    # process forever while the terminal showed "not connecting".
    $env:PYTHONPATH = $pkg
    $p = Start-Process -FilePath $py -ArgumentList @($bridge) -WorkingDirectory $root `
                       -WindowStyle Hidden -PassThru `
                       -RedirectStandardOutput $bridgeLog -RedirectStandardError $bridgeErrLog
    $script:lastBridgeStart = Get-Date
    Log "Started bridge PID $($p.Id) (PYTHONPATH=$pkg, output -> $bridgeLog)."
    return $true
  } catch { Log "Bridge start failed: $($_.Exception.Message)"; return $false }
}

function Stop-BridgeCopies {
  try {
    $procs = Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'"
    foreach ($p in $procs) {
      if ($p.CommandLine -and $p.CommandLine -match [regex]::Escape($bridge)) {
        Stop-Process -Id $p.ProcessId -Force
        Log "Stopped stale bridge PID $($p.ProcessId)."
      }
    }
  } catch {}
}

function Test-BridgePort {
  try {
    $c = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue
    return [bool]$c
  } catch {
    try { $t = New-Object Net.Sockets.TcpClient; $t.Connect('127.0.0.1',$port); $t.Close(); return $true } catch { return $false }
  }
}

function Start-Terminal {
  if (-not (Test-Path -LiteralPath $html)) { Log 'FATAL: MorryNet HTML missing.'; return }
  if (-not $script:browserExe) { $script:browserExe = Find-Browser }
  $uri = [Uri]::new($html).AbsoluteUri
  if ($script:browserExe) {
    try {
      $profileDir = Join-Path $root 'browser_profile'
      New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
      $browserArgs = @("--app=$uri", "--user-data-dir=$profileDir", '--no-first-run', '--no-default-browser-check')
      $script:browser = Start-Process -FilePath $script:browserExe -ArgumentList $browserArgs -PassThru
      Log "Started embedded MorryNet terminal PID $($script:browser.Id) using $($script:browserExe)."
      return
    } catch { Log "App-mode browser start failed: $($_.Exception.Message)" }
  }
  try {
    $script:browser = Start-Process -FilePath $html -PassThru
    Log "Started MorryNet terminal with default browser PID $($script:browser.Id)."
  } catch { Log "Browser start failed: $($_.Exception.Message)" }
}

function Restart-Terminal {
  try { if ($script:browser -and -not $script:browser.HasExited) { Stop-Process -Id $script:browser.Id -Force } } catch {}
  $script:browser = $null
  Start-Terminal
}

Log 'MorryNet watchdog started.'
if (-not (Test-BridgePort)) { Log 'No bridge listening on 8765 at startup - starting one.'; Start-Bridge | Out-Null }
Start-Terminal
while ($true) {
  Start-Sleep -Seconds 2
  $healthy = Test-BridgePort
  $now = Get-Date

  if ($healthy) {
    $bridgeDownSince = $null
  } else {
    if ($null -eq $bridgeDownSince) { $bridgeDownSince = $now; Log 'Bridge port 8765 is DOWN.' }
    $elapsed = ($now - $bridgeDownSince).TotalSeconds
    if (($elapsed -ge 5) -and (($now - $lastBridgeStart).TotalSeconds -ge $bridgeRestartCooldown)) {
      Log "Bridge unavailable for $([int]$elapsed)s — restarting bridge outright."
      Stop-BridgeCopies
      Start-Sleep -Milliseconds 500
      Start-Bridge | Out-Null
      $bridgeDownSince = $now
      # Give the HTML a chance to reconnect first; if it remains stale, restart the app outright.
      Start-Sleep -Seconds 3
      if (-not (Test-BridgePort)) { Restart-Terminal }
    }
    if ($elapsed -ge 20) { Log 'Bridge still unavailable after 20s — restarting terminal outright.'; Restart-Terminal; $bridgeDownSince = $now }
  }

  try { if (-not $script:browser -or $script:browser.HasExited) { Log 'Terminal process exited — relaunching.'; Start-Terminal } } catch { Start-Terminal }
}
