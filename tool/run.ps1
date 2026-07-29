# Runs Tripper with the Maps key from android/local.properties, so the key
# lives in exactly one gitignored place. Gradle reads it for the native SDK;
# --dart-define passes it to the Places HTTP calls.
#
#   .\tool\run.ps1            debug on the connected device
#   .\tool\run.ps1 -Release   release build

param([switch]$Release)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$propsPath = Join-Path $root 'android\local.properties'

if (-not (Test-Path $propsPath)) {
    Write-Error 'Missing android/local.properties - see README (Maps API key).'
    exit 1
}

$line = Get-Content $propsPath | Where-Object { $_ -match '^\s*MAPS_API_KEY\s*=' } | Select-Object -First 1
$key = ''
if ($line) {
    $key = ($line -replace '^\s*MAPS_API_KEY\s*=\s*', '').Trim()
}

if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Warning 'MAPS_API_KEY not set in android/local.properties.'
    Write-Warning 'Map will be blank; search falls back to OpenStreetMap.'
}

$mode = '--debug'
if ($Release) { $mode = '--release' }

Push-Location $root
try {
    flutter run $mode "--dart-define=MAPS_API_KEY=$key"
}
finally {
    Pop-Location
}
