#Stop-AXBatchServer
Param(
    $axcFile = ''  
    )

$xmlAXRun = $env:TEMP +'\RunStopBatch.xml'
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
$xmlWriter.WriteEndElement | Out-Null # <-- Run
 
# Write Close Tag for Root Element
$xmlWriter.WriteEndElement | Out-Null # <-- Closing RootElement
 
# End the XML Document
$xmlWriter.WriteEndDocument()
 
# Finish The Document
$xmlWriter.Finalize
$xmlWriter.Flush | Out-Null
$xmlWriter.Close()

#Stop Batch server
$startUpCommand = '-StartUpCmd=Autorun_'+$xmlAXRun
& 'C:\Program Files (x86)\Microsoft Dynamics AX\60\Client\Bin\Ax32.exe' $axcFile $startUpCommand | Out-Null