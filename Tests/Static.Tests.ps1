#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failed = 0

function Assert-Contains([string]$Text, [string]$Needle, [string]$Name) {
  if ($Text.Contains($Needle)) { Write-Host "  PASS $Name" -ForegroundColor Green }
  else { Write-Host "  FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

function Assert-NotContains([string]$Text, [string]$Needle, [string]$Name) {
  if (-not $Text.Contains($Needle)) { Write-Host "  PASS $Name" -ForegroundColor Green }
  else { Write-Host "  FAIL $Name" -ForegroundColor Red; $script:failed++ }
}

Write-Host '== Static security tests ==' -ForegroundColor Cyan
$engine = Get-Content -Raw (Join-Path $root 'Engine.ps1')
$update = Get-Content -Raw (Join-Path $root 'Update.ps1')
$linux = Get-Content -Raw (Join-Path $root 'linux\pc-otimizador.sh')
$macos = Get-Content -Raw (Join-Path $root 'macos\pc-otimizador.sh')
$android = Get-Content -Raw (Join-Path $root 'android\termux-pc-otimizador.sh')
$gui = Get-Content -Raw (Join-Path $root 'GuiNative.cs')
$cli = Get-Content -Raw (Join-Path $root 'PC-Otimizador-CLI.ps1')
$json = Get-Content -Raw (Join-Path $root 'core\presets.json') | ConvertFrom-Json

Assert-Contains $engine 'function Test-CleanupTarget' 'Windows cleanup target guard'
Assert-Contains $engine 'function Invoke-WithFallback' 'Windows controlled fallback pipeline'
Assert-Contains $engine 'function Invoke-ExternalChecked' 'External command exit-code verification'
Assert-Contains $engine 'function Get-CompatibilityProfile' 'Windows capability detection'
Assert-Contains $engine 'function Enter-ExecutionLock' 'Windows global execution lock'
Assert-Contains $engine 'function Undo-ActionTransaction' 'Windows action rollback'
Assert-Contains $engine 'function Write-ActionResult' 'Per-action result contract'
Assert-Contains $engine 'excedeu o limite de' 'External command timeout'
Assert-Contains $engine 'function Submit-TelemetryEvent' 'Opt-in privacy telemetry'
Assert-Contains $engine 'Snapshot CIM falhou; tentando WMI legado' 'System snapshot legacy fallback'
Assert-Contains $engine 'O plano Alto Desempenho nao ficou ativo' 'Power plan postcondition verification'
Assert-Contains $engine 'AllowHighRisk' 'Engine risk capability'
Assert-Contains $engine 'StateFlags{0}' 'CleanMgr temporary profile'
Assert-Contains $update 'Test-ZipEntriesSafe' 'ZIP traversal validation'
Assert-Contains $update "Release sem SHA256SUMS; atualizacao recusada." 'Hash fail-closed'
Assert-Contains $update "PC-Otimizador.exe" 'Complete package validation'
Assert-Contains $update 'Test-PackageManifest' 'Internal package manifest validation'
Assert-Contains $update 'Test-AuthenticodePolicy' 'Authenticode enforcement policy'
Assert-Contains $update "Write-UpdateStatus 'ROLLED_BACK'" 'Updater automatic rollback'
Assert-NotContains $update 'seguindo mesmo assim' 'No unsigned fallback'
Assert-NotContains $linux 'safe_rm_tree /tmp' 'Linux does not wipe /tmp root'
Assert-NotContains $linux 'apt-get autoremove' 'Linux safe does not autoremove'
Assert-NotContains $macos 'safe_rm_tree /tmp' 'macOS does not wipe /tmp root'
Assert-Contains $android 'fora do sandbox Termux' 'Termux sandbox guard'
Assert-NotContains (($json.windows.safe -join '|')) 'recycle' 'Windows safe excludes recycle'
Assert-NotContains (($json.windows.safe -join '|')) 'cleanmgr' 'Windows safe excludes CleanMgr'
Assert-Contains ([string]$json.risk_actions.upgrade) 'high' 'Upgrade risk is high'
Assert-Contains $gui 'class GlowProgress' 'GUI glow progress control'
Assert-Contains $gui 'Segoe Fluent Icons' 'GUI official Microsoft Fluent icons'
Assert-Contains $gui 'TableLayoutPanel' 'GUI responsive preset grid'
Assert-Contains $gui 'INICIALIZAÇÃO' 'GUI initialization navigation'
Assert-Contains $gui 'CONFIGURAÇÕES' 'GUI settings navigation'
Assert-Contains $gui 'FormBorderStyle = FormBorderStyle.None' 'GUI custom chrome'
Assert-Contains $gui 'void LayoutRoot()' 'GUI sidebar/content bounds'
Assert-Contains $gui 'int cellWidth' 'GUI equal card sizing'
Assert-Contains $gui 'SizeType.Absolute' 'GUI pixel-stable card columns'
Assert-Contains $gui 'min.Click += (s, e) => WindowState' 'GUI minimize handler'
Assert-Contains $gui 'max.Click += (s, e) => ToggleMaximize' 'GUI maximize handler'
Assert-Contains $gui 'close.Click += (s, e) => Close' 'GUI close handler'
Assert-Contains $gui '_btnCancel.Click += (s, e) => CancelRun' 'GUI cancel handler'
Assert-Contains $gui 'p.Click += click; iconPanel.Click += click; titleLabel.Click += click' 'GUI preset card handlers'
Assert-Contains $gui 'p.Click += click; i.Click += click; t.Click += click; s.Click += click' 'GUI tool card handlers'
Assert-Contains $gui 'TextRenderer.MeasureText' 'GUI stable title measurement'
Assert-Contains $gui 'int gridLeft = Math.Max(0, (w - gridWidth) / 2)' 'GUI page-relative grid placement'
Assert-Contains $gui 'FlowLayoutPanel' 'GUI responsive tools flow'
Assert-Contains $gui 'AutoScroll = true' 'GUI scrollable inner pages'
Assert-Contains $gui '_helpScroll' 'GUI responsive help page'
Assert-Contains $gui 'class ConsentDialog' 'GUI explicit consent dialog'
Assert-Contains $gui 'class UserPrefs' 'GUI remembers last consent selection'
Assert-Contains $gui 'class ScheduleDialog' 'GUI schedule consent dialog'
Assert-Contains $gui 'class StartupInventory' 'GUI Windows startup manager'
Assert-Contains $engine 'function Save-TweakSnapshot' 'Engine stores reversible tweak snapshot'
Assert-Contains $engine 'function Restore-LastTweaks' 'Engine restores last tweaks'
Assert-Contains $engine 'function Get-ChromiumCacheTargets' 'Chromium multi-profile cache discovery'
Assert-Contains $engine 'SkipSizeWalk' 'Engine can skip duplicate size walk'
Assert-Contains $engine '[int]$BudgetMs = 800' 'Bounded folder size walk'
Assert-Contains $gui 'void BeginMeasure' 'GUI measures consent sizes off the UI thread'
Assert-Contains $gui 'ChromiumCachePaths' 'GUI estimates all Chromium profiles'
Assert-Contains $update 'Continuando com a versao local intacta.' 'Updater fail-open when local install is intact'
Assert-Contains $engine 'function Test-AllowedTweakRegistry' 'Undo snapshot registry allowlist'
Assert-Contains $engine 'Snapshot ignorou registro fora da allowlist' 'Undo snapshot rejects unknown registry paths'
Assert-Contains $engine 'function Test-NagleRestorePath' 'Undo snapshot Nagle path allowlist'
Assert-Contains $engine 'function Test-Ipv4Address' 'Undo snapshot DNS IPv4 guard'
Assert-Contains $gui 'class ActionIdGuard' 'GUI action-id sanitizer'
Assert-Contains $gui 'static bool IsSafeEntry' 'GUI startup entry sanitizer'
Assert-Contains $cli 'undotweaks' 'CLI undo-tweaks mode'
Assert-Contains $cli 'ScheduleDay' 'CLI schedule day parameter'
Assert-Contains $gui 'class ActionEstimates' 'GUI consent size estimates'
Assert-Contains $gui 'I have read the list and authorize' 'GUI consent checkbox text (EN)'
Assert-Contains $gui 'Li a lista e autorizo somente as ações marcadas.' 'GUI consent checkbox text (PT)'
Assert-Contains $gui 'Concordo — executar' 'GUI consent run button (PT)'
Assert-Contains $cli '[string]$Actions' 'CLI selected-action filter'
Assert-Contains $cli 'Digite CONCORDO' 'CLI explicit consent token'
Assert-Contains $gui '_languagePtButton' 'GUI language selector'
Assert-Contains $gui 'ShowPage("configuracoes")' 'GUI settings navigation route'
Assert-Contains $gui 'BuildPageLimpeza' 'GUI cleanup page'
Assert-Contains $gui 'BuildPageDesempenho' 'GUI performance page'
Assert-Contains $gui 'BuildPageInternet' 'GUI network page'
Assert-Contains $gui 'BuildPageInicializacao' 'GUI startup page'
Assert-Contains $gui 'BuildPageConfiguracoes' 'GUI settings page'
Assert-Contains $gui 'BuildPageDispositivo' 'GUI device information page'
Assert-Contains $gui 'Win32_Processor' 'GUI device CPU inventory'
Assert-Contains $gui 'Win32_VideoController' 'GUI device GPU inventory'
Assert-Contains $gui 'Win32_PhysicalMemory' 'GUI device memory inventory'
Assert-Contains $gui 'MSAcpi_ThermalZoneTemperature' 'GUI device temperature sensors'
Assert-Contains $gui 'english ? "Decline" : "Recusar"' 'GUI consent decline button'
Assert-NotContains $gui '"SIMULAÇÃO", "DRY-RUN"' 'GUI has no simulation toggle'
Assert-Contains $gui '"Pontuação de saúde", "Health score"' 'GUI localized health terminology'
Assert-Contains $gui 'string target = _pages.ContainsKey(name) ? name : "inicio"' 'GUI direct page routing'
Assert-Contains $gui 'case "network"' 'GUI network icon'
Assert-Contains $gui 'case "clock"' 'GUI clock icon'
Assert-Contains $gui 'case "folder"' 'GUI folder icon'
Assert-Contains $gui 'ShowTile = false' 'GUI metric icons without empty tile'
Assert-Contains $gui 'case "health"' 'GUI health metric icon'
Assert-Contains $gui '_btnCancel.Visible = false' 'GUI idle cancel button hidden'
Assert-Contains $gui 'settings.telemetry.title' 'GUI telemetry consent control'
Assert-Contains $gui '##ACTION##|' 'GUI per-action result handling'
Assert-Contains $gui 'WaitForExit(7200000)' 'GUI global execution timeout'

$compat = Get-Content -Raw (Join-Path $root 'core\compatibility.json') | ConvertFrom-Json
Assert-Contains ([string]$compat.policy.all_methods_failed) 'fail_action' 'Compatibility matrix fail-closed policy'
if (@($compat.platforms.windows.actions.PSObject.Properties).Count -ge 40) { Write-Host '  PASS Compatibility matrix covers Windows actions' -ForegroundColor Green }
else { Write-Host '  FAIL Compatibility matrix covers Windows actions' -ForegroundColor Red; $script:failed++ }

if ($failed -eq 0) { Write-Host "`nALL STATIC TESTS PASSED" -ForegroundColor Green; exit 0 }
Write-Host "`n$failed FAILED" -ForegroundColor Red
exit 1
