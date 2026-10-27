@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "ROOT=%~dp0"
set "PY=%ROOT%runtime\python\python.exe"
set "BRIDGE=%ROOT%app\mt5_bridge.py"
set "PKG=%ROOT%site-packages"
set "LOGDIR=%ROOT%logs"

echo ============================================================
echo   MORRYNET BRIDGE - single complete setup
echo   WebSocket API  : ws://127.0.0.1:8765
echo   Terminal UI    : http://127.0.0.1:8766/
echo   Health check   : http://127.0.0.1:8766/health
echo   This window shows the LIVE bridge log.
echo ============================================================
echo.

if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

echo [1/4] Checking the embedded Python runtime...
if not exist "%PY%" (
  echo   ERROR: runtime\python\python.exe is missing.
  echo   Extract the FULL MorryNet-Complete folder from the ZIP first -
  echo   do not run it from inside the ZIP preview.
  goto :fatal
)
for /f "delims=" %%V in ('"%PY%" --version 2^>^&1') do echo   OK - %%V

if not exist "%BRIDGE%" (
  echo   ERROR: app\mt5_bridge.py is missing.
  goto :fatal
)

echo [2/4] Checking for an already-running healthy bridge...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$h=$null; try { $h=Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 'http://127.0.0.1:8766/health' } catch {}; if ($h -and $h.StatusCode -eq 200) { exit 0 } else { exit 1 }"
if not errorlevel 1 (
  echo   A healthy bridge is ALREADY running - not starting a second copy.
  echo   Opening the terminal window...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%OPEN_TERMINAL_WHEN_READY.ps1"
  goto :end_ok
)
echo   No healthy bridge running - continuing.

echo [3/4] Clearing stale listeners on ports 8765/8766 (if any)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='SilentlyContinue'; foreach ($port in 8765,8766) { $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue; if ($conns) { $owners = $conns | Select-Object -ExpandProperty OwningProcess -Unique; foreach ($procId in $owners) { if ($procId -and $procId -ne 0) { try { $proc = Get-Process -Id $procId -ErrorAction Stop; Write-Host ('   killing stale listener: ' + $proc.ProcessName + ' (PID ' + $procId + ') on port ' + $port); Stop-Process -Id $procId -Force } catch {} } }; Start-Sleep -Milliseconds 800 } }"
echo   Ports clear.

echo [4/4] Starting the bridge under the supervisor...
echo   (Type N in this window to STOP the bridge, or R for an immediate clean restart.)
echo.

rem Open the terminal window automatically the moment the bridge is UP.
rem Detached + hidden: it just polls the health endpoint quietly and exits.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -WindowStyle Hidden powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','"%ROOT%OPEN_TERMINAL_WHEN_READY.ps1"'"

set "PYTHONPATH=%PKG%"
set "PATH=%ROOT%runtime\python;%ROOT%runtime\python\Scripts;%PATH%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%SUPERVISE_BRIDGE.ps1"
set "SUP_EXIT=%ERRORLEVEL%"

echo.
echo ============================================================
if "%SUP_EXIT%"=="2" (
  echo   Bridge stopped by user ^(N^). Terminal windows can stay open -
  echo   they will reconnect automatically if you start MorryNet again.
) else (
  echo   Supervisor exited ^(code %SUP_EXIT%^).
)
echo ============================================================

:end_ok
echo.
echo You can close this window now. Nothing is running anymore
echo unless you left the watchdog ^(MORRYNET_WATCHDOG.ps1^) running.
pause
exit /b 0

:fatal
echo.
echo ============================================================
echo   START FAILED - see the message above.
echo   If you are stuck, run DIAGNOSE_CONNECTION.bat and follow
echo   its one-page report.
echo ============================================================
pause
exit /b 1
