#Requires -Version 5.1
# Engine compartilhado — limpeza/otimizacao (GUI + CLI)
$ErrorActionPreference = 'Continue'
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
  $before = Get-FolderSizeMB $Path
  try {
    if ($Recurse) {
      Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
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
  Write-Host $line -ForegroundColor $color
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
  Write-Log 'Limpeza de Disco do Windows...'
  $base = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
  foreach ($k in @(
    'Temporary Files', 'Temporary Setup Files', 'Thumbnail Cache', 'Recycle Bin',
    'Delivery Optimization Files', 'Windows Error Reporting Files', 'Update Cleanup',
    'Downloaded Program Files', 'Internet Cache Files', 'Previous Installations',
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
