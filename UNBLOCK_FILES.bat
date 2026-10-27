@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "MORRYNET_ROOT=%~dp0"

echo ============================================================
echo   MORRYNET UNBLOCK - run this ONCE after extracting,
echo   if Windows blocks or warns about MorryNet's files.
echo ============================================================
echo.
echo Windows marks files that arrived via a download as "blocked",
echo which triggers SmartScreen and "came from another computer"
echo warnings for .bat and .ps1 files. This script clears those
echo marks on every file in this folder. Nothing else is changed.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$r=$env:MORRYNET_ROOT; Get-Item -LiteralPath $r | Unblock-File; $n=0; Get-ChildItem -LiteralPath $r -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { try { Unblock-File -LiteralPath $_.FullName -ErrorAction Stop; $n++ } catch {} }; Write-Host ('   Unblocked ' + $n + ' files under ' + $r)"

echo.
echo Done. Now double-click START_MORRYNET.bat again.
echo.
echo If python.exe keeps disappearing or the bridge complains, your
echo antivirus may be quarantining it: restore it from the AV's
echo protection history, exclude the MorryNet folder, then run
echo REPAIR_APEX_RUNTIME.bat.
echo.
pause
exit /b 0
