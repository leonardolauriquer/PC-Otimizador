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
$script:ExecutionMutex = $null
$script:RollbackSteps = $null
$script:CurrentActionId = $null
$script:ActionResults = $null
$script:LastExecutionMethod = 1
$script:CurrentActionWarnings = $null
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
      Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
      Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
    if ($null -eq $sum) { return 0 }
    return [math]::Round($sum / 1MB, 2)
  } catch { return 0 }
}

function Get-WindowsRoot {
  $machineRoot = [Environment]::GetEnvironmentVariable('SystemRoot', 'Machine')
  if ($machineRoot) { return $machineRoot }
  if ($env:SystemRoot) { return $env:SystemRoot }
  if ($env:WINDIR) { return $env:WINDIR }
  return 'C:\Windows'
}

function Get-CleanupAllowedRoots {
  $systemRoot = Get-WindowsRoot
  $systemDrive = if ($env:SystemDrive) { $env:SystemDrive } else { $systemRoot.Substring(0,2) }
  $localApp = [Environment]::GetFolderPath('LocalApplicationData')
  $appData = [Environment]::GetFolderPath('ApplicationData')
  $programData = [Environment]::GetFolderPath('CommonApplicationData')
  $userTemp = [IO.Path]::GetTempPath()
  $roots = @(
    $userTemp,
    (Join-Path $localApp 'Temp'),
    (Join-Path $systemRoot 'Temp'),
    (Join-Path $systemRoot 'SoftwareDistribution\Download'),
    (Join-Path $systemRoot 'SoftwareDistribution\DeliveryOptimization'),
    (Join-Path $systemRoot 'ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache'),
    (Join-Path $programData 'Microsoft\Windows\WER'),
    (Join-Path $localApp 'Microsoft\Windows\WER'),
    (Join-Path $systemRoot 'Minidump'),
    (Join-Path $systemRoot 'Logs\CBS'),
    (Join-Path $systemRoot 'Logs\DISM'),
    (Join-Path $systemRoot 'Logs\WindowsUpdate'),
    (Join-Path $localApp 'Microsoft\Windows\Explorer'),
    ([Environment]::GetFolderPath('Recent')),
    (Join-Path $localApp 'D3DSCache'),
    (Join-Path $localApp 'NVIDIA\DXCache'),
    (Join-Path $localApp 'NVIDIA\GLCache'),
    (Join-Path $localApp 'AMD\DxCache'),
    (Join-Path $localApp 'Intel\ShaderCache'),
    (Join-Path $appData 'discord\Cache'),
    (Join-Path $appData 'discord\Code Cache'),
    (Join-Path $appData 'discord\GPUCache'),
    (Join-Path $localApp 'Steam\htmlcache'),
    (Join-Path $appData 'Microsoft\Teams\Cache'),
    (Join-Path $appData 'Microsoft\Teams\GPUCache'),
    (Join-Path $appData 'Spotify\Storage'),
    (Join-Path $localApp 'Microsoft\Windows\INetCache'),
    (Join-Path $localApp 'Microsoft\Windows\Fonts'),
    (Join-Path $localApp 'Google\Chrome\User Data\Default\Cache'),
    (Join-Path $localApp 'Google\Chrome\User Data\Default\Code Cache'),
    (Join-Path $localApp 'Google\Chrome\User Data\Default\GPUCache'),
    (Join-Path $localApp 'Microsoft\Edge\User Data\Default\Cache'),
    (Join-Path $localApp 'Microsoft\Edge\User Data\Default\Code Cache'),
    (Join-Path $localApp 'Microsoft\Edge\User Data\Default\GPUCache'),
    (Join-Path $localApp 'BraveSoftware\Brave-Browser\User Data\Default\Cache'),
    (Join-Path $localApp 'Opera Software\Opera Stable\Cache'),
    (Join-Path $localApp 'Mozilla\Firefox\Profiles'),
    (Join-Path $localApp 'Packages'),
    (Join-Path $systemRoot 'ServiceProfiles\LocalService\AppData\Local\FontCache'),
    (Join-Path $systemDrive '$Windows.~BT'),
    (Join-Path $systemDrive '$Windows.~WS'),
    (Join-Path $systemDrive 'Windows.old')
  )
  $profileRoot = [Environment]::GetFolderPath('UserProfile')
  return @($roots | Where-Object { $_ } | ForEach-Object {
    try { [IO.Path]::GetFullPath([string]$_).TrimEnd('\','/') } catch { $null }
  } | Where-Object {
    $_ -and $_ -ne [IO.Path]::GetPathRoot($_) -and
    (-not $profileRoot -or -not (Test-PathUnderRoot -Path $profileRoot -Root $_))
  } | Select-Object -Unique)
}

function Test-CleanupTarget {
  param([string]$Path)
  if (-not $Path) { return $false }
  try { $full = [IO.Path]::GetFullPath($Path).TrimEnd('\','/') } catch { return $false }
  $root = [IO.Path]::GetPathRoot($full).TrimEnd('\','/')
  if (-not $root -or [string]::Equals($full, $root, [StringComparison]::OrdinalIgnoreCase)) { return $false }
  foreach ($allowed in (Get-CleanupAllowedRoots)) {
    if (Test-PathUnderRoot -Path $full -Root $allowed) {
      $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
      if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
      return $true
    }
  }
  return $false
}

function Remove-PathSafe {
  param([string]$Path, [switch]$Recurse)
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  if (-not (Test-CleanupTarget $Path)) {
    Write-Log ("Alvo recusado pela allowlist: {0}" -f $Path) 'ERROR'
    return 0
  }
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
        if ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) {
          Write-Log ("Reparse point ignorado: {0}" -f $_.FullName) 'WARN'
          return
        }
        if (Test-PathWhitelisted $_.FullName) { return }
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
      }
    } else {
      Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
  } catch {}
  $after = Get-FolderSizeMB $Path
  if ($before -gt 0 -and $after -gt 0.1) { Add-ActionWarning ("Limpeza parcial: {0} MB permaneceram em {1} (arquivos podem estar em uso)." -f $after, $Path) }
  return [math]::Max(0, $before - $after)
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

function Test-CommandAvailable {
  param([Parameter(Mandatory=$true)][string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-ExternalChecked {
  param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [int[]]$SuccessExitCodes = @(0),
    [string]$Label = $FilePath,
    [ValidateRange(1,7200)][int]$TimeoutSec = 600
  )
  $cmd = Get-Command $FilePath -ErrorAction SilentlyContinue
  if (-not $cmd) { throw ("{0} indisponivel neste Windows" -f $Label) }
  $p = Start-Process -FilePath $cmd.Source -ArgumentList $ArgumentList -PassThru -WindowStyle Hidden -ErrorAction Stop
  if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    try { $p.Kill() } catch {}
    throw ("{0} excedeu o limite de {1}s e foi encerrado" -f $Label, $TimeoutSec)
  }
  if ($SuccessExitCodes -notcontains [int]$p.ExitCode) { throw ("{0} retornou codigo {1}" -f $Label, $p.ExitCode) }
  Write-Log ("{0}: concluido (codigo {1})" -f $Label, $p.ExitCode)
  return $p.ExitCode
}

function Invoke-WithFallback {
  param([Parameter(Mandatory=$true)][string]$Name, [Parameter(Mandatory=$true)][scriptblock[]]$Attempts)
  $errors = @()
  for ($i = 0; $i -lt $Attempts.Count; $i++) {
    try {
      if ($i -gt 0) { Write-Log ("{0}: tentando metodo alternativo {1}/{2}" -f $Name, ($i + 1), $Attempts.Count) 'WARN' }
      $value = & $Attempts[$i]
      $script:LastExecutionMethod = $i + 1
      Write-Log ("{0}: verificado pelo metodo {1}" -f $Name, ($i + 1))
      return $value
    } catch {
      $errors += $_.Exception.Message
      Write-Log ("{0}: metodo {1} falhou: {2}" -f $Name, ($i + 1), $_.Exception.Message) 'WARN'
    }
  }
  throw ("{0}: nenhum metodo funcionou ({1})" -f $Name, ($errors -join ' | '))
}

function Enter-ExecutionLock {
  param([string]$Name = 'Global\PCOtimizadorPro.Engine')
  $created = $false
  $script:ExecutionMutex = New-Object Threading.Mutex($false, $Name, [ref]$created)
  try { $acquired = $script:ExecutionMutex.WaitOne(0, $false) } catch { $acquired = $false }
  if (-not $acquired) {
    try { $script:ExecutionMutex.Dispose() } catch {}
    $script:ExecutionMutex = $null
    throw 'Outra otimizacao ja esta em execucao. Aguarde a conclusao antes de iniciar uma nova.'
  }
  return $true
}

function Exit-ExecutionLock {
  if ($script:ExecutionMutex) {
    try { $script:ExecutionMutex.ReleaseMutex() } catch {}
    try { $script:ExecutionMutex.Dispose() } catch {}
    $script:ExecutionMutex = $null
  }
}

function Start-ActionTransaction {
  param([string]$ActionId)
  $script:CurrentActionId = $ActionId
  $script:RollbackSteps = New-Object Collections.Generic.List[object]
  $script:CurrentActionWarnings = New-Object Collections.Generic.List[string]
}

function Add-ActionWarning {
  param([string]$Message)
  if ($null -ne $script:CurrentActionWarnings) { $script:CurrentActionWarnings.Add($Message) }
  Write-Log $Message 'WARN'
}

function Add-RollbackStep {
  param([string]$Description, [scriptblock]$Action)
  if ($null -eq $script:RollbackSteps) { return }
  $script:RollbackSteps.Add([pscustomobject]@{ Description = $Description; Action = $Action })
}

function Complete-ActionTransaction {
  $script:RollbackSteps = $null
  $script:CurrentActionId = $null
  $script:CurrentActionWarnings = $null
}

function Undo-ActionTransaction {
  $steps = @($script:RollbackSteps | ForEach-Object { $_ })
  [array]::Reverse($steps)
  foreach ($step in $steps) {
    try { & $step.Action; Write-Log ("Rollback: {0}" -f $step.Description) }
    catch { Write-Log ("Rollback falhou ({0}): {1}" -f $step.Description, $_.Exception.Message) 'ERROR' }
  }
  Complete-ActionTransaction
}

function Write-ActionResult {
  param([string]$Id, [string]$Name, [ValidateSet('SUCCESS','PARTIAL','FAILED','SKIPPED','BLOCKED')][string]$Status, [string]$Message = '')
  $safeMessage = ($Message -replace '[\r\n|]+', ' ').Trim()
  $item = [pscustomobject]@{ Id = $Id; Name = $Name; Status = $Status; Method = [int]$script:LastExecutionMethod; Message = $safeMessage }
  if ($null -ne $script:ActionResults) { $script:ActionResults.Add($item) }
  Write-Log ("ACTION {0} | {1} | metodo={2} | {3}" -f $Id, $Status, $item.Method, $safeMessage) $(if ($Status -eq 'FAILED') { 'ERROR' } elseif ($Status -in @('PARTIAL','SKIPPED','BLOCKED')) { 'WARN' } else { 'INFO' })
  try { [Console]::Out.WriteLine(('##ACTION##|{0}|{1}|{2}|{3}' -f $Id, $Status, $item.Method, $safeMessage)) } catch {}
  return $item
}

function Get-CompatibilityProfile {
  $os = $null
  try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch {}
  [pscustomobject]@{
    Version = if ($null -ne $os -and $os.Version) { [string]$os.Version } else { [Environment]::OSVersion.Version.ToString() }
    Build = if ($null -ne $os -and $os.BuildNumber) { [string]$os.BuildNumber } else { [Environment]::OSVersion.Version.Build.ToString() }
    PowerShell = $PSVersionTable.PSVersion.ToString(); Is64Bit = [Environment]::Is64BitOperatingSystem
    IsAdmin = Test-IsAdmin; HasCim = (Test-CommandAvailable 'Get-CimInstance')
    HasStorage = (Test-CommandAvailable 'Optimize-Volume'); HasDnsCmdlet = (Test-CommandAvailable 'Clear-DnsClientCache')
    HasDism = (Test-CommandAvailable 'dism.exe'); HasSfc = (Test-CommandAvailable 'sfc.exe')
  }
}

function Get-AppSettingsPath {
  $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [Environment]::GetFolderPath('LocalApplicationData') }
  if (-not $base) { $base = Join-Path $env:TEMP 'PC-Otimizador-User' }
  $dir = Join-Path $base 'PC-Otimizador'
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  return Join-Path $dir 'settings.json'
}

function Get-AppSettings {
  $path = Get-AppSettingsPath
  if (Test-Path -LiteralPath $path) {
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop } catch {}
  }
  return [pscustomobject]@{ TelemetryConsent = $false; TelemetryEndpoint = '' }
}

function Set-TelemetrySettings {
  param([bool]$Consent, [string]$Endpoint = '')
  if ($Endpoint -and $Endpoint -notmatch '^https://') { throw 'O endpoint de telemetria deve usar HTTPS.' }
  $settings = [ordered]@{ TelemetryConsent = $Consent; TelemetryEndpoint = $Endpoint; UpdatedAtUtc = [DateTime]::UtcNow.ToString('o') }
  $settingsPath = Get-AppSettingsPath
  $settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
  if (-not $Consent) {
    $queue = Join-Path (Split-Path $settingsPath -Parent) 'telemetry.jsonl'
    if (Test-Path -LiteralPath $queue) { Remove-Item -LiteralPath $queue -Force -ErrorAction SilentlyContinue }
  }
  return [pscustomobject]$settings
}

function Submit-TelemetryEvent {
  param([string]$ActionId, [string]$Status, [int]$DurationMs, [string]$FailureCategory = '')
  $settings = Get-AppSettings
  $consentProp = $settings.PSObject.Properties['TelemetryConsent']
  if (-not $consentProp -or -not [bool]$consentProp.Value) { return $false }
  $versionPath = Join-Path $PSScriptRoot 'VERSION'
  $appVersion = if (Test-Path -LiteralPath $versionPath) { (Get-Content -LiteralPath $versionPath -Raw).Trim() } else { 'unknown' }
  $compat = Get-CompatibilityProfile
  $payload = [ordered]@{
    schema = 1; timestampUtc = [DateTime]::UtcNow.ToString('o'); appVersion = $appVersion
    osVersion = $compat.Version; osBuild = $compat.Build; powershell = $compat.PowerShell
    action = $ActionId; status = $Status; durationMs = $DurationMs; failureCategory = $FailureCategory
  }
  $queue = Join-Path (Split-Path (Get-AppSettingsPath) -Parent) 'telemetry.jsonl'
  ($payload | ConvertTo-Json -Compress) | Add-Content -LiteralPath $queue -Encoding UTF8
  $endpointProp = $settings.PSObject.Properties['TelemetryEndpoint']
  if ($endpointProp -and $endpointProp.Value) {
    try {
      Invoke-RestMethod -Uri ([string]$endpointProp.Value) -Method Post -ContentType 'application/json' -Body ($payload | ConvertTo-Json -Compress) -TimeoutSec 5 | Out-Null
    } catch { Write-Log ("Telemetria nao enviada; evento mantido localmente: {0}" -f $_.Exception.Message) 'WARN'; return $false }
  }
  return $true
}

function Get-SystemSnapshot {
  try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
  } catch {
    Write-Log ("Snapshot CIM falhou; tentando WMI legado: {0}" -f $_.Exception.Message) 'WARN'
    if (Test-CommandAvailable 'Get-WmiObject') {
      try {
        $os = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction Stop
        $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
      } catch { $os = $null; Write-Log ("Snapshot WMI tambem falhou: {0}" -f $_.Exception.Message) 'WARN' }
    }
    if ($null -eq $os) {
      $driveRoot = if ($env:SystemDrive) { $env:SystemDrive + '\' } else { 'C:\' }
      $drive = New-Object IO.DriveInfo($driveRoot)
      Write-Log 'CIM e WMI indisponiveis; memoria sera marcada como nao mensuravel.' 'WARN'
      return [pscustomobject]@{
        PC = [Environment]::MachineName; OS = [Environment]::OSVersion.VersionString
        DiskFree = [math]::Round($drive.AvailableFreeSpace / 1GB, 2); DiskTot = [math]::Round($drive.TotalSize / 1GB, 2)
        DiskUsed = [math]::Round((($drive.TotalSize - $drive.AvailableFreeSpace) / $drive.TotalSize) * 100, 1)
        RamUsed = 0; RamTot = 0
      }
    }
  }
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
  $pathExisted = Test-Path $Path
  $existed = $false; $oldValue = $null
  if ($pathExisted) {
    try { $oldValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name; $existed = $true } catch {}
  }
  $rollbackPath = $Path; $rollbackName = $Name; $rollbackExisted = $existed; $rollbackValue = $oldValue; $rollbackPathExisted = $pathExisted
  Add-RollbackStep ("Registro {0}\{1}" -f $Path, $Name) ({
    if ($rollbackExisted) { Set-ItemProperty -Path $rollbackPath -Name $rollbackName -Value $rollbackValue -Type DWord -Force -ErrorAction Stop }
    else {
      Remove-ItemProperty -Path $rollbackPath -Name $rollbackName -Force -ErrorAction SilentlyContinue
      if (-not $rollbackPathExisted -and (Test-Path $rollbackPath)) { Remove-Item -Path $rollbackPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
  }.GetNewClosure())
  if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
  Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
  $actual = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
  $expectedUnsigned = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$Value), 0)
  if ([uint64]$actual -ne [uint64]$expectedUnsigned) { throw ("Registro nao confirmou {0}\{1}" -f $Path, $Name) }
}

# ── Actions: Limpeza ─────────────────────────────────────────────────────────
function Invoke-CleanTemp {
  $freed = 0.0
  $systemRoot = Get-WindowsRoot
  $targets = @($env:TEMP, "$env:LOCALAPPDATA\Temp", (Join-Path $systemRoot 'Temp')) | Select-Object -Unique
  foreach ($p in $targets) {
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
  $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
  $bits = Get-Service bits -ErrorAction SilentlyContinue
  $wuWasRunning = $wu -and $wu.Status -eq 'Running'
  $bitsWasRunning = $bits -and $bits.Status -eq 'Running'
  try {
    if ($wuWasRunning) { Stop-Service wuauserv -Force -ErrorAction Stop; (Get-Service wuauserv).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(30)) }
    if ($bitsWasRunning) { Stop-Service bits -Force -ErrorAction Stop; (Get-Service bits).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(30)) }
    $freed = [double](Remove-PathSafe (Join-Path (Get-WindowsRoot) 'SoftwareDistribution\Download') -Recurse)
  } finally {
    if ($bitsWasRunning) { Start-Service bits -ErrorAction Stop; (Get-Service bits).WaitForStatus('Running',[TimeSpan]::FromSeconds(30)) }
    if ($wuWasRunning) { Start-Service wuauserv -ErrorAction Stop; (Get-Service wuauserv).WaitForStatus('Running',[TimeSpan]::FromSeconds(30)) }
  }
  Write-Log "Update cache: ~$freed MB"; return $freed
}

function Invoke-CleanDeliveryOptimization {
  Write-Log 'Delivery Optimization...'
  $freed = [double](Remove-PathSafe (Join-Path (Get-WindowsRoot) 'SoftwareDistribution\DeliveryOptimization') -Recurse)
  $freed += [double](Remove-PathSafe (Join-Path (Get-WindowsRoot) 'ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache') -Recurse)
  Write-Log "Delivery Opt: ~$freed MB"; return $freed
}

function Invoke-CleanThumbnails {
  Write-Log 'Cache de miniaturas/icones...'
  $freed = 0.0
  $ex = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
  Get-ChildItem $ex -Filter 'thumbcache_*.db' -Force -EA SilentlyContinue | ForEach-Object {
    $freed += [math]::Round($_.Length / 1MB, 2)
    Remove-Item $_.FullName -Force -EA SilentlyContinue
  }
  $icon = "$env:LOCALAPPDATA\IconCache.db"
  if (Test-Path $icon) { Remove-Item $icon -Force -EA SilentlyContinue }
  Write-Log "Thumbs/icons: ~$freed MB"; return $freed
}

function Invoke-CleanPrefetch {
  Write-Log 'Prefetch...'
  $f = [double](Remove-PathSafe (Join-Path (Get-WindowsRoot) 'Prefetch') -Recurse)
  Write-Log "Prefetch: ~$f MB"; return $f
}

function Invoke-CleanWER {
  Write-Log 'Relatorios de erro + minidumps...'
  $f = 0.0
  foreach ($p in @(
    (Join-Path $env:ProgramData 'Microsoft\Windows\WER'),
    "$env:LOCALAPPDATA\Microsoft\Windows\WER",
    (Join-Path (Get-WindowsRoot) 'Minidump')
  )) { $f += [double](Remove-PathSafe $p -Recurse) }
  $memoryDump = Join-Path (Get-WindowsRoot) 'MEMORY.DMP'
  if (Test-Path $memoryDump) {
    $sz = [math]::Round((Get-Item $memoryDump).Length / 1MB, 2)
    Remove-Item $memoryDump -Force -EA SilentlyContinue
    $f += $sz
  }
  Write-Log "WER/dumps: ~$f MB"; return $f
}

function Invoke-CleanLogs {
  Write-Log 'Logs do Windows...'
  $f = 0.0
  foreach ($p in @(
    (Join-Path (Get-WindowsRoot) 'Logs\CBS'),
    (Join-Path (Get-WindowsRoot) 'Logs\DISM'),
    (Join-Path (Get-WindowsRoot) 'Logs\WindowsUpdate'),
    (Join-Path (Get-WindowsRoot) 'SoftwareDistribution\ReportingEvents.log')
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
  $svc = Get-Service FontCache -ErrorAction SilentlyContinue
  $wasRunning = $svc -and $svc.Status -eq 'Running'
  try {
    if ($wasRunning) { Stop-Service FontCache -Force -ErrorAction Stop; (Get-Service FontCache).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(30)) }
    $null = Remove-PathSafe (Join-Path (Get-WindowsRoot) 'ServiceProfiles\LocalService\AppData\Local\FontCache') -Recurse
  } finally {
    if ($wasRunning) { Start-Service FontCache -ErrorAction Stop; (Get-Service FontCache).WaitForStatus('Running',[TimeSpan]::FromSeconds(30)) }
  }
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
  $null = Invoke-ExternalChecked 'wsreset.exe' @() @(0) 'Microsoft Store reset' 300
  Write-Log "Store: ~$f MB"; return $f
}

function Invoke-CleanMgr {
  Write-Log 'Limpeza de Disco do Windows (perfil temporario seguro)...'
  $base = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
  $keys = @(
    'Temporary Files', 'Temporary Setup Files', 'Thumbnail Cache', 'Recycle Bin',
    'Delivery Optimization Files', 'Windows Error Reporting Files',
    'Downloaded Program Files', 'Internet Cache Files',
    'System error memory dump files', 'System error minidump files'
  )
  $slot = Get-Random -Minimum 7000 -Maximum 9999
  $flag = "StateFlags{0}" -f $slot
  $changed = @()
  try {
    while (@(Get-ChildItem -LiteralPath $base -EA SilentlyContinue | Where-Object {
      $v = Get-ItemProperty -LiteralPath $_.PSPath -Name $flag -EA SilentlyContinue
      $null -ne $v
    }).Count -gt 0) { $slot = Get-Random -Minimum 7000 -Maximum 9999; $flag = "StateFlags{0}" -f $slot }
    foreach ($k in $keys) {
      $path = Join-Path $base $k
      if (-not (Test-Path $path)) { continue }
      $old = Get-ItemProperty -LiteralPath $path -Name $flag -EA SilentlyContinue
      $hadOld = $null -ne $old
      $oldValue = if ($hadOld) { [int]$old.$flag } else { 0 }
      $changed += [pscustomobject]@{ Path = $path; Had = $hadOld; Value = $oldValue }
      Set-ItemProperty $path -Name $flag -Value 2 -Type DWord -Force -EA Stop
    }
    $null = Invoke-ExternalChecked 'cleanmgr.exe' @(("/sagerun:{0}" -f $slot)) @(0) 'Limpeza de Disco'
    Write-Log 'cleanmgr concluido'; return 0
  } catch {
    Write-Log ("cleanmgr falhou: {0}" -f $_) 'WARN'; throw
  } finally {
    foreach ($entry in $changed) {
      if ($entry.Had) { Set-ItemProperty $entry.Path -Name $flag -Value $entry.Value -Type DWord -Force -EA SilentlyContinue }
      else { Remove-ItemProperty $entry.Path -Name $flag -Force -EA SilentlyContinue }
    }
  }
}

function Invoke-DismCleanup {
  Write-Log 'DISM Component Cleanup (pode demorar)...'
  $null = Invoke-ExternalChecked 'dism.exe' @('/Online','/Cleanup-Image','/StartComponentCleanup') @(0,3010) 'DISM Component Cleanup'
  return 0
}

function Invoke-CleanUpgradeLeftovers {
  Write-Log 'Pastas de upgrade orfas ($Windows.~BT / ~WS)...'
  $f = 0.0
  $systemDrive = if ($env:SystemDrive) { $env:SystemDrive } else { (Get-WindowsRoot).Substring(0,2) }
  foreach ($p in @((Join-Path $systemDrive '$Windows.~BT'), (Join-Path $systemDrive '$Windows.~WS'), (Join-Path $systemDrive 'Windows.old'))) {
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
    $letter = [string]$_.DriveLetter
    Invoke-WithFallback ("Otimizar unidade {0}:" -f $letter) @(
      { Optimize-Volume -DriveLetter $letter -ReTrim -ErrorAction Stop | Out-Null; return 0 },
      { $null = Invoke-ExternalChecked 'defrag.exe' @(("{0}:" -f $letter),'/L','/U') @(0) ("Defrag/TRIM {0}:" -f $letter); return 0 }
    ) | Out-Null
  }
  return 0
}

function Invoke-HighPerformance {
  Write-Log 'Plano Alto Desempenho...'
  $script:ActivatedHighPerformanceGuid = $null
  $previousScheme = (& powercfg.exe /getactivescheme 2>&1 | Out-String)
  if ($previousScheme -match '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}') {
    $previousGuid = $matches[0]
    Add-RollbackStep 'Plano de energia anterior' ({ $null = Invoke-ExternalChecked 'powercfg.exe' @('/setactive',$previousGuid) @(0) 'Rollback powercfg' }.GetNewClosure())
  }
  $guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
  Invoke-WithFallback 'Plano Alto Desempenho' @(
    { $null = Invoke-ExternalChecked 'powercfg.exe' @('/setactive',$guid) @(0) 'powercfg'; return 0 },
    {
      $duplicate = (& powercfg.exe /duplicatescheme $guid 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0 -or $duplicate -notmatch '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}') { throw 'nao foi possivel duplicar o plano' }
      $script:ActivatedHighPerformanceGuid = $matches[0]
      $null = Invoke-ExternalChecked 'powercfg.exe' @('/setactive',$script:ActivatedHighPerformanceGuid) @(0) 'powercfg alternativo'
      return 0
    }
  ) | Out-Null
  if ($script:ActivatedHighPerformanceGuid) { $guid = $script:ActivatedHighPerformanceGuid }
  $active = (& powercfg.exe /getactivescheme 2>&1 | Out-String)
  if ($active -notmatch [regex]::Escape($guid)) { throw 'O plano Alto Desempenho nao ficou ativo apos a tentativa.' }
  return 0
}

function Invoke-BalancedPower {
  Write-Log 'Plano Equilibrado...'
  $previousScheme = (& powercfg.exe /getactivescheme 2>&1 | Out-String)
  if ($previousScheme -match '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}') {
    $previousGuid = $matches[0]
    Add-RollbackStep 'Plano de energia anterior' ({ $null = Invoke-ExternalChecked 'powercfg.exe' @('/setactive',$previousGuid) @(0) 'Rollback powercfg' }.GetNewClosure())
  }
  $guid = '381b4222-f694-41f0-9685-ff5bb260df2e'
  $null = Invoke-ExternalChecked 'powercfg.exe' @('/setactive',$guid) @(0) 'Plano Equilibrado'
  $active = (& powercfg.exe /getactivescheme 2>&1 | Out-String)
  if ($active -notmatch [regex]::Escape($guid)) { throw 'O plano Equilibrado nao ficou ativo apos a tentativa.' }
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
  Write-Log 'Flush DNS...'
  Invoke-WithFallback 'Limpeza DNS' @(
    { if (-not (Test-CommandAvailable 'Clear-DnsClientCache')) { throw 'cmdlet ausente' }; Clear-DnsClientCache -ErrorAction Stop; return 0 },
    { $null = Invoke-ExternalChecked 'ipconfig.exe' @('/flushdns') @(0) 'ipconfig /flushdns'; return 0 }
  ) | Out-Null
  return 0
}

function Invoke-FlushARP {
  Write-Log 'Flush ARP...'; $null = Invoke-ExternalChecked 'arp.exe' @('-d','*') @(0) 'Limpeza ARP'; return 0
}

function Invoke-RenewIP {
  Write-Log 'Renovando IP...'
  $null = Invoke-ExternalChecked 'ipconfig.exe' @('/release') @(0) 'Liberar IP'
  Start-Sleep -Milliseconds 500
  $null = Invoke-ExternalChecked 'ipconfig.exe' @('/renew') @(0) 'Renovar IP'
  return 0
}

function Invoke-ResetWinsock {
  Write-Log 'Reset Winsock (reinicie depois)...'
  $null = Invoke-ExternalChecked 'netsh.exe' @('winsock','reset','catalog') @(0) 'Reset Winsock'
  return 0
}

function Invoke-ResetTCPIP {
  Write-Log 'Reset TCP/IP (reinicie depois)...'
  $null = Invoke-ExternalChecked 'netsh.exe' @('int','ip','reset') @(0) 'Reset TCP/IP'
  return 0
}

function Invoke-NetOptimizations {
  Write-Log 'Otimizacoes TCP leves...'
  $null = Invoke-ExternalChecked 'netsh.exe' @('int','tcp','set','global','autotuninglevel=normal') @(0) 'TCP autotuning'
  foreach ($setting in @('chimney=disabled','dca=enabled','netdma=enabled','ecncapability=enabled','timestamps=disabled')) {
    try { $null = Invoke-ExternalChecked 'netsh.exe' @('int','tcp','set','global',$setting) @(0) ("TCP {0}" -f $setting) }
    catch { Add-ActionWarning ("Opcao TCP nao suportada nesta versao ({0}): {1}" -f $setting, $_.Exception.Message) }
  }
  # Network Throttling Index (multimedia)
  Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' -1
  Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10
  Write-Log 'TCP/multimedia tweaks OK'; return 0
}

function Set-DnsServersResilient {
  param([string[]]$Servers, [string]$Label)
  Invoke-WithFallback $Label @(
    {
      if (-not (Test-CommandAvailable 'Get-NetAdapter') -or -not (Test-CommandAvailable 'Set-DnsClientServerAddress')) { throw 'cmdlets DNS modernos ausentes' }
      $adapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object Status -eq 'Up')
      if ($adapters.Count -eq 0) { throw 'nenhum adaptador ativo' }
      foreach ($adapter in $adapters) {
        $index = [int]$adapter.ifIndex
        $old = @(Get-DnsClientServerAddress -InterfaceIndex $index -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object ServerAddresses)
        Add-RollbackStep ("DNS do adaptador {0}" -f $adapter.Name) ({
          if ($old.Count -gt 0) { Set-DnsClientServerAddress -InterfaceIndex $index -ServerAddresses $old -ErrorAction Stop }
          else { Set-DnsClientServerAddress -InterfaceIndex $index -ResetServerAddresses -ErrorAction Stop }
        }.GetNewClosure())
        Set-DnsClientServerAddress -InterfaceIndex $index -ServerAddresses $Servers -ErrorAction Stop
        $actual = @(Get-DnsClientServerAddress -InterfaceIndex $index -AddressFamily IPv4 -ErrorAction Stop | ForEach-Object ServerAddresses)
        if ($actual -notcontains $Servers[0]) { throw ("adaptador {0} nao confirmou DNS" -f $adapter.Name) }
        Write-Log ("  {0} -> {1}" -f $adapter.Name, ($Servers -join ', '))
      }
      return $adapters.Count
    },
    {
      if (-not (Test-CommandAvailable 'Get-WmiObject')) { throw 'WMI DNS indisponivel' }
      $configs = @(Get-WmiObject Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction Stop)
      if ($configs.Count -eq 0) { throw 'nenhum adaptador IP ativo via WMI' }
      foreach ($config in $configs) {
        $old = @($config.DNSServerSearchOrder); $wmiIndex = [uint32]$config.Index
        Add-RollbackStep ("DNS WMI do adaptador {0}" -f $wmiIndex) ({
          $target = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter ("Index={0}" -f $wmiIndex) -ErrorAction Stop
          $result = $target.SetDNSServerSearchOrder($(if ($old.Count) { [string[]]$old } else { $null }))
          if ([int]$result.ReturnValue -notin @(0,1)) { throw ("WMI rollback retornou {0}" -f $result.ReturnValue) }
        }.GetNewClosure())
        $result = $config.SetDNSServerSearchOrder([string[]]$Servers)
        if ([int]$result.ReturnValue -notin @(0,1)) { throw ("WMI DNS retornou {0}" -f $result.ReturnValue) }
      }
      return $configs.Count
    }
  ) | Out-Null
  return 0
}

function Invoke-DnsCloudflare {
  Write-Log 'DNS Cloudflare 1.1.1.1 nas placas ativas...'
  return Set-DnsServersResilient -Servers @('1.1.1.1','1.0.0.1') -Label 'DNS Cloudflare'
}

function Invoke-DnsGoogle {
  Write-Log 'DNS Google 8.8.8.8 nas placas ativas...'
  return Set-DnsServersResilient -Servers @('8.8.8.8','8.8.4.4') -Label 'DNS Google'
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
  Write-Log 'Limpando cache NetBIOS...'
  $null = Invoke-ExternalChecked 'nbtstat.exe' @('-R') @(0) 'NetBIOS cache'
  $null = Invoke-ExternalChecked 'nbtstat.exe' @('-RR') @(0) 'NetBIOS refresh'
  return 0
}

# ── Actions: Manutencao ──────────────────────────────────────────────────────
function Invoke-RestorePoint {
  Write-Log 'Criando ponto de restauracao...'
  try { Enable-ComputerRestore -Drive 'C:\' -ErrorAction Stop } catch { Write-Log ("Protecao do Sistema: {0}" -f $_.Exception.Message) 'WARN' }
  Invoke-WithFallback 'Ponto de restauracao' @(
    { Checkpoint-Computer -Description 'PC Otimizador Pro' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; return 0 },
    {
      if (-not (Test-CommandAvailable 'Get-WmiObject')) { throw 'WMI legado indisponivel' }
      $sr = Get-WmiObject -List SystemRestore -Namespace root\default -ErrorAction Stop
      $result = $sr.CreateRestorePoint('PC Otimizador Pro', 12, 100)
      if ([int]$result.ReturnValue -ne 0) { throw ("SystemRestore retornou {0}" -f $result.ReturnValue) }
      return 0
    }
  ) | Out-Null
  Write-Log 'Ponto de restauracao criado e confirmado.'
  return 0
}

function Invoke-SFC {
  Write-Log 'SFC /scannow (demorado)...'
  $null = Invoke-ExternalChecked 'sfc.exe' @('/scannow') @(0,1) 'SFC'
  return 0
}

function Invoke-DismRestore {
  Write-Log 'DISM RestoreHealth (demorado)...'
  $null = Invoke-ExternalChecked 'dism.exe' @('/Online','/Cleanup-Image','/RestoreHealth') @(0,3010) 'DISM RestoreHealth'
  return 0
}

function Invoke-ScanOnly {
  Write-Log '=== VARREDURA (nao apaga nada) ==='
  $items = @(
    @{ N = 'Temp usuario'; P = $env:TEMP }
    @{ N = 'Temp LocalAppData'; P = "$env:LOCALAPPDATA\Temp" }
    @{ N = 'Temp Windows'; P = (Join-Path (Get-WindowsRoot) 'Temp') }
    @{ N = 'Windows Update'; P = (Join-Path (Get-WindowsRoot) 'SoftwareDistribution\Download') }
    @{ N = 'Prefetch'; P = (Join-Path (Get-WindowsRoot) 'Prefetch') }
    @{ N = 'WER'; P = (Join-Path $env:ProgramData 'Microsoft\Windows\WER') }
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
    [switch]$EstimateOnly,
    [switch]$AllowHighRisk
  )
  $null = Enter-ExecutionLock
  $script:ActionResults = New-Object Collections.Generic.List[object]
  try {
  Reset-CancelFlag
  Import-Whitelist
  $script:DryRun = [bool]$DryRun
  $null = Initialize-SessionLog
  $compat = Get-CompatibilityProfile
  Write-Log ("Compatibilidade | Windows {0} build {1} | PowerShell {2} | 64-bit={3} | Admin={4}" -f $compat.Version, $compat.Build, $compat.PowerShell, $compat.Is64Bit, $compat.IsAdmin)
  if (-not $compat.HasCim) { Write-Log 'CIM ausente: inventario e metricas usarao metodos legados.' 'WARN' }
  if (-not $compat.HasDism) { Write-Log 'DISM ausente: reparos de imagem serao marcados como indisponiveis.' 'WARN' }
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
  $highRisk = @(Get-HighRiskActionIds -Ids $Ids)
  if (-not $DryRun -and -not $EstimateOnly -and $highRisk.Count -gt 0 -and -not $AllowHighRisk) {
    $blockedMsg = "Bloqueado: exige confirmacao de alto risco: {0}" -f ($highRisk -join ', ')
    Write-Log $blockedMsg 'ERROR'
    $path = Complete-SessionLog -Summary $blockedMsg
    foreach ($blockedId in $highRisk) { $script:LastExecutionMethod = 0; $null = Write-ActionResult $blockedId $blockedId 'BLOCKED' 'Confirmacao de alto risco ausente.' }
    try {
      [Console]::Out.WriteLine(('##SUMMARY##|SUCCESS=0|PARTIAL=0|SKIPPED=0|FAILED=0|TOTAL={0}' -f $script:ActionResults.Count))
      [Console]::Out.WriteLine(('##DONE##|BLOCKED|{0}' -f ($highRisk -join ',')))
    } catch {}
    Exit-ExecutionLock
    return [pscustomobject]@{
      FreedMB = 0; DeltaGB = 0; Log = $path; EstimatedMB = $est
      Before = $before; After = $before; Cancelled = $false; Blocked = $true
      Failed = $false; Health = (Get-HealthScore); ActionResults = @($script:ActionResults | ForEach-Object { $_ })
    }
  }
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
    foreach ($plannedId in $Ids) { $script:LastExecutionMethod = 0; $null = Write-ActionResult $plannedId $plannedId 'SKIPPED' $(if ($DryRun) { 'Simulacao: nenhuma alteracao aplicada.' } else { 'Somente estimativa.' }) }
    $skippedCount = @($script:ActionResults | Where-Object Status -eq 'SKIPPED').Count
    $path = Complete-SessionLog -Summary ("Estimativa total: ~{0} MB" -f $est)
    $after = Get-SystemSnapshot
    try {
      [Console]::Out.WriteLine(('##RESULT##|AFTER|{0}|{1}|{2}|{3}|{4}|{5}|0' -f $after.DiskFree, $after.DiskTot, $after.RamUsed, $after.RamTot, $est, $path))
      [Console]::Out.WriteLine(('##SUMMARY##|SUCCESS=0|PARTIAL=0|SKIPPED={0}|FAILED=0|TOTAL={1}' -f $skippedCount, $script:ActionResults.Count))
      [Console]::Out.WriteLine(('##DONE##|{0}' -f $(if ($script:CancelRequested) { 'CANCELLED' } elseif ($DryRun) { 'DRYRUN' } else { 'ESTIMATE' })))
    } catch {}
    Exit-ExecutionLock
    return [pscustomobject]@{
      FreedMB = 0; DeltaGB = 0; Log = $path; EstimatedMB = $est
      Before = $before; After = $after; Cancelled = [bool]$script:CancelRequested
      Blocked = $false; Failed = $false; Health = (Get-HealthScore); ActionResults = @($script:ActionResults | ForEach-Object { $_ })
    }
  }

  $freed = 0.0
  $order = @($Ids | Sort-Object { if ($_ -eq 'restore') { 0 } else { 1 } })
  # filter trim suggestion already logged; still allow if selected
  $i = 0
  $cancelled = $false
  $failed = $false
  Save-TweakSnapshot -Ids $order
  foreach ($id in $order) {
    $i++
    if (Test-CancelRequested) { $cancelled = $true; Write-Log (Get-T 'cancelled') 'WARN'; break }
    if (-not $Actions.ContainsKey($id)) { $null = Write-ActionResult $id $id 'SKIPPED' 'Acao nao existe nesta versao.'; continue }
    $o = $Actions[$id]
    Write-ProgressLine -Current $i -Total $order.Count -Name $o.Nome
    Write-Log (">> [{0}/{1}] {2}" -f $i, $order.Count, $o.Nome)
    Start-ActionTransaction $id
    $script:LastExecutionMethod = 1
    $actionTimer = [Diagnostics.Stopwatch]::StartNew()
    try {
      $f = & $o.Act
      if ($f) { $freed += [double]$f }
      $warnings = @($script:CurrentActionWarnings | ForEach-Object { $_ })
      Complete-ActionTransaction
      $actionStatus = if ($warnings.Count -gt 0) { 'PARTIAL' } else { 'SUCCESS' }
      $actionMessage = if ($warnings.Count -gt 0) { $warnings -join '; ' } else { 'Pos-condicoes confirmadas.' }
      $null = Write-ActionResult $id $o.Nome $actionStatus $actionMessage
      $actionTimer.Stop(); $null = Submit-TelemetryEvent $id $actionStatus ([int]$actionTimer.ElapsedMilliseconds)
    } catch {
      $failed = $true
      $errorMessage = $_.Exception.Message
      Write-Log "Erro $id : $errorMessage" 'ERROR'
      Undo-ActionTransaction
      $contractStatus = if ($errorMessage -match 'indisponivel|ausente|nao suport|nenhum adaptador') { 'SKIPPED' } else { 'FAILED' }
      $null = Write-ActionResult $id $o.Nome $contractStatus $errorMessage
      $actionTimer.Stop(); $failureCategory = if ($errorMessage -match 'permiss|acesso|admin') { 'permission' } elseif ($errorMessage -match 'indisponivel|ausente|suport') { 'unsupported' } elseif ($errorMessage -match 'limite|tempo|timeout') { 'timeout' } else { 'execution' }
      $null = Submit-TelemetryEvent $id $contractStatus ([int]$actionTimer.ElapsedMilliseconds) $failureCategory
    }
  }
  $after = Get-SystemSnapshot
  $delta = [math]::Round($after.DiskFree - $before.DiskFree, 2)
  $sum = ("Freed~{0:N0} MB | Disco +{1} GB | cancel={2}" -f $freed, $delta, $cancelled)
  Write-Log $sum
  $path = Complete-SessionLog -Summary $sum
  $health = Get-HealthScore
  Add-HealthHistory -Score $health.Score
  $successCount = @($script:ActionResults | Where-Object Status -eq 'SUCCESS').Count
  $partialCount = @($script:ActionResults | Where-Object Status -eq 'PARTIAL').Count
  $failedCount = @($script:ActionResults | Where-Object Status -eq 'FAILED').Count
  $skippedCount = @($script:ActionResults | Where-Object Status -eq 'SKIPPED').Count
  try {
    [Console]::Out.WriteLine(('##RESULT##|AFTER|{0}|{1}|{2}|{3}|{4}|{5}|{6}' -f $after.DiskFree, $after.DiskTot, $after.RamUsed, $after.RamTot, [math]::Round($freed,1), $path, $health.Score))
    [Console]::Out.WriteLine(('##SUMMARY##|SUCCESS={0}|PARTIAL={1}|SKIPPED={2}|FAILED={3}|TOTAL={4}' -f $successCount, $partialCount, $skippedCount, $failedCount, $script:ActionResults.Count))
    [Console]::Out.WriteLine(('##DONE##|{0}' -f $(if ($cancelled) { 'CANCELLED' } elseif ($failed) { 'FAILED' } else { 'OK' })))
  } catch {}
  Exit-ExecutionLock
  return [pscustomobject]@{
    FreedMB = $freed; DeltaGB = $delta; Log = $path; EstimatedMB = $est
    Before = $before; After = $after; Cancelled = $cancelled; Blocked = $false
    Failed = $failed; Health = $health; ActionResults = @($script:ActionResults | ForEach-Object { $_ })
  }
  } finally {
    Exit-ExecutionLock
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
  $root = Get-WindowsRoot
  $drive = if ($env:SystemDrive) { $env:SystemDrive } else { $root.Substring(0,2) }
  $localApp = [Environment]::GetFolderPath('LocalApplicationData')
  $appData = [Environment]::GetFolderPath('ApplicationData')
  $programData = [Environment]::GetFolderPath('CommonApplicationData')
  @{
    temp     = @($env:TEMP, "$env:LOCALAPPDATA\Temp", (Join-Path $root 'Temp'))
    update   = @((Join-Path $root 'SoftwareDistribution\Download'))
    delivery = @((Join-Path $root 'SoftwareDistribution\DeliveryOptimization'), (Join-Path $root 'ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache'))
    wer      = @((Join-Path $programData 'Microsoft\Windows\WER'), "$env:LOCALAPPDATA\Microsoft\Windows\WER", (Join-Path $root 'Minidump'))
    logs     = @((Join-Path $root 'Logs\CBS'), (Join-Path $root 'Logs\DISM'), (Join-Path $root 'Logs\WindowsUpdate'))
    prefetch = @((Join-Path $root 'Prefetch'))
    recent   = @([Environment]::GetFolderPath('Recent'))
    gpu      = @((Join-Path $localApp 'D3DSCache'), (Join-Path $localApp 'NVIDIA\DXCache'), (Join-Path $localApp 'NVIDIA\GLCache'), (Join-Path $localApp 'AMD\DxCache'), (Join-Path $localApp 'Intel\ShaderCache'))
    browser  = @((Join-Path $localApp 'Google\Chrome\User Data\Default\Cache'), (Join-Path $localApp 'Microsoft\Edge\User Data\Default\Cache'), (Join-Path $localApp 'BraveSoftware\Brave-Browser\User Data\Default\Cache'))
    apps     = @((Join-Path $appData 'discord\Cache'), (Join-Path $localApp 'Steam\htmlcache'), (Join-Path $appData 'Microsoft\Teams\Cache'), (Join-Path $appData 'Spotify\Storage'))
    store    = @((Join-Path $localApp 'Microsoft\Windows\INetCache'))
    upgrade  = @((Join-Path $drive '$Windows.~BT'), (Join-Path $drive '$Windows.~WS'), (Join-Path $drive 'Windows.old'))
  }
}

function Get-OptionEstimateMB {
  param([string]$Id)
  $total = 0.0
  $map = Get-OptionPathMap
  if ($map.ContainsKey($Id)) {
    foreach ($p in @($map[$Id] | ForEach-Object {
      try { [IO.Path]::GetFullPath([string]$_) } catch { [string]$_ }
    } | Select-Object -Unique)) {
      if ($p -and (Test-Path -LiteralPath $p)) { $total += [double](Get-FolderSizeMB $p) }
    }
  }
  $memoryDump = Join-Path (Get-WindowsRoot) 'MEMORY.DMP'
  if ($Id -eq 'wer' -and (Test-Path $memoryDump)) {
    $total += [math]::Round((Get-Item $memoryDump).Length / 1MB, 2)
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
    'notebook' { return @('restore','temp','update','delivery','thumbs','wer','logs','recent','font','trim','storage','tips','powerbal','bgapps','widgets','dns','arp','netbios') }
    default    { return @('restore','temp','update','delivery','thumbs','wer','logs','recent','font','trim','storage','tips','dns','arp','netbios') }
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
    { $_ -in @('dnscloud','dnsgoogle','powerhigh','renewip','bloat','upgrade','recycle','prefetch','winsock','tcpip','cleanmgr') } { return 'high' }
    { $_ -in @('nagle','nettweak','browser','apps','dismcleanup','visual','sfc','dismrestore') } { return 'medium' }
    default { return 'safe' }
  }
}

function Get-HighRiskActionIds {
  param([string[]]$Ids)
  if (-not $Ids) { return @() }
  return @($Ids | Where-Object { (Get-ActionRiskLevel $_) -eq 'high' } | Select-Object -Unique)
}

function Get-UserDataDirectory {
  Split-Path (Get-AppSettingsPath) -Parent
}

function Get-ReversibleActionIds {
  @('powerhigh','powerbal','visual','bgapps','tips','widgets','storage','searchweb','gamebar','gamemode','nettweak','nagle','dnscloud','dnsgoogle')
}

function Get-TweakRegistryMap {
  @{
    visual    = @(@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name='VisualFXSetting' }, @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='EnableTransparency' }, @{ Path='HKCU:\Control Panel\Desktop\WindowMetrics'; Name='MinAnimate' })
    bgapps    = @(@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name='GlobalUserDisabled' })
    tips      = @(@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SystemPaneSuggestionsEnabled' }, @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SoftLandingEnabled' }, @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338389Enabled' })
    widgets   = @(@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarDa' }, @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name='AllowNewsAndInterests' })
    storage   = @(@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'; Name='01' }, @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'; Name='04' }, @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'; Name='08' }, @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'; Name='32' })
    searchweb = @(@{ Path='HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name='DisableSearchBoxSuggestions' })
    gamebar   = @(@{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name='AppCaptureEnabled' }, @{ Path='HKCU:\System\GameConfigStore'; Name='GameDVR_Enabled' }, @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name='AllowGameDVR' })
    gamemode  = @(@{ Path='HKCU:\Software\Microsoft\GameBar'; Name='AutoGameModeEnabled' }, @{ Path='HKCU:\Software\Microsoft\GameBar'; Name='AllowAutoGameMode' })
    nettweak  = @(@{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name='NetworkThrottlingIndex' }, @{ Path='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name='SystemResponsiveness' })
  }
}

function Read-RegSnapshot {
  param([string]$Path, [string]$Name)
  $existed = $false; $value = $null
  if (Test-Path -LiteralPath $Path) {
    try { $value = (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name; $existed = $true } catch {}
  }
  [pscustomobject]@{ Path = $Path; Name = $Name; Existed = $existed; Value = $value }
}

function Save-TweakSnapshot {
  param([string[]]$Ids)
  $hit = @($Ids | Where-Object { (Get-ReversibleActionIds) -contains $_ })
  if ($hit.Count -eq 0) { return }
  $snap = [ordered]@{
    capturedUtc = [DateTime]::UtcNow.ToString('o')
    actions = @($hit)
    powerScheme = $null
    dns = @()
    registry = @()
    nagle = @()
  }
  if ($hit -contains 'powerhigh' -or $hit -contains 'powerbal') {
    $scheme = (& powercfg.exe /getactivescheme 2>&1 | Out-String)
    if ($scheme -match '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}') { $snap.powerScheme = $matches[0] }
  }
  if ($hit -contains 'dnscloud' -or $hit -contains 'dnsgoogle') {
    try {
      if ((Test-CommandAvailable 'Get-NetAdapter') -and (Test-CommandAvailable 'Get-DnsClientServerAddress')) {
        foreach ($adapter in @(Get-NetAdapter -ErrorAction Stop | Where-Object Status -eq 'Up')) {
          $servers = @(Get-DnsClientServerAddress -InterfaceIndex ([int]$adapter.ifIndex) -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.ServerAddresses })
          $snap.dns += [pscustomobject]@{ Index = [int]$adapter.ifIndex; Name = [string]$adapter.Name; Servers = @($servers) }
        }
      }
    } catch { Write-Log ("Snapshot DNS falhou: {0}" -f $_.Exception.Message) 'WARN' }
  }
  $map = Get-TweakRegistryMap
  foreach ($id in $hit) {
    if (-not $map.ContainsKey($id)) { continue }
    foreach ($entry in @($map[$id])) { $snap.registry += Read-RegSnapshot -Path $entry.Path -Name $entry.Name }
  }
  if ($hit -contains 'nagle') {
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object {
      $ack = $null; $delay = $null
      try { $ack = (Get-ItemProperty $_.PSPath -Name TcpAckFrequency -ErrorAction Stop).TcpAckFrequency } catch {}
      try { $delay = (Get-ItemProperty $_.PSPath -Name TCPNoDelay -ErrorAction Stop).TCPNoDelay } catch {}
      $snap.nagle += [pscustomobject]@{ Path = [string]$_.PSPath; TcpAckFrequency = $ack; TCPNoDelay = $delay }
    }
  }
  $path = Join-Path (Get-UserDataDirectory) 'last-tweaks.json'
  ($snap | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $path -Encoding UTF8
  Write-Log ("Snapshot de ajustes salvo ({0} acoes reversíveis)." -f $hit.Count)
}

function Test-AllowedTweakRegistry {
  param([string]$Path, [string]$Name)
  if (-not $Path -or -not $Name) { return $false }
  if ($Path -notmatch '^HK(?:CU|LM):\\') { return $false }
  if ($Name -notmatch '^[A-Za-z0-9_\-]{1,80}$') { return $false }
  $map = Get-TweakRegistryMap
  foreach ($id in $map.Keys) {
    foreach ($entry in @($map[$id])) {
      if ([string]$entry.Path -eq $Path -and [string]$entry.Name -eq $Name) { return $true }
    }
  }
  return $false
}

function Test-NagleRestorePath {
  param([string]$Path)
  if (-not $Path) { return $false }
  return $Path -match '(^|[\\:])SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\\Interfaces\\[0-9a-fA-F\-]{36}$'
}

function Test-Ipv4Address {
  param([string]$Value)
  $parts = @($Value -split '\.')
  if ($parts.Count -ne 4) { return $false }
  foreach ($part in $parts) {
    $n = 0
    if (-not [int]::TryParse($part, [ref]$n)) { return $false }
    if ($n -lt 0 -or $n -gt 255) { return $false }
  }
  return $true
}

function Convert-OptionalDword {
  param($Value)
  if ($null -eq $Value) { return $null }
  $n = 0
  if (-not [int]::TryParse([string]$Value, [ref]$n)) { return $null }
  return [int]$n
}

function Restore-LastTweaks {
  $path = Join-Path (Get-UserDataDirectory) 'last-tweaks.json'
  if (-not (Test-Path -LiteralPath $path)) { throw 'Nao ha ajustes recentes para desfazer.' }
  $snap = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($snap.powerScheme -and [string]$snap.powerScheme -notmatch '^[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {
    Write-Log 'Snapshot ignorou plano de energia com GUID invalido.' 'WARN'
    $snap.powerScheme = $null
  }
  if ($snap.powerScheme) {
    $null = Invoke-ExternalChecked 'powercfg.exe' @('/setactive', [string]$snap.powerScheme) @(0) 'Restaurar plano de energia'
  }
  foreach ($dns in @($snap.dns)) {
    try {
      $idx = 0
      if (-not [int]::TryParse([string]$dns.Index, [ref]$idx) -or $idx -lt 1) { continue }
      $servers = @($dns.Servers | ForEach-Object { [string]$_ } | Where-Object { $_ -and (Test-Ipv4Address $_) })
      if ($servers.Count -gt 0) { Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $servers -ErrorAction Stop }
      else { Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses -ErrorAction Stop }
      Write-Log ("DNS restaurado: {0}" -f $dns.Name)
    } catch { Write-Log ("Falha ao restaurar DNS {0}: {1}" -f $dns.Name, $_.Exception.Message) 'WARN' }
  }
  foreach ($reg in @($snap.registry)) {
    if (-not (Test-AllowedTweakRegistry -Path ([string]$reg.Path) -Name ([string]$reg.Name))) {
      Write-Log ("Snapshot ignorou registro fora da allowlist: {0}\{1}" -f $reg.Path, $reg.Name) 'WARN'
      continue
    }
    try {
      if ($reg.Existed) {
        if (-not (Test-Path -LiteralPath $reg.Path)) { New-Item -Path $reg.Path -Force | Out-Null }
        Set-ItemProperty -LiteralPath $reg.Path -Name $reg.Name -Value $reg.Value -Force -ErrorAction Stop
      } else {
        Remove-ItemProperty -LiteralPath $reg.Path -Name $reg.Name -Force -ErrorAction SilentlyContinue
      }
    } catch { Write-Log ("Falha ao restaurar registro {0}\{1}: {2}" -f $reg.Path, $reg.Name, $_.Exception.Message) 'WARN' }
  }
  foreach ($nagle in @($snap.nagle)) {
    if (-not (Test-NagleRestorePath ([string]$nagle.Path))) {
      Write-Log 'Snapshot ignorou caminho Nagle fora da allowlist.' 'WARN'
      continue
    }
    try {
      $ack = Convert-OptionalDword $nagle.TcpAckFrequency
      $nagleDelay = Convert-OptionalDword $nagle.TCPNoDelay
      if ($null -ne $ack) { Set-ItemProperty -Path $nagle.Path -Name TcpAckFrequency -Value $ack -Type DWord -Force }
      elseif ($null -eq $nagle.TcpAckFrequency) { Remove-ItemProperty -Path $nagle.Path -Name TcpAckFrequency -Force -ErrorAction SilentlyContinue }
      if ($null -ne $nagleDelay) { Set-ItemProperty -Path $nagle.Path -Name TCPNoDelay -Value $nagleDelay -Type DWord -Force }
      elseif ($null -eq $nagle.TCPNoDelay) { Remove-ItemProperty -Path $nagle.Path -Name TCPNoDelay -Force -ErrorAction SilentlyContinue }
    } catch { Write-Log ("Falha ao restaurar Nagle: {0}" -f $_.Exception.Message) 'WARN' }
  }
  $done = Join-Path (Get-UserDataDirectory) 'last-tweaks.restored.json'
  Move-Item -LiteralPath $path -Destination $done -Force
  Write-Log 'Ajustes anteriores restaurados.'
  return $true
}

function Test-TweakSnapshotExists {
  Test-Path -LiteralPath (Join-Path (Get-UserDataDirectory) 'last-tweaks.json')
}

function Add-HealthHistory {
  param([int]$Score)
  $file = Join-Path (Get-UserDataDirectory) 'health.csv'
  $line = '{0},{1}' -f [DateTime]::UtcNow.ToString('o'), $Score
  Add-Content -LiteralPath $file -Value $line -Encoding UTF8
  try {
    $keep = @(Get-Content -LiteralPath $file -Encoding UTF8 | Select-Object -Last 40)
    Set-Content -LiteralPath $file -Value $keep -Encoding UTF8
  } catch {}
}

function Register-WeeklyCleanup {
  param(
    [string]$DaysOfWeek = 'Sunday',
    [string]$At = '10:00',
    [string[]]$Actions
  )
  $task = 'PCOtimizadorProWeekly'
  $payloadBase = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'PC-Otimizador'
  New-Item -ItemType Directory -Path $payloadBase -Force | Out-Null
  & icacls.exe $payloadBase /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)' /setintegritylevel H | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel proteger a pasta do agendamento.' }
  Get-ChildItem -LiteralPath $payloadBase -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'scheduled-*' } | ForEach-Object {
    try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue } catch {}
  }
  $payload = Join-Path $payloadBase ("scheduled-{0}" -f [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $payload -Force | Out-Null
  & icacls.exe $payload /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)' /setintegritylevel H | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel proteger o payload do agendamento.' }
  New-Item -ItemType Directory -Path (Join-Path $payload 'core') -Force | Out-Null
  foreach ($file in @('PC-Otimizador-CLI.ps1','Engine.ps1','VERSION')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $payload $file) -Force -ErrorAction Stop
  }
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'core\presets.json') -Destination (Join-Path $payload 'core\presets.json') -Force -ErrorAction Stop
  $cli = Join-Path $payload 'PC-Otimizador-CLI.ps1'
  $ids = @($Actions | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[a-z][a-z0-9]{0,31}$' })
  if ($ids.Count -eq 0) { $ids = @(Get-PresetIds 'safe') }
  $joined = ($ids -join ',')
  $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$cli`" -Actions `"$joined`" -AutoYes"
  $high = @(Get-HighRiskActionIds -Ids $ids)
  if ($high.Count -gt 0) { $arg += ' -AllowHighRisk' }
  $powershell = Join-Path (Get-WindowsRoot) 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $action = New-ScheduledTaskAction -Execute $powershell -Argument $arg
  $day = 'Sunday'
  try { $day = [DayOfWeek]$DaysOfWeek } catch { $day = [DayOfWeek]::Sunday }
  if ($At -notmatch '^([01]?\d|2[0-3]):[0-5]\d$') { $At = '10:00' }
  $when = Get-Date '10:00'
  try { $when = [DateTime]::ParseExact($At, 'H:mm', [Globalization.CultureInfo]::InvariantCulture) } catch {}
  $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $day -At $when
  $prin = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
  Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Principal $prin -Force | Out-Null
  Write-Log ("{0} ({1} {2:HH:mm}, {3} acoes)" -f (Get-T 'weeklyOk'), $day, $when, $ids.Count)
}

function Unregister-WeeklyCleanup {
  Unregister-ScheduledTask -TaskName 'PCOtimizadorProWeekly' -Confirm:$false -EA SilentlyContinue
  Write-Log (Get-T 'weeklyOff')
}
