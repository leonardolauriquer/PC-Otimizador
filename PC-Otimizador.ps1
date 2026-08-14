#Requires -Version 5.1
<#
.SYNOPSIS
  PC Otimizador Pro v3 — UI futurista, fluxo intuitivo (Home -> Opcoes -> Execucao -> Pronto).
  Nao apaga Documentos, Fotos, Downloads nem arquivos pessoais.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ── Theme (futurista: void + ciano eletrico) ─────────────────────────────────
$script:T = @{
  Bg      = [Drawing.Color]::FromArgb(6, 8, 14)
  Panel   = [Drawing.Color]::FromArgb(12, 16, 26)
  Card    = [Drawing.Color]::FromArgb(16, 22, 36)
  CardHi  = [Drawing.Color]::FromArgb(22, 32, 52)
  Border  = [Drawing.Color]::FromArgb(40, 60, 90)
  Accent  = [Drawing.Color]::FromArgb(0, 229, 192)      # cyan mint
  Accent2 = [Drawing.Color]::FromArgb(56, 189, 248)     # sky
  Accent3 = [Drawing.Color]::FromArgb(167, 139, 250)    # soft violet ONLY for one badge
  Warn    = [Drawing.Color]::FromArgb(251, 191, 36)
  Danger  = [Drawing.Color]::FromArgb(248, 113, 113)
  Text    = [Drawing.Color]::FromArgb(241, 245, 249)
  Muted   = [Drawing.Color]::FromArgb(100, 116, 139)
  Ok      = [Drawing.Color]::FromArgb(52, 211, 153)
  LogBg   = [Drawing.Color]::FromArgb(4, 6, 10)
  LogFg   = [Drawing.Color]::FromArgb(110, 231, 183)
}

$script:LogBox = $null
$script:Checks = [ordered]@{}
$script:Screens = @{}
$script:StepLabels = @{}
$script:Progress = $null
$script:ProgressLbl = $null
$script:TaskLbl = $null
$script:ResultLbl = $null
$script:SelectedLbl = $null
$script:GaugeFill = $null
$script:GaugeText = $null
$script:HeroStats = $null
$script:SnapBefore = $null
$script:LastFreedMB = 0
$script:CatalogFilter = 'all'

# Motor compartilhado (CLI + GUI)
. (Join-Path $PSScriptRoot 'Engine.ps1')

# ── Catalog (fonte unica das opcoes) ─────────────────────────────────────────
function Get-OptCatalog {
  @(
    @{ Id='restore'; Cat='maint'; Name='Criar ponto de restauracao'; Hint='Seguranca antes de mudar o sistema'; Risk='safe'; Action={ Invoke-RestorePoint } }
    @{ Id='temp'; Cat='limpeza'; Name='Arquivos temporarios'; Hint='Temp do usuario e do Windows'; Risk='safe'; Action={ Invoke-CleanTemp } }
    @{ Id='recycle'; Cat='limpeza'; Name='Esvaziar Lixeira'; Hint='Remove itens da Lixeira'; Risk='safe'; Action={ Invoke-CleanRecycleBin } }
    @{ Id='update'; Cat='limpeza'; Name='Cache Windows Update'; Hint='Downloads de update ja aplicados'; Risk='safe'; Action={ Invoke-CleanUpdateCache } }
    @{ Id='delivery'; Cat='limpeza'; Name='Delivery Optimization'; Hint='Cache P2P de atualizacoes'; Risk='safe'; Action={ Invoke-CleanDeliveryOptimization } }
    @{ Id='thumbs'; Cat='limpeza'; Name='Miniaturas e icones'; Hint='Recria caches do Explorer'; Risk='safe'; Action={ Invoke-CleanThumbnails } }
    @{ Id='wer'; Cat='limpeza'; Name='Erros e dumps de memoria'; Hint='WER + Minidump + MEMORY.DMP'; Risk='safe'; Action={ Invoke-CleanWER } }
    @{ Id='logs'; Cat='limpeza'; Name='Logs do Windows'; Hint='CBS / DISM / WindowsUpdate'; Risk='safe'; Action={ Invoke-CleanLogs } }
    @{ Id='recent'; Cat='limpeza'; Name='Atalhos recentes'; Hint='So atalhos, nao apaga arquivos'; Risk='safe'; Action={ Invoke-CleanRecent } }
    @{ Id='font'; Cat='limpeza'; Name='Cache de fontes'; Hint='Reinicia FontCache'; Risk='safe'; Action={ Invoke-CleanFontCache } }
    @{ Id='cleanmgr'; Cat='limpeza'; Name='Limpeza de Disco (cleanmgr)'; Hint='Ferramenta oficial Microsoft'; Risk='safe'; Action={ Invoke-CleanMgr } }
    @{ Id='dismcleanup'; Cat='limpeza'; Name='DISM Component Cleanup'; Hint='Remove componentes antigos (demora)'; Risk='caution'; Action={ Invoke-DismCleanup } }
    @{ Id='browser'; Cat='limpeza'; Name='Cache de navegadores'; Hint='Favoritos e senhas preservados'; Risk='caution'; Action={ Invoke-CleanBrowserCaches } }
    @{ Id='gpu'; Cat='limpeza'; Name='Cache GPU / shaders'; Hint='DirectX / NVIDIA / AMD / Intel'; Risk='safe'; Action={ Invoke-CleanGpuCache } }
    @{ Id='apps'; Cat='limpeza'; Name='Discord / Steam / Teams / Spotify'; Hint='Fecha o app e limpa cache'; Risk='caution'; Action={ Invoke-CleanAppCaches } }
    @{ Id='store'; Cat='limpeza'; Name='Cache Microsoft Store'; Hint='wsreset + INetCache'; Risk='safe'; Action={ Invoke-CleanStoreCache } }
    @{ Id='prefetch'; Cat='limpeza'; Name='Prefetch'; Hint='Pode deixar o proximo boot mais lento'; Risk='advanced'; Action={ Invoke-CleanPrefetch } }
    @{ Id='upgrade'; Cat='limpeza'; Name='Restos de upgrade (Windows.old)'; Hint='Pode liberar GBs; irreversivel'; Risk='advanced'; Action={ Invoke-CleanUpgradeLeftovers } }
    @{ Id='trim'; Cat='perf'; Name='Otimizar unidades (TRIM)'; Hint='Recomendado em SSD'; Risk='safe'; Action={ Invoke-OptimizeDrives } }
    @{ Id='storage'; Cat='perf'; Name='Storage Sense (sem Downloads)'; Hint='Limpeza automatica so de temp'; Risk='safe'; Action={ Invoke-StorageSense } }
    @{ Id='tips'; Cat='perf'; Name='Reduzir dicas e telemetria'; Hint='Nao desativa Windows Update'; Risk='safe'; Action={ Invoke-DisableTips } }
    @{ Id='powerhigh'; Cat='perf'; Name='Plano Alto Desempenho'; Hint='Mais energia — cuidado em notebook'; Risk='caution'; Action={ Invoke-HighPerformance } }
    @{ Id='powerbal'; Cat='perf'; Name='Plano Equilibrado'; Hint='Melhor para notebook'; Risk='safe'; Action={ Invoke-BalancedPower } }
    @{ Id='visual'; Cat='perf'; Name='Efeitos visuais para desempenho'; Hint='Menos animacoes'; Risk='caution'; Action={ Invoke-VisualPerf } }
    @{ Id='bgapps'; Cat='perf'; Name='Limitar apps em segundo plano'; Hint='Economiza RAM/CPU'; Risk='safe'; Action={ Invoke-DisableBackgroundApps } }
    @{ Id='widgets'; Cat='perf'; Name='Desativar Widgets / noticias'; Hint='Barra de tarefas mais limpa'; Risk='safe'; Action={ Invoke-DisableWidgets } }
    @{ Id='searchweb'; Cat='perf'; Name='Desativar busca web no Iniciar'; Hint='Busca apenas local'; Risk='safe'; Action={ Invoke-DisableSearchWeb } }
    @{ Id='gamebar'; Cat='perf'; Name='Desativar Game Bar / DVR'; Hint='Menos overhead em jogos'; Risk='safe'; Action={ Invoke-DisableGameBar } }
    @{ Id='gamemode'; Cat='perf'; Name='Ativar Modo de Jogo'; Hint='Prioriza recursos no jogo'; Risk='safe'; Action={ Invoke-GameMode } }
    @{ Id='dns'; Cat='net'; Name='Flush DNS'; Hint='Limpa cache de nomes'; Risk='safe'; Action={ Invoke-FlushDNS } }
    @{ Id='arp'; Cat='net'; Name='Flush ARP'; Hint='Limpa tabela ARP'; Risk='safe'; Action={ Invoke-FlushARP } }
    @{ Id='netbios'; Cat='net'; Name='Limpar NetBIOS'; Hint='nbtstat -R / -RR'; Risk='safe'; Action={ Invoke-ClearNetBIOS } }
    @{ Id='nettweak'; Cat='net'; Name='Tweaks TCP + throttling'; Hint='Autotuning e perfil multimedia'; Risk='safe'; Action={ Invoke-NetOptimizations } }
    @{ Id='renewip'; Cat='net'; Name='Renovar IP'; Hint='Pode cair a net alguns segundos'; Risk='caution'; Action={ Invoke-RenewIP } }
    @{ Id='dnscloud'; Cat='net'; Name='DNS Cloudflare 1.1.1.1'; Hint='Troca DNS das placas ativas'; Risk='caution'; Action={ Invoke-DnsCloudflare } }
    @{ Id='dnsgoogle'; Cat='net'; Name='DNS Google 8.8.8.8'; Hint='Alternativa ao Cloudflare'; Risk='caution'; Action={ Invoke-DnsGoogle } }
    @{ Id='nagle'; Cat='net'; Name='Desativar Nagle (latencia)'; Hint='Jogos competitivos'; Risk='caution'; Action={ Invoke-DisableNagle } }
    @{ Id='winsock'; Cat='net'; Name='Reset Winsock'; Hint='Exige reiniciar'; Risk='advanced'; Action={ Invoke-ResetWinsock } }
    @{ Id='tcpip'; Cat='net'; Name='Reset TCP/IP'; Hint='Exige reiniciar'; Risk='advanced'; Action={ Invoke-ResetTCPIP } }
    @{ Id='sfc'; Cat='maint'; Name='SFC /scannow'; Hint='10-30 min'; Risk='caution'; Action={ Invoke-SFC } }
    @{ Id='dismrestore'; Cat='maint'; Name='DISM RestoreHealth'; Hint='10-40 min'; Risk='caution'; Action={ Invoke-DismRestore } }
  )
}

$script:Presets = @{
  safe     = @(Get-PresetIds 'safe')
  gamer    = @(Get-PresetIds 'gamer')
  net      = @(Get-PresetIds 'net')
  full     = @(Get-PresetIds 'full')
  notebook = @(Get-PresetIds 'notebook')
}
$script:DryRunUi = $false
$script:LightTheme = $false

# ── UI helpers ───────────────────────────────────────────────────────────────
function Update-HeroStats {
  $s = Get-SystemSnapshot
  $admin = if (Test-IsAdmin) { 'ADMIN OK' } else { 'SEM ADMIN' }
  if ($script:HeroStats) {
    $script:HeroStats.Text = "$($s.PC)  ·  $($s.OS)  ·  $admin`nRAM  $($s.RamUsed)/$($s.RamTot) GB"
  }
  if ($script:GaugeFill -and $script:GaugeText) {
    $pct = [math]::Min(100, [int]$s.DiskUsed)
    $script:GaugeFill.Width = [math]::Max(4, [int](360 * $pct / 100))
    $col = if ($pct -ge 90) { $script:T.Danger } elseif ($pct -ge 75) { $script:T.Warn } else { $script:T.Accent }
    $script:GaugeFill.BackColor = $col
    $script:GaugeText.Text = "Disco C  ·  $($s.DiskFree) GB livres de $($s.DiskTot) GB  ·  $pct% usado"
  }
}

function Set-Step {
  param([int]$Active) # 1..4
  foreach ($i in 1..4) {
    $l = $script:StepLabels[$i]
    if (-not $l) { continue }
    if ($i -eq $Active) {
      $l.ForeColor = $script:T.Bg
      $l.BackColor = $script:T.Accent
    } elseif ($i -lt $Active) {
      $l.ForeColor = $script:T.Accent
      $l.BackColor = $script:T.CardHi
    } else {
      $l.ForeColor = $script:T.Muted
      $l.BackColor = $script:T.Card
    }
  }
}

function Show-Screen {
  param([string]$Name)
  foreach ($k in $script:Screens.Keys) { $script:Screens[$k].Visible = ($k -eq $Name) }
  switch ($Name) {
    'home'   { Set-Step 1; Update-HeroStats }
    'custom' { Set-Step 2; Update-SelectedCount }
    'run'    { Set-Step 3 }
    'done'   { Set-Step 4; Update-HeroStats }
  }
}

function Apply-PresetIds {
  param([string[]]$Ids)
  foreach ($id in $script:Checks.Keys) { $script:Checks[$id].Box.Checked = $false }
  foreach ($id in $Ids) {
    if ($script:Checks.Contains($id)) { $script:Checks[$id].Box.Checked = $true }
  }
  Update-SelectedCount
}

function Update-SelectedCount {
  $n = @($script:Checks.Keys | Where-Object { $script:Checks[$_].Box.Checked }).Count
  if ($script:SelectedLbl) { $script:SelectedLbl.Text = "$n selecionadas" }
}

function New-GlowCard {
  param([int]$X, [int]$Y, [int]$W, [int]$H, [string]$Title, [string]$Sub, [string]$Badge, [Drawing.Color]$Accent, [scriptblock]$OnClick)
  $card = New-Object Windows.Forms.Panel
  $card.Location = New-Object Drawing.Point($X, $Y)
  $card.Size = New-Object Drawing.Size($W, $H)
  $card.BackColor = $script:T.Card
  $card.Cursor = [Windows.Forms.Cursors]::Hand

  $edge = New-Object Windows.Forms.Panel
  $edge.Size = New-Object Drawing.Size(4, $H)
  $edge.Location = New-Object Drawing.Point(0, 0)
  $edge.BackColor = $Accent
  $card.Controls.Add($edge)

  $badgeLbl = New-Object Windows.Forms.Label
  $badgeLbl.Text = $Badge
  $badgeLbl.Location = New-Object Drawing.Point(18, 16)
  $badgeLbl.AutoSize = $true
  $badgeLbl.Font = New-Object Drawing.Font('Segoe UI Semibold', 8)
  $badgeLbl.ForeColor = $Accent
  $card.Controls.Add($badgeLbl)

  $t = New-Object Windows.Forms.Label
  $t.Text = $Title
  $t.Location = New-Object Drawing.Point(18, 40)
  $t.Size = New-Object Drawing.Size(($W - 30), 36)
  $t.Font = New-Object Drawing.Font('Segoe UI Semibold', 14)
  $t.ForeColor = $script:T.Text
  $card.Controls.Add($t)

  $s = New-Object Windows.Forms.Label
  $s.Text = $Sub
  $s.Location = New-Object Drawing.Point(18, 84)
  $s.Size = New-Object Drawing.Size(($W - 30), 48)
  $s.Font = New-Object Drawing.Font('Segoe UI', 9)
  $s.ForeColor = $script:T.Muted
  $card.Controls.Add($s)

  $go = New-Object Windows.Forms.Label
  $go.Text = 'Iniciar  →'
  $go.Location = New-Object Drawing.Point(18, ($H - 36))
  $go.AutoSize = $true
  $go.Font = New-Object Drawing.Font('Segoe UI Semibold', 9.5)
  $go.ForeColor = $Accent
  $card.Controls.Add($go)

  $handler = {
    param($sender, $e)
    & $OnClick
  }.GetNewClosure()

  foreach ($c in @($card, $t, $s, $go, $badgeLbl, $edge)) {
    $c.Cursor = [Windows.Forms.Cursors]::Hand
    $c.Add_Click($handler)
  }
  $card.Add_MouseEnter({ $card.BackColor = $script:T.CardHi }.GetNewClosure())
  $card.Add_MouseLeave({ $card.BackColor = $script:T.Card }.GetNewClosure())
  return $card
}

function New-Pill {
  param([string]$Text, [int]$X, [string]$Filter)
  $b = New-Object Windows.Forms.Button
  $b.Text = $Text
  $b.Tag = $Filter
  $b.Location = New-Object Drawing.Point($X, 0)
  $b.Size = New-Object Drawing.Size(100, 30)
  $b.FlatStyle = 'Flat'
  $b.FlatAppearance.BorderSize = 1
  $b.FlatAppearance.BorderColor = $script:T.Border
  $b.BackColor = $script:T.Card
  $b.ForeColor = $script:T.Muted
  $b.Font = New-Object Drawing.Font('Segoe UI Semibold', 8.5)
  $b.Add_Click({
    param($sender, $e)
    $script:CatalogFilter = [string]$sender.Tag
    Apply-OptFilter
  })
  return $b
}

function Apply-OptFilter {
  $f = $script:CatalogFilter
  foreach ($id in $script:Checks.Keys) {
    $row = $script:Checks[$id].Row
    $cat = $script:Checks[$id].Cat
    $row.Visible = ($f -eq 'all' -or $f -eq $cat)
  }
}

function Start-OptimizationRun {
  $selected = @($script:Checks.Keys | Where-Object { $script:Checks[$_].Box.Checked })
  if ($selected.Count -eq 0) {
    [Windows.Forms.MessageBox]::Show('Nenhuma opcao marcada.', 'Atencao', 'OK', 'Information') | Out-Null
    return
  }

  $modeLabel = if ($script:DryRunUi) { 'DRY-RUN (simular)' } else { 'EXECUCAO REAL' }
  $summary = "$modeLabel`n$($selected.Count) otimizacoes.`n`nNao apaga fotos/documentos/downloads.`nContinuar?"
  if ([Windows.Forms.MessageBox]::Show($summary, 'Confirmar', 'YesNo', 'Question') -ne 'Yes') { return }

  Show-Screen 'run'
  $script:LogBox = $script:RunLogBox
  if ($script:LogBox) { $script:LogBox.Clear() }
  $script:Progress.Value = 0
  $script:ProgressLbl.Text = '0%'
  $script:TaskLbl.Text = 'Preparando...'
  [Windows.Forms.Application]::DoEvents()

  $actions = @{}
  foreach ($id in $script:Checks.Keys) {
    $actions[$id] = @{ Nome = $script:Checks[$id].Name; Act = $script:Checks[$id].Action }
  }
  $result = Invoke-OptimizationBatch -Ids $selected -Actions $actions -DryRun:$script:DryRunUi
  $script:Progress.Value = 100
  $script:ProgressLbl.Text = '100%'
  $script:TaskLbl.Text = 'Concluido'
  if ($script:ResultLbl) {
    $script:ResultLbl.Text = ("+{0} GB livres`n~{1:N0} MB limpos`nEstimativa previa ~{2:N0} MB`n`nLog: {3}" -f $result.DeltaGB, $result.FreedMB, $result.EstimatedMB, $result.Log)
  }
  Show-Screen 'done'
}

# ── Form ─────────────────────────────────────────────────────────────────────
$form = New-Object Windows.Forms.Form
$form.Text = 'PC Otimizador Pro'
$form.Size = New-Object Drawing.Size(1020, 700)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $script:T.Bg
$form.ForeColor = $script:T.Text
$form.Font = New-Object Drawing.Font('Segoe UI', 9)

# Top bar
$top = New-Object Windows.Forms.Panel
$top.Dock = 'Top'
$top.Height = 64
$top.BackColor = $script:T.Panel
$form.Controls.Add($top)

$logo = New-Object Windows.Forms.Label
$logo.Text = '◈  PC OTIMIZADOR PRO'
$logo.Font = New-Object Drawing.Font('Segoe UI Semibold', 12)
$logo.ForeColor = $script:T.Accent
$logo.Location = New-Object Drawing.Point(20, 18)
$logo.AutoSize = $true
$top.Controls.Add($logo)

# Steps
$stepNames = @{ 1 = '1  Inicio'; 2 = '2  Opcoes'; 3 = '3  Executar'; 4 = '4  Pronto' }
$sx = 420
foreach ($i in 1..4) {
  $sl = New-Object Windows.Forms.Label
  $sl.Text = $stepNames[$i]
  $sl.TextAlign = 'MiddleCenter'
  $sl.Size = New-Object Drawing.Size(110, 28)
  $sl.Location = New-Object Drawing.Point($sx, 18)
  $sl.Font = New-Object Drawing.Font('Segoe UI Semibold', 8.5)
  $sl.BackColor = $script:T.Card
  $sl.ForeColor = $script:T.Muted
  $top.Controls.Add($sl)
  $script:StepLabels[$i] = $sl
  $sx += 118
}

# Screen host
$screenHost = New-Object Windows.Forms.Panel
$screenHost.Dock = 'Fill'
$screenHost.BackColor = $script:T.Bg
$screenHost.Padding = New-Object Windows.Forms.Padding(24)
$form.Controls.Add($screenHost)

function New-Screen([string]$Key) {
  $p = New-Object Windows.Forms.Panel
  $p.Dock = 'Fill'
  $p.BackColor = $script:T.Bg
  $p.Visible = $false
  $screenHost.Controls.Add($p)
  $script:Screens[$Key] = $p
  return $p
}

# ══ HOME ═════════════════════════════════════════════════════════════════════
$home = New-Screen 'home'

$script:HeroStats = New-Object Windows.Forms.Label
$script:HeroStats.Location = New-Object Drawing.Point(8, 8)
$script:HeroStats.Size = New-Object Drawing.Size(700, 40)
$script:HeroStats.ForeColor = $script:T.Muted
$script:HeroStats.Font = New-Object Drawing.Font('Segoe UI', 9.5)
$home.Controls.Add($script:HeroStats)

$hero = New-Object Windows.Forms.Label
$hero.Text = 'Otimize seu PC em 1 clique'
$hero.Location = New-Object Drawing.Point(8, 56)
$hero.Size = New-Object Drawing.Size(700, 40)
$hero.Font = New-Object Drawing.Font('Segoe UI Semibold', 22)
$hero.ForeColor = $script:T.Text
$home.Controls.Add($hero)

$heroSub = New-Object Windows.Forms.Label
$heroSub.Text = 'Escolha um perfil. Nada de fotos, documentos ou downloads e apagado.'
$heroSub.Location = New-Object Drawing.Point(10, 98)
$heroSub.Size = New-Object Drawing.Size(700, 24)
$heroSub.ForeColor = $script:T.Muted
$home.Controls.Add($heroSub)

# Gauge
$gaugeBg = New-Object Windows.Forms.Panel
$gaugeBg.Location = New-Object Drawing.Point(10, 136)
$gaugeBg.Size = New-Object Drawing.Size(360, 10)
$gaugeBg.BackColor = $script:T.Card
$home.Controls.Add($gaugeBg)

$script:GaugeFill = New-Object Windows.Forms.Panel
$script:GaugeFill.Location = New-Object Drawing.Point(0, 0)
$script:GaugeFill.Size = New-Object Drawing.Size(100, 10)
$script:GaugeFill.BackColor = $script:T.Accent
$gaugeBg.Controls.Add($script:GaugeFill)

$script:GaugeText = New-Object Windows.Forms.Label
$script:GaugeText.Location = New-Object Drawing.Point(380, 130)
$script:GaugeText.Size = New-Object Drawing.Size(480, 22)
$script:GaugeText.ForeColor = $script:T.Muted
$script:GaugeText.Font = New-Object Drawing.Font('Segoe UI', 9)
$home.Controls.Add($script:GaugeText)

# Profile cards
$home.Controls.Add((New-GlowCard 10 180 230 150 'Limpeza Segura' "Recomendado para`nqualquer pessoa." '★ SAFE' $script:T.Accent {
  Apply-PresetIds $script:Presets.safe
  Start-OptimizationRun
}))
$home.Controls.Add((New-GlowCard 255 180 230 150 'Turbo / Gamer' "FPS, Game Bar off,`nGPU e latencia." 'PERF' $script:T.Accent2 {
  Apply-PresetIds $script:Presets.gamer
  Start-OptimizationRun
}))
$home.Controls.Add((New-GlowCard 500 180 230 150 'Reparar Internet' "DNS, ARP, TCP e`nCloudflare 1.1.1.1." 'NET' $script:T.Warn {
  Apply-PresetIds $script:Presets.net
  Start-OptimizationRun
}))
$home.Controls.Add((New-GlowCard 745 180 230 150 'Notebook' "Equilibrado, bateria,`nsem Alto Desempenho." 'LAPTOP' ([Drawing.Color]::FromArgb(52, 211, 153)) {
  Apply-PresetIds $script:Presets.notebook
  Start-OptimizationRun
}))

$chkDry = New-Object Windows.Forms.CheckBox
$chkDry.Text = 'Dry-run (simular, nao apaga)'
$chkDry.Location = New-Object Drawing.Point(10, 345)
$chkDry.AutoSize = $true
$chkDry.ForeColor = $script:T.Warn
$chkDry.Add_CheckedChanged({ $script:DryRunUi = $chkDry.Checked })
$home.Controls.Add($chkDry)

$btnScanHome = New-Object Windows.Forms.Button
$btnScanHome.Text = 'Varrer + estimar MB'
$btnScanHome.Location = New-Object Drawing.Point(10, 380)
$btnScanHome.Size = New-Object Drawing.Size(200, 40)
$btnScanHome.FlatStyle = 'Flat'
$btnScanHome.FlatAppearance.BorderColor = $script:T.Border
$btnScanHome.BackColor = $script:T.Card
$btnScanHome.ForeColor = $script:T.Text
$btnScanHome.Font = New-Object Drawing.Font('Segoe UI Semibold', 9)
$home.Controls.Add($btnScanHome)

$btnCustom = New-Object Windows.Forms.Button
$btnCustom.Text = 'Personalizar  →'
$btnCustom.Location = New-Object Drawing.Point(230, 380)
$btnCustom.Size = New-Object Drawing.Size(180, 40)
$btnCustom.FlatStyle = 'Flat'
$btnCustom.FlatAppearance.BorderSize = 0
$btnCustom.BackColor = $script:T.CardHi
$btnCustom.ForeColor = $script:T.Accent
$btnCustom.Font = New-Object Drawing.Font('Segoe UI Semibold', 9.5)
$home.Controls.Add($btnCustom)

$btnFullHome = New-Object Windows.Forms.Button
$btnFullHome.Text = 'Preset completo'
$btnFullHome.Location = New-Object Drawing.Point(430, 380)
$btnFullHome.Size = New-Object Drawing.Size(150, 40)
$btnFullHome.FlatStyle = 'Flat'
$btnFullHome.FlatAppearance.BorderColor = $script:T.Border
$btnFullHome.BackColor = $script:T.Card
$btnFullHome.ForeColor = $script:T.Muted
$home.Controls.Add($btnFullHome)

$btnTheme = New-Object Windows.Forms.Button
$btnTheme.Text = 'Tema claro/escuro'
$btnTheme.Location = New-Object Drawing.Point(600, 380)
$btnTheme.Size = New-Object Drawing.Size(150, 40)
$btnTheme.FlatStyle = 'Flat'
$btnTheme.BackColor = $script:T.Card
$btnTheme.ForeColor = $script:T.Muted
$home.Controls.Add($btnTheme)

$btnLang = New-Object Windows.Forms.Button
$btnLang.Text = 'PT / EN'
$btnLang.Location = New-Object Drawing.Point(770, 380)
$btnLang.Size = New-Object Drawing.Size(100, 40)
$btnLang.FlatStyle = 'Flat'
$btnLang.BackColor = $script:T.Card
$btnLang.ForeColor = $script:T.Muted
$home.Controls.Add($btnLang)

$hint = New-Object Windows.Forms.Label
$hint.Text = "Dica: Limpeza Segura para a maioria. Notebook em laptop. Dry-run para simular."
$hint.Location = New-Object Drawing.Point(10, 430)
$hint.Size = New-Object Drawing.Size(900, 24)
$hint.ForeColor = $script:T.Muted
$hint.Font = New-Object Drawing.Font('Segoe UI', 9)
$home.Controls.Add($hint)

# Mini log on home for scan
$homeLog = New-Object Windows.Forms.TextBox
$homeLog.Multiline = $true
$homeLog.ReadOnly = $true
$homeLog.ScrollBars = 'Vertical'
$homeLog.BorderStyle = 'None'
$homeLog.BackColor = $script:T.LogBg
$homeLog.ForeColor = $script:T.LogFg
$homeLog.Font = New-Object Drawing.Font('Consolas', 8)
$homeLog.Location = New-Object Drawing.Point(10, 480)
$homeLog.Size = New-Object Drawing.Size(940, 100)
$home.Controls.Add($homeLog)

# ══ CUSTOM ═══════════════════════════════════════════════════════════════════
$custom = New-Screen 'custom'

$custTitle = New-Object Windows.Forms.Label
$custTitle.Text = 'Personalizar'
$custTitle.Font = New-Object Drawing.Font('Segoe UI Semibold', 16)
$custTitle.ForeColor = $script:T.Text
$custTitle.Location = New-Object Drawing.Point(8, 8)
$custTitle.AutoSize = $true
$custom.Controls.Add($custTitle)

$script:SelectedLbl = New-Object Windows.Forms.Label
$script:SelectedLbl.Text = '0 selecionadas'
$script:SelectedLbl.ForeColor = $script:T.Accent
$script:SelectedLbl.Font = New-Object Drawing.Font('Segoe UI Semibold', 10)
$script:SelectedLbl.Location = New-Object Drawing.Point(180, 14)
$script:SelectedLbl.AutoSize = $true
$custom.Controls.Add($script:SelectedLbl)

$pills = New-Object Windows.Forms.Panel
$pills.Location = New-Object Drawing.Point(8, 48)
$pills.Size = New-Object Drawing.Size(700, 34)
$pills.BackColor = $script:T.Bg
$custom.Controls.Add($pills)
$pills.Controls.Add((New-Pill 'Todas' 0 'all'))
$pills.Controls.Add((New-Pill 'Limpeza' 108 'limpeza'))
$pills.Controls.Add((New-Pill 'Performance' 216 'perf'))
$pills.Controls.Add((New-Pill 'Internet' 324 'net'))
$pills.Controls.Add((New-Pill 'Manutencao' 432 'maint'))

$listHost = New-Object Windows.Forms.Panel
$listHost.Location = New-Object Drawing.Point(8, 92)
$listHost.Size = New-Object Drawing.Size(960, 420)
$listHost.AutoScroll = $true
$listHost.BackColor = $script:T.Panel
$custom.Controls.Add($listHost)

# Build option rows (add top-to-bottom via reverse dock)
$catalog = Get-OptCatalog
$rows = New-Object System.Collections.Generic.List[object]
foreach ($opt in $catalog) {
  $row = New-Object Windows.Forms.Panel
  $row.Height = 40
  $row.Dock = 'Top'
  $row.BackColor = $script:T.Card
  $row.Padding = New-Object Windows.Forms.Padding(12, 6, 12, 6)

  $chk = New-Object Windows.Forms.CheckBox
  $chk.Text = $opt.Name
  $chk.Dock = 'Fill'
  $chk.ForeColor = switch ($opt.Risk) {
    'caution'  { $script:T.Warn }
    'advanced' { $script:T.Danger }
    default    { $script:T.Text }
  }
  $chk.Font = New-Object Drawing.Font('Segoe UI', 9.25)
  $chk.Checked = $false
  $tip = New-Object Windows.Forms.ToolTip
  $tip.SetToolTip($chk, $opt.Hint)
  $chk.Add_CheckedChanged({ Update-SelectedCount })
  $row.Controls.Add($chk)

  $script:Checks[$opt.Id] = @{
    Box = $chk; Action = $opt.Action; Name = $opt.Name; Cat = $opt.Cat; Row = $row; Risk = $opt.Risk
  }
  $rows.Add($row) | Out-Null
}
for ($i = $rows.Count - 1; $i -ge 0; $i--) { $listHost.Controls.Add($rows[$i]) }

$btnBack = New-Object Windows.Forms.Button
$btnBack.Text = '←  Voltar'
$btnBack.Location = New-Object Drawing.Point(8, 530)
$btnBack.Size = New-Object Drawing.Size(120, 40)
$btnBack.FlatStyle = 'Flat'
$btnBack.FlatAppearance.BorderColor = $script:T.Border
$btnBack.BackColor = $script:T.Card
$btnBack.ForeColor = $script:T.Text
$custom.Controls.Add($btnBack)

$btnSafe2 = New-Object Windows.Forms.Button
$btnSafe2.Text = 'Preset seguro'
$btnSafe2.Location = New-Object Drawing.Point(140, 530)
$btnSafe2.Size = New-Object Drawing.Size(130, 40)
$btnSafe2.FlatStyle = 'Flat'
$btnSafe2.FlatAppearance.BorderSize = 0
$btnSafe2.BackColor = $script:T.CardHi
$btnSafe2.ForeColor = $script:T.Accent
$custom.Controls.Add($btnSafe2)

$btnClear = New-Object Windows.Forms.Button
$btnClear.Text = 'Limpar marcas'
$btnClear.Location = New-Object Drawing.Point(280, 530)
$btnClear.Size = New-Object Drawing.Size(120, 40)
$btnClear.FlatStyle = 'Flat'
$btnClear.FlatAppearance.BorderColor = $script:T.Border
$btnClear.BackColor = $script:T.Card
$btnClear.ForeColor = $script:T.Muted
$custom.Controls.Add($btnClear)

$btnRunCustom = New-Object Windows.Forms.Button
$btnRunCustom.Text = 'EXECUTAR SELECIONADAS'
$btnRunCustom.Location = New-Object Drawing.Point(680, 530)
$btnRunCustom.Size = New-Object Drawing.Size(280, 40)
$btnRunCustom.FlatStyle = 'Flat'
$btnRunCustom.FlatAppearance.BorderSize = 0
$btnRunCustom.BackColor = $script:T.Accent
$btnRunCustom.ForeColor = $script:T.Bg
$btnRunCustom.Font = New-Object Drawing.Font('Segoe UI Semibold', 10)
$custom.Controls.Add($btnRunCustom)

# ══ RUN ══════════════════════════════════════════════════════════════════════
$run = New-Screen 'run'

$runTitle = New-Object Windows.Forms.Label
$runTitle.Text = 'Otimizando...'
$runTitle.Font = New-Object Drawing.Font('Segoe UI Semibold', 20)
$runTitle.ForeColor = $script:T.Text
$runTitle.Location = New-Object Drawing.Point(8, 40)
$runTitle.AutoSize = $true
$run.Controls.Add($runTitle)

$script:TaskLbl = New-Object Windows.Forms.Label
$script:TaskLbl.Text = '...'
$script:TaskLbl.Font = New-Object Drawing.Font('Segoe UI', 11)
$script:TaskLbl.ForeColor = $script:T.Accent
$script:TaskLbl.Location = New-Object Drawing.Point(10, 90)
$script:TaskLbl.Size = New-Object Drawing.Size(900, 28)
$run.Controls.Add($script:TaskLbl)

$script:Progress = New-Object Windows.Forms.ProgressBar
$script:Progress.Location = New-Object Drawing.Point(10, 130)
$script:Progress.Size = New-Object Drawing.Size(820, 18)
$script:Progress.Style = 'Continuous'
$run.Controls.Add($script:Progress)

$script:ProgressLbl = New-Object Windows.Forms.Label
$script:ProgressLbl.Text = '0%'
$script:ProgressLbl.Font = New-Object Drawing.Font('Segoe UI Semibold', 14)
$script:ProgressLbl.ForeColor = $script:T.Accent2
$script:ProgressLbl.Location = New-Object Drawing.Point(850, 122)
$script:ProgressLbl.AutoSize = $true
$run.Controls.Add($script:ProgressLbl)

$script:LogBox = New-Object Windows.Forms.TextBox
$script:LogBox.Multiline = $true
$script:LogBox.ReadOnly = $true
$script:LogBox.ScrollBars = 'Vertical'
$script:LogBox.BorderStyle = 'None'
$script:LogBox.BackColor = $script:T.LogBg
$script:LogBox.ForeColor = $script:T.LogFg
$script:LogBox.Font = New-Object Drawing.Font('Consolas', 8.5)
$script:LogBox.Location = New-Object Drawing.Point(10, 170)
$script:LogBox.Size = New-Object Drawing.Size(940, 380)
$run.Controls.Add($script:LogBox)

# ══ DONE ═════════════════════════════════════════════════════════════════════
$done = New-Screen 'done'

$doneTitle = New-Object Windows.Forms.Label
$doneTitle.Text = 'Tudo pronto'
$doneTitle.Font = New-Object Drawing.Font('Segoe UI Semibold', 24)
$doneTitle.ForeColor = $script:T.Accent
$doneTitle.Location = New-Object Drawing.Point(8, 50)
$doneTitle.AutoSize = $true
$done.Controls.Add($doneTitle)

$script:ResultLbl = New-Object Windows.Forms.Label
$script:ResultLbl.Text = ''
$script:ResultLbl.Font = New-Object Drawing.Font('Segoe UI', 12)
$script:ResultLbl.ForeColor = $script:T.Text
$script:ResultLbl.Location = New-Object Drawing.Point(10, 110)
$script:ResultLbl.Size = New-Object Drawing.Size(800, 140)
$done.Controls.Add($script:ResultLbl)

$btnReboot = New-Object Windows.Forms.Button
$btnReboot.Text = 'Reiniciar PC agora'
$btnReboot.Location = New-Object Drawing.Point(10, 280)
$btnReboot.Size = New-Object Drawing.Size(220, 48)
$btnReboot.FlatStyle = 'Flat'
$btnReboot.FlatAppearance.BorderSize = 0
$btnReboot.BackColor = $script:T.Accent
$btnReboot.ForeColor = $script:T.Bg
$btnReboot.Font = New-Object Drawing.Font('Segoe UI Semibold', 10)
$done.Controls.Add($btnReboot)

$btnHome = New-Object Windows.Forms.Button
$btnHome.Text = 'Voltar ao inicio'
$btnHome.Location = New-Object Drawing.Point(250, 280)
$btnHome.Size = New-Object Drawing.Size(180, 48)
$btnHome.FlatStyle = 'Flat'
$btnHome.FlatAppearance.BorderColor = $script:T.Border
$btnHome.BackColor = $script:T.Card
$btnHome.ForeColor = $script:T.Text
$done.Controls.Add($btnHome)

$btnClose = New-Object Windows.Forms.Button
$btnClose.Text = 'Fechar'
$btnClose.Location = New-Object Drawing.Point(450, 280)
$btnClose.Size = New-Object Drawing.Size(120, 48)
$btnClose.FlatStyle = 'Flat'
$btnClose.FlatAppearance.BorderSize = 0
$btnClose.BackColor = [Drawing.Color]::FromArgb(50, 30, 36)
$btnClose.ForeColor = $script:T.Text
$done.Controls.Add($btnClose)

$doneNote = New-Object Windows.Forms.Label
$doneNote.Text = 'Seus arquivos pessoais nao foram apagados. Caches limpos regeneram sozinhos.'
$doneNote.Location = New-Object Drawing.Point(10, 360)
$doneNote.Size = New-Object Drawing.Size(800, 30)
$doneNote.ForeColor = $script:T.Muted
$done.Controls.Add($doneNote)

# ── Events ───────────────────────────────────────────────────────────────────
$btnCustom.Add_Click({
  Apply-PresetIds $script:Presets.safe
  Show-Screen 'custom'
})
$btnFullHome.Add_Click({
  Apply-PresetIds $script:Presets.full
  Show-Screen 'custom'
})
$btnBack.Add_Click({ Show-Screen 'home' })
$btnSafe2.Add_Click({ Apply-PresetIds $script:Presets.safe })
$btnClear.Add_Click({
  foreach ($id in $script:Checks.Keys) { $script:Checks[$id].Box.Checked = $false }
  Update-SelectedCount
})
$btnRunCustom.Add_Click({ Start-OptimizationRun })
$btnHome.Add_Click({ Show-Screen 'home' })
$btnClose.Add_Click({ $form.Close() })
$btnReboot.Add_Click({
  $r = [Windows.Forms.MessageBox]::Show('Reiniciar o PC agora?', 'Reiniciar', 'YesNo', 'Question')
  if ($r -eq 'Yes') { shutdown.exe /r /t 3 /c "PC Otimizador Pro" }
})

$btnScanHome.Add_Click({
  $script:LogBox = $homeLog
  $homeLog.Clear()
  $homeLog.Visible = $true
  try {
    $null = Initialize-SessionLog
    Invoke-ScanOnly | Out-Null
    Write-EstimatesReport (Get-PresetIds 'safe') | Out-Null
    Complete-SessionLog | Out-Null
    Update-HeroStats
  } catch { Write-Log "$_" 'ERROR' }
})

$btnTheme.Add_Click({
  $script:LightTheme = -not $script:LightTheme
  if ($script:LightTheme) {
    $form.BackColor = [Drawing.Color]::FromArgb(245, 247, 250)
    $home.BackColor = [Drawing.Color]::FromArgb(245, 247, 250)
    $hero.ForeColor = [Drawing.Color]::FromArgb(15, 23, 42)
    $hint.ForeColor = [Drawing.Color]::FromArgb(71, 85, 105)
  } else {
    $form.BackColor = $script:T.Bg
    $home.BackColor = $script:T.Bg
    $hero.ForeColor = $script:T.Text
    $hint.ForeColor = $script:T.Muted
  }
})

$btnLang.Add_Click({
  $script:UiLang = if ($script:UiLang -eq 'pt') { 'en' } else { 'pt' }
  $hero.Text = if ($script:UiLang -eq 'en') { 'Optimize your PC in 1 click' } else { 'Otimize seu PC em 1 clique' }
  [Windows.Forms.MessageBox]::Show(("Language: {0}" -f $script:UiLang), 'PC Otimizador') | Out-Null
})

# Wire run log as primary when running — Start-OptimizationRun sets progress on run screen's log
# Fix: ensure $script:LogBox points to run log by default after scan
$runLogRef = $script:LogBox
# After building run screen, LogBox is run's textbox. Scan temporarily switches to homeLog.

Apply-PresetIds $script:Presets.safe
Show-Screen 'home'
Update-HeroStats

[void]$form.ShowDialog()