# Compila launcher C# (GuiNative) — NAO usa ps2exe
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$out = Join-Path $PSScriptRoot 'PC-Otimizador.exe'
if (Test-Path $out) {
  try { Remove-Item $out -Force } catch { Rename-Item $out ("PC-Otimizador.old.{0}.exe" -f (Get-Date -Format 'HHmmss')) -Force -EA SilentlyContinue }
}
Write-Host 'Compilando GUI C# nativa...' -ForegroundColor Cyan
& $csc /nologo /target:winexe /optimize+ /platform:anycpu `
  /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Management.dll `
  /win32manifest:app.manifest /out:$out GuiNative.cs
if (-not (Test-Path $out)) { throw 'Falha compile' }
Write-Host ("OK: {0} ({1:N1} KB)" -f $out, ((Get-Item $out).Length/1KB)) -ForegroundColor Green
Write-Host 'Passe JUNTO: PC-Otimizador.exe + Engine.ps1 + PC-Otimizador-CLI.ps1 (+ Executar.bat)'
