$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\Common.ps1')
$context = Get-GuardContext
$xml = New-GuardTaskXml $context
[xml]$document = $xml
$ns = New-Object Xml.XmlNamespaceManager($document.NameTable)
$ns.AddNamespace('t', 'http://schemas.microsoft.com/windows/2004/02/mit/task')
if ($document.SelectNodes('/t:Task/t:Triggers/*', $ns).Count -ne 3) { throw 'Expected event, logon and periodic triggers.' }
if ($document.SelectSingleNode('//t:Exec/t:Arguments', $ns).InnerText -ne '--once') { throw 'Wrong action.' }
if ($document.SelectSingleNode('//t:DisallowStartIfOnBatteries', $ns).InnerText -ne 'false') { throw 'Battery checks disabled.' }
# TASK_VALIDATE_ONLY (1) validates the real Windows schema without installing a task.
# https://learn.microsoft.com/windows/win32/taskschd/taskfolder-registertask
$service = New-Object -ComObject Schedule.Service
$service.Connect()
$folder = $service.GetFolder('\')
$null = $folder.RegisterTask($context.TaskName, $xml, 1, $null, $null, 3, $null)
$escaped = [pscustomobject]@{ Root='C:\Example Folder & Co'; Exe='C:\Example Folder & Co\bin\WifiClashGuard.exe'; Sid=$context.Sid }
[xml]$escapedXml = New-GuardTaskXml $escaped
$escapedNs = New-Object Xml.XmlNamespaceManager($escapedXml.NameTable)
$escapedNs.AddNamespace('t', 'http://schemas.microsoft.com/windows/2004/02/mit/task')
if ($escapedXml.SelectSingleNode('//t:Exec/t:Command', $escapedNs).InnerText -ne $escaped.Exe) { throw 'Path escaping failed.' }
Write-Host 'PASS: task XML, event/logon/timer triggers, battery settings, Windows schema and XML path escaping. No task was installed.'
