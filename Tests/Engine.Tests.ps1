#Requires -Version 5.1
# Testes basicos do Engine (sem apagar nada de verdade)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $root 'Engine.ps1'))) { $root = $PSScriptRoot }
Set-Location $root
. (Join-Path $root 'Engine.ps1')

$failed = 0
function Assert-True([bool]$Cond, [string]$Name) {
  if ($Cond) { Write-Host "  PASS $Name" -ForegroundColor Green }
  else { Write-Host "  FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

Write-Host '== Engine tests ==' -ForegroundColor Cyan
Assert-True (Test-Path function:Get-FolderSizeMB) 'Get-FolderSizeMB exists'
Assert-True (Test-Path function:Get-PresetIds) 'Get-PresetIds exists'
Assert-True (Test-Path function:Get-OptionEstimateMB) 'Get-OptionEstimateMB exists'
Assert-True (Test-Path function:Write-EstimatesReport) 'Write-EstimatesReport exists'
Assert-True (Test-Path function:Invoke-OptimizationBatch) 'Invoke-OptimizationBatch exists'
Assert-True (Test-Path function:Register-WeeklyCleanup) 'Register-WeeklyCleanup exists'

$safe = @(Get-PresetIds 'safe')
Assert-True ($safe.Count -gt 5) 'safe preset has items'
Assert-True ($safe -contains 'temp') 'safe contains temp'
Assert-True ($safe -notcontains 'powerhigh') 'safe avoids high performance'

$nb = @(Get-PresetIds 'notebook')
Assert-True ($nb -contains 'powerbal') 'notebook has balanced power'
Assert-True ($nb -notcontains 'powerhigh') 'notebook avoids high performance'

$gamer = @(Get-PresetIds 'gamer')
Assert-True ($gamer -contains 'gamebar') 'gamer has gamebar'

$mb = Get-OptionEstimateMB 'temp'
Assert-True ($mb -ge 0) 'temp estimate >= 0'

$script:DryRun = $true
$log = Initialize-SessionLog
Assert-True (Test-Path $log) 'session log created'
Write-Log 'teste'
Complete-SessionLog -Summary 'ok' | Out-Null
Assert-True ((Get-Content $log -Raw) -match 'teste') 'session log writable'

# Dry batch with fake actions (no real cleanup)
$actions = @{
  temp = @{ Nome = 'Temp'; Act = { return 1.5 } }
  dns  = @{ Nome = 'DNS'; Act = { return 0 } }
}
$r = Invoke-OptimizationBatch -Ids @('temp','dns') -Actions $actions -DryRun
Assert-True ($null -ne $r.Log) 'batch returns log'
Assert-True ($r.FreedMB -eq 0) 'dry-run frees 0'

if ($failed -eq 0) {
  Write-Host "`nALL TESTS PASSED" -ForegroundColor Green
  exit 0
} else {
  Write-Host "`n$failed FAILED" -ForegroundColor Red
  exit 1
}
