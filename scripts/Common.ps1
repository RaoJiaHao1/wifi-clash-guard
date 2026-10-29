$ErrorActionPreference = 'Stop'
function Get-GuardContext {
    $root = Split-Path -Parent $PSScriptRoot
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $id = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($sid)))).Replace('-', '').Substring(0, 12) }
    finally { $sha.Dispose() }
    [pscustomobject]@{ Root=$root; Sid=$sid; TaskName="WifiClashGuard-$id"; Exe=(Join-Path $root 'bin\WifiClashGuard.exe') }
}
function Assert-GuardOwnership($context) {
    $task = Get-ScheduledTask -TaskName $context.TaskName -ErrorAction SilentlyContinue
    if ($null -ne $task) {
        if ($task.Description -ne 'WifiClashGuard managed task' -or @($task.Actions).Count -ne 1 -or $task.Actions[0].Execute -ne $context.Exe) {
            throw 'A task for another installation already exists. Uninstall it from its original folder first.'
        }
    }
    return $task
}
function New-GuardTaskXml($context) {
    $exe = [Security.SecurityElement]::Escape($context.Exe)
    $directory = [Security.SecurityElement]::Escape($context.Root)
    $sid = $context.Sid
    $start = (Get-Date).AddMinutes(5).ToString('yyyy-MM-ddTHH:mm:sszzz')
    $query = '<QueryList><Query Id="0" Path="Microsoft-Windows-WLAN-AutoConfig/Operational"><Select Path="Microsoft-Windows-WLAN-AutoConfig/Operational">*[System[EventID=8001]]</Select></Query></QueryList>'
    $subscription = [Security.SecurityElement]::Escape($query)
    return @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>WifiClashGuard managed task</Description></RegistrationInfo>
  <Triggers>
    <EventTrigger><Enabled>true</Enabled><Subscription>$subscription</Subscription><Delay>PT1S</Delay></EventTrigger>
    <TimeTrigger><Repetition><Interval>PT5M</Interval><StopAtDurationEnd>false</StopAtDurationEnd></Repetition><StartBoundary>$start</StartBoundary><Enabled>true</Enabled></TimeTrigger>
    <LogonTrigger><Enabled>true</Enabled><UserId>$sid</UserId><Delay>PT15S</Delay></LogonTrigger>
  </Triggers>
  <Principals><Principal id="User"><UserId>$sid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable><RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><Hidden>false</Hidden><RunOnlyIfIdle>false</RunOnlyIfIdle><WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit><Priority>7</Priority>
  </Settings>
  <Actions Context="User"><Exec><Command>$exe</Command><Arguments>--once</Arguments><WorkingDirectory>$directory</WorkingDirectory></Exec></Actions>
</Task>
"@
}
