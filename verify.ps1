#!/usr/bin/env pwsh
# Project verification gate: static analysis + full test suite.
# Matches CLAUDE.md's "Verification" section (`flutter analyze && flutter test`),
# the project's standing bar for calling a change done.

$ErrorActionPreference = 'Stop'

Write-Host "==> flutter analyze" -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: flutter analyze reported issues." -ForegroundColor Red
    exit 1
}

Write-Host "==> flutter test" -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL: flutter test reported failures." -ForegroundColor Red
    exit 1
}

Write-Host "PASS" -ForegroundColor Green
exit 0
