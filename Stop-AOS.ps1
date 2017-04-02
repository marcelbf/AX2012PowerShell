#Stop-AOS
Param(
    $aosServerNames = ('AU11STHAOSPRD07','AU11STHAOSPRD08'),
    $aosServiceName = 'AOS60$01'
    )

try
{
    $servicesList = New-Object System.Collections.ArrayList

    foreach ($AOSServer in $aosServerNames) 
    {
        $service = Get-Service -ComputerName $AOSServer $aosServiceName
        
        if ($service.Status -eq "Running" -and $service.CanStop -eq $True)
        {                                    
            $servicesList.Add($service) | Out-Null
            Write-Output "Stopping AOS in $AOSServer"            
            $service.Stop()
        }
        else
        {
            Write-Output "Could not stop AOS in $AOSServer"
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
    Write-Output "Error stoping AOS"
    break
}    

