function Install-PrinterServices {
    # Check if Print and Document Services feature is installed
    if (!(Get-WindowsFeature -Name Print-Services -ErrorAction SilentlyContinue | Where-Object {$_.Installed})) {
        # Install Print and Document Services feature
        Write-Host "> Installing Print and Document Services feature..." -ForegroundColor Yellow
        Install-WindowsFeature -Name Print-Services -IncludeAllSubFeature -Restart -Verbose
        Write-Host "> Print and Document Services feature installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "> Print and Document Services feature is already installed." -ForegroundColor DarkGreen
    }
    #continue to change the spool directory
    changeSpool
}

function changeSpool {
    # Define registry path and new spool directory
    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers"
    $newSpoolDirectory = "C:\Spool"
    
    # Check if new spool directory exists, create it if not
    if (!(Test-Path $newSpoolDirectory)) {
        Write-Host "> $newSpoolDirectory directory not found" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $newSpoolDirectory | Out-Null
        Write-Host "> The new spool directory $newSpoolDirectory has been created." -ForegroundColor Green
    } else {
        Write-Host "> The new spool directory $newSpoolDirectory exists." -ForegroundColor Green
    }
    
    # Check if the registry key exists and set the new spool directory
    if (Test-Path $registryPath) {
        $currentSpoolDirectory = Get-ItemProperty -Path $registryPath -Name DefaultSpoolDirectory
        if ($currentSpoolDirectory -ne $newSpoolDirectory) {
            Set-ItemProperty -Path $registryPath -Name DefaultSpoolDirectory -Value $newSpoolDirectory
            Write-Host "> The DefaultSpoolDirectory key has been changed to $newSpoolDirectory." -ForegroundColor Green
        } else {
            Write-Host "> The DefaultSpoolDirectory key is already configured correctly." -ForegroundColor Green
        }   
    } else {
        Write-Host "> Error: The registry key $registryPath does not exist." -ForegroundColor Red
        Write-Host "> Warning: Skipping the change of the DefaultSpoolDirectory key." -ForegroundColor Yellow
        if ($currentSpoolDirectory) {
            Write-Host "> Warning: DefaultSpoolDirectory: $currentSpoolDirectory" -ForegroundColor Yellow
        }
    } 
    checkPrinterDriver() 
}

function checkPrinterDriver {
    # Check if the printer driver is installed
    $printerDriver = Get-PrinterDriver -Name "Your Printer Driver Name"
    if ($printerDriver) {
        Write-Host "> The printer driver is installed." -ForegroundColor Green
        Write-Host "> Skipping to installing the printer." -ForegroundColor Green
        installPrinter
    }
    else {
        Write-Host "> The printer driver is not installed." -ForegroundColor Yellow
        Write-Host "> Installing the printer driver." -ForegroundColor Yellow
        # Install the printer driver
        installPrinterDriver
        Write-Host "> The printer driver has been installed." -ForegroundColor Green
    }
}


function installPrinterDriver {
    $url = "https://ftp.hp.com/pub/softlib/software13/COL40842/ds-99374-24/upd-pcl6-x64-7.0.1.24923.exe"
    $outputPath = "C:\Temp"
    $outputFile = "driver.exe"
    
    # Check if the output path exists and create it if it doesn't
    if (!(Test-Path $outputPath)) {
        Write-Host "> $outputPath directory not found" -ForegroundColor Yellow
        Write-Host "> Creating new directory $outputPath." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $outputPath -WhatIf
        Write-Host "> The directory $outputPath has been created." -ForegroundColor Green
    }
    
    # Check if the output file exists and delete it if it does
    if (Test-Path "$outputPath\$outputFile") {
        Write-Host "> The file $outputPath\$outputFile already exists." -ForegroundColor Green
        Write-Host "> Deleting the existing file." -ForegroundColor Yellow
        Remove-Item "$outputPath\$outputFile" -Force
        Write-Host "> The existing file has been deleted." -ForegroundColor Green
    }
    
    Write-Host "> Downloading the file from $url to $outputPath\$outputFile" -ForegroundColor Green
    Write-Host "> !!! Don't forget to copy your driver to the path you unzip the file to !!!" -ForegroundColor Yellow
    try {
        # Download the file
        Invoke-WebRequest -Uri $url -OutFile "$outputPath\$outputFile"
        
        # Extract the driver to the output path
        Write-Host "> Extracting the driver to $outputPath." -ForegroundColor Green
        Start-Process "$outputPath\$outputFile" -ArgumentList "/extract:$outputPath" -Wait
        
        # Remove the downloaded file
        Write-Host "> Removing the downloaded file." -ForegroundColor Green
        Remove-Item "$outputPath\$outputFile" -Force
        
        Write-Host "> The driver has been extracted to $outputPath." -ForegroundColor Green
        
        $driverPath = Read-Host -Prompt "Enter the path where you extracted the driver files:"
        while ($driverPath -eq "" -or (!(Test-Path $driverPath))) {
            Write-Host "> Error: The path does not exist." -ForegroundColor Red
            $driverPath = Read-Host -Prompt "Enter the path where you extracted the driver files:"
        }
        
        $driverName = (Get-ChildItem -Path $driverPath -Filter "*.inf").Name
        Write-Host "> The driver name is $driverName" -ForegroundColor Green
        
        installPrinter()
    }
    catch {
        Write-Host "> Error: The file could not be downloaded." -ForegroundColor Red
        $ans = Read-Host -Prompt "Try again? (Y/N)"
        while ($ans.ToLower() -ne "") {
            if ($ans -eq "y") {
                installPrinterDriver()
                break
            }
            elseif ($ans -eq "n") {
                Write-Host "> Cannot continue without a driver. Breaking operation." -ForegroundColor Red
                break
            }
            else {
                Write-Host "> Error: Please enter Y or N." -ForegroundColor Red
                $ans = Read-Host -Prompt "Do you want to try again? (Y/N)"
            }
        }
    }
}

function installPrinter {
    # Install and share a network printer, with IP address 172.23.80.3, with that driver.
    $printerName = "HP Printer"
    $printerDriver = "HP Universal Printing PCL 6"
    $printerDriverPath = $driverPath
    $printerPort = "IP_172.23.80.3"
    $printerIPAddress = "172.23.80.3"
    $shareName = "HP_Printer_Shared"
    $printerLocation = "KWE-A-2-105"

    try {
        # Add the printer port
        Add-PrinterPort -Name $printerPort -PrinterHostAddress $printerIPAddress
        
        # Install the printer driver
        Add-PrinterDriver -Name $printerDriver -InfPath "$printerDriverPath\hpcu187v.inf"
        
        # Add the printer
        Add-Printer -Name $printerName -DriverName $printerDriver -PortName $printerPort
    
        # Share the printer
        Set-Printer -Name $printerName -Location $printerLocation -Shared $True -ShareName $shareName

        Write-Host "> The printer has been installed." -ForegroundColor Green
        Write-Host "> The printer is shared as $shareName." -ForegroundColor Green
        Write-Host "> The printer is located at $printerLocation." -ForegroundColor Green
        Write-Host "> The printer is available at \\$env:COMPUTERNAME\$shareName." -ForegroundColor Green
        $ans = Read-Host -Prompt "Would you like to print a test page? (Y/N)"
        while ($ans.ToLower() -ne "") {
            if ($ans -eq "y") {
                Write-Host "> Printing a test page." -ForegroundColor Green
                Print-TestPage()
                break
            }
            elseif ($ans -eq "n") {
                Write-Host "> No test page is printed." -ForegroundColor Green
                
                break
            }
            else {
                Write-Host "> Error: Please enter Y or N." -ForegroundColor Red
                $ans = Read-Host -Prompt "Would you like to print a test page? (Y/N)"
            }
        }
    }
    catch {
        Write-Host "> Error: $($_.Exception.Message)" -ForegroundColor Red
        $ans = Read-Host -Prompt "Try again? (Y/N)"
        while ($ans.ToLower() -ne "") {
            if ($ans -eq "y") {
                installPrinter()
                break
            }
            elseif ($ans -eq "n") {
                Write-Host "> No printer is installed" -ForegroundColor Red
                break
            }
            else {
                Write-Host "> Error: Please enter Y or N." -ForegroundColor Red
                $ans = Read-Host -Prompt "Try again? (Y/N)"
            }
        }
    }
}

function Print-TestPage {
    # Print a test page
    $printer = Get-Printer -Name $printerName
    if ($printer) {
        Write-Host "> The printer is installed." -ForegroundColor Green
        Write-Host "> Printing a test page." -ForegroundColor Green
        $printer | Out-Printer -FilePath "C:\Windows\System32\spool\drivers\color\A0000001.PPD"
        Write-Host "> The test page has been queued." -ForegroundColor Green
    }
    else {
        Write-Host "> The printer is not installed." -ForegroundColor Red
        Write-Host "> Cannot print a test page." -ForegroundColor Red
    }
}

$ans, $url, $outputPath, $outputFile, $registryPath, $newSpoolDirectory, $driverPath, $printerName, $printerDriver, $printerDriverPath, $printerPort, $printerIPAddress, $shareName, $printerLocation
installPrinterServices()