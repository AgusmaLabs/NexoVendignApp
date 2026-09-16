<#
.SYNOPSIS
  Start the E2E AVD (if needed) and run VendingApp against local NexoVending.

.DESCRIPTION
  Reads GOOGLE_CLIENT_ID from NexoVending\.env (or -GoogleServerClientId).
  Uses dart-defines documented in docs/E2E_LOCAL_RUN.md.

.PARAMETER GoogleServerClientId
  Web OAuth client ID. If omitted, reads NexoVending\.env GOOGLE_CLIENT_ID.

.PARAMETER VendingEnvPath
  Path to NexoVending .env (default: ..\NexoVending\.env next to this repo).

.PARAMETER AvdName
  Emulator AVD name (default: nexo_e2e_api35).

.PARAMETER SkipEmulatorStart
  Do not launch the AVD; require an already-connected device/emulator.

.EXAMPLE
  pwsh -File scripts/run_e2e_android.ps1
#>
[CmdletBinding()]
param(
  [string]$GoogleServerClientId = '',
  [string]$VendingEnvPath = '',
  [string]$AvdName = 'nexo_e2e_api35',
  [string]$ApiBaseUrl = 'http://10.0.2.2:8000',
  [string]$TenantId = 'tenant-a',
  [int]$HttpTimeoutMs = 30000,
  [switch]$SkipEmulatorStart
)

$ErrorActionPreference = 'Stop'

$appRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $appRoot

function Read-GoogleClientId([string]$envPath) {
  if (-not (Test-Path $envPath)) { return '' }
  foreach ($line in Get-Content $envPath) {
    if ($line -match '^\s*GOOGLE_CLIENT_ID\s*=(.*)$') {
      return $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return ''
}

if (-not $VendingEnvPath) {
  $candidate = Join-Path $appRoot '..\NexoVending\.env'
  if (Test-Path $candidate) {
    $VendingEnvPath = (Resolve-Path $candidate).Path
  }
}

if (-not $GoogleServerClientId) {
  if ($VendingEnvPath) {
    $GoogleServerClientId = Read-GoogleClientId $VendingEnvPath
  }
  if (-not $GoogleServerClientId -and (Test-Path "$env:TEMP\nexo_google_client_id.txt")) {
    $GoogleServerClientId = (Get-Content "$env:TEMP\nexo_google_client_id.txt" -Raw).Trim()
  }
}

if (-not $GoogleServerClientId) {
  throw @'
GOOGLE_SERVER_CLIENT_ID missing.
Set GOOGLE_CLIENT_ID in NexoVending\.env or pass -GoogleServerClientId.
'@
}

if ($GoogleServerClientId.Length -lt 20 -or -not $GoogleServerClientId.EndsWith('.apps.googleusercontent.com')) {
  throw 'GOOGLE_CLIENT_ID does not look like a Web OAuth client ID (*.apps.googleusercontent.com).'
}

# Persist for subsequent runs without printing the value.
Set-Content -Path "$env:TEMP\nexo_google_client_id.txt" -Value $GoogleServerClientId -NoNewline

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$env:ANDROID_HOME = $sdk
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'

if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
  $jbr = 'C:\Program Files\Android\Android Studio\jbr'
  if (Test-Path $jbr) { $env:JAVA_HOME = $jbr }
}

$env:Path = "$env:JAVA_HOME\bin;$sdk\platform-tools;$sdk\emulator;$env:Path"
if (-not $env:PROGRAMFILES_X86) {
  $env:PROGRAMFILES_X86 = ${env:ProgramFiles(x86)}
  if (-not $env:PROGRAMFILES_X86) { $env:PROGRAMFILES_X86 = 'C:\Program Files (x86)' }
}

function Test-AdbDevice {
  $lines = & $adb devices 2>$null | Select-Object -Skip 1
  return [bool]($lines | Where-Object { $_ -match 'device$' })
}

if (-not $SkipEmulatorStart) {
  if (-not (Test-AdbDevice)) {
    $avds = & $emulator -list-avds 2>$null
    if ($avds -notcontains $AvdName) {
      Write-Host "AVD $AvdName missing - running ensure_e2e_avd.ps1"
      & (Join-Path $PSScriptRoot 'ensure_e2e_avd.ps1') -AvdName $AvdName
    }
    Write-Host "Starting emulator $AvdName ..."
    Start-Process -FilePath $emulator -ArgumentList @('-avd', $AvdName, '-netdelay', 'none', '-netspeed', 'full') -WindowStyle Normal
    $deadline = (Get-Date).AddMinutes(4)
    do {
      Start-Sleep -Seconds 3
      if (Test-AdbDevice) { break }
    } while ((Get-Date) -lt $deadline)
    if (-not (Test-AdbDevice)) {
      throw 'Emulator did not become ready (adb devices) within 4 minutes.'
    }
    & $adb wait-for-device | Out-Null
    # Wait until boot completed
    $bootDeadline = (Get-Date).AddMinutes(3)
    do {
      $boot = (& $adb shell getprop sys.boot_completed 2>$null | Out-String).Trim()
      if ($boot -eq '1') { break }
      Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $bootDeadline)
  }
}

Write-Host "cid_len=$($GoogleServerClientId.Length) api=$ApiBaseUrl tenant=$TenantId"
Write-Host 'Launching flutter run (debug + cleartext + legacy JNI packaging)...'

$defines = @(
  '--dart-define=APP_ENV=development',
  "--dart-define=API_BASE_URL=$ApiBaseUrl",
  "--dart-define=TENANT_ID=$TenantId",
  "--dart-define=HTTP_TIMEOUT_MS=$HttpTimeoutMs",
  "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleServerClientId"
)

& flutter run -d emulator-5554 @defines
if ($LASTEXITCODE -ne 0) {
  # Fall back to any connected device id
  $dev = (& $adb devices | Select-String '\tdevice$' | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1)
  if ($dev) {
    Write-Host "Retrying on device $dev"
    & flutter run -d $dev @defines
  }
  exit $LASTEXITCODE
}
