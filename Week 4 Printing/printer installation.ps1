function checkIP {
    [ParameterType] [string]$tempIPAddress
    
    if ($tempIPAddress -match "(\b25[0-5]|\b2[0-4][0-9]|\b[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}" -and $tempIPAddress -as [IPAddress]) {
        return $True
    } 
    else {
        return $False
    }
}

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
    checkPrinterDriver 
}

function checkPrinterDriver {
    # Check if the printer driver is installed
    Get-PrinterDriver
    Write-Host ""
    $ans = Read-Host -Prompt "Do you see your printer driver? (Y/N)"
    while ($True) {
        if ($ans.ToLower() -eq "y") {
            Write-Host "> The printer driver is installed." -ForegroundColor Green
            Write-Host "> Skipping to installing the printer." -ForegroundColor Green
            installPrinter
            break
        }
        elseif ($ans.ToLower() -eq "n") {
            Write-Host "> The printer driver is not installed." -ForegroundColor Yellow
            Write-Host "> Installing the printer driver." -ForegroundColor Yellow
            # Install the printer driver
            installPrinterDriver
            Write-Host "> The printer driver has been installed." -ForegroundColor Green
            break
            
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
    $outputFile = "driver.exe"

    # Check if the output directory exists
    if (!(Test-Path $outputPath)) {
        Write-Host "> $outputPath directory not found" -ForegroundColor Yellow
        Write-Host "> Creating new directory $outputPath." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $outputPath
        Write-Host "> The directory $outputPath has been created." -ForegroundColor Green
    } else {
        Write-Host "> The directory $outputPath exists." -ForegroundColor Green
    }
    
    # Check if the output file exists
    if (!(Test-Path "$outputPath\$outputFile")) {
        Write-Host "> $outputPath\$outputFile Ffile not found." -ForegroundColor Yellow
        Write-Host "> Creating new file $outputFile." -ForegroundColor Yellow
        New-Item -ItemType File -Path "$outputPath\$outputFile"
        Write-Host "> The file $outputPath\$outputFile has been created." -ForegroundColor Green
    } else {
        Write-Host "> The file $outputPath\$outputFile exists." -ForegroundColor Green
    }

    Write-Host "> Downloading the file from $url to $outputPath\$outputFile" -ForegroundColor Green
    Write-Host "> !!! Don't forget to copy your driver to the path you unzip the file to !!!" -ForegroundColor Yellow
    Write-Host "> !!! Don't forget to copy your driver to the path you unzip the file to !!!" -ForegroundColor Yellow
    Write-Host "> !!! Don't forget to copy your driver to the path you unzip the file to !!!" -ForegroundColor Yellow
    Write-Host "> !!! Don't forget to copy your driver to the path you unzip the file to !!!" -ForegroundColor Yellow
    Write-Host "> !!! Don't forget to copy your driver to the path you unzip the file to !!!" -ForegroundColor Yellow
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
        
        Write-Host "> The file has been downloaded to $outputPath\$outputFile" -ForegroundColor Green
        
        $driverPath = Read-Host -Prompt "Enter the path where you extracted the driver files:"
        while ($driverPath -eq "" -or (!(Test-Path $driverPath))) {
            Write-Host "> Error: The path does not exist." -ForegroundColor Red
            $driverPath = Read-Host -Prompt "Enter the path where you extracted the driver files:"
        }

        $printerDriver = (Get-ChildItem -Path $driverPath -Filter "*.inf").Name
        Write-Host "> The driver name is $printerDriver" -ForegroundColor Green

        installPrinter
    }
    catch {
        Write-Host "> Error: The file could not be downloaded." -ForegroundColor Red
        $ans = Read-Host -Prompt "Try again? (Y/N)"
        while ($True) {
            if ($ans.ToLower() -eq "y") {
                installPrinterDriver
                break
            }
            elseif ($ans.ToLower() -eq "n") {
                Write-Host "> Cannot continue without a driver. Breaking operation." -ForegroundColor Red
                pause
                Get-Process -Name powershell | Stop-Process -Force

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

    $printerName = Read-Host -Prompt "Enter the printer name:"
    while ($printerName -eq "") {
        Write-Host "> Error: The printer name cannot be empty." -ForegroundColor Red
        $printerName = Read-Host -Prompt "Enter the printer name:"
        #check if the printername is already in use
        while (Get-Printer -Name $printerName -ErrorAction SilentlyContinue) {
            Write-Host "> Warning: The printer name is already in use." -ForegroundColor Yellow
            $printerName = Read-Host -Prompt "Do you wish to overwrite it? (can cause problems)"
        }
    }
    $tempprinterPort = Read-Host -Prompt "Enter the printer port:"
    while ($printerPort -eq "") {
        Write-Host "> Error: The printer port cannot be empty." -ForegroundColor Red
        $tempprinterPort = Read-Host -Prompt "Enter the printer port [no ip address!]:"
        #check if the printerport is already in use
        while (Get-PrinterPort -Name $tempprinterPort -ErrorAction SilentlyContinue) {
            Write-Host "> Warning: The printer port is already in use." -ForegroundColor Yellow
            $ans = Read-Host -Prompt "Do you wish to overwrite it? (can cause problems)"
        }
        $printerPort = $tempprinterPort
    }
    $tempIPAddress = Read-Host -Prompt "Enter the printer IP address:"
    while ($printerIPAddress -eq "") {
        Write-Host "> Error: The printer IP address cannot be empty." -ForegroundColor Red
        $tempIPAddress = Read-Host -Prompt "Enter the printer IP address:"
        if(checkIP($tempIPAddress)) {
            #check if there is already a print instaal with this ip
            $printerIPAddress = $tempIPAddress
        } else {
            Write-Host "> Error: The IP address is not valid." -ForegroundColor Red
        }
    }

    try {
        # Add the printer port
        Add-PrinterPort -Name $printerPort -PrinterHostAddress $printerIPAddress

        # Install the printer driver
        Add-PrinterDriver -Name $printerDriver -InfPath "$driverPath\hpcu187v.inf"

        # Add the printer
        Add-Printer -Name $printerName -DriverName $printerDriver -PortName $printerPort
    
        # Share the printer
        $ans = Read-Host -Prompt "Do you want to share the printer? (Y/N)"
        while ($True) {
            if ($ans -eq "y") {
                $shareName = Read-Host -Prompt "Enter the share name:"
                while ($shareName -eq "") {
                    Write-Host "> Error: The share name cannot be empty." -ForegroundColor Red
                    $shareName = Read-Host -Prompt "Enter the share name:"
                }
                $shareLocation = Read-Host -Prompt "Enter the location of the printer:"
                while ($shareLocation -eq "") {
                    Write-Host "> Error: The location of the printer cannot be empty." -ForegroundColor Red
                    $shareLocation = Read-Host -Prompt "Enter the location of the printer:"
                }
                Set-Printer -Name $printerName -Location $shareLocation -Shared $True -ShareName $shareName
                break
            }
            elseif ($ans -eq "n") {
                Write-Host "> The printer is not shared." -ForegroundColor Yellow
                break
            }
            else {
                Write-Host "> Error: Please enter Y or N." -ForegroundColor Red
                $ans = Read-Host -Prompt "Do you want to share the printer? (Y/N)"
            }
        }
        
        Write-Host "> The printer has been installed." -ForegroundColor Green
        Write-Host "> The printer is shared as $shareName." -ForegroundColor Green
        Write-Host "> The printer is located at $printerLocation." -ForegroundColor Green
        Write-Host "> The printer is available at \\$env:COMPUTERNAME\$shareName." -ForegroundColor Green
        $ans = Read-Host -Prompt "Would you like to print a test page? (Y/N)"
        while ($True) {
            if ($ans.ToLower() -eq "y") {
                Write-Host "> Printing a test page." -ForegroundColor Green
                PrintTestPage
                break
            }
            elseif ($ans.ToLower() -eq "n") {
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
        Write-Host "> Error: The printer could not be installed." -ForegroundColor Red
        $ans = Read-Host -Prompt "Try again? (Y/N)"
        while ($True) {
            if ($ans.ToLower() -eq "y") {
                checkPrinterDriver
                break
            }
            elseif ($ans.ToLower() -eq "n") {
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

function PrintTestPage {
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
Install-PrinterServices