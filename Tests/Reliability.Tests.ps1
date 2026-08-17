#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'Engine.ps1')
$failed = 0
function Assert-True([bool]$Condition, [string]$Name) {
  if ($Condition) { Write-Host "  PASS $Name" -ForegroundColor Green }
  else { Write-Host "  FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

Write-Host '== Reliability and fault-injection tests ==' -ForegroundColor Cyan

$watch = [Diagnostics.Stopwatch]::StartNew(); $timedOut = $false
try { $null = Invoke-ExternalChecked 'powershell.exe' @('-NoProfile','-Command','Start-Sleep -Seconds 5') @(0) 'timeout-test' 1 }
catch { $timedOut = $_.Exception.Message -match 'limite de 1s' }
$watch.Stop()
Assert-True ($timedOut -and $watch.Elapsed.TotalSeconds -lt 4) 'hung subprocess is terminated by timeout'

$fallbackOrder = New-Object Collections.Generic.List[int]
$value = Invoke-WithFallback 'fault injection' @(
  { $fallbackOrder.Add(1); throw 'primary unavailable' },
  { $fallbackOrder.Add(2); return 'recovered' }
)
Assert-True ($value -eq 'recovered' -and ($fallbackOrder -join ',') -eq '1,2') 'fallback order is deterministic'

$probe = Join-Path $env:TEMP ('pcopt-rollback-' + [guid]::NewGuid().ToString('N') + '.tmp')
Start-ActionTransaction 'rollback-test'
Set-Content -LiteralPath $probe -Value 'changed'
$probeCopy = $probe
Add-RollbackStep 'temporary probe' ({ Remove-Item -LiteralPath $probeCopy -Force -ErrorAction Stop }.GetNewClosure())
Undo-ActionTransaction
Assert-True (-not (Test-Path -LiteralPath $probe)) 'action rollback executes compensating steps'

$batchProbe = Join-Path $env:TEMP ('pcopt-batch-rollback-' + [guid]::NewGuid().ToString('N') + '.tmp')
$batchProbeCopy = $batchProbe
$batch = Invoke-OptimizationBatch -Ids @('fault') -Actions @{
  fault = @{ Nome='Injected failure'; Act={
    Set-Content -LiteralPath $batchProbeCopy -Value 'partial change'
    Add-RollbackStep 'batch probe' ({ Remove-Item -LiteralPath $batchProbeCopy -Force }.GetNewClosure())
    throw 'injected action failure'
  }.GetNewClosure() }
}
Assert-True ($batch.Failed -and $batch.ActionResults.Count -eq 1 -and $batch.ActionResults[0].Status -eq 'FAILED') 'batch exposes failed action result'
Assert-True (-not (Test-Path -LiteralPath $batchProbe)) 'batch automatically rolls back failed action'

$regPath = 'HKCU:\Software\PCOtimizador\ReliabilityTest'
try {
  Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
  Start-ActionTransaction 'registry-idempotence'
  Set-RegDword $regPath 'Probe' 1
  Set-RegDword $regPath 'Probe' 1
  Assert-True (((Get-ItemProperty $regPath).Probe) -eq 1) 'registry action is idempotent'
  Undo-ActionTransaction
  Assert-True (-not (Test-Path $regPath)) 'registry transaction restores absent original state'
} finally { Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue }

$job = Start-Job -ScriptBlock {
  param($engine)
  . $engine
  $null = Enter-ExecutionLock 'Global\PCOtimizadorPro.TestLock'
  'LOCKED'
  Start-Sleep -Seconds 8
  Exit-ExecutionLock
} -ArgumentList (Join-Path $root 'Engine.ps1')
$lockReady = $false
for ($i=0; $i -lt 20 -and -not $lockReady; $i++) {
  Start-Sleep -Milliseconds 250
  $lockReady = @((Receive-Job $job -Keep -ErrorAction SilentlyContinue)) -contains 'LOCKED'
}
Assert-True $lockReady 'lock holder started'
$lockRejected = $false
try { $null = Enter-ExecutionLock 'Global\PCOtimizadorPro.TestLock' } catch { $lockRejected = $_.Exception.Message -match 'ja esta em execucao' }
Assert-True $lockRejected 'second concurrent execution is rejected'
Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue
Exit-ExecutionLock

$originalLocalAppData = $env:LOCALAPPDATA
$telemetryRoot = Join-Path $env:TEMP ('pcopt-telemetry-' + [guid]::NewGuid().ToString('N'))
$env:LOCALAPPDATA = $telemetryRoot
try {
  $null = Set-TelemetrySettings -Consent $false
  $sent = Submit-TelemetryEvent 'test' 'SUCCESS' 1
  Assert-True (-not $sent -and -not (Test-Path (Join-Path $telemetryRoot 'PC-Otimizador\telemetry.jsonl'))) 'telemetry is off by default'
  $null = Set-TelemetrySettings -Consent $true
  $null = Submit-TelemetryEvent 'test' 'FAILED' 2 'execution'
  $event = Get-Content (Join-Path $telemetryRoot 'PC-Otimizador\telemetry.jsonl') -Raw | ConvertFrom-Json
  Assert-True ($event.action -eq 'test' -and -not $event.PSObject.Properties['username'] -and -not $event.PSObject.Properties['path']) 'opt-in telemetry excludes identity and paths'
  $httpRejected = $false
  try { $null = Set-TelemetrySettings -Consent $true -Endpoint 'http://example.invalid' } catch { $httpRejected = $true }
  Assert-True $httpRejected 'telemetry endpoint requires HTTPS'
} finally {
  $env:LOCALAPPDATA = $originalLocalAppData
  if (Test-Path -LiteralPath $telemetryRoot) { Remove-Item -LiteralPath $telemetryRoot -Recurse -Force }
}

if ($failed) { Write-Host "`n$failed FAILED" -ForegroundColor Red; exit 1 }
Write-Host "`nALL RELIABILITY TESTS PASSED" -ForegroundColor Green
