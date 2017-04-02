#SQL AX MODEL restore
Param(
    $SQLServer,
    $AXDatabaseName,
    $dbBackupFileToRestore    
    )
try
{
    $SQLsession = New-PSSession -ComputerName $SQLServer
    icm -Session $SQLsession -ScriptBlock{Restore-SqlDatabase -ServerInstance $args[0] -Database $args[1] -BackupFile $args[2] -Replace -Verbose} -ArgumentList $SQLServer, $AXDatabaseName, $dbBackupFileToRestore
}
catch
{
    $output = 'SQL restore error' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message
    Write-Output $output
    break
}
