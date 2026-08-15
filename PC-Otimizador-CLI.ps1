#Requires -Version 5.1
<#
  PC Otimizador Pro — CLI v5.3
  -Preset safe|gamer|net|full|notebook
  -Mode menu|custom|scan|schedule|unschedule
  -DryRun -EstimateOnly -AutoYes -Lang pt|en
#>
param(
  [ValidateSet('safe','gamer','net','full','notebook','')]
  [string]$Preset = '',
  [ValidateSet('menu','custom','scan','schedule','unschedule','health','whitelist','bloat','')]
  [string]$Mode = '',
  [switch]$DryRun,
  [switch]$EstimateOnly,
  [switch]$AutoYes,
  [switch]$AllowHighRisk,
  [switch]$StreamProgress,
  [ValidateSet('pt','en')]
  [string]$Lang = 'pt'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$Host.UI.RawUI.WindowTitle = 'PC Otimizador Pro'
. (Join-Path $PSScriptRoot 'Engine.ps1')
$script:UiLang = $Lang

if (-not (Test-IsAdmin)) {
  Write-Host 'Admin...' -ForegroundColor Yellow
  $pass = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath)
  if ($Preset) { $pass += @('-Preset',$Preset) }
  if ($Mode) { $pass += @('-Mode',$Mode) }
  if ($DryRun) { $pass += '-DryRun' }
  if ($EstimateOnly) { $pass += '-EstimateOnly' }
  if ($AutoYes) { $pass += '-AutoYes' }
  if ($AllowHighRisk) { $pass += '-AllowHighRisk' }
  if ($StreamProgress) { $pass += '-StreamProgress' }
  if ($Lang) { $pass += @('-Lang',$Lang) }
  Start-Process powershell.exe -Verb RunAs -ArgumentList $pass | Out-Null
  exit
}

$script:Opts = [ordered]@{
  restore=@{ Nome='Criar ponto de restauracao'; Cat='maint'; Risk='safe'; Act={ Invoke-RestorePoint } }
  temp=@{ Nome='Arquivos temporarios'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanTemp } }
  recycle=@{ Nome='Esvaziar Lixeira'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanRecycleBin } }
  update=@{ Nome='Cache Windows Update'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanUpdateCache } }
  delivery=@{ Nome='Delivery Optimization'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanDeliveryOptimization } }
  thumbs=@{ Nome='Miniaturas e icones'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanThumbnails } }
  wer=@{ Nome='Erros e dumps'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanWER } }
  logs=@{ Nome='Logs do Windows'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanLogs } }
  recent=@{ Nome='Atalhos recentes'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanRecent } }
  font=@{ Nome='Cache de fontes'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanFontCache } }
  cleanmgr=@{ Nome='Limpeza de Disco (cleanmgr)'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanMgr } }
  dismcleanup=@{ Nome='DISM Component Cleanup'; Cat='limpeza'; Risk='caution'; Act={ Invoke-DismCleanup } }
  browser=@{ Nome='Cache de navegadores'; Cat='limpeza'; Risk='caution'; Act={ Invoke-CleanBrowserCaches } }
  gpu=@{ Nome='Cache GPU / shaders'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanGpuCache } }
  apps=@{ Nome='Discord/Steam/Teams/Spotify'; Cat='limpeza'; Risk='caution'; Act={ Invoke-CleanAppCaches } }
  store=@{ Nome='Cache Microsoft Store'; Cat='limpeza'; Risk='safe'; Act={ Invoke-CleanStoreCache } }
  prefetch=@{ Nome='Prefetch'; Cat='limpeza'; Risk='advanced'; Act={ Invoke-CleanPrefetch } }
  upgrade=@{ Nome='Windows.old / upgrade leftovers'; Cat='limpeza'; Risk='advanced'; Act={ Invoke-CleanUpgradeLeftovers } }
  trim=@{ Nome='Otimizar unidades (TRIM)'; Cat='perf'; Risk='safe'; Act={ Invoke-OptimizeDrives } }
  storage=@{ Nome='Storage Sense (sem Downloads)'; Cat='perf'; Risk='safe'; Act={ Invoke-StorageSense } }
  tips=@{ Nome='Reduzir dicas/telemetria'; Cat='perf'; Risk='safe'; Act={ Invoke-DisableTips } }
  powerhigh=@{ Nome='Plano Alto Desempenho'; Cat='perf'; Risk='caution'; Act={ Invoke-HighPerformance } }
  powerbal=@{ Nome='Plano Equilibrado'; Cat='perf'; Risk='safe'; Act={ Invoke-BalancedPower } }
  visual=@{ Nome='Efeitos visuais -> desempenho'; Cat='perf'; Risk='caution'; Act={ Invoke-VisualPerf } }
  bgapps=@{ Nome='Limitar apps 2o plano'; Cat='perf'; Risk='safe'; Act={ Invoke-DisableBackgroundApps } }
  widgets=@{ Nome='Desativar Widgets'; Cat='perf'; Risk='safe'; Act={ Invoke-DisableWidgets } }
  searchweb=@{ Nome='Desativar busca web Iniciar'; Cat='perf'; Risk='safe'; Act={ Invoke-DisableSearchWeb } }
  gamebar=@{ Nome='Desativar Game Bar/DVR'; Cat='perf'; Risk='safe'; Act={ Invoke-DisableGameBar } }
  gamemode=@{ Nome='Ativar Modo de Jogo'; Cat='perf'; Risk='safe'; Act={ Invoke-GameMode } }
  dns=@{ Nome='Flush DNS'; Cat='net'; Risk='safe'; Act={ Invoke-FlushDNS } }
  arp=@{ Nome='Flush ARP'; Cat='net'; Risk='safe'; Act={ Invoke-FlushARP } }
  netbios=@{ Nome='Limpar NetBIOS'; Cat='net'; Risk='safe'; Act={ Invoke-ClearNetBIOS } }
  nettweak=@{ Nome='Tweaks TCP'; Cat='net'; Risk='safe'; Act={ Invoke-NetOptimizations } }
  renewip=@{ Nome='Renovar IP'; Cat='net'; Risk='caution'; Act={ Invoke-RenewIP } }
  dnscloud=@{ Nome='DNS Cloudflare 1.1.1.1'; Cat='net'; Risk='caution'; Act={ Invoke-DnsCloudflare } }
  dnsgoogle=@{ Nome='DNS Google 8.8.8.8'; Cat='net'; Risk='caution'; Act={ Invoke-DnsGoogle } }
  nagle=@{ Nome='Desativar Nagle'; Cat='net'; Risk='caution'; Act={ Invoke-DisableNagle } }
  winsock=@{ Nome='Reset Winsock'; Cat='net'; Risk='advanced'; Act={ Invoke-ResetWinsock } }
  tcpip=@{ Nome='Reset TCP/IP'; Cat='net'; Risk='advanced'; Act={ Invoke-ResetTCPIP } }
  sfc=@{ Nome='SFC /scannow'; Cat='maint'; Risk='caution'; Act={ Invoke-SFC } }
  dismrestore=@{ Nome='DISM RestoreHealth'; Cat='maint'; Risk='caution'; Act={ Invoke-DismRestore } }
}

$script:Selected = [System.Collections.Generic.HashSet[string]]::new()

function Clear-Menu { Clear-Host }
function Write-Banner {
  $s = Get-SystemSnapshot
  Write-Host ''
  Write-Host '  ============================================================' -ForegroundColor DarkCyan
  Write-Host '       PC OTIMIZADOR PRO  ·  v5.4' -ForegroundColor Cyan
  Write-Host '  ============================================================' -ForegroundColor DarkCyan
  Write-Host ("  {0} | {1} | Disco {2} GB livres ({3}% usado)" -f $s.PC, $s.OS, $s.DiskFree, $s.DiskUsed) -ForegroundColor DarkGray
  Write-Host '  Nao apaga Documentos/Fotos/Downloads. Digite ? para ajuda.' -ForegroundColor DarkGreen
  Write-Host ''
}

function Show-HelpScreen {
  Clear-Menu
  Write-Host ''
  Write-Host '  ============================================================' -ForegroundColor Cyan
  Write-Host '       AJUDA — o que cada coisa faz' -ForegroundColor Cyan
  Write-Host '  ============================================================' -ForegroundColor Cyan
  Write-Host ''
  Write-Host '  Limpeza Segura (1)  ' -NoNewline -ForegroundColor Green
  Write-Host 'Temp, lixeira, caches. Ideal na 1a vez.'
  Write-Host '  Dry-run / D         ' -NoNewline -ForegroundColor Yellow
  Write-Host 'Simula sem apagar. Use antes de Executar.'
  Write-Host '  Turbo/Gamer (2)     ' -NoNewline -ForegroundColor Red
  Write-Host 'Pode mudar DNS e plano Alto Desempenho.'
  Write-Host '  Internet (3)        ' -NoNewline -ForegroundColor Red
  Write-Host 'Pode renovar IP e DNS Cloudflare.'
  Write-Host '  Notebook (5)        ' -NoNewline -ForegroundColor Cyan
  Write-Host 'Limpeza + energia equilibrada (bateria).'
  Write-Host '  Health / Varrer     ' -NoNewline -ForegroundColor Cyan
  Write-Host 'So medem (nota 0-100 / MB estimados).'
  Write-Host '  Whitelist (W)       ' -NoNewline -ForegroundColor Cyan
  Write-Host 'Pastas protegidas — nunca apagadas.'
  Write-Host '  Agendar (8)         ' -NoNewline -ForegroundColor White
  Write-Host 'Domingo 10h, so Limpeza Segura.'
  Write-Host '  Bloat (B)           ' -NoNewline -ForegroundColor Yellow
  Write-Host 'Lista apps; so remove se voce confirmar.'
  Write-Host ''
  Write-Host '  NUNCA apagamos: Documentos, Fotos, Videos, Musica,' -ForegroundColor DarkGreen
  Write-Host '  Desktop, Downloads, OneDrive.' -ForegroundColor DarkGreen
  Write-Host '  Logs: Documentos\PC-Otimizador-Logs' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  Fluxo sugerido: Health -> Dry-run da Segura -> Executar.' -ForegroundColor Yellow
  Write-Host ''
  [void](Read-Host '  Enter para voltar')
}

function Get-PresetBlurb([string]$Key) {
  switch ($Key) {
    'safe'     { return 'SAFE: limpa lixo regeneravel. Nao muda DNS/energia.' }
    'gamer'    { return 'RISK: limpeza + alto desempenho + possivel DNS/rede.' }
    'net'      { return 'RISK: flush rede; pode renovar IP e DNS Cloudflare.' }
    'full'     { return 'Limpeza ampla (apps/navegador). Mais demorada.' }
    'notebook' { return 'SAFE: limpeza + plano equilibrado (bom p/ bateria).' }
    default    { return '' }
  }
}
function Read-Choice([string]$Prompt='Opcao') {
  Write-Host -NoNewline "  $Prompt > " -ForegroundColor Yellow
  return (Read-Host).Trim().ToLowerInvariant()
}
function Confirm-Go([string]$Msg='Continuar?') {
  if ($AutoYes) { return $true }
  Write-Host "  $Msg  [S/N]" -ForegroundColor Yellow
  $r = Read-Choice 'Confirma'
  return ($r -in @('s','sim','y','yes'))
}

function Invoke-SelectedRun {
  param([string[]]$Ids, [switch]$AsDry, [switch]$AsEstimate)
  if (-not $Ids -or $Ids.Count -eq 0) { Write-Host '  Nada selecionado.' -ForegroundColor Red; Start-Sleep 1; return }
  Write-Host ("  Itens: {0}" -f $Ids.Count) -ForegroundColor Cyan
  if (-not $AsEstimate -and -not $AsDry -and -not (Confirm-Go 'Executar agora?')) { return }
  if (-not $AsEstimate -and -not $AsDry) {
    $risky = @(Get-HighRiskActionIds -Ids $Ids)
    if ($risky.Count -gt 0) {
      Write-Host ("  ALTO RISCO (DNS / energia / IP): {0}" -f ($risky -join ', ')) -ForegroundColor Red
      if ($AllowHighRisk) {
        Write-Log 'AllowHighRisk: usuario ja confirmou na UI/CLI'
      } elseif ($AutoYes) {
        Write-Host '  Bloqueado: AutoYes nao aplica alto risco. Confirme no menu ou use -AllowHighRisk.' -ForegroundColor Yellow
        return
      } elseif (-not (Confirm-Go 'Confirma acoes de ALTO RISCO? (pode mudar DNS e plano de energia)')) {
        return
      }
    }
  }
  $actions = @{}
  foreach ($k in $script:Opts.Keys) { $actions[$k] = @{ Nome = $script:Opts[$k].Nome; Act = $script:Opts[$k].Act } }
  $result = Invoke-OptimizationBatch -Ids $Ids -Actions $actions -DryRun:$AsDry -EstimateOnly:$AsEstimate
  Write-Host ''
  Write-Host ("  Resultado: ~{0:N0} MB | Disco +{1} GB" -f $result.FreedMB, $result.DeltaGB) -ForegroundColor Green
  if ($result.Log) { Write-Host ("  Log: {0}" -f $result.Log) -ForegroundColor DarkGray }
  if (-not $AsDry -and -not $AsEstimate -and -not $AutoYes) {
    if (Confirm-Go 'Reiniciar PC agora?') { shutdown.exe /r /t 5 /c 'PC Otimizador Pro' }
    else { Write-Host '  Enter...'; [void](Read-Host) }
  } elseif (-not $AutoYes) { Write-Host '  Enter...'; [void](Read-Host) }
}

function Show-PresetAndRun([string]$Key, [string]$Titulo) {
  Clear-Menu; Write-Banner
  $ids = @(Get-PresetIds $Key)
  Write-Host "  PERFIL: $Titulo" -ForegroundColor Cyan
  Write-Host ("  {0}" -f (Get-PresetBlurb $Key)) -ForegroundColor DarkYellow
  Write-Host '  ----------------------------------------------------------' -ForegroundColor DarkGray
  $n=1; foreach ($id in $ids) {
    $nome = if ($script:Opts.Keys -contains $id) { $script:Opts[$id].Nome } else { $id }
    Write-Host ("   {0,2}. {1}" -f $n, $nome); $n++
  }
  Write-Host ''
  Write-Host '  [E] Executar  [D] Dry-run (simula)  [M] So estimar MB  [?] Ajuda  [V] Voltar' -ForegroundColor Yellow
  if ($AutoYes) { Invoke-SelectedRun $ids; return }
  $c = Read-Choice
  switch ($c) {
    'e' { Invoke-SelectedRun $ids }
    'd' { Invoke-SelectedRun $ids -AsDry }
    'm' { Invoke-SelectedRun $ids -AsEstimate }
    '?' { Show-HelpScreen; Show-PresetAndRun $Key $Titulo }
    'h' { Show-HelpScreen; Show-PresetAndRun $Key $Titulo }
  }
}

function Toggle-Id([string]$Id) {
  if ($script:Selected.Contains($Id)) { [void]$script:Selected.Remove($Id) } else { [void]$script:Selected.Add($Id) }
}

function Show-CategoryMenu([string]$Cat, [string]$Titulo) {
  while ($true) {
    Clear-Menu; Write-Banner
    Write-Host "  $Titulo" -ForegroundColor Cyan
    $list = @($script:Opts.GetEnumerator() | Where-Object { $_.Value.Cat -eq $Cat })
    for ($i=0; $i -lt $list.Count; $i++) {
      $id=$list[$i].Key; $o=$list[$i].Value
      $mark = if ($script:Selected.Contains($id)) { '[X]' } else { '[ ]' }
      $mb = Get-OptionEstimateMB $id
      $extra = if ($mb -gt 0.05) { (' ~{0:N0}MB' -f $mb) } else { '' }
      $col = switch ($o.Risk) { 'caution'{'Yellow'} 'advanced'{'Red'} default{'White'} }
      Write-Host ("   {0,2}. {1} {2}{3}" -f ($i+1), $mark, $o.Nome, $extra) -ForegroundColor $col
    }
    Write-Host ("  Selecionadas: {0}" -f $script:Selected.Count) -ForegroundColor Cyan
    Write-Host '  [n] marca  [A] todas  [L] limpa  [E] executa  [D] dry-run  [M] estima  [V] volta' -ForegroundColor DarkYellow
    $c = Read-Choice
    if ($c -eq 'v') { return }
    if ($c -eq 'e') { Invoke-SelectedRun @($script:Selected); return }
    if ($c -eq 'd') { Invoke-SelectedRun @($script:Selected) -AsDry; return }
    if ($c -eq 'm') { Invoke-SelectedRun @($script:Selected) -AsEstimate; return }
    if ($c -eq 'l') { $script:Selected.Clear(); continue }
    if ($c -eq 'a') { foreach ($x in $list) { [void]$script:Selected.Add($x.Key) }; continue }
    $num=0
    if ([int]::TryParse($c,[ref]$num) -and $num -ge 1 -and $num -le $list.Count) { Toggle-Id $list[$num-1].Key }
  }
}

function Show-CustomHub {
  while ($true) {
    Clear-Menu; Write-Banner
    Write-Host '  PERSONALIZAR' -ForegroundColor Cyan
    Write-Host '   1. Limpeza   2. Performance   3. Internet   4. Manutencao' -ForegroundColor White
    Write-Host '   5. Executar marcas   6. Preset seguro nas marcas   7. Limpar marcas' -ForegroundColor Cyan
    Write-Host '   0. Voltar' -ForegroundColor Yellow
    switch (Read-Choice) {
      '1' { Show-CategoryMenu 'limpeza' 'LIMPEZA' }
      '2' { Show-CategoryMenu 'perf' 'PERFORMANCE' }
      '3' { Show-CategoryMenu 'net' 'INTERNET' }
      '4' { Show-CategoryMenu 'maint' 'MANUTENCAO' }
      '5' { Invoke-SelectedRun @($script:Selected) }
      '6' { $script:Selected.Clear(); foreach ($id in (Get-PresetIds 'safe')) { [void]$script:Selected.Add($id) } }
      '7' { $script:Selected.Clear() }
      '0' { return }
      'v' { return }
    }
  }
}

function Start-Gui {
  $exe = Join-Path $PSScriptRoot 'PC-Otimizador.exe'
  if (Test-Path $exe) { Start-Process $exe -Wait; return }
  Write-Host 'Compile a GUI nativa: Compilar-EXE.ps1 (PC-Otimizador.ps1 e legado).' -ForegroundColor Yellow
  Start-Sleep 2
}

# Entry points
if ($Mode -eq 'schedule') { Register-WeeklyCleanup; if (-not $AutoYes) { [void](Read-Host 'Enter') }; exit }
if ($Mode -eq 'unschedule') { Unregister-WeeklyCleanup; if (-not $AutoYes) { [void](Read-Host 'Enter') }; exit }
if ($Mode -eq 'health') {
  Import-Whitelist
  $h = Get-HealthScore
  $m = Get-DriveMediaInfo
  Write-Host ("Health Score: {0}/100 ({1})" -f $h.Score, $h.Grade) -ForegroundColor Cyan
  Write-Host ("Disco usado: {0}% | Livres: {1} GB | RAM: {2}% | Lixo~{3} MB" -f $h.DiskUsed, $h.DiskFreeGB, $h.RamPct, $h.JunkMB)
  if ($m.HasSSD) { Write-Host (Get-T 'ssd') -ForegroundColor Green } elseif ($m.HasHDD) { Write-Host (Get-T 'hdd') -ForegroundColor Yellow }
  try { [Console]::Out.WriteLine(('##HEALTH##|{0}|{1}|Disk {2}%|Free {3}GB|RAM {4}%|Junk {5}MB' -f $h.Score, $h.Grade, $h.DiskUsed, $h.DiskFreeGB, $h.RamPct, $h.JunkMB)) } catch {}
  if (-not $AutoYes) { [void](Read-Host 'Enter') }
  exit
}
if ($Mode -eq 'whitelist') {
  Import-Whitelist
  Write-Host 'Whitelist (pastas protegidas):' -ForegroundColor Cyan
  $script:Whitelist | ForEach-Object { Write-Host ("  - {0}" -f $_) }
  Write-Host ("Arquivo: {0}" -f (Get-WhitelistPath)) -ForegroundColor DarkGray
  Write-Host 'Para adicionar: edite o arquivo ou use Add-WhitelistPath no PowerShell.'
  if (-not $AutoYes) {
    Write-Host -NoNewline 'Caminho extra para proteger (Enter pula): '
    $extra = Read-Host
    if ($extra) { Add-WhitelistPath $extra }
  }
  exit
}
if ($Mode -eq 'bloat') {
  Write-Host 'Bloatware candidatos (AppX):' -ForegroundColor Cyan
  $cands = @(Get-BloatPackageCandidates)
  if ($cands.Count -eq 0) { Write-Host 'Nenhum da lista encontrado.'; if (-not $AutoYes) { [void](Read-Host 'Enter') }; exit }
  $i=1; foreach ($c in $cands) { Write-Host ("  {0}. {1}" -f $i, $c.Name); $i++ }
  if ($AutoYes) {
    Write-Host 'AutoYes: nao remove bloat sem confirmacao interativa.' -ForegroundColor Yellow
    exit
  }
  if (Confirm-Go 'Remover TODOS listados? (pode afetar apps da Microsoft Store)') {
    $script:DryRun = [bool]$DryRun
    Remove-BloatPackages -PackageFullNames ($cands.PackageFullName) | Out-Null
  }
  exit
}
if ($Mode -eq 'scan') {
  Clear-Menu; Write-Banner
  $null = Initialize-SessionLog
  Invoke-ScanOnly | Out-Null
  Write-EstimatesReport (Get-PresetIds 'safe') | Out-Null
  $h = Get-HealthScore
  Write-Log ("Health Score: {0}/100 ({1})" -f $h.Score, $h.Grade)
  Complete-SessionLog | Out-Null
  if (-not $AutoYes) { [void](Read-Host 'Enter') }
  exit
}
if ($Preset) {
  if ($DryRun -or $EstimateOnly -or $AutoYes) {
    $ids = @(Get-PresetIds $Preset)
    Invoke-SelectedRun $ids -AsDry:$DryRun -AsEstimate:$EstimateOnly
    exit
  }
  $titles = @{ safe='Limpeza Segura'; gamer='Turbo/Gamer'; net='Reparar Internet'; full='Completo'; notebook='Notebook' }
  Show-PresetAndRun $Preset $titles[$Preset]
  exit
}
if ($Mode -eq 'custom') { Show-CustomHub; exit }

while ($true) {
  Clear-Menu; Write-Banner
  Write-Host '  MENU PRINCIPAL  (digite ? para ajuda)' -ForegroundColor Cyan
  Write-Host '  ----------------------------------------------------------' -ForegroundColor DarkGray
  Write-Host '   1. Limpeza Segura ★     ' -NoNewline -ForegroundColor Green; Write-Host 'temp/lixeira/caches (recomendado)' -ForegroundColor DarkGray
  Write-Host '   2. Turbo / Gamer        ' -NoNewline -ForegroundColor White; Write-Host 'RISK: DNS/energia' -ForegroundColor DarkYellow
  Write-Host '   3. Reparar Internet     ' -NoNewline -ForegroundColor White; Write-Host 'RISK: DNS/IP' -ForegroundColor DarkYellow
  Write-Host '   4. Preset Completo      ' -NoNewline -ForegroundColor White; Write-Host 'limpeza ampla' -ForegroundColor DarkGray
  Write-Host '   5. Notebook (bateria)   ' -NoNewline -ForegroundColor Cyan; Write-Host 'plano equilibrado' -ForegroundColor DarkGray
  Write-Host '   6. Personalizar         ' -NoNewline -ForegroundColor Cyan; Write-Host 'escolhe item a item' -ForegroundColor DarkGray
  Write-Host '   7. So varrer / estimar  ' -NoNewline -ForegroundColor DarkYellow; Write-Host 'nao apaga' -ForegroundColor DarkGray
  Write-Host '   8. Agendar semanal      ' -NoNewline -ForegroundColor White; Write-Host 'domingo 10h SAFE' -ForegroundColor DarkGray
  Write-Host '   9. Remover agendamento' -ForegroundColor DarkGray
  Write-Host '   H. Health Score         ' -NoNewline -ForegroundColor Cyan; Write-Host 'nota 0-100' -ForegroundColor DarkGray
  Write-Host '   W. Whitelist            ' -NoNewline -ForegroundColor Cyan; Write-Host 'pastas protegidas' -ForegroundColor DarkGray
  Write-Host '   B. Bloatware            ' -NoNewline -ForegroundColor Yellow; Write-Host 'lista + confirma' -ForegroundColor DarkGray
  Write-Host '   G. Interface grafica    ' -NoNewline -ForegroundColor DarkGray; Write-Host 'tooltips' -ForegroundColor DarkGray
  Write-Host '   ?. Ajuda' -ForegroundColor Green
  Write-Host '   L. PT/EN idioma' -ForegroundColor DarkGray
  Write-Host '   0. Sair' -ForegroundColor Yellow
  switch (Read-Choice) {
    '1' { Show-PresetAndRun 'safe' 'Limpeza Segura' }
    '2' { Show-PresetAndRun 'gamer' 'Turbo / Gamer' }
    '3' { Show-PresetAndRun 'net' 'Reparar Internet' }
    '4' { Show-PresetAndRun 'full' 'Completo' }
    '5' { Show-PresetAndRun 'notebook' 'Notebook' }
    '6' { Show-CustomHub }
    '7' {
      Clear-Menu; Write-Banner
      Write-Host '  Modo varrer: estima espaco, nao apaga.' -ForegroundColor Yellow
      $null = Initialize-SessionLog
      Invoke-ScanOnly | Out-Null
      Write-EstimatesReport (Get-PresetIds 'safe') | Out-Null
      $h = Get-HealthScore; Write-Host ("  Health: {0}/100 ({1})" -f $h.Score, $h.Grade) -ForegroundColor Cyan
      Complete-SessionLog | Out-Null
      [void](Read-Host 'Enter')
    }
    '8' {
      Write-Host '  Agenda so Limpeza Segura (sem DNS/energia), domingo 10h.' -ForegroundColor Yellow
      if (Confirm-Go 'Criar agendamento?') { Register-WeeklyCleanup }
      [void](Read-Host 'Enter')
    }
    '9' { Unregister-WeeklyCleanup; [void](Read-Host 'Enter') }
    'h' {
      $h = Get-HealthScore; $m = Get-DriveMediaInfo
      Write-Host ("  Score {0}/100 ({1}) | Disco {2}% | Lixo~{3}MB" -f $h.Score, $h.Grade, $h.DiskUsed, $h.JunkMB) -ForegroundColor Cyan
      Write-Host '  Quanto maior o score, melhor. Nao altera o PC.' -ForegroundColor DarkGray
      if ($m.HasSSD) { Write-Host ('  ' + (Get-T 'ssd')) -ForegroundColor Green }
      [void](Read-Host 'Enter')
    }
    'w' {
      Import-Whitelist
      Write-Host '  Pastas que NUNCA serao apagadas:' -ForegroundColor Cyan
      $script:Whitelist | ForEach-Object { Write-Host ("  - {0}" -f $_) }
      Write-Host -NoNewline '  Extra path para proteger (Enter pula): '; $x = Read-Host
      if ($x) { Add-WhitelistPath $x }
    }
    'b' {
      Write-Host '  Lista candidatos; so remove se voce confirmar.' -ForegroundColor Yellow
      $cands = @(Get-BloatPackageCandidates)
      if ($cands.Count -eq 0) { Write-Host '  Nenhum bloat da lista.'; [void](Read-Host 'Enter'); continue }
      $cands | ForEach-Object { Write-Host ("  - {0}" -f $_.Name) }
      if (Confirm-Go 'Remover todos listados?') { Remove-BloatPackages -PackageFullNames $cands.PackageFullName | Out-Null }
      [void](Read-Host 'Enter')
    }
    'g' { Start-Gui }
    '?' { Show-HelpScreen }
    'ajuda' { Show-HelpScreen }
    'l' {
      $script:UiLang = if ($script:UiLang -eq 'pt') { 'en' } else { 'pt' }
      Write-Host ("  Lang = {0}" -f $script:UiLang) -ForegroundColor Cyan; Start-Sleep 1
    }
    '0' { break }
    's' { break }
  }
}
Write-Host '  Ate mais!' -ForegroundColor Cyan
