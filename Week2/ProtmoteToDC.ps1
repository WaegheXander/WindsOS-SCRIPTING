#
# Check if the script is running as administrator
#region 
Write-Host "> Checking permissions"
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "> Error: Insufficient permissions to run this script. Open the PowerShell console as administrator and try again." -ForegroundColor Red
    Pause
    Exit
}
else {
    Write-Host "> Code is running as administrator" -ForegroundColor Green
}
#endregion

#
# get the nic
#region
try {
    $nic = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias (Get-NetAdapter).Name | Select-Object -ExpandProperty InterfaceIndex)
}
catch {
    Write-Host "> Error: No network adapter found" -ForegroundColor Red
    Pause
    Exit
}
#endregion

#
# Check if AD-Domain-Services is installed
#region
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
#endregion

#
# Install Forest if not already installed
#Region
Import-Module ADDSDeployment
# Check if a domain controller is already installed
if (Get-ADDomainController) {
    # A forest is already installed
    Write-Host "> Warining: A forest is already installed." -ForegroundColor Yellow
    #get the forest name
    $forestName = (Get-WmiObject Win32_ComputerSystem).Domain
    Write-Host "> Forest name: $forestName" -ForegroundColor Green

    # Check if it is an Primary or a Backup Domain Controller
    if ((Get-WmiObject -Class Win32_ComputerSystem).DomainRole -eq 5) {
        # Primary Domain Controller
        Write-Host "> Primary Domain Controller" -ForegroundColor Green
    }
    elseif ((Get-WmiObject -Class Win32_ComputerSystem).DomainRole -eq 4) {
        # Backup Domain Controller
        Write-Host "> Backup Domain Controller" -ForegroundColor Green
    }

}
else {
    $ans = Read-Host "Do you want to create a Primary or a Backup Domain Controller? (P/B)"
    while ($ans.ToLower() -ne "p" -or $ans.ToLower() -ne "b") {
        Write-Host "> Error: Invalid answer. Please enter P or B" -ForegroundColor Red
        $ans = Read-Host "Do you want to create a Primary or a Backup Domain Controller? (P/B)"
    }
    if ($ans.ToLower() -eq "p") {
        install-PrimaryDC
    }
    elseif ($ans.ToLower() -eq "b") {
        install-BackupDC
    }
}

# install a Primary Domain Controller 
function install-PrimaryDC {
    $NetBiosName = Read-Host "Enter the name of the NetBiosName (ex. INTRANET)"
    while ($NetBiosName -eq "") {
        Write-Host "The NetBiosName cannot be empty" -ForegroundColor Red
        $NetBiosName = Read-Host "Enter the name of the NetBiosName (ex. INTRANET)"
    }
    $NetBiosName = $NetBiosName.ToUpper()

    $DomainName = Read-Host "Enter the name of the new forest ($NetBiosName.???)"
    while ($DomainName -eq "") {
        Write-Host "The forest name cannot be empty" -ForegroundColor Red
        $DomainName = Read-Host "Enter the name of the new forest ($NetBiosName.???)"
    }
    $forestName = $NetBiosName.$DomainName
    Write-Host "> Creating new forest $forestName..." -ForegroundColor Yellow
    try {
        Install-ADDSForest `
            -DomainName $forestName `
            -DomainNetbiosName $NetBiosName `
            -DomainMode "WinThreshold" `
            -ForestMode "WinThreshold" `
            -InstallDns:$True `
            -SafeModeAdministratorPassword (ConvertTo-SecureString (Read-Host "Password for PrimaryDC" -AsSecureString) -AsPlainText -Force) `
            -Force:$True;
        Write-Host "> Forest $forestName created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "> Error: Something went wrong while creating the forest." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
}

# install a secondary domain controller in an existing forest
function install-BackupDC {
    $DomainName = (Get-WmiObject Win32_ComputerSystem).Domain
    Write-Host "> Creating Backup domain controller" -ForegroundColor Yellow
    try {
        Install-ADDSDomainController `
            -DomainMode "WinThreshold" `
            -DomainMode "WinThreshold" `
            -DomainName $DomainName `
            -DomainNetbiosName $DomainName `
            -SafeModeAdministratorPassword (ConvertTo-SecureString (Read-Host "Password for BackupDC" -AsSecureString) -AsPlainText -Force) `
            -Force:$True;
        Write-Host "> Domain $DomainName created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "> Error: Something went wrong while creating the domain." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
}
#endregion


#
# Configure DNS
#region
try {
    $CurrentDns = Get-DnsClientServerAddress -InterfaceIndex $nic;
    if ($CurrentDns.ServerAddresses -ne $DnsServers) {
        Write-Host "> Configuring DNS servers..." -ForegroundColor Yellow
        $primDNS = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $nic | Select-Object -ExpandProperty IPAddress
        $secDNS = Read-Host "Enter the secondary DNS server"
        while (!($secDNS -as [IPAddress])) {
            Write-Host "> Error: Invalid IP address" -ForegroundColor Red
            $secDNS = Read-Host "Enter the secondary DNS server"
        }
        Set-DnsClientServerAddress -InterfaceIndex $nic -ServerAddresses ($primDNS, $secDNS);
        Write-Host "> DNS servers configured successfully." -ForegroundColor Green
    }
}
catch {
    Write-Host "> Error: Something went wrong while configuring the DNS servers." -ForegroundColor Red
    Write-Error $_.Exception.Message
}
#endregion

#
# Configure Reverse Lookup Zone
#region
# Get the IP address and subnet of the Ethernet adapter automatically
try {
    $adapter = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $nic
    $ipAddress = $adapter | Get-NetIPAddress -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress
    $subnet = $adapter | Get-NetIPAddress -AddressFamily IPv4 | Select-Object -ExpandProperty PrefixLength
    $networkAddress = ($ipAddress.Split(".")[0..2] -join ".") + ".0"
    $netID = "$networkAddress/$subnet"

    # Check if a reverse lookup zone exists for the subnet
    $zoneName = (($netID -split '\.')[2, 1, 0] -join '.') + ".in-addr.arpa"
    $zoneExists = Get-DnsServerZone -Name $zoneName -ErrorAction SilentlyContinue
    if ($zoneExists) {
        Write-Host "> Warning: Reverse lookup zone already exists." -ForegroundColor Yellow
    }
    else {
        Write-Output "> Warning: Reverse lookup zone does not exist." -ForegroundColor Yellow
        Write-Host "> Creating reverse lookup zone $zoneName" -ForegroundColor Yellow
        # Create the reverse lookup zone
        Add-DnsServerPrimaryZone -NetworkID $netID -ReplicationScope "Domain"
        Write-Host "> Creating PTR record" -ForegroundColor Yellow
        # Create the PTR record
        $PtrDomainName = (Get-WmiObject win32_computersystem).DNSHostName + "." + (Get-WmiObject win32_computersystem).Domain;
        Add-DnsServerResourceRecordPtr -ZoneName $zoneName -Name $env:computername -PtrDomainName $PtrDomainName
        Write-Host "> Reverse lookup zone $zoneName created successfully." -ForegroundColor Green
    }
}
catch {
    Write-Host "> Error: Something went wrong while creating the reverse lookup zone." -ForegroundColor Red
    Write-Error $_.Exception.Message
}
#endregion


function Add-ReversLookupZone {
    <#
        .SYNOPSIS
        Add the reverse lookup zone
        .DESCRIPTION
        Adds the reverse lookup zone for the subnet and makes sure the pointer record of the first domain controller appears in that zone
        .EXAMPLE
        Add-ReversLookupZone
    #>
    # Get the interface index of the network adapter that is connected to the network
    $InterfaceIndex = (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notlike 'Microsoft*' -and $_.InterfaceAlias -notlike '*Virtual*' } | Select-Object -ExpandProperty InterfaceIndex); # Get the interface index of the network adapter that is connected to the network
    # Create the reverse lookup zone for the subnet and make sure the pointer record of the first domain controller appears in that zone
    $Ipconfig = Get-NetIPAddress | Where-Object { $_.InterfaceIndex -eq $InterfaceIndex -and $_.AddressFamily -eq 'IPv4' -and $_.InterfaceAlias -notlike '*Loopback*' }; # Get ipconfig of the first network adapter
    
    $Subnet = Out-NetworkIpAddress -IpAddress $Ipconfig.IpAddress -PrefixLength ($Ipconfig.PrefixLength); # Get the network part of the IP address
   
    Add-DnsServerPrimaryZone -NetworkID $Subnet -ReplicationScope "Domain" -DynamicUpdate "Secure";
    Add-DnsServerResourceRecordPTR -Name $env:computername -PtrDomainName Get-ComputerFQDN -ZoneName ("0." + (Get-ReverseLookupZoneName -InterfaceIndex $InterfaceIndex));
}
