# Deploy a given model database to PRODUCTION AX
Param(
    $aosServerNames = ('AU11STHAOSPRD01', 'AU11STHAOSPRD02', 'AU11STHAOSPRD03', 'AU11STHAOSPRD04', 'AU11STHAOSPRD05', 'AU11STHAOSPRD06', 'AU11STHAOSPRD07', 'AU11STHAOSPRD08'),
    $primaryAOSName = 'AU11STHAOSPRD07',
    $aosBatchServer = 'AU11STHAOSPRD01',
    $AXServiceName = 'AOS60$01',
    $XppILFolderStr = 'C$\Program Files\Microsoft Dynamics AX\60\Server\DynamicsAX_PROD\bin\XppIL\',
    $SSRSServer = 'AU11STHSSRPRD01',
    $SSRSServiceName = 'ReportServer',
    $LasernetServer = 'AU11STHLSNPRD01',
    $LasernetServiceName = 'Lasernet 7 (PROD:3279)',
    $LasernetPrintCaptureServiceName = 'Lasernet Print Capture 7',
    $SQLServer = 'MHSTHSQLPRD01',
    $AXDatabaseName = 'DynamicsAX_PROD',
    $AXModelName = 'DynamicsAX_PROD_model',
    $dbBackupPath = 'E:\MSSQL\Backup\',
    $ModelToRestore = 'E:\AXDeployments\Restore\DynamicsAX_Staging_model_20180406-1100.bak',
    $NotifyEmail = ('laurencel@sable37.com', 'marcelf@sable37.com', 'alan.mills@steelandtube.co.nz', 'judy.vanschaik@steelandtube.co.nz', 'colin.williams@steelandtube.co.nz', 'matthew.rangiwahia@steelandtube.co.nz')
    )

$ErrorActionPreference = "Stop"

function Send-StepNotification {
    param(
        $emailTo = $(throw "Please specify the email destination"),
        $emailFrom = "AXdeployment@steelandtube.co.nz",
        $smtpServer = "scantomailmx1.steel.steelandtube.co.nz",
        $subject = "AX deployment",
        $atachFile,
        $notification
        )

    if ($atachFile)
    {
        Send-MailMessage -to $emailTo -Subject $subject -Body $notification -SmtpServer $smtpServer -from $emailFrom -BodyAsHtml -Attachments $atachFile
    }
    else
    {
        Send-MailMessage -to $emailTo -Subject $subject -Body $notification -SmtpServer $smtpServer -from $emailFrom -BodyAsHtml 
    }
    #Sleep to send emails in the right order
    Start-Sleep -Seconds 5
    
    Write-Output $notification
}

Send-StepNotification -subject "Starting AX deployment" -notification ("Server " + $env:COMPUTERNAME) -emailTo $NotifyEmail

#region Create log folder
$logFolder = 'C:\Scripts\log\' + (Get-Date -Format 'yyyyMMdd-HHmm')
try
{
    New-Item -ItemType Directory -Force -Path $logFolder
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('Could not create log file ' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}
#endregion

#region Disable batch server
Send-StepNotification -subject "Starting step 'Disable batch server & drain AOS to stop'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm ')  -emailTo $NotifyEmail

#create xpo
$automationAXClass = 'STH_DeploymentAutomation'
$automationXPO = ($logFolder+'\STH_DeploymentAutomation.xpo')


Add-Content -Path $automationXPO -Value @"
Exportfile for AOT version 1.0 or later
Formatversion: 1

***Element: CLS

; Microsoft Dynamics AX Class: STH_DeploymentAutomation unloaded
; --------------------------------------------------------------------------------
    CLSVERSION 1
  
    CLASS #STH_DeploymentAutomation
    PROPERTIES
        Name                #STH_DeploymentAutomation
        Origin              #{791F3C97-A023-4C37-91B7-634F5760372A}
    ENDPROPERTIES
    
    METHODS
        SOURCE #classDeclaration
        #/// <summary>
        #/// This class is used to automate deployment
        #/// </summary>
        #/// <remarks>
        #/// This class is imported by the deployment powershell script
        #/// </remarks>
        #
        #class STH_DeploymentAutomation
        #{
        #}
        ENDSOURCE
        SOURCE #disableAllBatchServer
        #public static void disableAllBatchServer()
        #{
        #    SysServerConfig sysServerConfig;
        #
        #    update_recordSet SysServerConfig
        #        setting enablebatch = NoYes::No;
        #
        #}
        ENDSOURCE
        SOURCE #drainAllServers
        #public static void drainAllServers()
        #{
        #    SysServersDrain     sysServersDrain;
        #    SysServerSessions   serverSessions;
        #    container           serversList;
        #    ;
        #    while select serverSessions
        #        where serverSessions.Status == SysServerStatus::Alive
        #    {
        #        serversList += [[serverSessions.Instance_Name, serverSessions.ServerId]];
        #    }
        #    sysServersDrain = SysServersDrain::newServersList(SysServerStatus::Drain, serversList);
        #    sysServersDrain.run();
        #}
        ENDSOURCE
        SOURCE #enableBatchServer
        #public static void enableBatchServer(ServerId _serverId)
        #{
        #    SysServerConfig sysServerConfig;
        #
        #    ttsBegin;
        #
        #    select forupdate sysServerConfig where sysServerConfig.ServerId like '*'+ _serverId;
        #    if(sysServerConfig.RecId)
        #    {
        #        sysServerConfig.EnableBatch = NoYes::Yes;
        #        sysServerConfig.doUpdate();
        #        ttsCommit;
        #    }
        #    else
        #    {
        #        ttsAbort;
        #        error(strFmt('Could not find server %1',_serverId));
        #    }
        #}
        ENDSOURCE
        SOURCE #killAllSessions
        #public static void killAllSessions()
        #{
        #    SysClientSessions   sysClientSessions;
        #    xSession            xSession;
        #    SessionType         tmpSessionType;
        #
        #    while select sysClientSessions
        #        where sysClientSessions.Status == SessionStatus::Running
        #    {
        #        xSession = new xSession(sysClientSessions.SessionId, true);
        #        tmpSessionType = sysClientSessions.sessionType;
        #        info(strFmt('The session "%1" type "%2" of the user "%3" will be terminated',sysClientSessions.SessionId, enum2str(tmpSessionType), sysClientSessions.userId));
        #        xSession.terminate();
        #    }
        #}
        ENDSOURCE
    ENDMETHODS
    ENDCLASS

***Element: END
"@

#createXML command to importXPO
$xmlImportXPO = $logFolder+'\XpoImport.xml'
$XmlWriter = New-Object System.XMl.XmlTextWriter($xmlImportXPO,$Null)
 
# Set The Formatting
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
 
# Write the XML Decleration
$xmlWriter.WriteStartDocument()
 
# Write Root Element
$xmlWriter.WriteStartElement("AxaptaAutoRun")
 
# Write the Document    
$xmlWriter.WriteAttributeString("exitWhenDone","True")
$xmlWriter.WriteAttributeString("version","6.0")
$xmlWriter.WriteAttributeString("logFile", ($logFolder + '\XpoImport.log'))

$xmlWriter.WriteStartElement("XpoImport")
$XmlWriter.WriteAttributeString("file",$automationXPO)
$xmlWriter.WriteEndElement # <-- XpoImport
 
# Write Close Tag for Root Element
$xmlWriter.WriteEndElement # <-- Closing RootElement
 
# End the XML Document
$xmlWriter.WriteEndDocument()
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush
$xmlWriter.Close()

#importXPO
$startUpCommand = '-StartUpCmd=Autorun_'+$xmlImportXPO
& 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin\Ax32.exe' $startUpCommand | Out-Null

#Stop batch server
$xmlAXRun = $logFolder+'\RunStopBatch.xml'
$XmlWriter = New-Object System.XMl.XmlTextWriter($xmlAXRun,$Null)
 
# Set The Formatting
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
 
# Write the XML Decleration
$xmlWriter.WriteStartDocument()
 
# Write Root Element
$xmlWriter.WriteStartElement("AxaptaAutoRun")
 
# Write the Document    
$xmlWriter.WriteAttributeString("exitWhenDone","True")
$xmlWriter.WriteAttributeString("version","6.0")
$xmlWriter.WriteAttributeString("logFile", ($xmlAXRun + '.log'))

$xmlWriter.WriteStartElement("Run")
$XmlWriter.WriteAttributeString("type","Class")
$XmlWriter.WriteAttributeString("name",$automationAXClass)
$XmlWriter.WriteAttributeString("method","disableAllBatchServer")
$xmlWriter.WriteEndElement # <-- Run
 
# Write Close Tag for Root Element
$xmlWriter.WriteEndElement # <-- Closing RootElement
 
# End the XML Document
$xmlWriter.WriteEndDocument()
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush
$xmlWriter.Close()

#Stop Batch server
$startUpCommand = '-StartUpCmd=Autorun_'+$xmlAXRun
& 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin\Ax32.exe' $startUpCommand | Out-Null

$drainDate = Get-Date -Format 'dd/MM/yyyy'
$drainTime = Get-Date -Format 'HH:mm'
#Send-StepNotification -subject "Step complete 'Disable batch server & drain AOS to stop'" -notification ('date:'+$drainDate+' time:'+$drainTime) -emailTo $NotifyEmail
#endregion

#region Stop all AOS in parallel
Send-StepNotification -subject "Starting step 'Stop ALL AOS for PROD'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

try
{
    $servicesList = New-Object System.Collections.ArrayList

    foreach ($AOSServer in $aosServerNames) 
    {
        $service = Get-Service -ComputerName $AOSServer $AXServiceName
        $servicesList.Add($service) | Out-Null

        if ($service.Status -eq "Stopped")
        {
            continue
        }

        if ($service.Status -eq "Running" -and $service.CanStop -eq $True)
        {                                    
            
            Write-Output "Stopping AOS in $AOSServer"            
            $service.Stop()
        }        
        else
        {
            throw "Could not stop AOS in $AOSServer"
        }                 
    }

    foreach ($service in $servicesList)
    {        
        Write-Output "Waiting for server $($service.MachineName) to stop"
        $service.WaitForStatus("stopped")
        Write-Output "AOS in' $($service.MachineName) is stopped"
    }
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('Could not stop AOS' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}

$stopAllAOSDate = Get-Date -Format 'dd/MM/yyyy'
$stopAllAOSTime = Get-Date -Format 'HH:mm'

#Send-StepNotification -subject "Step complete 'Stop ALL AOS for PROD'" -notification ('date:'+$stopAllAOSDate+' time:'+$stopAllAOSTime) -emailTo $NotifyEmail
#endregion

#region SQL AX DB backup
Send-StepNotification -subject "Starting step 'Take backup of target model and database'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

try
{
    #Create SQL session
    $SQLsession = New-PSSession -ComputerName $SQLServer

    $BackupFile = $dbBackupPath + $AXDatabaseName + "_" + (Get-Date -Format yyyyMMdd-HHmm) + ".bak"
    Invoke-Command -Session $SQLsession -ScriptBlock{Backup-SqlDatabase -ServerInstance $args[0] -Database $args[1] -BackupFile $args[2] -Verbose} -ArgumentList $SQLServer, $AXDatabaseName, $BackupFile
}
catch
{
    Send-StepNotification -notification ('Backup AX database failed ' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}

$AXDBBkpDate = Get-Date -Format 'dd/MM/yyyy'
$AXDBBkpTime = Get-Date -Format 'HH:mm'
$AXDBBkpDetail = 'Backup file:' + $BackupFile + ' server' + $SQLServer

#Send-StepNotification -subject "Step complete 'Take backup of target database'" -notification ('date:'+$AXDBBkpDate+' time:'+$AXDBBkpTime + ' ' + $AXDBBkpDetail) -emailTo $NotifyEmail
#endregion

#region SQL AX MODEL backup
Send-StepNotification -subject "Starting step 'Take backup of target model'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

$BackupFile = $dbBackupPath + $AXModelName + "_" + (Get-Date -Format yyyyMMdd-HHmm) + ".bak"
try
{
    Invoke-Command -Session $SQLsession -ScriptBlock{Backup-SqlDatabase -ServerInstance $args[0] -Database $args[1] -BackupFile $args[2] -Verbose} -ArgumentList $SQLServer, $AXModelName, $BackupFile
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('SQL backup error ' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}

$AXModelBkpDate = Get-Date -Format 'dd/MM/yyyy'
$AXModelBkpTime = Get-Date -Format 'HH:mm'
$AXModelBkpDetail = 'Backup file:' + $BackupFile + ' server' + $SQLServer

Send-StepNotification -subject "Step complete 'Take backup of target model'" -notification ('date:'+$AXModelBkpDate+' time:'+$AXModelBkpTime + ' ' + $AXModelBkpDetail) -emailTo $NotifyEmail
#endregion

#region SQL AX MODEL restore
Send-StepNotification -subject "Starting step 'Restore back up of Staging model database over target model database'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

try
{
    Invoke-Command -Session $SQLsession -ScriptBlock{Restore-SqlDatabase -ServerInstance $args[0] -Database $args[1] -BackupFile $args[2] -Replace -Verbose} -ArgumentList $SQLServer, $AXModelName, $ModelToRestore
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('SQL restore error' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}

$AXRestoreBkpDate = Get-Date -Format 'dd/MM/yyyy'
$AXRestoreBkpTime = Get-Date -Format 'HH:mm'
$AXRestoreBkpDetail = 'Restored from file:' + $ModelToRestore + ' server' + $SQLServer

#Send-StepNotification -subject "Step complete 'Restore back up of Staging model database over target model database'" -notification ('date:'+$AXRestoreBkpDate+' time:'+$AXRestoreBkpTime + ' ' + $AXRestoreBkpDetail) -emailTo $NotifyEmail
#endregion

#region Clean XppIL folders on all AOSes
Send-StepNotification -subject "Starting step 'Clean XppIL folders on all AOSes'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

try
{
    foreach ($AOSServer in $aosServerNames)
    {
        $currentAOSXppILFolderStr = "\\" + $AOSServer + "\" + $XppILFolderStr
        $currentAOSXppILFolderStrDeleteFilter = $currentAOSXppILFolderStr + "*"

        Remove-Item $currentAOSXppILFolderStrDeleteFilter -Force -Recurse -ErrorAction SilentlyContinue -Verbose
    }
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('Clean XppIL folders on all AOSes ' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}

$CleanXppIlDate = Get-Date -Format 'dd/MM/yyyy'
$CleanXppIlTime = Get-Date -Format 'HH:mm'

#Send-StepNotification -subject "Step complete 'Clean XppIL folders on all AOSes'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail
#endregion

#region Truncate SYSXPPASSEMBLY table within the model database
Send-StepNotification -subject "Starting step 'Truncate SYSXPPASSEMBLY CIL system table'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

try
{
    $SQLCmdTruncateCILTable = "DELETE FROM [dbo].[SYSXPPASSEMBLY]"

    icm -Session $SQLsession -ScriptBlock{Invoke-Sqlcmd -ServerInstance $args[0] -Database $args[1] -Query $args[2] -Verbose} -ArgumentList $SQLServer, $AXModelName, $SQLCmdTruncateCILTable
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('Truncate SYSXPPASSEMBLY CIL system table' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}

#Send-StepNotification -subject "Step complete 'Truncate SYSXPPASSEMBLY CIL system table'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail
#endregion

#region Truncate SYSCLIENTSESSIONS table within AX database
Send-StepNotification -subject "Starting step 'Truncate SYSCLIENTSESSIONS table'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

try
{
    $SQLCmdTruncateSYSCLIENTSESSIONSTable = "TRUNCATE TABLE [dbo].[SYSCLIENTSESSIONS]"

    Invoke-Command -Session $SQLsession -ScriptBlock{Invoke-Sqlcmd -ServerInstance $args[0] -Database $args[1] -Query $args[2] -Verbose} `
	    -ArgumentList $SQLServer, $AXDatabaseName, $SQLCmdTruncateSYSCLIENTSESSIONSTable
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('Truncate SYSCLIENTSESSIONS table' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}
#endregion

#region Clear SQL plan cache
Send-StepNotification -subject "Starting step 'Clear SQL plan cache'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail
try
{
    $SQLCmdDBCCFREEPROCCACHE = "DBCC FREEPROCCACHE"

    Invoke-Command -Session $SQLsession -ScriptBlock{Invoke-Sqlcmd -ServerInstance $args[0] -Database $args[1] -Query $args[2] -Verbose} `
	    -ArgumentList $SQLServer, $AXDatabaseName, $SQLCmdDBCCFREEPROCCACHE
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('Clear SQL plan cache' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}
#endregion

#region Model optimization
Import-module "C:\Program Files\Microsoft Dynamics AX\60\ManagementUtilities\Microsoft.Dynamics.ManagementUtilities.ps1"
 
$targetserver = $SQLServer
$targetdb = $AXModelName
$targetAOSAccount = 'steel\svc.dax.live.aos'
 
Initialize-AXModelStore -Server $targetserver -Database $targetdb
Grant-AXModelStore -Server $targetserver -Database $targetdb -AOSAccount $targetAOSAccount
Optimize-AXModelStore -Server $targetserver -Database $targetdb

& 'C:\Program Files\Microsoft Dynamics AX\60\ManagementUtilities\axutil.exe' 'refreshrolecache'

#endregion

#region Start main AOS
Send-StepNotification -subject "Starting step 'Start primary AOS'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

try
{
    Get-Service -ComputerName $primaryAOSName $AXServiceName | Start-Service 
}
catch
{
    Send-StepNotification -subject 'Deployment failed' -notification ('Could not start AOS ' + (Get-Date -Format 'dd/MM/yyyy - HH:mm ') + $_.Exception.Message) -emailTo $NotifyEmail 
    break
}

$startPrimaryAOSDate = Get-Date -Format 'dd/MM/yyyy'
$startPrimaryAOSTime = Get-Date -Format 'HH:mm'
$startPrimaryAOSDetail = 'AOS name:' + $primaryAOSName + 'service name:'+$AXServiceName

#Send-StepNotification -subject "Step complete 'Start primary AOS'" -notification ('date:'+$startPrimaryAOSDate+' time:'+$startPrimaryAOSTime + ' ' + $startPrimaryAOSDetail) -emailTo $NotifyEmail
#endregion

#region AX client - Generate CIL
Send-StepNotification -subject "Starting step 'Run full CIL'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

$xmlAXRun = $logFolder+'\CompileIl.xml'
$XmlWriter = New-Object System.XMl.XmlTextWriter($xmlAXRun,$Null)
 
# Set The Formatting
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
 
# Write the XML Decleration
$xmlWriter.WriteStartDocument()
 
# Write Root Element
$xmlWriter.WriteStartElement("AxaptaAutoRun")
 
# Write the Document    
$xmlWriter.WriteAttributeString("exitWhenDone","True")
$xmlWriter.WriteAttributeString("version","6.0")
$xmlWriter.WriteAttributeString("logFile", ($xmlAXRun + '.txt'))

$xmlWriter.WriteStartElement("CompileIL")
$XmlWriter.WriteAttributeString("incremental","false")

$xmlWriter.WriteEndElement # <-- Run
 
# Write Close Tag for Root Element
$xmlWriter.WriteEndElement # <-- Closing RootElement
 
# End the XML Document
$xmlWriter.WriteEndDocument()
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush
$xmlWriter.Close()

#AX client - Generate full CIL
$startUpCommand = '-StartUpCmd=Autorun_'+$xmlAXRun
& 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin\Ax32.exe' $startUpCommand | Out-Null

$generateFullCilDate = Get-Date -Format 'dd/MM/yyyy'
$generateFullCilTime = Get-Date -Format 'HH:mm'
$generateFullCilDetail = 'Log file:' + $xmlAXRun + '.txt'

Send-StepNotification -subject "Step complete 'Run full CIL'" -notification ('date:'+$generateFullCilDate+' time:'+$generateFullCilTime + ' ' + $generateFullCilDetail) -emailTo $NotifyEmail -atachFile ($xmlAXRun + '.txt')
#endregion

#region AX client - Synchronize
Send-StepNotification -subject "Starting step 'Run full Synchronisation'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

$xmlAXRun = $logFolder+'\Sync.xml'
$XmlWriter = New-Object System.XMl.XmlTextWriter($xmlAXRun,$Null)
 
# Set The Formatting
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
 
# Write the XML Decleration
$xmlWriter.WriteStartDocument()
 
# Write Root Element
$xmlWriter.WriteStartElement("AxaptaAutoRun")
 
# Write the Document    
$xmlWriter.WriteAttributeString("exitWhenDone","True")
$xmlWriter.WriteAttributeString("version","6.0")
$xmlWriter.WriteAttributeString("logFile", ($xmlAXRun + '.txt'))

$xmlWriter.WriteStartElement("Synchronize")
$xmlWriter.WriteEndElement # <-- Run
 
# Write Close Tag for Root Element
$xmlWriter.WriteEndElement # <-- Closing RootElement
 
# End the XML Document
$xmlWriter.WriteEndDocument()
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush
$xmlWriter.Close()

$startUpCommand = '-StartUpCmd=Autorun_'+$xmlAXRun
& 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin\Ax32.exe' $startUpCommand | Out-Null

$runFullSyncDate = Get-Date -Format 'dd/MM/yyyy'
$runFullSyncTime = Get-Date -Format 'HH:mm'
$runFullSyncDetail = 'Log file:' + $xmlAXRun + '.txt'

Send-StepNotification -subject "Step complete 'Run full Synchronisation'" -notification ('date:'+$runFullSyncDate+' time:'+$runFullSyncTime + ' ' + $runFullSyncDetail) -emailTo $NotifyEmail -atachFile ($xmlAXRun + '.txt')
#endregion

#region Start all AOS
Send-StepNotification -subject "Starting step 'Restart all AOS for the target environment'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

#Stop main AOS
Get-Service -ComputerName $primaryAOSName $AXServiceName | Stop-Service

#Start all AOS
foreach ($AOSServer in $aosServerNames) 
{
    Get-Service -ComputerName $AOSServer $AXServiceName | Start-Service -Verbose 
}

$restartAllAOSDate = Get-Date -Format 'dd/MM/yyyy'
$restartAllAOSTime = Get-Date -Format 'HH:mm'
$restartAllAOSDetail = 'Application object servers' + $aosServerNames

Send-StepNotification -subject "Step complete 'Restart all AOS for the target environment'" -notification ('date:'+$restartAllAOSDate+' time:'+$restartAllAOSTime + ' ' + $restartAllAOSDetail) -emailTo $NotifyEmail
#endregion

#region Restart SSRS
Send-StepNotification -subject "Starting step 'Restart SSRS reporting server services'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

Get-Service -ComputerName $SSRSServer $SSRSServiceName | Restart-Service

Send-StepNotification -subject "Step complete 'Restart SSRS reporting server services'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail
#endregion

#region Restart Lasernet service
Send-StepNotification -subject "Starting step 'Restart Lasernet reporting server services'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

Get-Service -ComputerName $LasernetServer $LasernetServiceName | Restart-Service
Get-Service -ComputerName $LasernetServer $LasernetPrintCaptureServiceName | Restart-Service

Send-StepNotification -subject "Step complete 'Restart Lasernet reporting server services'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail
#endregion

#region Enable batch server
Send-StepNotification -subject "Starting step 'Enable batch server'" -notification (Get-Date -Format 'dd/MM/yyyy - HH:mm') -emailTo $NotifyEmail

#createXML command to importXPO
$xmlImportXPO = $logFolder+'\XpoImport2.xml'
$XmlWriter = New-Object System.XMl.XmlTextWriter($xmlImportXPO,$Null)
 
# Set The Formatting
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
 
# Write the XML Decleration
$xmlWriter.WriteStartDocument()
 
# Write Root Element
$xmlWriter.WriteStartElement("AxaptaAutoRun")
 
# Write the Document    
$xmlWriter.WriteAttributeString("exitWhenDone","True")
$xmlWriter.WriteAttributeString("version","6.0")
$xmlWriter.WriteAttributeString("logFile", ($logFolder + '\XpoImport2.log'))

$xmlWriter.WriteStartElement("XpoImport")
$XmlWriter.WriteAttributeString("file",$automationXPO)
$xmlWriter.WriteEndElement # <-- XpoImport
 
# Write Close Tag for Root Element
$xmlWriter.WriteEndElement # <-- Closing RootElement
 
# End the XML Document
$xmlWriter.WriteEndDocument()
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush
$xmlWriter.Close()

#importXPO
$startUpCommand = '-StartUpCmd=Autorun_'+$xmlImportXPO
& 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin\Ax32.exe' $startUpCommand | Out-Null

#Start batch server
$xmlAXRun = $logFolder+'\RunStartBatch.xml'
$XmlWriter = New-Object System.XMl.XmlTextWriter($xmlAXRun,$Null)
 
# Set The Formatting
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
 
# Write the XML Decleration
$xmlWriter.WriteStartDocument()
 
# Write Root Element
$xmlWriter.WriteStartElement("AxaptaAutoRun")
 
# Write the Document    
$xmlWriter.WriteAttributeString("exitWhenDone","True")
$xmlWriter.WriteAttributeString("version","6.0")
$xmlWriter.WriteAttributeString("logFile", ($xmlAXRun + '.log'))

$xmlWriter.WriteStartElement("Run")
$XmlWriter.WriteAttributeString("type","Class")
$XmlWriter.WriteAttributeString("name",$automationAXClass)
$XmlWriter.WriteAttributeString("method","enableBatchServer")
$XmlWriter.WriteAttributeString("parameters","'"+$aosBatchServer+"'")
$xmlWriter.WriteEndElement # <-- Run
 
# Write Close Tag for Root Element
$xmlWriter.WriteEndElement # <-- Closing RootElement
 
# End the XML Document
$xmlWriter.WriteEndDocument()
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush
$xmlWriter.Close()

#Enable Batch server
$startUpCommand = '-StartUpCmd=Autorun_'+$xmlAXRun
& 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin\Ax32.exe' $startUpCommand | Out-Null

$enableBatchAOSDate = Get-Date -Format 'dd/MM/yyyy'
$enableBatchAOSTime = Get-Date -Format 'HH:mm'
$enableBatchAOSDetail = 'Batch server enabled:' + $aosBatchServer

Send-StepNotification -subject "Step complete 'Enable batch server'" -notification ('date:'+$enableBatchAOSDate+' time:'+$enableBatchAOSTime + ' ' + $enableBatchDetail) -emailTo $NotifyEmail

#endregion

#region Final report HTML
$finalReport = @"
<html>
  <head>
    <style>
      table, th, td {
        border: 1px solid black;
        border-collapse: collapse;
      }
      th, td {
        padding: 5px;
      }
      th {
        text-align: left;
      }
    </style>
  </head>
  <body>
    <table style="width:100%">
      <caption><b>AX deployment checklist</b></caption>      
      <tr>
        <td><b>Item / task</b></td>
        <td><b>Date</b></td>
        <td><b>Time</b></td>
        <td><b>Details</b></td>
      </tr>
      <tr>
        <td>Disable batch server & drain AOS to stop</td>
        <td>$drainDate</td>
        <td>$drainTime</td>
        <td>$drainDetails</td>
      </tr>
      <tr>
        <td>Stop ALL AOS for PROD</td>
        <td>$stopAllAOSDate</td>
        <td>$stopAllAOSTime</td>
        <td>$stopAllAOSDetails</td>
      </tr>
      <tr>
        <td>Take backup of target database</td>
        <td>$AXDBBkpDate</td>
        <td>$AXDBBkpTime</td>
        <td>$AXDBBkpDetail</td>
      </tr>
      <tr>
        <td>Take backup of target model</td>
        <td>$AXModelBkpDate</td>
        <td>$AXModelBkpTime</td>
        <td>$AXModelBkpDetail</td>
      </tr>
      <tr>
        <td>Restore back up of Staging model database over target model database</td>
        <td>$AXRestoreBkpDate</td>
        <td>$AXRestoreBkpTime</td>
        <td>$AXRestoreBkpDetail</td>
      </tr>
      <tr>
        <td>Clean XppIL folders on all AOSes</td>
        <td>$CleanXppIlDate</td>
        <td>$CleanXppIlTime</td>
        <td></td>
      </tr>
      <tr>
        <td>Start primary AOS</td>
        <td>$startPrimaryAOSDate</td>
        <td>$startPrimaryAOSTime</td>
        <td>$startPrimaryAOSDetail</td>
      </tr>  
      <tr>
        <td>Run full CIL</td>
        <td>$generateFullCilDate</td>
        <td>$generateFullCilTime</td>
        <td>$generateFullCilDetail</td>
      </tr>
      <tr>
        <td>Run full Synchronisation</td>
        <td>$runFullSyncDate</td>
        <td>$runFullSyncTime</td>
        <td>$runFullSyncDetail</td>
      </tr>  
      <tr>
        <td>Restart all AOS for the target environment</td>
        <td>$restartAllAOSDate</td>
        <td>$restartAllAOSTime</td>
        <td>$restartAllAOSDetail</td>
      </tr>
      <tr>
        <td>Enable batch server</td>
        <td>$enableBatchAOSDate</td>
        <td>$enableBatchAOSTime</td>
        <td>$enableBatchAOSDetail</td>
      </tr>
    </table>
  </body>
</html>
"@
#endregion

Send-StepNotification -subject "Deployment complete" -notification $finalReport -emailTo $NotifyEmail
