#Start-AOS
Param(
    $aosServerNames = (''),
    $aosServiceName = 'AOS60$01'
    )

try
{
    $servicesList = New-Object System.Collections.ArrayList

    foreach ($AOSServer in $aosServerNames) 
    {
        $service = Get-Service -ComputerName $AOSServer $aosServiceName
        
        if ($service.Status -eq "Stopped")
        {   
            $servicesList.add($service) | Out-Null                
            Write-Output "Starting AOS in $AOSServer"
            $service.Start()
        }
        else
        {
            Write-Output "Could not start AOS in $AOSServer the service status is $service.Status" 
        }                
    }   
    
    foreach ($service in $servicesList)
    {
        if ($service.Status -eq 'Running')
        {
            Write-Output "AOS in $($service.MachineName) is running"
        }
        else
        {
            Write-Output "Waiting AOS $($service.MachineName) to start"
            $service.WaitForStatus("Running")
            Write-Output "AOS in $($service.MachineName) is running"
        }
        
    } 
}
catch
{
    Write-Output "Error stoping AOS"
    break
}    

