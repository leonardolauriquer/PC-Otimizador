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
$json = Get-Content -Raw (Join-Path $root 'core\presets.json') | ConvertFrom-Json

Assert-Contains $engine 'function Test-CleanupTarget' 'Windows cleanup target guard'
Assert-Contains $engine 'AllowHighRisk' 'Engine risk capability'
Assert-Contains $engine 'StateFlags{0}' 'CleanMgr temporary profile'
Assert-Contains $update 'Test-ZipEntriesSafe' 'ZIP traversal validation'
Assert-Contains $update "Release sem SHA256SUMS; atualizacao recusada." 'Hash fail-closed'
Assert-Contains $update "PC-Otimizador.exe" 'Complete package validation'
Assert-NotContains $update 'seguindo mesmo assim' 'No unsigned fallback'
Assert-NotContains $linux 'safe_rm_tree /tmp' 'Linux does not wipe /tmp root'
Assert-NotContains $linux 'apt-get autoremove' 'Linux safe does not autoremove'
Assert-NotContains $macos 'safe_rm_tree /tmp' 'macOS does not wipe /tmp root'
Assert-Contains $android 'fora do sandbox Termux' 'Termux sandbox guard'
Assert-NotContains (($json.windows.safe -join '|')) 'recycle' 'Windows safe excludes recycle'
Assert-NotContains (($json.windows.safe -join '|')) 'cleanmgr' 'Windows safe excludes CleanMgr'
Assert-Contains ([string]$json.risk_actions.upgrade) 'high' 'Upgrade risk is high'
Assert-Contains $gui 'class GlowProgress' 'GUI glow progress control'
Assert-Contains $gui 'class IconCanvas' 'GUI vector icon system'
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
Assert-Contains $gui 'static class UiText' 'GUI localization catalog'
Assert-Contains $gui 'ComboBoxStyle.DropDownList' 'GUI language selector'
Assert-Contains $gui 'BuildPageLimpeza' 'GUI cleanup page'
Assert-Contains $gui 'BuildPageDesempenho' 'GUI performance page'
Assert-Contains $gui 'BuildPageInternet' 'GUI network page'
Assert-Contains $gui 'BuildPageInicializacao' 'GUI startup page'
Assert-Contains $gui 'BuildPageConfiguracoes' 'GUI settings page'
Assert-Contains $gui 'string target = _pages.ContainsKey(name) ? name : "inicio"' 'GUI direct page routing'
Assert-Contains $gui 'case "network"' 'GUI network icon'
Assert-Contains $gui 'case "clock"' 'GUI clock icon'
Assert-Contains $gui 'case "folder"' 'GUI folder icon'
Assert-Contains $gui 'ShowTile = false' 'GUI metric icons without empty tile'
Assert-Contains $gui 'case "health"' 'GUI health metric icon'
Assert-Contains $gui '_btnCancel.Visible = false' 'GUI idle cancel button hidden'

if ($failed -eq 0) { Write-Host "`nALL STATIC TESTS PASSED" -ForegroundColor Green; exit 0 }
Write-Host "`n$failed FAILED" -ForegroundColor Red
exit 1
