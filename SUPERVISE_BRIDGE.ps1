# SUPERVISE_BRIDGE.ps1 -- MorryNet V67 user-mode bridge supervisor.
#
# Runs the embedded-Python MT5 bridge as a child process, shows its LIVE
# log in this window, mirrors it to logs\bridge.log, and supervises it:
#
#   * EXIT CODE 81  : planned FRESHNESS recycle (the bridge exits by itself
#                     after 8h of uptime, at a quiet moment, so the trading
#                     path stays fresh). This supervisor relaunches a clean
#                     copy INSTANTLY -- no penalty, nothing to babysit. Tuned
#                     configs live on disk (apex_bridge\, browser_profile\)
#                     and are picked back up automatically.
#   * ANY OTHER EXIT: restarts the bridge after a 3s pause (crash recovery).
#   * KEY N         : stop the bridge and exit this supervisor (exit code 2).
#   * KEY R         : stop the bridge and IMMEDIATELY relaunch a clean copy.
#   * Closing this window stops the bridge for good.
#
# Windows PowerShell 5.1 compatible. No admin rights required.
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$py   = Join-Path $root 'runtime\python\python.exe'
$bridge = Join-Path $root 'app\mt5_bridge.py'
$pkg  = Join-Path $root 'site-packages'
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$bridgeLog = Join-Path $logs 'bridge.log'

if (-not (Test-Path -LiteralPath $py))    { Write-Host "FATAL: $py not found"; exit 1 }
if (-not (Test-Path -LiteralPath $bridge)) { Write-Host "FATAL: $bridge not found"; exit 1 }

# Freshness recycle config (exit code 81 from the bridge).
$FRESHNESS_EXIT_CODE = 81

# Simple bounded log rotation so bridge.log never grows without limit.
try {
  if (Test-Path -LiteralPath $bridgeLog) {
    if ((Get-Item -LiteralPath $bridgeLog).Length -gt 20MB) {
      $old = "$bridgeLog.old"
      if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
      Move-Item -LiteralPath $bridgeLog -Destination $old -Force
    }
  }
} catch {}

# Synchronized queue bridging the async output events -> main poll loop.
$Global:MnLineQueue = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))

function Start-BridgeProcess {
  # Fresh log marker per launch so each run's log is easy to find.
  $stamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  Add-Content -LiteralPath $bridgeLog -Value ""
  Add-Content -LiteralPath $bridgeLog -Value "============================================================"
  Add-Content -LiteralPath $bridgeLog -Value "  MORRYNET BRIDGE started by supervisor - $stamp"
  Add-Content -LiteralPath $bridgeLog -Value "============================================================"

  $env:PYTHONPATH = $pkg
  $pinfo = New-Object System.Diagnostics.ProcessStartInfo
  $pinfo.FileName = $py
  $pinfo.Arguments = '"' + $bridge + '"'
  $pinfo.WorkingDirectory = $root
  $pinfo.UseShellExecute = $false
  $pinfo.RedirectStandardOutput = $true
  $pinfo.RedirectStandardError = $true
  $pinfo.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $pinfo
  # Direct .NET event handlers (threadpool threads -> synchronized queue).
  # This is the reliable PS 5.1 live-tail pattern: the main loop dequeues and
  # prints, so all console writes stay on the pipeline thread.
  $outHandler = {
    param($sender, $e)
    if ($e.Data) { $Global:MnLineQueue.Enqueue($e.Data) }
  }
  $errHandler = {
    param($sender, $e)
    if ($e.Data) { $Global:MnLineQueue.Enqueue('[stderr] ' + $e.Data) }
  }
  $p.add_OutputDataReceived($outHandler)
  $p.add_ErrorDataReceived($errHandler)
  $null = $p.Start()
  $p.BeginOutputReadLine()
  $p.BeginErrorReadLine()
  return $p
}

function Stop-BridgeProcess($p) {
  if ($p -and -not $p.HasExited) {
    try { $p.Kill() } catch {}
    try { $p.WaitForExit(5000) | Out-Null } catch {}
  }
}

function Drain-Queue([bool]$ToConsole = $true) {
  while ($Global:MnLineQueue.Count -gt 0) {
    $line = [string]$Global:MnLineQueue.Dequeue()
    Add-Content -LiteralPath $bridgeLog -Value $line
    if ($ToConsole) { Write-Host $line }
  }
}

$launchCount = 0
:supervise while ($true) {
  $launchCount++
  if ($launchCount -gt 1) { Write-Host "" }
  $p = Start-BridgeProcess

  $userStopped = $false
  $cleanRestart = $false

  # -- LIVE LOG + KEYBOARD POLL LOOP --------------------------------
  $keysOk = $true
  try { $null = [Console]::KeyAvailable } catch { $keysOk = $false }
  while (-not $p.HasExited) {
    Drain-Queue $true
    if ($keysOk) {
      $pressed = $false
      try { $pressed = [Console]::KeyAvailable } catch { $keysOk = $false }
      if ($pressed) {
      $key = [Console]::ReadKey($true)
      $k = $key.KeyChar.ToString().ToUpperInvariant()
      if ($k -eq 'N') {
        Write-Host ""
        Write-Host "  N received - stopping the bridge..."
        Stop-BridgeProcess $p
        $userStopped = $true
        break
      }
      elseif ($k -eq 'R') {
        Write-Host ""
        Write-Host "  R received - stopping the bridge for an immediate clean restart..."
        Stop-BridgeProcess $p
        $cleanRestart = $true
        break
      }
      }
    }
    Start-Sleep -Milliseconds 150
  }
  # Flush any tail lines still queued after exit.
  Start-Sleep -Milliseconds 400
  Drain-Queue $true

  $code = 0
  try { $code = $p.ExitCode } catch { $code = -1 }
  try { $p.Dispose() } catch {}

  if ($userStopped) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  Bridge stopped by user (N)."
    Write-Host "  Close this window to stop the supervisor for good."
    Write-Host "============================================================"
    exit 2
  }

  if ($cleanRestart) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  Clean restart requested (R) - relaunching a fresh copy..."
    Write-Host "============================================================"
    Start-Sleep -Milliseconds 800
    continue
  }

  if ($code -eq $FRESHNESS_EXIT_CODE) {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "  Bridge exited (code 81) - planned FRESHNESS recycle."
    Write-Host "  Relaunching a clean copy INSTANTLY. Tuned configs on"
    Write-Host "  disk (apex_bridge\, browser_profile\) are preserved."
    Write-Host "============================================================"
    continue
  }

  Write-Host ""
  Write-Host "============================================================"
  Write-Host "  Bridge process exited (code $code). Restarting in 3s."
  Write-Host "  Close this window to stop the bridge for good."
  Write-Host "============================================================"
  Start-Sleep -Seconds 3
}
