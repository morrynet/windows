$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$py = Join-Path $root 'runtime\python\python.exe'
$wheelDir = Join-Path $root 'offline_wheels'
$pkg = Join-Path $root 'site-packages'
if (!(Test-Path $py)) { throw "Portable Python not found: $py" }
New-Item -ItemType Directory -Path $pkg -Force | Out-Null
$files = @(
  'numpy-2.5.1-cp313-cp313-win_amd64.whl',
  'metatrader5-5.0.5488-cp313-cp313-win_amd64.whl',
  'websockets-14.2-cp313-cp313-win_amd64.whl'
)
foreach ($f in $files) {
  $p = Join-Path $wheelDir $f
  if (!(Test-Path $p)) { throw "Missing offline wheel: $p" }
  Write-Host "Installing $f ..."
  & $py -m pip install --no-index --no-deps --target $pkg $p
  if ($LASTEXITCODE -ne 0) { throw "pip failed for $f" }
}
$env:PYTHONPATH = $pkg
& $py -c "import numpy; print('NumPy', numpy.__version__)"
& $py -c "import websockets; print('websockets', websockets.__version__)"
& $py -c "import MetaTrader5 as mt5; print('MetaTrader5', mt5.__version__)"
Write-Host "Offline dependencies installed successfully."
