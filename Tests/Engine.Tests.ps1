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

Write-Host '== Engine tests v5.9 ==' -ForegroundColor Cyan
Assert-True (Test-Path function:Get-HealthScore) 'Get-HealthScore'
Assert-True (Test-Path function:Get-DriveMediaInfo) 'Get-DriveMediaInfo'
Assert-True (Test-Path function:Test-PathWhitelisted) 'Test-PathWhitelisted'
Assert-True (Test-Path function:Test-PathUnderRoot) 'Test-PathUnderRoot'
Assert-True (Test-Path function:Request-Cancel) 'Request-Cancel'
Assert-True (Test-Path function:Get-BloatPackageCandidates) 'Get-BloatPackageCandidates'
Assert-True (Test-Path function:Write-ProgressLine) 'Write-ProgressLine'
Assert-True (Test-Path function:Get-HighRiskActionIds) 'Get-HighRiskActionIds'
Assert-True (Test-Path function:Invoke-WithFallback) 'Invoke-WithFallback'
Assert-True (Test-Path function:Invoke-ExternalChecked) 'Invoke-ExternalChecked'
Assert-True (Test-Path function:Get-CompatibilityProfile) 'Get-CompatibilityProfile'
Assert-True (Test-Path (Join-Path $root 'core\presets.json')) 'core/presets.json exists'

$fallbackCalls = 0
$fallbackValue = Invoke-WithFallback 'teste controlado' @(
  { $script:fallbackCalls++; throw 'falha primaria simulada' },
  { $script:fallbackCalls++; return 42 }
)
Assert-True ($fallbackValue -eq 42 -and $fallbackCalls -eq 2) 'fallback uses alternate method after failure'
$allFallbacksFailed = $false
try { $null = Invoke-WithFallback 'teste sem saida' @({ throw 'a' }, { throw 'b' }) } catch { $allFallbacksFailed = $_.Exception.Message -match 'nenhum metodo funcionou' }
Assert-True $allFallbacksFailed 'fallback reports failure when every method fails'
$checkedExitOk = $false
try { $null = Invoke-ExternalChecked 'powershell.exe' @('-NoProfile','-Command','exit 0') @(0) 'subprocesso teste'; $checkedExitOk = $true } catch {}
Assert-True $checkedExitOk 'external command accepts declared success code'
$checkedExitFails = $false
try { $null = Invoke-ExternalChecked 'powershell.exe' @('-NoProfile','-Command','exit 7') @(0) 'subprocesso teste' } catch { $checkedExitFails = $_.Exception.Message -match 'codigo 7' }
Assert-True $checkedExitFails 'external command rejects undeclared exit code'
$compat = Get-CompatibilityProfile
Assert-True (-not [string]::IsNullOrWhiteSpace($compat.Build)) 'compatibility profile has Windows build'
Assert-True (-not [string]::IsNullOrWhiteSpace($compat.PowerShell)) 'compatibility profile has PowerShell version'

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
Assert-True ($r.ActionResults.Count -eq 2 -and @($r.ActionResults | Where-Object Status -eq 'SKIPPED').Count -eq 2) 'dry-run reports every action as skipped'

$blocked = Invoke-OptimizationBatch -Ids @('upgrade') -Actions @{ upgrade = @{ Nome = 'Upgrade'; Act = { return 1 } } }
Assert-True ($blocked.Blocked) 'high risk blocked without capability'
Assert-True ($blocked.ActionResults.Count -eq 1 -and $blocked.ActionResults[0].Status -eq 'BLOCKED') 'blocked action has explicit contract result'

Assert-True (Test-AllowedTweakRegistry -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting') 'allowlist accepts known visual tweak'
Assert-True (Test-AllowedTweakRegistry -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled') 'allowlist accepts underscore registry names'
Assert-True (-not (Test-AllowedTweakRegistry -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'Userinit')) 'allowlist rejects arbitrary registry'
Assert-True (Test-NagleRestorePath 'Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') 'nagle allowlist accepts interface path'
Assert-True (-not (Test-NagleRestorePath 'HKLM:\SOFTWARE\Evil\Interfaces\aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')) 'nagle allowlist rejects other keys'
Assert-True ((Test-Ipv4Address '1.1.1.1') -and -not (Test-Ipv4Address '999.1.1.1') -and -not (Test-Ipv4Address '1.1.1')) 'IPv4 restore validator'

if ($failed -eq 0) { Write-Host "`nALL TESTS PASSED" -ForegroundColor Green; exit 0 }
Write-Host "`n$failed FAILED" -ForegroundColor Red; exit 1
