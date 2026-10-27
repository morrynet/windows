@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "ROOT=%~dp0"
set "PY=%ROOT%runtime\python\python.exe"
set "PKG=%ROOT%site-packages"
set "LOGDIR=%ROOT%logs"

echo ============================================================
echo   MORRYNET V31 - CONNECTION DIAGNOSTIC
echo ============================================================
echo.

echo [1] Portable Python
if exist "%PY%" ("%PY%" --version) else (echo    MISSING: %PY%)
echo.

echo [2] Bundled packages (with PYTHONPATH=%PKG%)
set "PYTHONPATH=%PKG%"
"%PY%" -c "import numpy; print('    numpy', numpy.__version__)" 2>&1
"%PY%" -c "import websockets; print('    websockets', websockets.__version__)" 2>&1
"%PY%" -c "import MetaTrader5 as m; print('    MetaTrader5', m.__version__)" 2>&1
echo.

echo [3] Is MT5 terminal running?
tasklist /fi "imagename eq terminal64.exe" 2>nul | find /i "terminal64.exe" >nul && (echo     terminal64.exe is running) || (echo     terminal64.exe NOT running - open MT5 and log in)
echo.

echo [4] Is anything listening on port 8765?
netstat -ano | findstr ":8765" && (echo     Port 8765 is OPEN - the bridge is up) || (echo     Nothing is listening on 8765 - the bridge is NOT running)
echo.

echo [5] WebSocket handshake test (127.0.0.1 and localhost)
rem Single-line python: a multi-line -c does not survive a .bat file.
"%PY%" -c "exec('import asyncio, json, websockets\nasync def t(u):\n    try:\n        async with websockets.connect(u, open_timeout=5) as ws:\n            await ws.send(json.dumps({\'type\':\'hello\',\'client\':\'diagnostic\'}))\n            print(\'    OK  \', u)\n    except Exception as e:\n        print(\'    FAIL\', u, \'->\', type(e).__name__, e)\nasync def m():\n    await asyncio.gather(t(\'ws://127.0.0.1:8765\'), t(\'ws://localhost:8765\'))\nasyncio.run(m())')" 2>&1
echo.

echo [6] Last 25 lines of logs\bridge.log
if exist "%LOGDIR%\bridge.log" (powershell.exe -NoProfile -Command "Get-Content -LiteralPath '%LOGDIR%\bridge.log' -Tail 25") else (echo     no bridge.log yet)
echo.

echo [7] Last 15 lines of logs\dependency_check.log
if exist "%LOGDIR%\dependency_check.log" (powershell.exe -NoProfile -Command "Get-Content -LiteralPath '%LOGDIR%\dependency_check.log' -Tail 15") else (echo     no dependency_check.log yet)
echo.

pause
