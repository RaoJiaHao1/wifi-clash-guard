param([ValidateSet('Enable','Disable','Uninstall','Diagnose','Status')][string]$Action = 'Status')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$context = Get-GuardContext
if ($Action -eq 'Diagnose') {
    $probe = Start-Process -FilePath $context.Exe -ArgumentList '--diagnose' -WindowStyle Hidden -Wait -PassThru
    if ($probe.ExitCode -ne 0) { throw 'Diagnostic failed. See runtime/guard.log (error code only).' }
    Get-Content -LiteralPath (Join-Path $context.Root 'runtime\diagnostics.txt')
    exit 0
}
$task = Assert-GuardOwnership $context
if ($null -eq $task) {
    if ($Action -eq 'Uninstall') { Write-Host 'Not installed.'; exit 0 }
    throw 'Not installed. Run Install.cmd first.'
}
switch ($Action) {
    'Enable' { Enable-ScheduledTask -TaskName $context.TaskName | Out-Null; Start-ScheduledTask -TaskName $context.TaskName; Write-Host 'Enabled.' }
    'Disable' { Disable-ScheduledTask -TaskName $context.TaskName | Out-Null; Stop-ScheduledTask -TaskName $context.TaskName -ErrorAction SilentlyContinue; Write-Host 'Disabled, including logon and network triggers.' }
    'Uninstall' {
        Disable-ScheduledTask -TaskName $context.TaskName | Out-Null
        Stop-ScheduledTask -TaskName $context.TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $context.TaskName -Confirm:$false
        Write-Host 'Uninstalled. Local configuration and logs were kept.'
    }
    'Status' {
        Write-Host ('State: ' + $task.State)
        $info = Get-ScheduledTaskInfo -TaskName $context.TaskName
        Write-Host ('Last result: ' + $info.LastTaskResult)
        Write-Host ('Last run: ' + $info.LastRunTime)
        Write-Host ('Next fallback: ' + $info.NextRunTime)
    }
}
