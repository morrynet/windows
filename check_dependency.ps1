# MORRYNET V31 - dependency import test with a hard timeout.
#
# Takes a MODULE NAME, never a code string. An argument like
#   -Code "import numpy; print(numpy.__version__)"
# loses everything after the first space crossing the cmd.exe -> powershell
# -File boundary, so python received just "import" and raised a SyntaxError.
# A bare module name has no spaces, quotes or semicolons, so there is nothing
# left to mangle; this script builds the -c snippet itself.
#
# Exit codes: 0 = import OK, 124 = timed out, anything else = import failed.
param(
  [Parameter(Mandatory = $true)][string]$Python,
  [Parameter(Mandatory = $true)][string]$PkgPath,
  [Parameter(Mandatory = $true)][string]$Module,
  [int]$TimeoutSeconds = 12,
  [string]$LogFile
)

$ErrorActionPreference = 'Continue'

function Write-Both([string]$text) {
  Write-Host $text
  if ($LogFile) { try { Add-Content -LiteralPath $LogFile -Value $text } catch {} }
}

if ($Module -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
  Write-Both "Refusing to test suspicious module name: $Module"
  exit 2
}
if (-not (Test-Path -LiteralPath $Python)) {
  Write-Both "Portable Python not found: $Python"
  exit 2
}

$code = "import $Module as _m; print('$Module', getattr(_m, '__version__', 'unknown'))"

# System.Diagnostics.Process rather than Start-Process: Start-Process's
# -PassThru object can hand back a null ExitCode, which "exit $null" turns
# into 0 -- that is why the previous version printed a SyntaxError and then
# cheerfully reported "numpy OK."
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $Python
$psi.UseShellExecute        = $false
$psi.CreateNoWindow         = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.Arguments = '-c "' + $code.Replace('"', '\"') + '"'
$psi.EnvironmentVariables['PYTHONPATH'] = $PkgPath

try {
  $p = [System.Diagnostics.Process]::Start($psi)
} catch {
  Write-Both "Could not start Python: $($_.Exception.Message)"
  exit 3
}

# Read both streams asynchronously so a chatty import cannot fill a pipe
# buffer and deadlock while we wait on the process.
$stdout = $p.StandardOutput.ReadToEndAsync()
$stderr = $p.StandardError.ReadToEndAsync()

if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
  try { $p.Kill() } catch {}
  Write-Both "TIMEOUT after $TimeoutSeconds seconds importing $Module"
  exit 124
}

foreach ($t in @($stdout, $stderr)) {
  $text = $t.Result
  if ($text) { foreach ($line in $text -split "`r?`n") { if ($line.Trim()) { Write-Both "    $line" } } }
}

$rc = $p.ExitCode
if ($null -eq $rc) { $rc = 1 }
exit $rc
