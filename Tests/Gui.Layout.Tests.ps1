#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "C# compiler not found: $csc" }
$exe = Join-Path ([IO.Path]::GetTempPath()) ("pc-otimizador-gui-layout-{0}.exe" -f ([guid]::NewGuid().ToString('N')))
try {
  & $csc /nologo /target:exe /optimize+ /platform:anycpu /main:PCOtimizador.GuiLayoutTests `
    /reference:System.Windows.Forms.dll /reference:System.Drawing.dll `
    "/out:$exe" (Join-Path $root 'GuiNative.cs') (Join-Path $root 'Tests\Gui.Layout.Tests.cs')
  if ($LASTEXITCODE -ne 0) { throw 'GUI layout test compilation failed' }
  & $exe
  if ($LASTEXITCODE -ne 0) { throw 'GUI layout contract failed' }
} finally {
  if (Test-Path $exe) { [IO.File]::Delete($exe) }
  $pdb = [IO.Path]::ChangeExtension($exe, '.pdb')
  if (Test-Path $pdb) { [IO.File]::Delete($pdb) }
}
