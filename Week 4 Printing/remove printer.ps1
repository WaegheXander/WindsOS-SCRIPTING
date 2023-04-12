function  Remove-PrinteByName {
    # Prompt the user for the printer name
    $printerName = Read-Host "Enter the name of the printer to remove"
    
    # Get the printer object
    $printer = Get-Printer -Name $printerName
    
    if ($printer) {
        # Remove the printer
        Remove-Printer -InputObject $printer
        Write-Host "Printer $printerName has been removed."
        
        # Get the printer ports associated with the printer
        $ports = Get-PrinterPort -CimSession $printer.CimSession | Where-Object { $_.Name -match $printerName }
        
        if ($ports) {
            # Remove any unused ports
            foreach ($port in $ports) {
                if ((Get-WmiObject -Class Win32_Printer -Filter "PortName='$($port.Name)'").Count -eq 0) {
                    Remove-PrinterPort -InputObject $port
                    Write-Host "Port $($port.Name) has been removed."
                }
            }
        }
        else {
            Write-Host "No printer ports found for printer $printerName."
            Remove-PrinteByName
        }
    }
    else {
        Write-Host "Printer $printerName not found."
        Remove-PrinteByName
    }
}
