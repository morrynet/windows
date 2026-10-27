@echo off
setlocal
cd /d "%~dp0"
set "ROOT=%~dp0"
set "ZIP=%ROOT%runtime\python.zip"
set "PY=%ROOT%runtime\python"
if not exist "%ZIP%" (echo ERROR: python.zip missing & pause & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root='%ROOT%'; $zip='%ZIP%'; $tmp=Join-Path $root 'runtime\repair_tmp'; if(Test-Path $tmp){Remove-Item $tmp -Recurse -Force}; Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force; $exe=Get-ChildItem -Path $tmp -Filter python.exe -Recurse -File | Select-Object -First 1; if(!$exe){throw 'python.exe not found in archive'}; $src=$exe.Directory.FullName; if(Test-Path (Join-Path $root 'runtime\python')){Remove-Item (Join-Path $root 'runtime\python') -Recurse -Force}; Move-Item $src (Join-Path $root 'runtime\python'); Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; Write-Host 'Portable Python repaired successfully.'"
if errorlevel 1 (echo Repair failed.&pause&exit /b 1)
if exist "%PY%\python.exe" ("%PY%\python.exe" --version) else (echo ERROR: python.exe missing)
pause
