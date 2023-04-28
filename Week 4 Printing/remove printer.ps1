#
# Removing a printer
#
$PrinterName = "HP Laserjet 4050"

try {
    Get-Printer -Name $PrinterName -ErrorAction Stop | Out-Null
    Remove-Printer -Name $PrinterName
    Write-Host "> Printer $PrinterName Removed" -ForegroundColor Green
}
catch {
    Write-Host "> Error: Printer $PrinterName doesn't exist ..." -ForegroundColor Red
    Pause
    exit
}

#
# Removing a printer port
#
$PrinterPort = "172.23.80.3_TCPPort"
try {
    Get-PrinterPort -Name $PrinterPort -ErrorAction Stop | Out-Null
    try {
        Remove-PrinterPort -Name $PrinterPort -ErrorAction Stop
        Write-Host "> Printer port $PrinterPort Removed" -ForegroundColor Green
    }
    catch {
        # Printer port is in use …
        Write-Host "> Error: Unable to remove printer port '$PrinterPort'" -ForegroundColor Red
    } 
}
catch {
    # Printer port is in use …
    Write-Host "> Error: Printer port $PrinterPort doesn't exist ..." -ForegroundColor Red
}
