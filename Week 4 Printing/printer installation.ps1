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
    changeSpool()
}


function changeSpool {
    # change the location of the print spool folder
    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers"
    $newSpoolDirectory = "C:\Spool"
    
    # Test if the new spool directory exists
    if (!(Test-Path $newSpoolDirectory)) {
        # Create new spool directory
        Write-Host "> $newSpoolDirectory directory not found" -ForegroundColor Yellow
        Write-Host "> Creating new spool directory $newSpoolDirectory." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $newSpoolDirectory -WhatIf
        Write-Host "> The new spool directory $newSpoolDirectory has been created." -ForegroundColor Green
    }
    else {
        Write-Host "> The new spool directory $newSpoolDirectory exists." -ForegroundColor Green
    }
    
    # Check if the registry key exists
    if (Test-Path $registryPath) {
        if ((Get-ItemProperty -Path $registryPath -Name DefaultSpoolDirectory) -ne $newSpoolDirectory) {
            Set-ItemProperty -Path $registryPath -Name DefaultSpoolDirectory -Value $newSpoolDirectory -WhatIf
            Write-Host "> The DefaultSpoolDirectory key has been changed to $newSpoolDirectory." -ForegroundColor Green
        }
        else {
            Write-Host "> The DefaultSpoolDirectory key is already configuered correctly" -ForegroundColor Green
        }   
    }
    else {
        Write-Host "> Error: The registry key $registryPath does not exist." -ForegroundColor Red
        Write-Host "> Warning: Skipping the change of the DefaultSpoolDirectory key." -ForegroundColor Yellow
        $defueltSpoonDirectory = Get-ItemProperty -Path $registryPath -Name DefaultSpoolDirectory
        Write-Host "> Warning: DefaultSpoolDirectory: $defueltSpoonDirectory" -ForegroundColor Yellow
    } 
    checkPrinterDriver() 
}

function checkPrinterDriver {
    # Check if the printer driver is installed
    Get-PrinterDriver
    Write-Host ""
    $ans = Read-Host -Prompt "Do you see your printer driver? (Y/N)"
    while ($ans.ToLower() -ne "") {
        if ($ans -eq "y") {
            Write-Host "> The printer driver is installed." -ForegroundColor Green
            Write-Host "> Skipping to installing the printer." -ForegroundColor Green
            installPrinter()
        }
        elseif ($ans -eq "n") {
            Write-Host "> The printer driver is not installed." -ForegroundColor Yellow
            Write-Host "> Installing the printer driver." -ForegroundColor Yellow
            # Install the printer driver
            installPrinterDriver()
            Write-Host "> The printer driver has been installed." -ForegroundColor Green
            
        }
        else {
            Get-PrinterDriver
            Write-Host ""
            Write-Host "> Error: Please enter Y or N." -ForegroundColor Red
            $ans = Read-Host -Prompt "Do you see your printer driver? (Y/N)"
        }
    }
}

function installPrinterDriver {
    $url = "https://ftp.hp.com/pub/softlib/software13/COL40842/ds-99374-24/upd-pcl6-x64-7.0.1.24923.exe"
    $outputPath = "C:/Temp"
    #chek if the path exists else make it
    $outputFile = "driver.exe"
    #check if the file exists else make it
    
    Write-Host "> Downloading the file from $url to $outputPath\$outputFile" -ForegroundColor Green
    Write-Host "> !!! Don't forget to copy your driver to the path you unzip the file to !!!" -ForegroundColor Yellow
    try {
        # Download the file
        Invoke-WebRequest -Uri $url -OutFile "$outputPath\$outputFile"
        #run the file
        Start-Process "$outputPath\$outputFile" -ArgumentList "/extract:$outputPath" -Wait
        #remove the file
        Remove-Item "$outputPath\$outputFile"
        
        Write-Host "> The file has been downloaded to $outputPath\$outputFile" -ForegroundColor Green
        
        $driverPath = Read-Host -Prompt "The Path U unzip the file to"
        while ($driverPath -eq "" -or (!(Test-Path $driverPath))) {
            Write-Host "> Error: The path does not exist." -ForegroundColor Red
            $driverPath = Read-Host -Prompt "The Path U unzip the file to"
        }
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
                Write-Host "> Cannot continue without a drive breaking opperation." -ForegroundColor Red
                #exit the script
            }
            else {
                Write-Host "> Error: Please enter Y or N." -ForegroundColor Red
                $ans = Read-Host -Prompt "Do you see your printer driver? (Y/N)"
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
        Add-PrinterPort -Name $printerPort -PrinterHostAddress $printerIPAddress -WhatIf
        # Install the printer driver
        Add-PrinterDriver -Name $printerDriver -InfPath "$printerDriverPath\hpcu187v.inf" -WhatIf
        # Add the printer
        Add-Printer -Name $printerName -DriverName $printerDriver -PortName $printerPort -WhatIf
    
        # Share the printer
        Set-Printer -Name $printerName -Location $printerLocation -Shared $True -ShareName $shareName -WhatIf
    }
    catch {
        Write-Host "> Error: The printer could not be installed." -ForegroundColor Red
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
                $ans = Read-Host -Prompt "Do you see your printer driver? (Y/N)"
            }
        }
    }
}

$ans, $url, $outputPath, $outputFile, $registryPath, $newSpoolDirectory, $driverPath, $printerName, $printerDriver, $printerDriverPath, $printerPort, $printerIPAddress, $shareName, $printerLocation
installPrinterServices()