#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$disks = @(Get-CimInstance Win32_DiskDrive | ForEach-Object {
  [ordered]@{ interface = $_.InterfaceType; media = $_.MediaType; sizeGB = [math]::Round($_.Size / 1GB, 0) }
})
$adapters = @(Get-CimInstance Win32_NetworkAdapter -Filter 'PhysicalAdapter=True' | ForEach-Object {
  [ordered]@{ type = $_.AdapterType; enabled = [bool]$_.NetEnabled }
})
$contract = [ordered]@{
  schema = 1; appVersion = $version; timestampUtc = [DateTime]::UtcNow.ToString('o')
  os = [ordered]@{ caption=$os.Caption; version=$os.Version; build=$os.BuildNumber; architecture=$os.OSArchitecture }
  cpu = [ordered]@{ architecture=$cpu.Architecture; cores=$cpu.NumberOfCores; threads=$cpu.NumberOfLogicalProcessors }
  disks = $disks; networkAdapters = $adapters
  privacy = 'No serial numbers, usernames, hostnames, IPs or device IDs.'
}
$out = Join-Path $root 'hardware-contract.json'
$contract | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $out -Encoding UTF8
Get-Content $out
