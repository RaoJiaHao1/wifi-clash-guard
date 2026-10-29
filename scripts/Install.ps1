$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$context = Get-GuardContext
$config = Join-Path $context.Root 'config.json'
if (-not (Test-Path -LiteralPath $config)) {
    Copy-Item -LiteralPath (Join-Path $context.Root 'config.example.json') -Destination $config
    throw 'Created config.json. Set wifiName, then run Install.cmd again.'
}
if (-not (Test-Path -LiteralPath $context.Exe)) { & (Join-Path $PSScriptRoot 'Build.ps1') }
$validation = Start-Process -FilePath $context.Exe -ArgumentList '--validate' -WindowStyle Hidden -Wait -PassThru
if ($validation.ExitCode -ne 0) { throw 'Invalid config.json. Set wifiName to your Wi-Fi name (or prefix), then retry.' }
$null = Assert-GuardOwnership $context
$channel = Get-WinEvent -ListLog 'Microsoft-Windows-WLAN-AutoConfig/Operational'
if (-not $channel.IsEnabled) { throw 'Enable the WLAN-AutoConfig/Operational log in Event Viewer before installing.' }
$xml = New-GuardTaskXml $context
Register-ScheduledTask -TaskName $context.TaskName -Xml $xml -Force | Out-Null
Start-ScheduledTask -TaskName $context.TaskName
Write-Host 'Installed. Wi-Fi connection, logon and 5-minute fallback checks are enabled.'
Write-Host 'Keep this folder in place. Edit config.json any time; no reinstall is needed.'
