# build.ps1 -- build the zho variant (simulator / unit test / release)
# Usage (from repo root):
#   simulator:   pwsh scripts/build.ps1 -Device fr57047mm
#   unit test:   pwsh scripts/build.ps1 -Device fr57047mm -UnitTest
#   release:     pwsh scripts/build.ps1 -Release -Key <developer-key.der>
param(
  [string]$Device = 'fr57047mm',
  [switch]$UnitTest,
  [switch]$Release,
  [string]$Key = ''
)
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path

# locate the SDK (default install: %APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-*, newest wins)
$sdkRoot = Join-Path $env:APPDATA 'Garmin\ConnectIQ\Sdks'
$sdkDirs = @()
if (Test-Path $sdkRoot) {
  $sdkDirs = Get-ChildItem $sdkRoot -Directory -Filter 'connectiq-sdk-win-*' | Sort-Object Name -Descending
}
if ($sdkDirs.Count -eq 0) {
  Write-Error "Connect IQ SDK not found (looked in $sdkRoot). Install it from https://developer.garmin.com/connect-iq/sdk/"
}
$monkeyc = Join-Path $sdkDirs[0].FullName 'bin\monkeyc.bat'
if (-not (Test-Path $monkeyc)) { Write-Error "monkeyc.bat not found: $monkeyc" }
Write-Host "SDK: $($sdkDirs[0].FullName)"

$jungle = Join-Path $root 'monkey-zho.jungle'
$outDir = Join-Path $root 'releases'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

if ($Release) {
  if (-not $Key -or -not (Test-Path $Key)) { Write-Error "-Release requires -Key <developer-key.der>" }
  $out = Join-Path $outDir 'AboutTime-zho.iq'
  Write-Host "monkeyc -f monkey-zho.jungle -e -y $Key -o $out"
  & $monkeyc -f $jungle -e -y $Key -o $out
} else {
  $out = Join-Path $outDir 'AboutTime-zho.prg'
  $args = @('-f', $jungle, '-d', $Device, '-o', $out, '-r', '-O', '2')
  if ($Key -and (Test-Path $Key)) { $args += @('-y', $Key) }
  elseif (Test-Path (Join-Path (Split-Path $root -Parent) 'developer_key.der')) { $args += @('-y', (Join-Path (Split-Path $root -Parent) 'developer_key.der')) }
  if ($UnitTest) { $args += '--unit-test' }
  Write-Host "monkeyc $($args -join ' ')"
  & $monkeyc @args
}
Write-Host "exit=$LASTEXITCODE"
exit $LASTEXITCODE

