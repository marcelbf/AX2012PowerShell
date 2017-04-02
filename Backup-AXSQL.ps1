#Backup-AXSQL
Param(
    $SQLServer,
    $dbBackupPath,
    $AXDatabaseName
    )
try
{
    #Create SQL session
    $SQLsession = New-PSSession -ComputerName $SQLServer

    $BackupFile = $dbBackupPath + $AXDatabaseName + "_" + (Get-Date -Format yyyyMMdd-HHmm) + ".bak"
    icm -Session $SQLsession -ScriptBlock{Backup-SqlDatabase -ServerInstance $args[0] -Database $args[1] -BackupFile $args[2] -Verbose} -ArgumentList $SQLServer, $AXDatabaseName, $BackupFile
}
catch
{
    $output = 'Backup AX database failed ' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message
    Write-Output $output
    break
}

return $BackupFile