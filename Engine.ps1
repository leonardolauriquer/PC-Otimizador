#Requires -Version 5.1
# Engine compartilhado — limpeza/otimizacao (GUI + CLI)
$ErrorActionPreference = 'Continue'
$script:DryRun = $false
$script:SessionLogFile = $null
$script:UiLang = 'pt'
$script:CancelRequested = $false
$script:CancelFile = Join-Path $env:TEMP 'pc-otimizador-cancel.flag'
$script:Whitelist = New-Object System.Collections.Generic.List[string]
$script:ProgressCallback = $null
$script:LogBox = $null
function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FolderSizeMB {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  try {
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
      Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
    if ($null -eq $sum) { return 0 }
    return [math]::Round($sum / 1MB, 2)
  } catch { return 0 }
}

function Remove-PathSafe {
  param([string]$Path, [switch]$Recurse)
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  if (Test-PathWhitelisted $Path) {
    Write-Log ("Whitelist: protegido, nao remove {0}" -f $Path) 'WARN'
    return 0
  }
  $before = Get-FolderSizeMB $Path
  if ($script:DryRun) {
    Write-Log ("[DRY-RUN] Removeria: {0} (~{1} MB)" -f $Path, $before)
    return $before
  }
  try {
    if ($Recurse) {
      Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if (Test-PathWhitelisted $_.FullName) { return }
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
      }
    } else {
      Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
  } catch {}
  return [math]::Max(0, $before - (Get-FolderSizeMB $Path))
}

function Write-Log {
  param([string]$Message, [string]$Level = 'INFO')
  $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
  $color = switch ($Level) {
    'ERROR' { 'Red' }
    'WARN'  { 'Yellow' }
    default { 'DarkCyan' }
  }
  try { Write-Host $line -ForegroundColor $color } catch {}
  try { [Console]::Out.WriteLine(("##LOG##|{0}|{1}" -f $Level, $Message)) } catch {}
  if ($script:SessionLogFile) {
    try { Add-Content -LiteralPath $script:SessionLogFile -Value $line -Encoding UTF8 } catch {}
  }
  if ($script:LogBox -and -not $script:LogBox.IsDisposed) {
    try {
      $script:LogBox.AppendText($line + "`r`n")
      $script:LogBox.SelectionStart = $script:LogBox.TextLength
      $script:LogBox.ScrollToCaret()
      [Windows.Forms.Application]::DoEvents()
    } catch {}
  }
}

function Get-SystemSnapshot {
  $os = Get-CimInstance Win32_OperatingSystem
  $cs = Get-CimInstance Win32_ComputerSystem
  $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
  [pscustomobject]@{
    PC       = $cs.Name
    OS       = ($os.Caption -replace 'Microsoft ', '')
    DiskFree = [math]::Round($disk.FreeSpace / 1GB, 2)
    DiskTot  = [math]::Round($disk.Size / 1GB, 2)
    DiskUsed = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
    RamUsed  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
    RamTot   = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
  }
}

function Set-RegDword {
  param([string]$Path, [string]$Name, [int]$Value)
  if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
  Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction SilentlyContinue
}

# ── Actions: Limpeza ─────────────────────────────────────────────────────────
function Invoke-CleanTemp {
  $freed = 0.0
  foreach ($p in @($env:TEMP, "$env:LOCALAPPDATA\Temp", 'C:\Windows\Temp')) {
    Write-Log "Limpando $p"
    $freed += [double](Remove-PathSafe $p -Recurse)
  }
  Write-Log "Temporarios: ~$freed MB"; return $freed
}

function Invoke-CleanRecycleBin {
  Write-Log 'Esvaziando Lixeira...'
  try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Log 'Lixeira OK'; return 1 }
  catch {
    try {
      (New-Object -ComObject Shell.Application).NameSpace(0xA).Items() | ForEach-Object {
        Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue
      }
      Write-Log 'Lixeira OK'; return 1
    } catch { Write-Log "Lixeira: $_" 'WARN'; return 0 }
  }
}

function Invoke-CleanUpdateCache {
  Write-Log 'Cache Windows Update...'
  $freed = 0.0
  try {
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    $freed = [double](Remove-PathSafe 'C:\Windows\SoftwareDistribution\Download' -Recurse)
  } finally {
    Start-Service bits, wuauserv -ErrorAction SilentlyContinue
  }
  Write-Log "Update cache: ~$freed MB"; return $freed
}

function Invoke-CleanDeliveryOptimization {
  Write-Log 'Delivery Optimization...'
  $freed = [double](Remove-PathSafe 'C:\Windows\SoftwareDistribution\DeliveryOptimization' -Recurse)
  $freed += [double](Remove-PathSafe "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache" -Recurse)
  Write-Log "Delivery Opt: ~$freed MB"; return $freed
}

function Invoke-CleanThumbnails {
  Write-Log 'Cache de miniaturas/icones...'
  Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 700
  $freed = 0.0
  $ex = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
  Get-ChildItem $ex -Filter 'thumbcache_*.db' -Force -EA SilentlyContinue | ForEach-Object {
    $freed += [math]::Round($_.Length / 1MB, 2)
    Remove-Item $_.FullName -Force -EA SilentlyContinue
  }
  $icon = "$env:LOCALAPPDATA\IconCache.db"
  if (Test-Path $icon) { Remove-Item $icon -Force -EA SilentlyContinue }
  Start-Process explorer.exe
  Write-Log "Thumbs/icons: ~$freed MB"; return $freed
}

function Invoke-CleanPrefetch {
  Write-Log 'Prefetch...'
  $f = [double](Remove-PathSafe 'C:\Windows\Prefetch' -Recurse)
  Write-Log "Prefetch: ~$f MB"; return $f
}

function Invoke-CleanWER {
  Write-Log 'Relatorios de erro + minidumps...'
  $f = 0.0
  foreach ($p in @(
    'C:\ProgramData\Microsoft\Windows\WER',
    "$env:LOCALAPPDATA\Microsoft\Windows\WER",
    'C:\Windows\Minidump'
  )) { $f += [double](Remove-PathSafe $p -Recurse) }
  if (Test-Path 'C:\Windows\MEMORY.DMP') {
    $sz = [math]::Round((Get-Item 'C:\Windows\MEMORY.DMP').Length / 1MB, 2)
    Remove-Item 'C:\Windows\MEMORY.DMP' -Force -EA SilentlyContinue
    $f += $sz
  }
  Write-Log "WER/dumps: ~$f MB"; return $f
}

function Invoke-CleanLogs {
  Write-Log 'Logs do Windows...'
  $f = 0.0
  foreach ($p in @(
    'C:\Windows\Logs\CBS',
    'C:\Windows\Logs\DISM',
    'C:\Windows\Logs\WindowsUpdate',
    'C:\Windows\SoftwareDistribution\ReportingEvents.log'
  )) {
    if (Test-Path $p -PathType Leaf) {
      $sz = [math]::Round((Get-Item $p).Length / 1MB, 2)
      Clear-Content $p -Force -EA SilentlyContinue
      $f += $sz
    } else { $f += [double](Remove-PathSafe $p -Recurse) }
  }
  Write-Log "Logs: ~$f MB"; return $f
}

function Invoke-CleanBrowserCaches {
  Write-Log 'Cache navegadores (favoritos/senhas preservados)...'
  foreach ($n in @('chrome', 'msedge', 'firefox', 'brave', 'opera')) {
    Get-Process -Name $n -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
  }
  Start-Sleep -Milliseconds 400
  $f = 0.0
  $paths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Opera Software\Opera Stable\Cache"
  )
  foreach ($t in $paths) { $f += [double](Remove-PathSafe $t -Recurse) }
  Get-ChildItem "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles" -Directory -EA SilentlyContinue | ForEach-Object {
    $f += [double](Remove-PathSafe (Join-Path $_.FullName 'cache2') -Recurse)
  }
  Write-Log "Browsers: ~$f MB"; return $f
}

function Invoke-CleanRecent {
  Write-Log 'Atalhos recentes (nao apaga arquivos)...'
  $f = [double](Remove-PathSafe ([Environment]::GetFolderPath('Recent')) -Recurse)
  Write-Log "Recentes: ~$f MB"; return $f
}

function Invoke-CleanFontCache {
  Write-Log 'Cache de fontes...'
  try {
    Stop-Service FontCache -Force -EA SilentlyContinue
    Remove-Item 'C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*' -Recurse -Force -EA SilentlyContinue
    Start-Service FontCache -EA SilentlyContinue
  } catch {}
  return 0
}

function Invoke-CleanGpuCache {
  Write-Log 'Cache GPU / DirectX / shaders...'
  $f = 0.0
  $paths = @(
    "$env:LOCALAPPDATA\D3DSCache",
    "$env:LOCALAPPDATA\NVIDIA\DXCache",
    "$env:LOCALAPPDATA\NVIDIA\GLCache",
    "$env:LOCALAPPDATA\AMD\DxCache",
    "$env:LOCALAPPDATA\Intel\ShaderCache"
  )
  foreach ($p in $paths) { $f += [double](Remove-PathSafe $p -Recurse) }
  Write-Log "GPU cache: ~$f MB"; return $f
}

function Invoke-CleanAppCaches {
  Write-Log 'Cache apps (Discord/Steam/Teams/Spotify)...'
  $f = 0.0
  foreach ($n in @('Discord', 'Steam', 'Teams', 'Spotify')) {
    Get-Process -Name $n -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
  }
  $paths = @(
    "$env:APPDATA\discord\Cache",
    "$env:APPDATA\discord\Code Cache",
    "$env:APPDATA\discord\GPUCache",
    "$env:LOCALAPPDATA\Steam\htmlcache",
    "$env:APPDATA\Microsoft\Teams\Cache",
    "$env:APPDATA\Microsoft\Teams\GPUCache",
    "$env:APPDATA\Spotify\Storage",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
  )
  foreach ($p in $paths) { $f += [double](Remove-PathSafe $p -Recurse) }
  # Steam shader cache (grande, regenera)
  Get-ChildItem "$env:LOCALAPPDATA\Steam" -Filter 'shadercache' -Directory -Recurse -EA SilentlyContinue |
    Select-Object -First 5 | ForEach-Object { $f += [double](Remove-PathSafe $_.FullName -Recurse) }
  Write-Log "Apps cache: ~$f MB"; return $f
}

function Invoke-CleanStoreCache {
  Write-Log 'Cache Microsoft Store / Delivery...'
  $f = 0.0
  Get-ChildItem "$env:LOCALAPPDATA\Packages" -Directory -Filter 'Microsoft.WindowsStore*' -EA SilentlyContinue | ForEach-Object {
    $f += [double](Remove-PathSafe (Join-Path $_.FullName 'LocalCache') -Recurse)
  }
  $f += [double](Remove-PathSafe "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" -Recurse)
  try { Start-Process wsreset.exe -WindowStyle Hidden -EA SilentlyContinue } catch {}
  Write-Log "Store: ~$f MB"; return $f
}

function Invoke-CleanMgr {
  Write-Log 'Limpeza de Disco do Windows (sem Windows.old)...'
  $base = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
  # NUNCA incluir Previous Installations aqui — isso apaga Windows.old.
  # Update Cleanup / Previous Installations ficam no perfil advanced (upgrade).
  foreach ($k in @(
    'Temporary Files', 'Temporary Setup Files', 'Thumbnail Cache', 'Recycle Bin',
    'Delivery Optimization Files', 'Windows Error Reporting Files',
    'Downloaded Program Files', 'Internet Cache Files',
    'System error memory dump files', 'System error minidump files'
  )) {
    $path = Join-Path $base $k
    if (Test-Path $path) {
      Set-ItemProperty $path -Name StateFlags0099 -Value 2 -Type DWord -Force -EA SilentlyContinue
    }
  }
  Start-Process cleanmgr.exe -ArgumentList '/sagerun:99' -Wait -WindowStyle Hidden -EA SilentlyContinue
  Write-Log 'cleanmgr concluido'; return 0
}

function Invoke-DismCleanup {
  Write-Log 'DISM Component Cleanup (pode demorar)...'
  $p = Start-Process dism.exe -ArgumentList '/Online','/Cleanup-Image','/StartComponentCleanup' -Wait -PassThru -WindowStyle Hidden
  Write-Log "DISM exit: $($p.ExitCode)"; return 0
}

function Invoke-CleanUpgradeLeftovers {
  Write-Log 'Pastas de upgrade orfas ($Windows.~BT / ~WS)...'
  $f = 0.0
  foreach ($p in @('C:\$Windows.~BT', 'C:\$Windows.~WS', 'C:\Windows.old')) {
    if (Test-Path $p) {
      Write-Log "Removendo $p (pode demorar)..."
      # Windows.old exige takeown; tenta via cleanmgr style
      takeown /F $p /R /D Y 2>$null | Out-Null
      icacls $p /grant Administrators:F /T 2>$null | Out-Null
      $f += [double](Remove-PathSafe $p -Recurse)
    }
  }
  Write-Log "Upgrade leftovers: ~$f MB"; return $f
}

# ── Actions: Performance ─────────────────────────────────────────────────────
function Invoke-OptimizeDrives {
  Write-Log 'Otimizando unidades (TRIM/SSD)...'
  Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystemType -eq 'NTFS' } | ForEach-Object {
    Write-Log "  Unidade $($_.DriveLetter):"
    Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -EA SilentlyContinue
  }
  return 0
}

function Invoke-HighPerformance {
  Write-Log 'Plano Alto Desempenho...'
  $null = cmd /c "powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
  if ($LASTEXITCODE -ne 0) {
    $null = cmd /c "powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    $null = cmd /c "powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
  }
  return 0
}

function Invoke-BalancedPower {
  Write-Log 'Plano Equilibrado...'
  powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
  return 0
}

function Invoke-VisualPerf {
  Write-Log 'Efeitos visuais -> desempenho...'
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
  Set-RegDword 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' 0
  return 0
}

function Invoke-DisableGameBar {
  Write-Log 'Desativando Game Bar / DVR...'
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
  Set-RegDword 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
  Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
  return 0
}

function Invoke-DisableBackgroundApps {
  Write-Log 'Limitando apps em segundo plano...'
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
  return 0
}

function Invoke-DisableTips {
  Write-Log 'Reduzindo dicas/sugestoes/telemetria basica...'
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 0
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 0
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0
  Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 1
  return 0
}

function Invoke-DisableWidgets {
  Write-Log 'Desativando Widgets / noticias...'
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
  Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
  return 0
}

function Invoke-StorageSense {
  Write-Log 'Ativando Storage Sense (so temp do sistema)...'
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 1
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '04' 1
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '08' 0  # nao limpar Downloads
  Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '32' 0
  return 0
}

function Invoke-DisableSearchWeb {
  Write-Log 'Desativando busca web no Iniciar...'
  Set-RegDword 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
  return 0
}

function Invoke-GameMode {
  Write-Log 'Ativando Modo de Jogo...'
  Set-RegDword 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
  Set-RegDword 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
  return 0
}

# ── Actions: Internet ────────────────────────────────────────────────────────
function Invoke-FlushDNS {
  Write-Log 'Flush DNS...'; ipconfig /flushdns | Out-Null; return 0
}

function Invoke-FlushARP {
  Write-Log 'Flush ARP...'; arp -d * 2>$null | Out-Null; return 0
}

function Invoke-RenewIP {
  Write-Log 'Renovando IP...'
  ipconfig /release | Out-Null
  Start-Sleep -Milliseconds 500
  ipconfig /renew | Out-Null
  return 0
}

function Invoke-ResetWinsock {
  Write-Log 'Reset Winsock (reinicie depois)...'
  netsh winsock reset catalog 2>$null | Out-Null
  return 0
}

function Invoke-ResetTCPIP {
  Write-Log 'Reset TCP/IP (reinicie depois)...'
  netsh int ip reset 2>$null | Out-Null
  return 0
}

function Invoke-NetOptimizations {
  Write-Log 'Otimizacoes TCP leves...'
  netsh int tcp set global autotuninglevel=normal | Out-Null
  netsh int tcp set global chimney=disabled 2>$null | Out-Null
  netsh int tcp set global dca=enabled 2>$null | Out-Null
  netsh int tcp set global netdma=enabled 2>$null | Out-Null
  netsh int tcp set global ecncapability=enabled 2>$null | Out-Null
  netsh int tcp set global timestamps=disabled 2>$null | Out-Null
  # Network Throttling Index (multimedia)
  Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' -1
  Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10
  Write-Log 'TCP/multimedia tweaks OK'; return 0
}

function Invoke-DnsCloudflare {
  Write-Log 'DNS Cloudflare 1.1.1.1 nas placas ativas...'
  Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
    try {
      Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses @('1.1.1.1', '1.0.0.1') -EA Stop
      Write-Log "  $($_.Name) -> 1.1.1.1"
    } catch { Write-Log "  $($_.Name): $_" 'WARN' }
  }
  return 0
}

function Invoke-DnsGoogle {
  Write-Log 'DNS Google 8.8.8.8 nas placas ativas...'
  Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
    try {
      Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses @('8.8.8.8', '8.8.4.4') -EA Stop
      Write-Log "  $($_.Name) -> 8.8.8.8"
    } catch { Write-Log "  $($_.Name): $_" 'WARN' }
  }
  return 0
}

function Invoke-DisableNagle {
  Write-Log 'Desativando Nagle (latencia menor em jogos)...'
  Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -EA SilentlyContinue | ForEach-Object {
    Set-ItemProperty $_.PSPath -Name TcpAckFrequency -Value 1 -Type DWord -Force -EA SilentlyContinue
    Set-ItemProperty $_.PSPath -Name TCPNoDelay -Value 1 -Type DWord -Force -EA SilentlyContinue
  }
  return 0
}

function Invoke-ClearNetBIOS {
  Write-Log 'Limpando cache NetBIOS...'; nbtstat -R 2>$null | Out-Null; nbtstat -RR 2>$null | Out-Null; return 0
}

# ── Actions: Manutencao ──────────────────────────────────────────────────────
function Invoke-RestorePoint {
  Write-Log 'Criando ponto de restauracao...'
  try {
    Enable-ComputerRestore -Drive 'C:\' -EA SilentlyContinue
    Checkpoint-Computer -Description 'PC Otimizador Pro' -RestorePointType MODIFY_SETTINGS -EA Stop
    Write-Log 'Ponto de restauracao criado.'
  } catch {
    Write-Log "Restore point: $_ (pode ja existir um recente)" 'WARN'
  }
  return 0
}

function Invoke-SFC {
  Write-Log 'SFC /scannow (demorado)...'
  $p = Start-Process sfc.exe -ArgumentList '/scannow' -Wait -PassThru -WindowStyle Hidden
  Write-Log "SFC exit: $($p.ExitCode)"; return 0
}

function Invoke-DismRestore {
  Write-Log 'DISM RestoreHealth (demorado)...'
  $p = Start-Process dism.exe -ArgumentList '/Online','/Cleanup-Image','/RestoreHealth' -Wait -PassThru -WindowStyle Hidden
  Write-Log "DISM Restore exit: $($p.ExitCode)"; return 0
}

function Invoke-ScanOnly {
  Write-Log '=== VARREDURA (nao apaga nada) ==='
  $items = @(
    @{ N = 'Temp usuario'; P = $env:TEMP }
    @{ N = 'Temp LocalAppData'; P = "$env:LOCALAPPDATA\Temp" }
    @{ N = 'Temp Windows'; P = 'C:\Windows\Temp' }
    @{ N = 'Windows Update'; P = 'C:\Windows\SoftwareDistribution\Download' }
    @{ N = 'Prefetch'; P = 'C:\Windows\Prefetch' }
    @{ N = 'WER'; P = 'C:\ProgramData\Microsoft\Windows\WER' }
    @{ N = 'D3DSCache'; P = "$env:LOCALAPPDATA\D3DSCache" }
    @{ N = 'Chrome Cache'; P = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" }
    @{ N = 'Edge Cache'; P = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" }
    @{ N = 'Discord Cache'; P = "$env:APPDATA\discord\Cache" }
  )
  $total = 0.0
  foreach ($i in $items) {
    $mb = [double](Get-FolderSizeMB $i.P)
    $total += $mb
    if ($mb -gt 0.1) { Write-Log ('  {0,-22} {1,10:N1} MB' -f $i.N, $mb) }
  }
  Write-Log ('Total estimado: ~{0:N0} MB ({1:N2} GB)' -f $total, ($total / 1024))
  return $total
}

# ── v4: session log, estimates, presets, schedule, i18n ───────────────────────
function Get-T {
  param([string]$Key)
  $pt = @{
    dry='Simulacao (dry-run)'; done='Concluido'; logSaved='Log salvo em'
    weeklyOk='Limpeza semanal agendada (domingo 10:00)'; weeklyOff='Agendamento semanal removido'
    notebook='Perfil Notebook'; cancelled='Cancelado pelo usuario'; health='Health Score'
    ssd='SSD detectado'; hdd='HDD detectado'; whitelist='Whitelist'; bloat='Bloatware'
    before='Antes'; after='Depois'; scoreTip='0=ruim · 100=otimo'
  }
  $en = @{
    dry='Dry-run simulation'; done='Done'; logSaved='Log saved to'
    weeklyOk='Weekly cleanup scheduled (Sunday 10:00)'; weeklyOff='Weekly schedule removed'
    notebook='Notebook profile'; cancelled='Cancelled by user'; health='Health Score'
    ssd='SSD detected'; hdd='HDD detected'; whitelist='Whitelist'; bloat='Bloatware'
    before='Before'; after='After'; scoreTip='0=poor · 100=great'
  }
  $map = if ($script:UiLang -eq 'en') { $en } else { $pt }
  if ($map.ContainsKey($Key)) { return $map[$Key] } else { return $Key }
}

function Write-ProgressLine {
  param([int]$Current, [int]$Total, [string]$Name)
  $pct = if ($Total -gt 0) { [math]::Min(100, [int](($Current * 100) / $Total)) } else { 0 }
  $msg = '##PROGRESS##|{0}|{1}|{2}|{3}' -f $Current, $Total, ($Name -replace '\|', '/'), $pct
  try { [Console]::Out.WriteLine($msg) } catch {}
  if ($script:ProgressCallback) { try { & $script:ProgressCallback $Current $Total $Name $pct } catch {} }
}

function Test-CancelRequested {
  if ($script:CancelRequested) { return $true }
  if (Test-Path -LiteralPath $script:CancelFile) {
    $script:CancelRequested = $true
    return $true
  }
  return $false
}

function Reset-CancelFlag {
  $script:CancelRequested = $false
  Remove-Item -LiteralPath $script:CancelFile -Force -ErrorAction SilentlyContinue
}

function Request-Cancel {
  $script:CancelRequested = $true
  Set-Content -LiteralPath $script:CancelFile -Value '1' -Encoding ASCII -Force
}

function Get-LogsDirectory {
  $docs = [Environment]::GetFolderPath('MyDocuments')
  if (-not $docs) { $docs = Join-Path $env:USERPROFILE 'Documents' }
  $dir = Join-Path $docs 'PC-Otimizador-Logs'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  return $dir
}

function Get-WhitelistPath {
  Join-Path (Get-LogsDirectory) 'whitelist.txt'
}

function Import-Whitelist {
  $script:Whitelist.Clear()
  $wf = Get-WhitelistPath
  # always protect personal roots (boundary-safe matching in Test-PathWhitelisted)
  $roots = @(
    [Environment]::GetFolderPath('MyDocuments'),
    [Environment]::GetFolderPath('MyPictures'),
    [Environment]::GetFolderPath('MyVideos'),
    [Environment]::GetFolderPath('MyMusic'),
    [Environment]::GetFolderPath('Desktop'),
    (Join-Path $env:USERPROFILE 'Downloads'),
    (Join-Path $env:USERPROFILE 'Documents'),
    (Join-Path $env:USERPROFILE 'Pictures'),
    (Join-Path $env:USERPROFILE 'Videos'),
    (Join-Path $env:USERPROFILE 'Music'),
    (Join-Path $env:USERPROFILE 'OneDrive'),
    (Join-Path $env:USERPROFILE 'OneDrive - Personal'),
    (Join-Path $env:USERPROFILE 'Saved Games')
  )
  foreach ($p in $roots) {
    if ($p -and -not ($script:Whitelist -contains $p)) { [void]$script:Whitelist.Add($p) }
  }
  if (Test-Path $wf) {
    Get-Content $wf -ErrorAction SilentlyContinue | Where-Object { $_ -and $_.Trim() } | ForEach-Object {
      $t = $_.Trim()
      if (-not ($script:Whitelist -contains $t)) { [void]$script:Whitelist.Add($t) }
    }
  }
}

function Add-WhitelistPath {
  param([string]$Path)
  if (-not $Path) { return }
  Import-Whitelist
  if (-not ($script:Whitelist -contains $Path)) {
    Add-Content -LiteralPath (Get-WhitelistPath) -Value $Path -Encoding UTF8
    [void]$script:Whitelist.Add($Path)
  }
  Write-Log ("Whitelist +: {0}" -f $Path)
}

function Test-PathUnderRoot {
  param([string]$Path, [string]$Root)
  if (-not $Path -or -not $Root) { return $false }
  $full = $Path
  $ww = $Root
  try { $full = [IO.Path]::GetFullPath($Path) } catch {}
  try { $ww = [IO.Path]::GetFullPath($Root) } catch {}
  $full = $full.TrimEnd('\', '/')
  $ww = $ww.TrimEnd('\', '/')
  if ([string]::Equals($full, $ww, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  $prefix = $ww + [IO.Path]::DirectorySeparatorChar
  return $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Test-PathWhitelisted {
  param([string]$Path)
  if (-not $Path) { return $false }
  if (-not $script:Whitelist -or $script:Whitelist.Count -eq 0) { Import-Whitelist }
  foreach ($w in $script:Whitelist) {
    if (Test-PathUnderRoot -Path $Path -Root $w) { return $true }
  }
  return $false
}

function Get-DriveMediaInfo {
  $info = [pscustomobject]@{ HasSSD = $false; HasHDD = $false; Details = @() }
  try {
    Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
      $media = [string]$_.MediaType
      $info.Details += ("{0}: {1}" -f $_.FriendlyName, $media)
      if ($media -match 'SSD|Solid') { $info.HasSSD = $true }
      if ($media -match 'HDD|Unspecified' -or $_.MediaType -eq 3) { $info.HasHDD = $true }
      if ($media -eq '4' -or $media -eq 'SSD') { $info.HasSSD = $true }
    }
  } catch {
    try {
      $model = (Get-CimInstance Win32_DiskDrive | Select-Object -First 1).Model
      if ($model -match 'SSD|NVMe|Solid') { $info.HasSSD = $true } else { $info.HasHDD = $true }
      $info.Details += $model
    } catch {}
  }
  return $info
}

function Get-HealthScore {
  $s = Get-SystemSnapshot
  $score = 100
  # disk pressure
  if ($s.DiskUsed -ge 95) { $score -= 40 }
  elseif ($s.DiskUsed -ge 85) { $score -= 25 }
  elseif ($s.DiskUsed -ge 75) { $score -= 15 }
  elseif ($s.DiskUsed -ge 60) { $score -= 5 }
  # RAM
  $ramPct = if ($s.RamTot -gt 0) { ($s.RamUsed / $s.RamTot) * 100 } else { 50 }
  if ($ramPct -ge 90) { $score -= 20 }
  elseif ($ramPct -ge 80) { $score -= 10 }
  # reclaimable junk
  $junk = (Get-OptionEstimateMB 'temp') + (Get-OptionEstimateMB 'update') + (Get-OptionEstimateMB 'wer')
  if ($junk -ge 5000) { $score -= 20 }
  elseif ($junk -ge 2000) { $score -= 12 }
  elseif ($junk -ge 500) { $score -= 6 }
  if (-not (Test-IsAdmin)) { $score -= 5 }
  $score = [math]::Max(0, [math]::Min(100, [int]$score))
  $grade = if ($score -ge 85) { 'A' } elseif ($score -ge 70) { 'B' } elseif ($score -ge 50) { 'C' } elseif ($score -ge 30) { 'D' } else { 'E' }
  [pscustomobject]@{
    Score = $score
    Grade = $grade
    DiskUsed = $s.DiskUsed
    DiskFreeGB = $s.DiskFree
    RamPct = [math]::Round($ramPct, 1)
    JunkMB = [math]::Round($junk, 0)
    Snapshot = $s
  }
}

function Get-BloatPackageCandidates {
  $names = @(
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
    'Microsoft.MicrosoftOfficeHub', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.People',
    'Microsoft.SkypeApp', 'Microsoft.WindowsFeedbackHub', 'Microsoft.Xbox.TCUI',
    'Microsoft.XboxApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.YourPhone',
    'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo', 'king.com.CandyCrushSaga', 'Disney.37853FC22B2CE'
  )
  $found = @()
  foreach ($n in $names) {
    $pkgs = Get-AppxPackage -Name $n -ErrorAction SilentlyContinue
    foreach ($p in $pkgs) {
      $found += [pscustomobject]@{ Name = $p.Name; PackageFullName = $p.PackageFullName }
    }
  }
  return $found
}

function Remove-BloatPackages {
  param([string[]]$PackageFullNames, [switch]$WhatIf)
  $removed = 0
  foreach ($pfn in $PackageFullNames) {
    if (Test-CancelRequested) { break }
    Write-Log ("Bloat: removendo {0}" -f $pfn)
    if ($WhatIf -or $script:DryRun) { Write-Log ("[DRY-RUN] Remove-AppxPackage {0}" -f $pfn); continue }
    try {
      Remove-AppxPackage -Package $pfn -ErrorAction Stop
      $removed++
    } catch {
      Write-Log ("Bloat falhou: {0}" -f $_) 'WARN'
    }
  }
  return $removed
}

function Invoke-OptimizationBatch {
  param(
    [string[]]$Ids,
    [hashtable]$Actions,
    [switch]$DryRun,
    [switch]$EstimateOnly
  )
  Reset-CancelFlag
  Import-Whitelist
  $script:DryRun = [bool]$DryRun
  $null = Initialize-SessionLog
  $before = Get-SystemSnapshot
  $media = Get-DriveMediaInfo
  if ($media.HasSSD) { Write-Log (Get-T 'ssd') } elseif ($media.HasHDD) { Write-Log (Get-T 'hdd') }
  if ($Ids -contains 'prefetch' -and $media.HasSSD) {
    Write-Log 'Aviso: Prefetch em SSD costuma ter pouco beneficio.' 'WARN'
  }
  if ($Ids -contains 'trim' -and (-not $media.HasSSD) -and $media.HasHDD) {
    Write-Log 'TRIM em HDD: Optimize-Volume ainda pode ajudar (desfrag analise).' 'WARN'
  }

  Write-Log ("Inicio batch | itens={0} | dry={1}" -f $Ids.Count, $script:DryRun)
  try { [Console]::Out.WriteLine(('##RESULT##|BEFORE|{0}|{1}|{2}|{3}' -f $before.DiskFree, $before.DiskTot, $before.RamUsed, $before.RamTot)) } catch {}
  $est = Write-EstimatesReport -Ids $Ids
  if ($EstimateOnly -or $DryRun) {
    if ($DryRun) {
      $i = 0
      foreach ($id in $Ids) {
        $i++
        if (Test-CancelRequested) { Write-Log (Get-T 'cancelled') 'WARN'; break }
        $n = if ($Actions.ContainsKey($id)) { $Actions[$id].Nome } else { $id }
        Write-ProgressLine -Current $i -Total $Ids.Count -Name $n
        Write-Log ("[DRY-RUN] Executaria: {0}" -f $n)
      }
    }
    $path = Complete-SessionLog -Summary ("Estimativa total: ~{0} MB" -f $est)
    $after = Get-SystemSnapshot
    try { [Console]::Out.WriteLine(('##RESULT##|AFTER|{0}|{1}|{2}|{3}|{4}|{5}|0' -f $after.DiskFree, $after.DiskTot, $after.RamUsed, $after.RamTot, $est, $path)) } catch {}
    return [pscustomobject]@{
      FreedMB = 0; DeltaGB = 0; Log = $path; EstimatedMB = $est
      Before = $before; After = $after; Cancelled = [bool]$script:CancelRequested; Health = (Get-HealthScore)
    }
  }

  $freed = 0.0
  $order = @($Ids | Sort-Object { if ($_ -eq 'restore') { 0 } else { 1 } })
  # filter trim suggestion already logged; still allow if selected
  $i = 0
  $cancelled = $false
  foreach ($id in $order) {
    $i++
    if (Test-CancelRequested) { $cancelled = $true; Write-Log (Get-T 'cancelled') 'WARN'; break }
    if (-not $Actions.ContainsKey($id)) { continue }
    $o = $Actions[$id]
    Write-ProgressLine -Current $i -Total $order.Count -Name $o.Nome
    Write-Log (">> [{0}/{1}] {2}" -f $i, $order.Count, $o.Nome)
    try {
      $f = & $o.Act
      if ($f) { $freed += [double]$f }
    } catch { Write-Log "Erro $id : $_" 'ERROR' }
  }
  $after = Get-SystemSnapshot
  $delta = [math]::Round($after.DiskFree - $before.DiskFree, 2)
  $sum = ("Freed~{0:N0} MB | Disco +{1} GB | cancel={2}" -f $freed, $delta, $cancelled)
  Write-Log $sum
  $path = Complete-SessionLog -Summary $sum
  $health = Get-HealthScore
  try {
    [Console]::Out.WriteLine(('##RESULT##|AFTER|{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $after.DiskFree, $after.DiskTot, $after.RamUsed, $after.RamTot, [math]::Round($freed,1), $path, $health.Score))
    [Console]::Out.WriteLine(('##DONE##|{0}' -f $(if ($cancelled) { 'CANCELLED' } else { 'OK' })))
  } catch {}
  return [pscustomobject]@{
    FreedMB = $freed; DeltaGB = $delta; Log = $path; EstimatedMB = $est
    Before = $before; After = $after; Cancelled = $cancelled; Health = $health
  }
}

function Initialize-SessionLog {
  $dir = Get-LogsDirectory
  $script:SessionLogFile = Join-Path $dir ('sessao-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
  @(
    'PC Otimizador Pro — log de sessao'
    ('Inicio: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    ('PC: {0} | Admin: {1} | DryRun: {2}' -f $env:COMPUTERNAME, (Test-IsAdmin), [bool]$script:DryRun)
    '----------------------------------------'
  ) | Set-Content -LiteralPath $script:SessionLogFile -Encoding UTF8
  return $script:SessionLogFile
}

function Complete-SessionLog {
  param([string]$Summary = '')
  if (-not $script:SessionLogFile) { return $null }
  Add-Content -LiteralPath $script:SessionLogFile -Value '----------------------------------------' -Encoding UTF8
  if ($Summary) { Add-Content -LiteralPath $script:SessionLogFile -Value $Summary -Encoding UTF8 }
  Add-Content -LiteralPath $script:SessionLogFile -Value ('Fim: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
  Write-Log ("{0}: {1}" -f (Get-T 'logSaved'), $script:SessionLogFile)
  return $script:SessionLogFile
}

function Get-OptionPathMap {
  @{
    temp     = @($env:TEMP, "$env:LOCALAPPDATA\Temp", 'C:\Windows\Temp')
    update   = @('C:\Windows\SoftwareDistribution\Download')
    delivery = @('C:\Windows\SoftwareDistribution\DeliveryOptimization', "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache")
    wer      = @('C:\ProgramData\Microsoft\Windows\WER', "$env:LOCALAPPDATA\Microsoft\Windows\WER", 'C:\Windows\Minidump')
    logs     = @('C:\Windows\Logs\CBS', 'C:\Windows\Logs\DISM', 'C:\Windows\Logs\WindowsUpdate')
    prefetch = @('C:\Windows\Prefetch')
    recent   = @([Environment]::GetFolderPath('Recent'))
    gpu      = @("$env:LOCALAPPDATA\D3DSCache", "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:LOCALAPPDATA\AMD\DxCache", "$env:LOCALAPPDATA\Intel\ShaderCache")
    browser  = @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache", "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache", "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache")
    apps     = @("$env:APPDATA\discord\Cache", "$env:LOCALAPPDATA\Steam\htmlcache", "$env:APPDATA\Microsoft\Teams\Cache", "$env:APPDATA\Spotify\Storage")
    store    = @("$env:LOCALAPPDATA\Microsoft\Windows\INetCache")
    upgrade  = @('C:\$Windows.~BT', 'C:\$Windows.~WS', 'C:\Windows.old')
  }
}

function Get-OptionEstimateMB {
  param([string]$Id)
  $total = 0.0
  $map = Get-OptionPathMap
  if ($map.ContainsKey($Id)) {
    foreach ($p in $map[$Id]) {
      if ($p -and (Test-Path -LiteralPath $p)) { $total += [double](Get-FolderSizeMB $p) }
    }
  }
  if ($Id -eq 'wer' -and (Test-Path 'C:\Windows\MEMORY.DMP')) {
    $total += [math]::Round((Get-Item 'C:\Windows\MEMORY.DMP').Length / 1MB, 2)
  }
  if ($Id -eq 'thumbs') {
    Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache_*.db' -Force -EA SilentlyContinue | ForEach-Object {
      $total += [math]::Round($_.Length / 1MB, 2)
    }
  }
  return [math]::Round($total, 2)
}

function Write-EstimatesReport {
  param([string[]]$Ids)
  Write-Log '=== ESTIMATIVA (nao apaga nada) ==='
  $sum = 0.0
  foreach ($id in $Ids) {
    $mb = Get-OptionEstimateMB $id
    $sum += $mb
    if ($mb -gt 0.05) { Write-Log ('  {0,-14} {1,10:N1} MB' -f $id, $mb) }
    else { Write-Log ('  {0,-14} (sistema / ~0 MB medivel)' -f $id) }
  }
  Write-Log ('TOTAL estimado: ~{0:N0} MB ({1:N2} GB)' -f $sum, ($sum/1024.0))
  return [math]::Round($sum, 2)
}

function Get-CorePresetsPath {
  $p = Join-Path $PSScriptRoot 'core\presets.json'
  if (Test-Path -LiteralPath $p) { return $p }
  return $null
}

function Get-CorePresetsData {
  $path = Get-CorePresetsPath
  if (-not $path) { return $null }
  try {
    return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
  } catch {
    Write-Log ("presets.json invalido: {0}" -f $_.Exception.Message) 'WARN'
    return $null
  }
}

function Get-PresetIds {
  param([string]$Name)
  $key = if ($Name) { $Name.ToLowerInvariant() } else { 'safe' }
  $j = Get-CorePresetsData
  if ($j -and $j.windows) {
    $prop = $j.windows.PSObject.Properties[$key]
    if (-not $prop) { $prop = $j.windows.PSObject.Properties['safe'] }
    if ($prop -and $prop.Value) { return @($prop.Value | ForEach-Object { [string]$_ }) }
  }
  # fallback if JSON missing
  switch ($key) {
    'gamer'    { return @('restore','temp','recycle','update','delivery','thumbs','wer','logs','gpu','apps','trim','tips','gamebar','gamemode','bgapps','widgets','powerhigh','dns','arp','nettweak','nagle','dnscloud') }
    'net'      { return @('restore','dns','arp','netbios','nettweak','renewip','dnscloud') }
    'full'     { return @('restore','temp','recycle','update','delivery','thumbs','wer','logs','recent','font','cleanmgr','dismcleanup','browser','gpu','apps','store','trim','storage','tips','visual','bgapps','widgets','searchweb','gamebar','gamemode','dns','arp','netbios') }
    'notebook' { return @('restore','temp','recycle','update','delivery','thumbs','wer','logs','recent','font','cleanmgr','trim','storage','tips','powerbal','bgapps','widgets','dns','arp','netbios') }
    default    { return @('restore','temp','recycle','update','delivery','thumbs','wer','logs','recent','font','cleanmgr','dismcleanup','trim','storage','tips','dns','arp','netbios') }
  }
}

function Get-ActionRiskLevel {
  param([string]$Id)
  if (-not $Id) { return 'safe' }
  $j = Get-CorePresetsData
  if ($j -and $j.risk_actions) {
    $prop = $j.risk_actions.PSObject.Properties[$Id]
    if ($prop) { return [string]$prop.Value }
  }
  switch ($Id) {
    { $_ -in @('dnscloud','powerhigh','renewip','bloat') } { return 'high' }
    { $_ -in @('nagle','nettweak') } { return 'medium' }
    default { return 'safe' }
  }
}

function Get-HighRiskActionIds {
  param([string[]]$Ids)
  if (-not $Ids) { return @() }
  return @($Ids | Where-Object { (Get-ActionRiskLevel $_) -eq 'high' } | Select-Object -Unique)
}

function Register-WeeklyCleanup {
  $task = 'PCOtimizadorProWeekly'
  $cli = Join-Path $PSScriptRoot 'PC-Otimizador-CLI.ps1'
  $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$cli`" -Preset safe -AutoYes"
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 10:00am
  $prin = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
  Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Principal $prin -Force | Out-Null
  Write-Log (Get-T 'weeklyOk')
}

function Unregister-WeeklyCleanup {
  Unregister-ScheduledTask -TaskName 'PCOtimizadorProWeekly' -Confirm:$false -EA SilentlyContinue
  Write-Log (Get-T 'weeklyOff')
}
