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

if ($failed -eq 0) { Write-Host "`nALL STATIC TESTS PASSED" -ForegroundColor Green; exit 0 }
Write-Host "`n$failed FAILED" -ForegroundColor Red
exit 1
