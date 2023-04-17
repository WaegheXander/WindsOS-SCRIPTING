# Define the printer names and port numbers
$printerNames = @("Printer1", "Printer2")
$portNumbers = @("172.23.80.3", "172.23.82.3")

# Begin the transaction
Start-Transaction

try {
    # Create the printer objects
    for ($i = 0; $i -lt $printerNames.Count; $i++) {
        $printerName = $printerNames[$i]
        $portNumber = $portNumbers[$i]

        # Add the printer port
        Add-PrinterPort -Name $portNumber -PrinterHostAddress $portNumber

        # Add the printer
        Add-Printer -Name $printerName -PortName $portNumber -Shared $true
    }

    # Create the printer pool
    rundll32.exe printui.dll,PrintUIEntry /if /q /n "PrinterPool" /m "Printer Pool" /r ""

    # Add the printers to the printer pool
    foreach ($printerName in $printerNames) {
        rundll32.exe printui.dll,PrintUIEntry /Sr /n "PrinterPool" /a "$printerName"
    }

    # Share the printer pool
    rundll32.exe printui.dll,PrintUIEntry /if /q /n "PrinterPool" /k /shared

    # Commit the transaction
    Complete-Transaction
}
catch {
    # Rollback the transaction in case of errors
    Undo-Transaction
    throw $_.Exception.Message

}

# Define the printer name and port number
$printerName = "DailyPrinter"
$portNumber = "192.168.1.100"

# Define the time ranges
$dailyStartTime = "08:00:00"
$dailyEndTime = "18:00:00"
$nightlyStartTime = "18:00:00"
$nightlyEndTime = "08:00:00"

# Create the printer object
Add-Printer -Name $printerName -PortName $portNumber

# Set the printer properties
Set-PrintConfiguration -PrinterName $printerName `
    -StartTime $dailyStartTime -EndTime $dailyEndTime -DaysOfWeek 1, 2, 3, 4, 5 `
    -StartTime2 $nightlyStartTime -EndTime2 $nightlyEndTime -DaysOfWeek2 1, 2, 3, 4, 5, 6, 7 `
    -Shared $true

# Share the printer
rundll32.exe printui.dll,PrintUIEntry /if /q /n "$printerName" /k /shared


# Define the printer name
$printerName = "Printer1"

# Define the user or group that should have access to the printer
$user = "DOMAIN\username"

# Set printer permissions
$securityDescriptor = (Get-Printer -Name $printerName).PermissionSDDL
$securityDescriptor += "($user,RD)"
Set-Printer -Name $printerName -PermissionSDDL $securityDescriptor
