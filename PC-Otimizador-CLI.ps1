#Requires -Version 5.1
<#
  PC Otimizador Pro — Menu no terminal (hierarquia completa).
  Uso:
    Executar.bat
    powershell -File PC-Otimizador-CLI.ps1
    powershell -File PC-Otimizador-CLI.ps1 -Preset safe
    powershell -File PC-Otimizador-CLI.ps1 -Mode custom|scan|menu
#>
param(
  [ValidateSet('safe','gamer','net','full','')]
  [string]$Preset = '',
  [ValidateSet('menu','custom','scan','')]
  [string]$Mode = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$Host.UI.RawUI.WindowTitle = 'PC Otimizador Pro — Menu'

. (Join-Path $PSScriptRoot 'Engine.ps1')

if (-not (Test-IsAdmin)) {
  Write-Host 'Solicitando Administrador...' -ForegroundColor Yellow
  $pass = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
  if ($Preset) { $pass += @('-Preset', $Preset) }
  if ($Mode)   { $pass += @('-Mode', $Mode) }
  Start-Process powershell.exe -Verb RunAs -ArgumentList $pass | Out-Null
  exit
}

# ── Catalogo do menu ─────────────────────────────────────────────────────────
$script:Opts = [ordered]@{
  restore     = @{ Nome = 'Criar ponto de restauracao';     Cat = 'maint';   Risk = 'safe';     Act = { Invoke-RestorePoint } }
  temp        = @{ Nome = 'Arquivos temporarios';           Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanTemp } }
  recycle     = @{ Nome = 'Esvaziar Lixeira';               Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanRecycleBin } }
  update      = @{ Nome = 'Cache Windows Update';           Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanUpdateCache } }
  delivery    = @{ Nome = 'Delivery Optimization';          Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanDeliveryOptimization } }
  thumbs      = @{ Nome = 'Miniaturas e icones';            Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanThumbnails } }
  wer         = @{ Nome = 'Erros e dumps';                  Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanWER } }
  logs        = @{ Nome = 'Logs do Windows';                Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanLogs } }
  recent      = @{ Nome = 'Atalhos recentes';               Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanRecent } }
  font        = @{ Nome = 'Cache de fontes';                Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanFontCache } }
  cleanmgr    = @{ Nome = 'Limpeza de Disco (cleanmgr)';    Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanMgr } }
  dismcleanup = @{ Nome = 'DISM Component Cleanup';         Cat = 'limpeza'; Risk = 'caution';  Act = { Invoke-DismCleanup } }
  browser     = @{ Nome = 'Cache de navegadores';           Cat = 'limpeza'; Risk = 'caution';  Act = { Invoke-CleanBrowserCaches } }
  gpu         = @{ Nome = 'Cache GPU / shaders';            Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanGpuCache } }
  apps        = @{ Nome = 'Discord/Steam/Teams/Spotify';    Cat = 'limpeza'; Risk = 'caution';  Act = { Invoke-CleanAppCaches } }
  store       = @{ Nome = 'Cache Microsoft Store';          Cat = 'limpeza'; Risk = 'safe';     Act = { Invoke-CleanStoreCache } }
  prefetch    = @{ Nome = 'Prefetch';                       Cat = 'limpeza'; Risk = 'advanced'; Act = { Invoke-CleanPrefetch } }
  upgrade     = @{ Nome = 'Windows.old / `$Windows.~BT';    Cat = 'limpeza'; Risk = 'advanced'; Act = { Invoke-CleanUpgradeLeftovers } }
  trim        = @{ Nome = 'Otimizar unidades (TRIM)';       Cat = 'perf';    Risk = 'safe';     Act = { Invoke-OptimizeDrives } }
  storage     = @{ Nome = 'Storage Sense (sem Downloads)';  Cat = 'perf';    Risk = 'safe';     Act = { Invoke-StorageSense } }
  tips        = @{ Nome = 'Reduzir dicas/telemetria';       Cat = 'perf';    Risk = 'safe';     Act = { Invoke-DisableTips } }
  powerhigh   = @{ Nome = 'Plano Alto Desempenho';         Cat = 'perf';    Risk = 'caution';  Act = { Invoke-HighPerformance } }
  powerbal    = @{ Nome = 'Plano Equilibrado';              Cat = 'perf';    Risk = 'safe';     Act = { Invoke-BalancedPower } }
  visual      = @{ Nome = 'Efeitos visuais -> desempenho';  Cat = 'perf';    Risk = 'caution';  Act = { Invoke-VisualPerf } }
  bgapps      = @{ Nome = 'Limitar apps 2o plano';          Cat = 'perf';    Risk = 'safe';     Act = { Invoke-DisableBackgroundApps } }
  widgets     = @{ Nome = 'Desativar Widgets';              Cat = 'perf';    Risk = 'safe';     Act = { Invoke-DisableWidgets } }
  searchweb   = @{ Nome = 'Desativar busca web Iniciar';    Cat = 'perf';    Risk = 'safe';     Act = { Invoke-DisableSearchWeb } }
  gamebar     = @{ Nome = 'Desativar Game Bar/DVR';         Cat = 'perf';    Risk = 'safe';     Act = { Invoke-DisableGameBar } }
  gamemode    = @{ Nome = 'Ativar Modo de Jogo';            Cat = 'perf';    Risk = 'safe';     Act = { Invoke-GameMode } }
  dns         = @{ Nome = 'Flush DNS';                      Cat = 'net';     Risk = 'safe';     Act = { Invoke-FlushDNS } }
  arp         = @{ Nome = 'Flush ARP';                      Cat = 'net';     Risk = 'safe';     Act = { Invoke-FlushARP } }
  netbios     = @{ Nome = 'Limpar NetBIOS';                 Cat = 'net';     Risk = 'safe';     Act = { Invoke-ClearNetBIOS } }
  nettweak    = @{ Nome = 'Tweaks TCP';                     Cat = 'net';     Risk = 'safe';     Act = { Invoke-NetOptimizations } }
  renewip     = @{ Nome = 'Renovar IP';                     Cat = 'net';     Risk = 'caution';  Act = { Invoke-RenewIP } }
  dnscloud    = @{ Nome = 'DNS Cloudflare 1.1.1.1';         Cat = 'net';     Risk = 'caution';  Act = { Invoke-DnsCloudflare } }
  dnsgoogle   = @{ Nome = 'DNS Google 8.8.8.8';             Cat = 'net';     Risk = 'caution';  Act = { Invoke-DnsGoogle } }
  nagle       = @{ Nome = 'Desativar Nagle (latencia)';     Cat = 'net';     Risk = 'caution';  Act = { Invoke-DisableNagle } }
  winsock     = @{ Nome = 'Reset Winsock';                  Cat = 'net';     Risk = 'advanced'; Act = { Invoke-ResetWinsock } }
  tcpip       = @{ Nome = 'Reset TCP/IP';                   Cat = 'net';     Risk = 'advanced'; Act = { Invoke-ResetTCPIP } }
  sfc         = @{ Nome = 'SFC /scannow';                   Cat = 'maint';   Risk = 'caution';  Act = { Invoke-SFC } }
  dismrestore = @{ Nome = 'DISM RestoreHealth';             Cat = 'maint';   Risk = 'caution';  Act = { Invoke-DismRestore } }
}

$script:Presets = @{
  safe  = @('restore','temp','recycle','update','delivery','thumbs','wer','logs','recent','font','cleanmgr','dismcleanup','trim','storage','tips','dns','arp','netbios','nettweak')
  gamer = @('restore','temp','recycle','update','delivery','thumbs','wer','logs','gpu','apps','trim','tips','gamebar','gamemode','bgapps','widgets','powerhigh','dns','arp','nettweak','nagle','dnscloud')
  net   = @('restore','dns','arp','netbios','nettweak','renewip','dnscloud')
  full  = @('restore','temp','recycle','update','delivery','thumbs','wer','logs','recent','font','cleanmgr','dismcleanup','browser','gpu','apps','store','trim','storage','tips','visual','bgapps','widgets','searchweb','gamebar','gamemode','dns','arp','netbios','nettweak')
}

$script:Selected = [System.Collections.Generic.HashSet[string]]::new()

# ── UI helpers ───────────────────────────────────────────────────────────────
function Clear-Menu {
  Clear-Host
}

function Write-Banner {
  $s = Get-SystemSnapshot
  Write-Host ''
  Write-Host '  ============================================================' -ForegroundColor DarkCyan
  Write-Host '       PC OTIMIZADOR PRO  ·  Menu Terminal' -ForegroundColor Cyan
  Write-Host '  ============================================================' -ForegroundColor DarkCyan
  Write-Host ("  PC: {0}  |  {1}" -f $s.PC, $s.OS) -ForegroundColor DarkGray
  Write-Host ("  Disco C: {0} GB livres / {1} GB ({2}% usado)  |  RAM {3}/{4} GB" -f `
    $s.DiskFree, $s.DiskTot, $s.DiskUsed, $s.RamUsed, $s.RamTot) -ForegroundColor DarkGray
  Write-Host '  Nao apaga Documentos, Fotos, Downloads nem senhas.' -ForegroundColor DarkGreen
  Write-Host ''
}

function Read-Choice {
  param([string]$Prompt = 'Escolha')
  Write-Host ''
  Write-Host -NoNewline "  $Prompt > " -ForegroundColor Yellow
  return (Read-Host).Trim().ToLowerInvariant()
}

function Confirm-Go {
  param([string]$Msg = 'Continuar?')
  Write-Host ''
  Write-Host "  $Msg" -ForegroundColor Yellow
  Write-Host -NoNewline '  [S] Sim   [N] Nao  > ' -ForegroundColor DarkYellow
  $r = (Read-Host).Trim().ToLowerInvariant()
  return ($r -eq 's' -or $r -eq 'sim' -or $r -eq 'y' -or $r -eq 'yes')
}

function Invoke-SelectedRun {
  param([string[]]$Ids)
  if (-not $Ids -or $Ids.Count -eq 0) {
    Write-Host '  Nenhuma opcao selecionada.' -ForegroundColor Red
    Start-Sleep -Seconds 1
    return
  }
  Write-Host ''
  Write-Host ("  Vai executar {0} tarefas." -f $Ids.Count) -ForegroundColor Cyan
  Write-Host '  Nao apaga arquivos pessoais.' -ForegroundColor DarkGray
  if (-not (Confirm-Go 'Confirmar execucao?')) { return }

  $before = Get-SystemSnapshot
  $order = @($Ids | Sort-Object { if ($_ -eq 'restore') { 0 } else { 1 } })
  $i = 0
  $freed = 0.0
  foreach ($id in $order) {
    $i++
    if (-not $script:Opts.Contains($id)) { continue }
    $o = $script:Opts[$id]
    Write-Host ''
    Write-Host ("  >> [{0}/{1}] {2}" -f $i, $order.Count, $o.Nome) -ForegroundColor Green
    try {
      $f = & $o.Act
      if ($f) { $freed += [double]$f }
    } catch {
      Write-Log "Erro em $id : $_" 'ERROR'
    }
  }
  $after = Get-SystemSnapshot
  $delta = [math]::Round($after.DiskFree - $before.DiskFree, 2)
  Write-Host ''
  Write-Host '  ============================================================' -ForegroundColor DarkCyan
  Write-Host ("  CONCLUIDO  |  ~{0:N0} MB  |  Disco C +{1} GB" -f $freed, $delta) -ForegroundColor Cyan
  Write-Host '  Reinicie o PC para aplicar tudo.' -ForegroundColor Yellow
  Write-Host '  ============================================================' -ForegroundColor DarkCyan
  Write-Host ''
  if (Confirm-Go 'Reiniciar o PC agora?') {
    shutdown.exe /r /t 5 /c "PC Otimizador Pro"
    Write-Host '  Reiniciando em 5 segundos...' -ForegroundColor Yellow
    Start-Sleep -Seconds 3
  } else {
    Write-Host ''
    Write-Host '  Pressione Enter para voltar ao menu...' -ForegroundColor DarkGray
    [void](Read-Host)
  }
}

function Show-PresetAndRun {
  param([string]$Key, [string]$Titulo)
  Clear-Menu; Write-Banner
  Write-Host "  PERFIL: $Titulo" -ForegroundColor Cyan
  Write-Host '  ----------------------------------------------------------' -ForegroundColor DarkGray
  $ids = $script:Presets[$Key]
  $n = 1
  foreach ($id in $ids) {
    Write-Host ("   {0,2}. {1}" -f $n, $script:Opts[$id].Nome) -ForegroundColor White
    $n++
  }
  Write-Host ''
  Write-Host '  [E] Executar este perfil   [V] Voltar' -ForegroundColor Yellow
  $c = Read-Choice
  if ($c -eq 'e') { Invoke-SelectedRun $ids }
}

function Toggle-Id([string]$Id) {
  if ($script:Selected.Contains($Id)) { [void]$script:Selected.Remove($Id) }
  else { [void]$script:Selected.Add($Id) }
}

function Show-CategoryMenu {
  param([string]$Cat, [string]$Titulo)
  while ($true) {
    Clear-Menu; Write-Banner
    Write-Host "  $Titulo" -ForegroundColor Cyan
    Write-Host '  Marque itens pelo numero. Cores: branco=seguro  amarelo=atencao  vermelho=avancado' -ForegroundColor DarkGray
    Write-Host '  ----------------------------------------------------------' -ForegroundColor DarkGray

    $list = @($script:Opts.GetEnumerator() | Where-Object { $_.Value.Cat -eq $Cat })
    for ($i = 0; $i -lt $list.Count; $i++) {
      $id = $list[$i].Key
      $o = $list[$i].Value
      $mark = if ($script:Selected.Contains($id)) { '[X]' } else { '[ ]' }
      $col = switch ($o.Risk) {
        'caution'  { 'Yellow' }
        'advanced' { 'Red' }
        default    { 'White' }
      }
      Write-Host ("   {0,2}. {1} {2}" -f ($i + 1), $mark, $o.Nome) -ForegroundColor $col
    }

    Write-Host ''
    Write-Host ("  Selecionadas nesta sessao: {0}" -f $script:Selected.Count) -ForegroundColor Cyan
    Write-Host '  [numero] marcar/desmarcar   [A] marcar todas da lista   [L] limpar marcas' -ForegroundColor DarkYellow
    Write-Host '  [E] executar selecionadas   [V] voltar' -ForegroundColor Yellow

    $c = Read-Choice
    if ($c -eq 'v') { return }
    if ($c -eq 'e') { Invoke-SelectedRun @($script:Selected); return }
    if ($c -eq 'l') { $script:Selected.Clear(); continue }
    if ($c -eq 'a') {
      foreach ($item in $list) { [void]$script:Selected.Add($item.Key) }
      continue
    }
    $num = 0
    if ([int]::TryParse($c, [ref]$num) -and $num -ge 1 -and $num -le $list.Count) {
      Toggle-Id $list[$num - 1].Key
    }
  }
}

function Show-CustomHub {
  while ($true) {
    Clear-Menu; Write-Banner
    Write-Host '  PERSONALIZAR' -ForegroundColor Cyan
    Write-Host '  ----------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '   1. Limpeza' -ForegroundColor White
    Write-Host '   2. Performance' -ForegroundColor White
    Write-Host '   3. Internet' -ForegroundColor White
    Write-Host '   4. Manutencao' -ForegroundColor White
    Write-Host '   5. Ver / executar tudo que marquei' -ForegroundColor Cyan
    Write-Host '   6. Aplicar preset seguro nas marcas' -ForegroundColor DarkGray
    Write-Host '   7. Limpar todas as marcas' -ForegroundColor DarkGray
    Write-Host '   0. Voltar' -ForegroundColor Yellow
    $c = Read-Choice
    switch ($c) {
      '1' { Show-CategoryMenu 'limpeza' 'LIMPEZA' }
      '2' { Show-CategoryMenu 'perf' 'PERFORMANCE' }
      '3' { Show-CategoryMenu 'net' 'INTERNET' }
      '4' { Show-CategoryMenu 'maint' 'MANUTENCAO' }
      '5' {
        Clear-Menu; Write-Banner
        if ($script:Selected.Count -eq 0) {
          Write-Host '  Nenhuma marca ainda.' -ForegroundColor Red
          Start-Sleep 1
        } else {
          Write-Host '  SELECIONADAS:' -ForegroundColor Cyan
          $n = 1
          foreach ($id in $script:Selected) {
            Write-Host ("   {0,2}. {1}" -f $n, $script:Opts[$id].Nome)
            $n++
          }
          Write-Host ''
          Write-Host '  [E] Executar   [V] Voltar' -ForegroundColor Yellow
          $x = Read-Choice
          if ($x -eq 'e') { Invoke-SelectedRun @($script:Selected) }
        }
      }
      '6' {
        $script:Selected.Clear()
        foreach ($id in $script:Presets.safe) { [void]$script:Selected.Add($id) }
        Write-Host '  Preset seguro aplicado nas marcas.' -ForegroundColor Green
        Start-Sleep 1
      }
      '7' { $script:Selected.Clear() }
      '0' { return }
      'v' { return }
    }
  }
}

function Start-Gui {
  $gui = Join-Path $PSScriptRoot 'PC-Otimizador.ps1'
  if (-not (Test-Path $gui)) {
    Write-Host '  Interface grafica nao encontrada.' -ForegroundColor Red
    Start-Sleep 2
    return
  }
  Write-Host '  Abrindo interface grafica...' -ForegroundColor Cyan
  Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$gui`"" -Wait
}

# ── Entry points (bat / argumentos) ──────────────────────────────────────────
if ($Preset) {
  $titles = @{
    safe  = 'Limpeza Segura'
    gamer = 'Turbo / Gamer'
    net   = 'Reparar Internet'
    full  = 'Preset Completo'
  }
  Show-PresetAndRun $Preset $titles[$Preset]
  exit
}

if ($Mode -eq 'scan') {
  Clear-Menu; Write-Banner
  Invoke-ScanOnly | Out-Null
  Write-Host ''
  Write-Host '  Pressione Enter...' -ForegroundColor DarkGray
  [void](Read-Host)
  exit
}

if ($Mode -eq 'custom') {
  Show-CustomHub
  exit
}

# ── Main loop ────────────────────────────────────────────────────────────────
while ($true) {
  Clear-Menu
  Write-Banner
  Write-Host '  MENU PRINCIPAL' -ForegroundColor Cyan
  Write-Host '  ----------------------------------------------------------' -ForegroundColor DarkGray
  Write-Host '   1. Limpeza Segura (recomendado)     << 1 clique' -ForegroundColor Green
  Write-Host '   2. Modo Turbo / Gamer' -ForegroundColor White
  Write-Host '   3. Reparar Internet' -ForegroundColor White
  Write-Host '   4. Preset Completo' -ForegroundColor White
  Write-Host '   5. Personalizar (marcar item a item)' -ForegroundColor Cyan
  Write-Host '   6. So varrer (nao apaga nada)' -ForegroundColor DarkYellow
  Write-Host '   7. Interface grafica' -ForegroundColor DarkGray
  Write-Host '   0. Sair' -ForegroundColor Yellow
  Write-Host ''
  Write-Host '  Dica: se nao souber, escolha 1.' -ForegroundColor DarkGray

  $c = Read-Choice 'Opcao'
  switch ($c) {
    '1' { Show-PresetAndRun 'safe' 'Limpeza Segura' }
    '2' { Show-PresetAndRun 'gamer' 'Turbo / Gamer' }
    '3' { Show-PresetAndRun 'net' 'Reparar Internet' }
    '4' { Show-PresetAndRun 'full' 'Preset Completo' }
    '5' { Show-CustomHub }
    '6' {
      Clear-Menu; Write-Banner
      Invoke-ScanOnly | Out-Null
      Write-Host ''
      Write-Host '  Pressione Enter...' -ForegroundColor DarkGray
      [void](Read-Host)
    }
    '7' { Start-Gui }
    '0' { break }
    's' { break }
    'sair' { break }
  }
}

Write-Host ''
Write-Host '  Ate mais!' -ForegroundColor Cyan
Start-Sleep -Milliseconds 600
