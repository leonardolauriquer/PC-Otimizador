# Compila launcher C# limpo (NAO usa ps2exe — evita falso positivo MSILHeracles)
# Uso: powershell -ExecutionPolicy Bypass -File .\Compilar-EXE.ps1

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path $csc)) { throw 'csc.exe nao encontrado (.NET Framework 4.x)' }

$out = Join-Path $PSScriptRoot 'PC-Otimizador.exe'
# Remove exe antigo (ps2exe) se estiver travado, tenta renomear
if (Test-Path $out) {
    try { Remove-Item $out -Force -ErrorAction Stop }
    catch {
        $bak = Join-Path $PSScriptRoot ("PC-Otimizador.old.{0}.exe" -f (Get-Date -Format 'HHmmss'))
        Move-Item $out $bak -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Compilando launcher C# limpo..." -ForegroundColor Cyan
& $csc /nologo /target:winexe /optimize+ /platform:anycpu `
    /reference:System.Windows.Forms.dll `
    /win32manifest:app.manifest `
    /out:$out `
    Launcher.cs

if (-not (Test-Path $out)) { throw 'Falha ao gerar PC-Otimizador.exe' }

$size = [math]::Round((Get-Item $out).Length / 1KB, 1)
Write-Host "OK: $out ($size KB)" -ForegroundColor Green
Write-Host "Passe JUNTO: PC-Otimizador.exe + PC-Otimizador.ps1 (+ Executar.bat opcional)"
Write-Host "Se o antivirus ainda reclamar, use so o Executar.bat (quase nunca alerta)."
