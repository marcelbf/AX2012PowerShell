#Import-AXAutomationHelper
Param(
    $xpoFolder = $env:temp,
    $axcFile = ''      
    )

$automationAXClass = 'STH_DeploymentAutomation'
$automationXPO = ($xpoFolder +'\STH_DeploymentAutomation.xpo')

if (Test-Path $automationXPO -PathType Leaf)
{
    del $automationXPO
}

#xpo file with automation Class
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
      SOURCE #updateEPSettings
        #/// <summary>
        #/// Update the Enterprise Portal websites.
        #/// </summary>
        #/// <remarks>
        #/// Harded coded PROD
        #/// </remarks>
        #public static void updateEPSettings()
        #{
        #    EPWebSiteParameters EPParameters;
        #
        #    boolean validate()
        #    {
        #        boolean ret;
        #        Microsoft.Dynamics.Framework.Deployment.Portal.EPWeb epWeb;
        #        SysEPDeployment epDeployment = null;
        #        guid siteId;
        #        boolean anonymousAccess;
        #        try
        #        {
        #            epDeployment = new SysEPDeployment();
        #            epWeb = epDeployment.getEPWeb(EPParameters.InternalUrl);
        #            siteId = epWeb.get_SiteId();
        #            epDeployment.dispose();
        #            epDeployment = null;
        #        }
        #        catch(Exception::Error)
        #        {
        #            if( epDeployment != null )
        #            {
        #                epDeployment.dispose();
        #                epDeployment = null;
        #            }
        #
        #            return false;
        #        }
        #
        #        if(siteId)
        #        {
        #            if(!EPParameters.RecId)
        #            {
        #                EPParameters.SiteId = siteId;
        #                anonymousAccess = epWeb.get_AnonymousAccess();
        #                if(anonymousAccess)
        #                {
        #                    EPParameters.AnonymousAccess = NoYes::Yes;
        #                }
        #                else
        #                {
        #                    EPParameters.AnonymousAccess = NoYes::No;
        #                }
        #
        #                EPParameters.ExternalUrl = EPParameters.InternalUrl;
        #
        #                if( SysEPDeployment::isMOSSInstalled() )
        #                {
        #                    EPParameters.SiteInstallationType = SharePointInstallationType::MOSS;
        #                }
        #                else
        #                {
        #                    EPParameters.SiteInstallationType = SharePointInstallationType::WSS;
        #                }
        #            }
        #            else
        #            {
        #                //check if this is the same site
        #                if(EPParameters.SiteId != siteId)
        #                {
        #                    Box::info("@SYS98620");
        #                    return false;
        #                }
        #            }
        #
        #        }
        #
        #        return ret;
        #    }
        #
        #    delete_from EPParameters;
        #
        #    EPParameters.initValue();
        #    EPParameters.InternalUrl = 'http://au11sthshpprd02:32843/sites/DynamicsAx';
        #    validate();
        #    EPParameters.Type = WebSiteType::Full;
        #
        #    EPParameters.insert();
        #
        #}
      ENDSOURCE
      SOURCE #classDeclaration
        #/// <summary>
        #/// This class is used to automate deployment
        #/// </summary>
        #/// <remarks>
        #/// This class is imported by the deployment powershell script
        #/// </remarks>
        #class STH_DeploymentAutomation
        #{
        #}
      ENDSOURCE
      SOURCE #disableAllBatchServer
        #/// <summary>
        #/// Disable all batch servers.
        #/// </summary>
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
        #/// <summary>
        #/// Prepare all AOS to stop.
        #/// </summary>
        #/// <remarks>
        #/// After execution AOS won't accept new connections until restarted.
        #/// </remarks>
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
        #/// <summary>
        #/// Enable a given AOS as batch server.
        #/// </summary>
        #/// <param name="_serverId">
        #/// A given server ID.
        #/// </param>
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
        #/// <summary>
        #/// Kill all sessions.
        #/// </summary>
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
      SOURCE #updateSSRSSettings
        #/// <summary>
        #/// Update the SSRS settings.
        #/// </summary>
        #/// <remarks>
        #/// Harded coded PROD servers.
        #/// </remarks>
        #public static void updateSSRSSettings()
        #{
        #    SRSServers  srsServers;
        #
        #    delete_from srsServers;
        #
        #    srsServers.AOSId = '01@AU11STHAOSPRD01';
        #    srsServers.AxaptaReportFolder = 'DynamicsAX';
        #    srsServers.ConfigurationId = '01@AU11STHAOSPRD01';
        #    srsServers.IsDefaultReportLibraryServer = NoYes::Yes;
        #    srsServers.ReportManagerUrl = 'http://mhsthsqlprd01/Reports';
        #    srsServers.ServerId = 'MHSTHSQLPRD01';
        #    srsServers.ServerInstance = 'MSSQLSERVER';
        #    srsServers.ServerUrl = 'http://mhsthsqlprd01/ReportServer';
        #
        #    srsServers.insert();
        #
        #    srsServers.AOSId = '01@AU11STHAOSPRD02';
        #    srsServers.AxaptaReportFolder = 'DynamicsAX';
        #    srsServers.ConfigurationId = '01@AU11STHAOSPRD02';
        #    srsServers.IsDefaultReportLibraryServer = NoYes::Yes;
        #    srsServers.ReportManagerUrl = 'http://mhsthsqlprd01/Reports';
        #    srsServers.ServerId = 'MHSTHSQLPRD01';
        #    srsServers.ServerInstance = 'MSSQLSERVER';
        #    srsServers.ServerUrl = 'http://mhsthsqlprd01/ReportServer';
        #
        #    srsServers.insert();
        #
        #    srsServers.AOSId = '01@AU11STHAOSPRD03';
        #    srsServers.AxaptaReportFolder = 'DynamicsAX';
        #    srsServers.ConfigurationId = '01@AU11STHAOSPRD03';
        #    srsServers.IsDefaultReportLibraryServer = NoYes::Yes;
        #    srsServers.ReportManagerUrl = 'http://mhsthsqlprd01/Reports';
        #    srsServers.ServerId = 'MHSTHSQLPRD01';
        #    srsServers.ServerInstance = 'MSSQLSERVER';
        #    srsServers.ServerUrl = 'http://mhsthsqlprd01/ReportServer';
        #
        #    srsServers.insert();
        #
        #    srsServers.AOSId = '01@AU11STHAOSPRD04';
        #    srsServers.AxaptaReportFolder = 'DynamicsAX';
        #    srsServers.ConfigurationId = '01@AU11STHAOSPRD04';
        #    srsServers.IsDefaultReportLibraryServer = NoYes::Yes;
        #    srsServers.ReportManagerUrl = 'http://mhsthsqlprd01/Reports';
        #    srsServers.ServerId = 'MHSTHSQLPRD01';
        #    srsServers.ServerInstance = 'MSSQLSERVER';
        #    srsServers.ServerUrl = 'http://mhsthsqlprd01/ReportServer';
        #
        #    srsServers.insert();
        #
        #    srsServers.AOSId = '01@AU11STHAOSPRD05';
        #    srsServers.AxaptaReportFolder = 'DynamicsAX';
        #    srsServers.ConfigurationId = '01@AU11STHAOSPRD05';
        #    srsServers.IsDefaultReportLibraryServer = NoYes::Yes;
        #    srsServers.ReportManagerUrl = 'http://mhsthsqlprd01/Reports';
        #    srsServers.ServerId = 'MHSTHSQLPRD01';
        #    srsServers.ServerInstance = 'MSSQLSERVER';
        #    srsServers.ServerUrl = 'http://mhsthsqlprd01/ReportServer';
        #
        #    srsServers.insert();
        #
        #    srsServers.AOSId = '01@AU11STHAOSPRD06';
        #    srsServers.AxaptaReportFolder = 'DynamicsAX';
        #    srsServers.ConfigurationId = '01@AU11STHAOSPRD06';
        #    srsServers.IsDefaultReportLibraryServer = NoYes::Yes;
        #    srsServers.ReportManagerUrl = 'http://mhsthsqlprd01/Reports';
        #    srsServers.ServerId = 'MHSTHSQLPRD01';
        #    srsServers.ServerInstance = 'MSSQLSERVER';
        #    srsServers.ServerUrl = 'http://mhsthsqlprd01/ReportServer';
        #
        #    srsServers.insert();
        #
        #    srsServers.AOSId = '01@AU11STHAOSPRD07';
        #    srsServers.AxaptaReportFolder = 'DynamicsAX';
        #    srsServers.ConfigurationId = '01@AU11STHAOSPRD07';
        #    srsServers.IsDefaultReportLibraryServer = NoYes::Yes;
        #    srsServers.ReportManagerUrl = 'http://mhsthsqlprd01/Reports';
        #    srsServers.ServerId = 'MHSTHSQLPRD01';
        #    srsServers.ServerInstance = 'MSSQLSERVER';
        #    srsServers.ServerUrl = 'http://mhsthsqlprd01/ReportServer';
        #
        #    srsServers.insert();
        #
        #    srsServers.AOSId = '01@AU11STHAOSPRD08';
        #    srsServers.AxaptaReportFolder = 'DynamicsAX';
        #    srsServers.ConfigurationId = '01@AU11STHAOSPRD08';
        #    srsServers.IsDefaultReportLibraryServer = NoYes::Yes;
        #    srsServers.ReportManagerUrl = 'http://mhsthsqlprd01/Reports';
        #    srsServers.ServerId = 'MHSTHSQLPRD01';
        #    srsServers.ServerInstance = 'MSSQLSERVER';
        #    srsServers.ServerUrl = 'http://mhsthsqlprd01/ReportServer';
        #
        #    srsServers.insert();
        #
        #}
      ENDSOURCE
    ENDMETHODS
  ENDCLASS

***Element: END
"@

$xmlImportXPO = $xpoFolder+'\XpoImport.xml'
if (Test-Path $xmlImportXPO -PathType Leaf)
{
    del $xmlImportXPO
}

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
$xmlWriter.WriteEndElement | Out-Null # <-- XpoImport
 
# Write Close Tag for Root Element
$xmlWriter.WriteEndElement | Out-Null # <-- Closing RootElement
 
# End the XML Document
$xmlWriter.WriteEndDocument()
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush | Out-Null
$xmlWriter.Close()

#importXPO
$startUpCommand = '-StartUpCmd=Autorun_'+$xmlImportXPO
& 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin\Ax32.exe' $axcFile $startUpCommand | Out-Null

Write-Output "The class $automationAXClass has been imported to AX" 