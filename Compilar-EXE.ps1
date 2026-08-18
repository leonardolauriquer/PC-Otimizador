# Compila launcher C# (GuiNative) — NAO usa ps2exe
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$out = Join-Path $PSScriptRoot 'PC-Otimizador.exe'
$ver = '0.0.0'
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'VERSION')) {
  $ver = ((Get-Content -LiteralPath (Join-Path $PSScriptRoot 'VERSION') -Raw) -replace '[^\d\.]', '').Trim()
}
if (-not $ver) { $ver = '0.0.0' }
$parts = @($ver.Split('.') | ForEach-Object { $n = 0; [void][int]::TryParse($_, [ref]$n); $n })
while ($parts.Count -lt 4) { $parts += 0 }
$fileVer = '{0},{1},{2},{3}' -f $parts[0], $parts[1], $parts[2], $parts[3]
$infoVer = '{0}.{1}.{2}.{3}' -f $parts[0], $parts[1], $parts[2], $parts[3]

if (Test-Path $out) {
  try { Remove-Item $out -Force } catch { Rename-Item $out ("PC-Otimizador.old.{0}.exe" -f (Get-Date -Format 'HHmmss')) -Force -EA SilentlyContinue }
}

$asmSrc = Join-Path $PSScriptRoot 'AssemblyInfo.cs'
$asmOut = Join-Path $PSScriptRoot 'AssemblyInfo.generated.cs'
$asmText = Get-Content -LiteralPath $asmSrc -Raw -Encoding UTF8
$asmText = [regex]::Replace($asmText, 'AssemblyVersion\("[^"]+"\)', "AssemblyVersion(`"$infoVer`")")
$asmText = [regex]::Replace($asmText, 'AssemblyFileVersion\("[^"]+"\)', "AssemblyFileVersion(`"$infoVer`")")
$asmText = [regex]::Replace($asmText, 'AssemblyInformationalVersion\("[^"]+"\)', "AssemblyInformationalVersion(`"$ver`")")
Set-Content -LiteralPath $asmOut -Value $asmText -Encoding UTF8

$win32res = $null
$rcExe = $null
$kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
if (Test-Path $kits) {
  $rcExe = Get-ChildItem $kits -Filter rc.exe -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\x64\\rc\.exe$' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
}
if ($rcExe) {
  $rcText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'app.rc') -Raw -Encoding UTF8
  $rcText = [regex]::Replace($rcText, 'FILEVERSION\s+[\d,]+', "FILEVERSION $fileVer")
  $rcText = [regex]::Replace($rcText, 'PRODUCTVERSION\s+[\d,]+', "PRODUCTVERSION $fileVer")
  $rcText = [regex]::Replace($rcText, 'VALUE "FileVersion", "[^"]+"', "VALUE `"FileVersion`", `"$infoVer`"")
  $rcText = [regex]::Replace($rcText, 'VALUE "ProductVersion", "[^"]+"', "VALUE `"ProductVersion`", `"$infoVer`"")
  $rcPath = Join-Path $PSScriptRoot 'app.generated.rc'
  $resPath = Join-Path $PSScriptRoot 'app.res'
  Set-Content -LiteralPath $rcPath -Value $rcText -Encoding ASCII
  & $rcExe.FullName /nologo /fo $resPath $rcPath
  if ($LASTEXITCODE -eq 0 -and (Test-Path $resPath)) { $win32res = $resPath }
}

Write-Host 'Compilando GUI C# nativa (metadados de versao, sem ps2exe)...' -ForegroundColor Cyan
$cscArgs = @(
  '/nologo', '/target:winexe', '/optimize+', '/debug-', '/platform:anycpu',
  '/reference:System.Windows.Forms.dll', '/reference:System.Drawing.dll', '/reference:System.Management.dll',
  "/out:$out", $asmOut, (Join-Path $PSScriptRoot 'GuiNative.cs')
)
if ($win32res) { $cscArgs = @("/win32res:$win32res") + $cscArgs }
else { $cscArgs = @('/win32manifest:app.manifest') + $cscArgs }
& $csc @cscArgs
if (-not (Test-Path $out)) { throw 'Falha compile' }
Write-Host ("OK: {0} ({1:N1} KB)  v{2}" -f $out, ((Get-Item $out).Length/1KB), $ver) -ForegroundColor Green
Write-Host 'Passe JUNTO: PC-Otimizador.exe + Engine.ps1 + PC-Otimizador-CLI.ps1 (+ Executar.bat)'
if ($env:SIGNING_PFX_PATH -and (Test-Path -LiteralPath $env:SIGNING_PFX_PATH) -and $env:SIGNING_PFX_PASSWORD) {
  Write-Host 'Assinando com SIGNING_PFX_PATH...' -ForegroundColor Cyan
  $secure = ConvertTo-SecureString $env:SIGNING_PFX_PASSWORD -AsPlainText -Force
  $cert = Import-PfxCertificate -FilePath $env:SIGNING_PFX_PATH -CertStoreLocation Cert:\CurrentUser\My -Password $secure
  $sig = Set-AuthenticodeSignature -FilePath $out -Certificate $cert -TimestampServer 'http://timestamp.digicert.com' -HashAlgorithm SHA256
  if ($sig.Status -ne 'Valid') { throw "Falha ao assinar EXE: $($sig.Status)" }
  Write-Host ("Assinado: {0}" -f $cert.Subject) -ForegroundColor Green
} else {
  Write-Host 'Sem certificado Authenticode neste build. Heuristicas de AV (ex.: Gen:Variant.AsyncRAT) sao comuns em EXE de admin + PowerShell sem assinatura — use Executar.bat ou a release assinada.' -ForegroundColor Yellow
}
