#Requires -Version 5.1
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

Write-Host '== Engine tests v5 ==' -ForegroundColor Cyan
Assert-True (Test-Path function:Get-HealthScore) 'Get-HealthScore'
Assert-True (Test-Path function:Get-DriveMediaInfo) 'Get-DriveMediaInfo'
Assert-True (Test-Path function:Test-PathWhitelisted) 'Test-PathWhitelisted'
Assert-True (Test-Path function:Request-Cancel) 'Request-Cancel'
Assert-True (Test-Path function:Get-BloatPackageCandidates) 'Get-BloatPackageCandidates'
Assert-True (Test-Path function:Write-ProgressLine) 'Write-ProgressLine'

Import-Whitelist
Assert-True ($script:Whitelist.Count -ge 1) 'whitelist has defaults'
$docs = [Environment]::GetFolderPath('MyDocuments')
Assert-True (Test-PathWhitelisted $docs) 'documents protected'

$h = Get-HealthScore
Assert-True ($h.Score -ge 0 -and $h.Score -le 100) 'health score range'
Assert-True ($h.Grade -match '^[A-E]$') 'health grade'

Reset-CancelFlag
Assert-True (-not (Test-CancelRequested)) 'cancel cleared'
Request-Cancel
Assert-True (Test-CancelRequested) 'cancel set'
Reset-CancelFlag

$m = Get-DriveMediaInfo
Assert-True ($null -ne $m) 'media info'

$safe = @(Get-PresetIds 'safe')
Assert-True ($safe -notcontains 'powerhigh') 'safe no high perf'
$nb = @(Get-PresetIds 'notebook')
Assert-True ($nb -contains 'powerbal') 'notebook balanced'

$actions = @{ temp = @{ Nome = 'Temp'; Act = { return 1 } }; dns = @{ Nome = 'DNS'; Act = { return 0 } } }
$r = Invoke-OptimizationBatch -Ids @('temp','dns') -Actions $actions -DryRun
Assert-True ($r.FreedMB -eq 0) 'dry frees 0'
Assert-True ($null -ne $r.Before -and $null -ne $r.After) 'before/after present'
Assert-True ($null -ne $r.Health) 'health on result'

if ($failed -eq 0) { Write-Host "`nALL TESTS PASSED" -ForegroundColor Green; exit 0 }
Write-Host "`n$failed FAILED" -ForegroundColor Red; exit 1
