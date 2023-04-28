# Check if Print and Document Services feature is installed
if (!(Get-WindowsFeature -Name Print-Services | Where-Object { $_.Installed })) {
    # Install Print and Document Services feature
    Write-Host "> Installing Print and Document Services feature..." -ForegroundColor Yellow
    Install-WindowsFeature -Name Print-Services -IncludeAllSubFeature -Restart -Verbose
    Write-Host "> Print and Document Services feature installed successfully." -ForegroundColor Green
}
else {
    Write-Host "> Print and Document Services feature is already installed." -ForegroundColor DarkGreen
}

# Define registry path and new spool directory
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers"
$newSpoolDirectory = "C:\Spool"
    
# Check if new spool directory exists, create it if not
if (!(Test-Path $newSpoolDirectory)) {
    New-Item -ItemType Directory -Path $newSpoolDirectory | Out-Null
    Write-Host "> The new spool directory $newSpoolDirectory has been created." -ForegroundColor Green
}
else {
    Write-Host "> The new spool directory $newSpoolDirectory exists." -ForegroundColor Green
}
    
# Check if the registry key exists and set the new spool directory
if (Test-Path $registryPath) {
    $currentSpoolDirectory = Get-ItemProperty -Path $registryPath -Name DefaultSpoolDirectory
    if ($currentSpoolDirectory -ne $newSpoolDirectory) {
        Set-ItemProperty -Path $registryPath -Name DefaultSpoolDirectory -Value $newSpoolDirectory
        Write-Host "> The DefaultSpoolDirectory key has been changed to $newSpoolDirectory." -ForegroundColor Green
    }
    else {
        Write-Host "> The DefaultSpoolDirectory key is already configured correctly." -ForegroundColor Green
    }   
}
else {
    Write-Host "> Error: The registry key $registryPath does not exist." -ForegroundColor Red
    Write-Host "> Warning: Skipping the change of the DefaultSpoolDirectory key." -ForegroundColor Yellow
    if ($currentSpoolDirectory) {
        Write-Host "> Warning: DefaultSpoolDirectory: $currentSpoolDirectory" -ForegroundColor Yellow
    }
} 

$url = "https://ftp.hp.com/pub/softlib/software13/COL40842/ds-99374-24/upd-pcl6-x64-7.0.1.24923.exe"
$outputPath = "C:/Temp"
$outputFile = "driver.exe"

# Check if the output directory exists
if (!(Test-Path $outputPath)) {
    Write-Host "> $outputPath directory not found" -ForegroundColor Yellow
    Write-Host "> Creating new directory $outputPath." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $outputPath
    Write-Host "> The directory $outputPath has been created." -ForegroundColor Green
}
else {
    Write-Host "> The directory $outputPath exists." -ForegroundColor Green
}
    
# Check if the output file exists
if (!(Test-Path "$outputPath\$outputFile")) {
    Write-Host "> $outputPath\$outputFile Ffile not found." -ForegroundColor Yellow
    Write-Host "> Creating new file $outputFile." -ForegroundColor Yellow
    New-Item -ItemType File -Path "$outputPath\$outputFile"
    Write-Host "> The file $outputPath\$outputFile has been created." -ForegroundColor Green
}
else {
    Write-Host "> The file $outputPath\$outputFile exists." -ForegroundColor Green
}

Write-Host "> Downloading the file from $url to $outputPath\$outputFile" -ForegroundColor Green


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
            exit

        }
        else {
            Write-Host "> Error: Please enter Y or N." -ForegroundColor Red
            $ans = Read-Host -Prompt "Do you see your printer driver? (Y/N)"
        }
    }
}

$PrinterName = "HP Laserjet 4050"
$PrinterIP = "172.23.80.3"
$PrinterPort = $PrinterIP + "_TCPPort"

$PrinterLocation = "KWE.A.2.105"
$PrinterShare = "HPLJ4050-KWE.A.2.105"

$inf = "C:\HP Universal Print Driver\pcl6-x64-7.0.1.24923\hpcu255u.inf"
Write-Host "> The inf file is '$inf'" -ForegroundColor Yellow

# Add the printer driver
PNPUtil.exe /add-driver $inf /install | Out-Null
Write-Host "> The printer driver has been added." -ForegroundColor Green

$DismInfo = Dism.exe /online /Get-DriverInfo /driver:$inf
$DriverName = ( $DismInfo | Select-String -Pattern "Description" | Select-Object -Last 1 ) -split " : " | Select-Object -Last 1
Write-Host "The driver name is '$DriverName'" -ForegroundColor Yellow

# Add the printer
Add-PrinterDriver -Name $DriverName
Write-Host "> The printer driver has been added." -ForegroundColor Green

# Add the printer port
Add-PrinterPort -Name $PrinterPort -PrinterHostAddress $PrinterIP -ErrorAction SilentlyContinue
Write-Host "> The printer port has been added." -ForegroundColor Green

# Add the printer and share it
Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PrinterPort -Location $PrinterLocation -Shared -ShareName $PrinterShare -Verbose

Pause
PrintTestPage


function PrintTestPage {
    $printer | Out-Printer -InputObject "test page"
    "Hello, World" | Out-Printer -Name $printerName
    Write-Host "> The test page has been queued." -ForegroundColor Green
}