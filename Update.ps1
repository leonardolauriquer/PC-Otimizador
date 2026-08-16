#Requires -Version 5.1
<#
.SYNOPSIS
  Verifica a release mais recente no GitHub e atualiza obrigatoriamente se houver versão nova.
.NOTES
  Exit codes:
    0  = ja atualizado, ou sem rede (continua)
    10 = atualizacao agendada — o processo pai DEVE encerrar
    2  = falha ao aplicar atualizacao obrigatoria
#>
param(
  [string]$Root = $PSScriptRoot,
  [string]$Repo = 'leonardolauriquer/PC-Otimizador',
  [string]$Relaunch = '',
  [switch]$CheckOnly,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-U([string]$Msg, [string]$Color = 'Cyan') {
  if ($Quiet) { return }
  Write-Host ("  [Update] {0}" -f $Msg) -ForegroundColor $Color
  try { [Console]::Out.WriteLine(("##UPDATE##|{0}" -f $Msg)) } catch {}
}

function Get-LocalVersion {
  $f = Join-Path $Root 'VERSION'
  if (Test-Path -LiteralPath $f) {
    return ((Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue) -replace '[^\d\.]', '').Trim()
  }
  return '0.0.0'
}

function Convert-VersionParts([string]$v) {
  $v = ($v -replace '^v', '').Trim()
  if (-not $v) { $v = '0.0.0' }
  $parts = $v.Split('.') | ForEach-Object {
    $n = 0
    [void][int]::TryParse($_, [ref]$n)
    $n
  }
  while ($parts.Count -lt 3) { $parts += 0 }
  return ,@($parts[0], $parts[1], $parts[2])
}

function Compare-Version([string]$A, [string]$B) {
  $pa = Convert-VersionParts $A
  $pb = Convert-VersionParts $B
  for ($i = 0; $i -lt 3; $i++) {
    if ($pa[$i] -lt $pb[$i]) { return -1 }
    if ($pa[$i] -gt $pb[$i]) { return 1 }
  }
  return 0
}

function Get-LatestRelease {
  $uri = "https://api.github.com/repos/$Repo/releases/latest"
  $headers = @{
    'User-Agent' = 'PC-Otimizador-Updater'
    'Accept'     = 'application/vnd.github+json'
  }
  return Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 25
}

function Test-Sha256([string]$FilePath, [string]$ExpectedHex) {
  $h = (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
  return ($h -eq $ExpectedHex.ToLowerInvariant())
}

function Test-ZipEntriesSafe([string]$Destination, $Zip) {
  $base = ([IO.Path]::GetFullPath($Destination)).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
  foreach ($entry in $Zip.Entries) {
    $name = [string]$entry.FullName
    if (-not $name -or $name -match '^[\\/]' -or $name -match '^[A-Za-z]:' -or $name -match '(^|[\\/])\.\.([\\/]|$)') { return $false }
    try { $candidate = [IO.Path]::GetFullPath((Join-Path $Destination $name)) } catch { return $false }
    if (-not $candidate.StartsWith($base, [StringComparison]::OrdinalIgnoreCase) -and
        -not [string]::Equals($candidate, $base.TrimEnd([IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) { return $false }
    if ($entry.Length -gt 524288000) { return $false }
  }
  return $true
}

$local = Get-LocalVersion
Write-U ("Versao local: {0}" -f $local)

try {
  $rel = Get-LatestRelease
} catch {
  Write-U ("Sem internet / GitHub indisponivel: {0}" -f $_.Exception.Message) 'Yellow'
  Write-U 'Continuando sem atualizar (tente de novo depois).' 'Yellow'
  exit 0
}

$tag = [string]$rel.tag_name
$remote = ($tag -replace '^v', '').Trim()
Write-U ("Ultima release: {0}" -f $tag)

if ((Compare-Version $local $remote) -ge 0) {
  Write-U 'Ja esta na ultima versao.' 'Green'
  exit 0
}

Write-U ("Atualizacao OBRIGATORIA: {0} -> {1}" -f $local, $remote) 'Yellow'

if ($CheckOnly) {
  Write-U 'CheckOnly: nova versao disponivel.' 'Yellow'
  exit 11
}

$zipAsset = @($rel.assets | Where-Object { $_.name -eq 'PC-Otimizador-Windows.zip' }) | Select-Object -First 1
$sumAsset = @($rel.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' }) | Select-Object -First 1
if (-not $zipAsset) {
  Write-U 'Release sem PC-Otimizador-Windows.zip.' 'Red'
  exit 2
}

$updateBase = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PC-Otimizador\updates'
$safeRemote = ($remote -replace '[^0-9A-Za-z._-]', '_')
$work = Join-Path $updateBase ("{0}-{1}" -f $safeRemote, [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $work 'PC-Otimizador-Windows.zip'
$sumPath = Join-Path $work 'SHA256SUMS.txt'
$extract = Join-Path $work 'extract'

try {
  New-Item -ItemType Directory -Path $updateBase -Force | Out-Null
  New-Item -ItemType Directory -Path $work -Force | Out-Null
  & icacls.exe $work /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)' /setintegritylevel H | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel proteger o staging da atualizacao.' }
  New-Item -ItemType Directory -Path $extract -Force | Out-Null

  Write-U 'Baixando pacote...'
  Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 180

  if (-not $sumAsset) { throw 'Release sem SHA256SUMS; atualizacao recusada.' }
  Write-U 'Baixando SHA256SUMS...'
  Invoke-WebRequest -Uri $sumAsset.browser_download_url -OutFile $sumPath -UseBasicParsing -TimeoutSec 60
  $line = Get-Content $sumPath | Where-Object { $_ -match '^\s*[a-fA-F0-9]{64}\s+[* ]?PC-Otimizador-Windows\.zip\s*$' } | Select-Object -First 1
  $expected = if ($line -match '^\s*([a-fA-F0-9]{64})') { $Matches[1] } else { $null }
  if (-not $expected) { throw 'SHA256SUMS sem hash valido do pacote.' }
  Write-U 'Verificando SHA256...'
  if (-not (Test-Sha256 $zipPath $expected)) { throw 'HASH INVALIDO — abortando atualizacao.' }
  Write-U 'SHA256 OK.' 'Green'

  Write-U 'Extraindo...'
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
  if (-not (Test-ZipEntriesSafe -Destination $extract -Zip $zip)) {
    $zip.Dispose()
    throw 'Pacote rejeitado: entrada ZIP fora do staging ou grande demais.'
  }
  $zip.Dispose()
  [IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extract)

  # Se o zip tiver pasta unica, descer um nivel
  $children = @(Get-ChildItem -LiteralPath $extract -Force)
  $src = $extract
  if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
    $src = $children[0].FullName
  }

  $required = @('Executar.bat','Engine.ps1','PC-Otimizador-CLI.ps1','PC-Otimizador.exe','Update.ps1','VERSION','core\presets.json')
  foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $src $file))) { throw "Pacote invalido (faltando $file)." }
  }
  $packageVersion = ((Get-Content -LiteralPath (Join-Path $src 'VERSION') -Raw) -replace '[^\d\.]','').Trim()
  if ((Compare-Version $packageVersion $remote) -ne 0) {
    throw "VERSION do pacote ($packageVersion) nao corresponde a release ($remote)."
  }

  if (-not $Relaunch) {
    $exe = Join-Path $Root 'PC-Otimizador.exe'
    $bat = Join-Path $Root 'Executar.bat'
    if (Test-Path $exe) { $Relaunch = $exe }
    elseif (Test-Path $bat) { $Relaunch = $bat }
    else { $Relaunch = $bat }
  }

  $apply = Join-Path $work 'apply-update.cmd'
  $srcEsc = $src
  $dstEsc = $Root
  $relaunchEsc = $Relaunch

  $cmd = @"
@echo off
setlocal
echo PC Otimizador — aplicando atualizacao $safeRemote ...
timeout /t 3 /nobreak >nul
:wait_exe
tasklist | find /I "PC-Otimizador.exe" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto wait_exe
)
  echo Copiando arquivos...
  xcopy /E /Y /Q /I "$srcEsc\*" "$dstEsc\" >nul
  if errorlevel 2 goto copy_failed
  if exist "$dstEsc\VERSION" (
    echo Atualizado. VERSION:
    type "$dstEsc\VERSION"
  )
  start "" "$relaunchEsc"
  timeout /t 1 /nobreak >nul
  rd /s /q "$work" >nul 2>nul
  del "%~f0" >nul 2>nul
  exit /b 0
:copy_failed
  echo Falha ao copiar o pacote; instalacao nao confirmada.
  exit /b 1
"@
  Set-Content -LiteralPath $apply -Value $cmd -Encoding ASCII

  Write-U ("Aplicando {0} e reiniciando..." -f $remote) 'Green'
  Start-Process -FilePath $apply -WindowStyle Normal
  exit 10
} catch {
  Write-U ("Falha na atualizacao: {0}" -f $_.Exception.Message) 'Red'
  exit 2
}
