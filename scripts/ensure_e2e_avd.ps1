<#
.SYNOPSIS
  Ensure the shared E2E Android Virtual Device exists (nexo_e2e_api35).

.DESCRIPTION
  Creates Pixel 6 / API 35 / Google APIs x86_64 AVD if missing.
  Does not start the emulator.

.EXAMPLE
  pwsh -File scripts/ensure_e2e_avd.ps1
#>
[CmdletBinding()]
param(
  [string]$AvdName = 'nexo_e2e_api35',
  [string]$ApiLevel = '35',
  [string]$Device = 'pixel_6',
  [string]$Tag = 'google_apis',
  [string]$Abi = 'x86_64'
)

$ErrorActionPreference = 'Stop'

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$avdmanagerCandidates = @(
  (Join-Path $sdk 'cmdline-tools\latest\bin\avdmanager.bat'),
  (Join-Path $sdk 'cmdline-tools\bin\avdmanager.bat')
) + @(Get-ChildItem (Join-Path $sdk 'cmdline-tools') -Recurse -Filter 'avdmanager.bat' -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty FullName)
$sdkmanagerCandidates = @(
  (Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'),
  (Join-Path $sdk 'cmdline-tools\bin\sdkmanager.bat')
) + @(Get-ChildItem (Join-Path $sdk 'cmdline-tools') -Recurse -Filter 'sdkmanager.bat' -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty FullName)

if (-not (Test-Path $emulator)) {
  throw "Android emulator not found under $sdk. Install Android SDK Emulator."
}

$existing = & $emulator -list-avds 2>$null
if ($existing -contains $AvdName) {
  Write-Host "AVD already present: $AvdName"
  exit 0
}

$avdmanager = $avdmanagerCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
$sdkmanager = $sdkmanagerCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $avdmanager -or -not $sdkmanager) {
  throw 'cmdline-tools (avdmanager/sdkmanager) not found. Install Android SDK Command-line Tools.'
}

$package = "system-images;android-$ApiLevel;$Tag;$Abi"
Write-Host "Installing system image if needed: $package"
$yes = "y`n" * 20
$yes | & $sdkmanager --sdk_root=$sdk $package | Out-Host

Write-Host "Creating AVD $AvdName (device=$Device)..."
# Non-interactive: accept defaults
'no' | & $avdmanager create avd `
  --force `
  --name $AvdName `
  --device $Device `
  --package $package `
  --tag $Tag `
  --abi $Abi | Out-Host

$check = & $emulator -list-avds 2>$null
if ($check -notcontains $AvdName) {
  throw "AVD creation failed; $AvdName not listed by emulator -list-avds"
}

Write-Host "Created AVD: $AvdName"
Write-Host "System image: $package"
Write-Host "Next: pwsh -File scripts/run_e2e_android.ps1"
