<#
.SYNOPSIS
  Tripper's local verify loop, bundled: pub get, l10n codegen, format,
  analyze, test — the sequence from CLAUDE.md's Verification section, run
  one command instead of five.

.PARAMETER Quick
  Skip `flutter pub get` and `flutter gen-l10n` — just format + analyze +
  test. Use this for the fast inner loop once dependencies/l10n are
  already up to date; drop -Quick after touching pubspec.yaml or any
  .arb file.

.PARAMETER Build
  Also run `flutter build apk --debug` at the end. Off by default — it's
  slow and most edit/test cycles don't need it; turn it on when you
  specifically want to catch a Gradle-level failure (missing permission,
  manifest error, dependency issue) before installing on device.

.EXAMPLE
  .\scripts\verify.ps1
.EXAMPLE
  .\scripts\verify.ps1 -Quick
.EXAMPLE
  .\scripts\verify.ps1 -Build
#>
param(
    [switch]$Quick,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'

# Always run from the repo root regardless of where this script is called
# from — this file lives in scripts/, so root is one level up.
Set-Location -Path (Join-Path $PSScriptRoot '..')

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "FAILED: $Name (exit code $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

if (-not $Quick) {
    Invoke-Step -Name 'flutter pub get'  -Command 'flutter' -Arguments @('pub', 'get')
    Invoke-Step -Name 'flutter gen-l10n' -Command 'flutter' -Arguments @('gen-l10n')
}

Invoke-Step -Name 'dart format lib test' -Command 'dart'    -Arguments @('format', 'lib', 'test')
Invoke-Step -Name 'flutter analyze'      -Command 'flutter' -Arguments @('analyze')
Invoke-Step -Name 'flutter test'         -Command 'flutter' -Arguments @('test')

if ($Build) {
    Invoke-Step -Name 'flutter build apk --debug' -Command 'flutter' -Arguments @('build', 'apk', '--debug')
}

Write-Host ""
Write-Host 'All checks passed.' -ForegroundColor Green
