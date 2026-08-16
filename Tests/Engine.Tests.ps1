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

Write-Host '== Engine tests v5.5 ==' -ForegroundColor Cyan
Assert-True (Test-Path function:Get-HealthScore) 'Get-HealthScore'
Assert-True (Test-Path function:Get-DriveMediaInfo) 'Get-DriveMediaInfo'
Assert-True (Test-Path function:Test-PathWhitelisted) 'Test-PathWhitelisted'
Assert-True (Test-Path function:Test-PathUnderRoot) 'Test-PathUnderRoot'
Assert-True (Test-Path function:Request-Cancel) 'Request-Cancel'
Assert-True (Test-Path function:Get-BloatPackageCandidates) 'Get-BloatPackageCandidates'
Assert-True (Test-Path function:Write-ProgressLine) 'Write-ProgressLine'
Assert-True (Test-Path function:Get-HighRiskActionIds) 'Get-HighRiskActionIds'
Assert-True (Test-Path (Join-Path $root 'core\presets.json')) 'core/presets.json exists'

Import-Whitelist
Assert-True ($script:Whitelist.Count -ge 1) 'whitelist has defaults'
$docs = [Environment]::GetFolderPath('MyDocuments')
Assert-True (Test-PathWhitelisted $docs) 'documents protected'
Assert-True (Test-PathUnderRoot -Path $docs -Root $docs) 'path under self'
$fakeSibling = $docs.TrimEnd('\', '/') + 'Backup'
Assert-True (-not (Test-PathUnderRoot -Path $fakeSibling -Root $docs)) 'DocumentsBackup NOT under Documents'
$od = Join-Path $env:USERPROFILE 'OneDrive'
if (Test-PathUnderRoot -Path $docs -Root $od) {
  Write-Host '  SKIP DocumentsBackup whitelist check (Documents under OneDrive — correctly protected)' -ForegroundColor DarkYellow
} else {
  Assert-True (-not (Test-PathWhitelisted $fakeSibling)) 'DocumentsBackup not whitelisted via prefix'
}
# synthetic boundary (independent of OneDrive layout)
$syn = Join-Path $env:TEMP 'pc-otimizador-wl-root'
Assert-True (-not (Test-PathUnderRoot -Path ($syn + 'Backup') -Root $syn)) 'synthetic Backup not under root'
Assert-True (Test-PathUnderRoot -Path (Join-Path $syn 'child') -Root $syn) 'synthetic child under root'

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
Assert-True ($safe.Count -gt 5) 'safe preset from core/json'
Assert-True ($safe -notcontains 'powerhigh') 'safe no high perf'
Assert-True ($safe -notcontains 'dnscloud') 'safe no dnscloud'
Assert-True ($safe -notcontains 'nettweak') 'safe no nettweak'
Assert-True ($safe -notcontains 'cleanmgr') 'safe excludes cleanmgr'
Assert-True ($safe -notcontains 'recycle') 'safe excludes irreversible recycle bin'
Assert-True ((Get-ActionRiskLevel 'upgrade') -eq 'high') 'upgrade high risk'
Assert-True ((Get-ActionRiskLevel 'cleanmgr') -eq 'high') 'cleanmgr high risk'
Assert-True ((Get-ActionRiskLevel 'dnsgoogle') -eq 'high') 'dnsgoogle high risk'
Assert-True ((Get-ActionRiskLevel 'winsock') -eq 'high') 'winsock high risk'
Assert-True (Test-CleanupTarget $env:TEMP) 'current temp is allowlisted'
Assert-True (-not (Test-CleanupTarget ([IO.Path]::GetPathRoot($env:TEMP)))) 'filesystem root rejected'
Assert-True (-not (Test-CleanupTarget $docs)) 'documents not cleanup target'

# StrictMode parity with CLI (would have caught LogBox P0)
$strictFailed = $false
try {
  $job = Start-Job -ScriptBlock {
    param($root)
    Set-Location $root
    Set-StrictMode -Version Latest
    . (Join-Path $root 'Engine.ps1')
    Write-Log 'strict ok'
    $actions = @{ temp = @{ Nome = 'Temp'; Act = { return 0 } } }
    $null = Invoke-OptimizationBatch -Ids @('temp') -Actions $actions -DryRun
    'OK'
  } -ArgumentList $root
  $out = Wait-Job $job -Timeout 120 | Receive-Job
  if ($job.State -ne 'Completed' -or ($out -notcontains 'OK' -and $out -ne 'OK')) { $strictFailed = $true }
  Remove-Job $job -Force -EA SilentlyContinue
} catch { $strictFailed = $true }
Assert-True (-not $strictFailed) 'StrictMode Write-Log + dry batch'
$nb = @(Get-PresetIds 'notebook')
Assert-True ($nb -contains 'powerbal') 'notebook balanced'
$gamer = @(Get-PresetIds 'gamer')
$risky = @(Get-HighRiskActionIds -Ids $gamer)
Assert-True ($risky.Count -ge 1) 'gamer has high risk'
Assert-True ((Get-ActionRiskLevel 'dnscloud') -eq 'high') 'dnscloud high'

$actions = @{ temp = @{ Nome = 'Temp'; Act = { return 1 } }; dns = @{ Nome = 'DNS'; Act = { return 0 } } }
$r = Invoke-OptimizationBatch -Ids @('temp','dns') -Actions $actions -DryRun
Assert-True ($r.FreedMB -eq 0) 'dry frees 0'
Assert-True ($null -ne $r.Before -and $null -ne $r.After) 'before/after present'
Assert-True ($null -ne $r.Health) 'health on result'

$blocked = Invoke-OptimizationBatch -Ids @('upgrade') -Actions @{ upgrade = @{ Nome = 'Upgrade'; Act = { return 1 } } }
Assert-True ($blocked.Blocked) 'high risk blocked without capability'

if ($failed -eq 0) { Write-Host "`nALL TESTS PASSED" -ForegroundColor Green; exit 0 }
Write-Host "`n$failed FAILED" -ForegroundColor Red; exit 1
