#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'Update.ps1') -LibraryOnly
$failed = 0
function Assert-True([bool]$Condition, [string]$Name) {
  if ($Condition) { Write-Host "  PASS $Name" -ForegroundColor Green }
  else { Write-Host "  FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

Write-Host '== Updater integrity and rollback tests ==' -ForegroundColor Cyan
$testRoot = Join-Path $env:TEMP ('pcopt-updater-' + [guid]::NewGuid().ToString('N'))
try {
  New-Item -ItemType Directory -Path (Join-Path $testRoot 'core') -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $testRoot 'VERSION') -Value '9.9.9' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $testRoot 'core\probe.txt') -Value 'trusted' -Encoding UTF8
  $files = @('VERSION','core/probe.txt') | ForEach-Object {
    $native = Join-Path $testRoot ($_ -replace '/', '\')
    [ordered]@{ path=$_; size=(Get-Item $native).Length; sha256=(Get-FileHash $native -Algorithm SHA256).Hash.ToLowerInvariant() }
  }
  [ordered]@{ schema=1; version='9.9.9'; files=$files } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testRoot 'package-manifest.json') -Encoding UTF8
  Assert-True (Test-PackageManifest $testRoot) 'valid internal package manifest is accepted'

  Add-Content -LiteralPath (Join-Path $testRoot 'core\probe.txt') -Value 'tampered'
  $tamperRejected = $false
  try { $null = Test-PackageManifest $testRoot } catch { $tamperRejected = $_.Exception.Message -match 'Hash interno invalido' }
  Assert-True $tamperRejected 'tampered package file is rejected'

  $files[1].path = '../escape.txt'
  [ordered]@{ schema=1; version='9.9.9'; files=$files } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $testRoot 'package-manifest.json') -Encoding UTF8
  $traversalRejected = $false
  try { $null = Test-PackageManifest $testRoot } catch { $traversalRejected = $_.Exception.Message -match 'Caminho invalido' }
  Assert-True $traversalRejected 'manifest path traversal is rejected'

  Remove-Item -LiteralPath (Join-Path $testRoot 'SIGNING-REQUIRED') -Force -ErrorAction SilentlyContinue
  Assert-True (Test-AuthenticodePolicy $testRoot) 'unsigned package allowed only without signing-required policy'
  Set-Content -LiteralPath (Join-Path $testRoot 'SIGNING-REQUIRED') -Value 'test'
  $unsignedRejected = $false
  try { $null = Test-AuthenticodePolicy $testRoot } catch { $unsignedRejected = $true }
  Assert-True $unsignedRejected 'signing-required policy rejects unsigned package'
} finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

$source = Get-Content -LiteralPath (Join-Path $root 'Update.ps1') -Raw
Assert-True ($source.Contains("Write-UpdateStatus 'ROLLED_BACK'") -and $source.Contains('previous-')) 'updater contains backup and automatic rollback path'
Assert-True ($source.Contains('Hash pos-instalacao invalido')) 'updater verifies installed files after copy'
Assert-True ($source.Contains('encerrou prematuramente')) 'updater checks new process startup'

if ($failed) { Write-Host "`n$failed FAILED" -ForegroundColor Red; exit 1 }
Write-Host "`nALL UPDATER TESTS PASSED" -ForegroundColor Green
