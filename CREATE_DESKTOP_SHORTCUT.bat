@echo off
setlocal
set "TARGET=%~dp0START_MORRYNET.bat"
set "DESKTOP=%USERPROFILE%\Desktop"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut([Environment]::GetFolderPath('Desktop')+'\MorryNet Terminal.lnk'); $s.TargetPath='%TARGET%'; $s.WorkingDirectory='%~dp0'; $s.Description='MorryNet V67 - MT5 bridge + terminal (strict SL invariant)'; $s.Save()"
echo Desktop shortcut created: MorryNet Terminal
pause
