$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-ne'A1025645101'){throw "HOST_MISMATCH:$($env:COMPUTERNAME)"}
$tp='C:\Windows\System32\Tasks\ArgosProjectPortal.JBOD.ResponseSender.RO'
$p='C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\R_4165D2AA78E1_20260911165403415_1688d84f.ready'
$s='C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\R_4165D2AA78E1_20260911165403415_1688d84f.ready'
[xml]$x=[IO.File]::ReadAllText($tp)
$ns=New-Object Xml.XmlNamespaceManager($x.NameTable);$ns.AddNamespace('t',$x.DocumentElement.NamespaceURI)
$exec=$x.SelectSingleNode('//t:Actions/t:Exec',$ns)
$procs=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -Property ProcessId,CreationDate,CommandLine|Where-Object{$_.CommandLine-match'ResponseSender'}|ForEach-Object{[ordered]@{pid=[int]$_.ProcessId;created=[string]$_.CreationDate;commandLine=[string]$_.CommandLine}})
[ordered]@{
 schema='argos_ols7_response_sender_observation_v3'
 state='PASS_OLS7_RESPONSE_SENDER_OBSERVATION'
 computerName=$env:COMPUTERNAME
 definition=[ordered]@{exists=$true;enabled=[string]$x.SelectSingleNode('//t:Settings/t:Enabled',$ns).'#text';command=[string]$exec.Command;arguments=[string]$exec.Arguments;workingDirectory=[string]$exec.WorkingDirectory}
 matchingProcesses=$procs
 target=[ordered]@{pending=Test-Path -LiteralPath $p;sent=Test-Path -LiteralPath $s}
 mutationsPerformed=$false
}|ConvertTo-Json -Compress -Depth 6
