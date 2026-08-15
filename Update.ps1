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

$work = Join-Path $env:TEMP ("pc-otimizador-update-{0}" -f $remote)
$zipPath = Join-Path $work 'PC-Otimizador-Windows.zip'
$sumPath = Join-Path $work 'SHA256SUMS.txt'
$extract = Join-Path $work 'extract'

try {
  if (Test-Path $work) { Remove-Item $work -Recurse -Force -EA SilentlyContinue }
  New-Item -ItemType Directory -Path $work -Force | Out-Null
  New-Item -ItemType Directory -Path $extract -Force | Out-Null

  Write-U 'Baixando pacote...'
  Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -UseBasicParsing -TimeoutSec 180

  $expected = $null
  if ($sumAsset) {
    Write-U 'Baixando SHA256SUMS...'
    Invoke-WebRequest -Uri $sumAsset.browser_download_url -OutFile $sumPath -UseBasicParsing -TimeoutSec 60
    $line = Get-Content $sumPath | Where-Object { $_ -match 'PC-Otimizador-Windows\.zip' } | Select-Object -First 1
    if ($line -match '^([a-fA-F0-9]{64})') { $expected = $Matches[1] }
  }

  if ($expected) {
    Write-U 'Verificando SHA256...'
    if (-not (Test-Sha256 $zipPath $expected)) {
      Write-U 'HASH INVALIDO — abortando atualizacao.' 'Red'
      exit 2
    }
    Write-U 'SHA256 OK.' 'Green'
  } else {
    Write-U 'Aviso: release sem SHA256SUMS — seguindo mesmo assim.' 'Yellow'
  }

  Write-U 'Extraindo...'
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extract)

  # Se o zip tiver pasta unica, descer um nivel
  $children = @(Get-ChildItem -LiteralPath $extract -Force)
  $src = $extract
  if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
    $src = $children[0].FullName
  }

  if (-not (Test-Path (Join-Path $src 'Engine.ps1')) -and -not (Test-Path (Join-Path $src 'PC-Otimizador-CLI.ps1'))) {
    Write-U 'Pacote invalido (faltam Engine/CLI).' 'Red'
    exit 2
  }

  if (-not $Relaunch) {
    $exe = Join-Path $Root 'PC-Otimizador.exe'
    $bat = Join-Path $Root 'Executar.bat'
    if (Test-Path $exe) { $Relaunch = $exe }
    elseif (Test-Path $bat) { $Relaunch = $bat }
    else { $Relaunch = $bat }
  }

  $apply = Join-Path $env:TEMP 'pc-otimizador-apply-update.cmd'
  $srcEsc = $src
  $dstEsc = $Root
  $relaunchEsc = $Relaunch

  $cmd = @"
@echo off
setlocal
echo PC Otimizador — aplicando atualizacao $remote ...
timeout /t 3 /nobreak >nul
:wait_exe
tasklist | find /I "PC-Otimizador.exe" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto wait_exe
)
echo Copiando arquivos...
xcopy /E /Y /Q /I "$srcEsc\*" "$dstEsc\" >nul
if exist "$dstEsc\VERSION" (
  echo Atualizado. VERSION:
  type "$dstEsc\VERSION"
)
start "" "$relaunchEsc"
timeout /t 1 /nobreak >nul
rd /s /q "$work" >nul 2>nul
del "%~f0" >nul 2>nul
"@
  Set-Content -LiteralPath $apply -Value $cmd -Encoding ASCII

  Write-U ("Aplicando {0} e reiniciando..." -f $remote) 'Green'
  Start-Process -FilePath $apply -WindowStyle Normal
  exit 10
} catch {
  Write-U ("Falha na atualizacao: {0}" -f $_.Exception.Message) 'Red'
  exit 2
}
