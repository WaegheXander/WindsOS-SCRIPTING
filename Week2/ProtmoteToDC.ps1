$forestMain = "intranet"

#
# Check if the script is running as administrator
#
Write-Host "> Checking permissions"
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Insufficient permissions to run this script. Open the PowerShell console as an administrator and run this script again."
    Pause
    Exit
}
else {
    Write-Host "Code is running as administrator" -ForegroundColor Green
}

#
# Check if AD-Domain-Services is installed
#
$feature = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction SilentlyContinue
if ($feature.Installed -ne "True") {
    # Install AD-Domain-Services feature
    Write-Host "> Installing AD-Domain-Services feature..." -ForegroundColor Yellow
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Host "> AD-Domain-Services feature installed successfully." -ForegroundColor Green
}
else {
    Write-Host "> AD-Domain-Services feature is already installed." -ForegroundColor Green
}

#
# Install Forest if not already installed
#
Import-Module ADDSDeployment
# Check if a forest is already installed
if (Get-ADForest -ErrorAction SilentlyContinue) {
    # A forest is already installed
    Write-Host "> Warining: A forest is already installed." -ForegroundColor Yellow
    Write-Host "> Getting the forest name" -ForegroundColor Yellow
    #get the forest name
    $forestName = (Get-ADForest).name
}
else {
    # No forest is installed
    Write-Host "> Warning: No forest is installed." -ForegroundColor Yellow
    $forestTemp = Read-Host "Enter the name of the new forest (intranet.???)"
    while ($forestTemp -eq "") {
        Write-Host "The forest name cannot be empty" -ForegroundColor Red
        $forestTemp = Read-Host "Enter the name of the new forest (INTRANET.???)"
    }
    $forestName = "$forestMain.$forestTemp"
    Write-Host "> Creating new forest $forestName..." -ForegroundColor Yellow
    Install-ADDSForest `
        -DomainName "$forestName" `
        -DomainNetbiosName "$forestMain" `
        -ForestMode "Windows2016Forest" `
        -DomainMode "Windows2016Forest" `
        -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) `
        -InstallDns `
        -NoRebootOnCompletion: $false `
        -Force:$true
}

#
# Install Domain if not already installed
#
# Check if a domain is already installed
if (Get-WindowsFeature AD-Domain-Services -ErrorAction SilentlyContinue) {
    Write-Host "> Warning: This server is already a domain controller." -ForegroundColor Yellow
} else {
    # No domain is installed
    Write-Host "> Warning: No domain is installed." -ForegroundColor Yellow
    try {
        Write-Host "> Getting the network configuration"
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        if ($adapter) {
            $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex
            $defaultGateway = Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix 0.0.0.0/0 | Select-Object -ExpandProperty NextHop
            $ipAddress = $ipConfig.IPAddress
            $subnetMask = $ipConfig.PrefixLength
            $adapterName = $adapter.Name
            Write-Host "> Network adapter: $($adapterName)"
            Write-Host "> IP address: $($ipAddress)"
            Write-Host "> Subnet mask: $($subnetMask)"
            Write-Host "> Default gateway: $($defaultGateway)"
        }
        else {
            Write-Host "No network adapter is currently up."
        }
    }
    catch {
        Write-Host "> Error: Something went wrong while getting the network configuration." -ForegroundColor Red
        Write-Error $_.Exception.Message
        Write-Host "> Exiting..." -ForegroundColor Red
        Pause
        exit
    }

    Write-Host "> This server is not a domain controller."
    # Create first DC in new forest/domain
    try {
        $domainName = Read-Host "Enter the name of the new domain (ex: intranet.local.be)"
        while ($domainName -eq "") {
            Write-Host "> Error: The domain name cannot be empty" -ForegroundColor Red
            $domainName = Read-Host "Enter the name of the new domain (ex: intranet.local.be)"
        }
        $siteName = Read-Host "Enter the name of the new site (ex: Brussels)"
        while ($siteName -eq "") {
            Write-Host "> Error: The site name cannot be empty" -ForegroundColor Red
            $siteName = Read-Host "Enter the name of the new site (ex: Brussels)"
        }
        $credentials = Get-Credential
        Write-Host "> Creating new domainController" -ForegroundColor Green
        Install-ADDSDomainController `
            -Credential $credentials `
            -DomainName $domainName `
            -InstallDns `
            -NoGlobalCatalog `
            -SiteName $siteName `
            -IPAddress $ipAddress `
            -Force
    } catch {
        Write-Host "> Error: Something went wrong while creating the domain controller." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
}


#
# Configure DNS
#
$preferredDNSServer = $dcIPAddress
$alternateDNSServer = $dc2IPAddress

# Check and set local DNS servers
$nic = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.Name -eq "Ethernet"} | Select-Object -First 1
$dnsServers = Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex | Select-Object -ExpandProperty ServerAddresses
if ($dnsServers[0] -ne $preferredDNSServer -or $dnsServers[1] -ne $alternateDNSServer) {
    $dnsServers = @($preferredDNSServer, $alternateDNSServer)
    Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $dnsServers
    Write-Host "Local DNS servers updated."
} else {
    Write-Host "Local DNS servers already set correctly."
}







