#
# Check if the input is a valid IP address
#region
function checkValidIP {
    param (
        $ip
    )
    
    $ipRegex = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    if ($ip -match $ipRegex) {
        return $true
    }
    else {
        return $false
    }
}
#endregion

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
    $nic = Get-NetAdapter -Physical | Where-Object { $_.PhysicalMediaType -match "802.3"-and $_.status -eq "up"}
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
#region
Import-Module ADDSDeployment
# install a Primary Domain Controller 
function install-PrimaryDC {
    $NetBiosName = Read-Host "Enter the name of the NetBiosName (ex. INTRANET)"
    $NetBiosName = $NetBiosName.ToUpper()

    $DomainName = Read-Host "Enter the name of the new forest ($NetBiosName.???)"
    $forestName = "$NetBiosName.$DomainName"
    Write-Host "> Creating new forest $forestName..." -ForegroundColor Yellow
    try {
        Install-ADDSForest `
            -DomainName $forestName `
            -DomainNetbiosName $NetBiosName `
            -DomainMode "WinThreshold" `
            -ForestMode "WinThreshold" `
            -InstallDns:$True `
            -SafeModeAdministratorPassword (ConvertTo-SecureString (Read-Host "Password for PrimaryDC" -AsSecureString) -AsPlainText -Force) `
            -NoRebootOnCompletion:$True `
            -Force:$True;
        Write-Host "> Forest $forestName created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "> Error: Something went wrong while creating the forest." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
}

# install a backup domain controller
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
            -NoRebootOnCompletion:$True `
            -Force:$True;
        Write-Host "> Domain $DomainName created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "> Error: Something went wrong while creating the domain." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
}

# Check if it is an Primary or a Backup Domain Controller
if ((Get-WmiObject -Class Win32_ComputerSystem).DomainRole -eq 5) {
    # Primary Domain Controller
    Write-Host "> Warining: A forest is already installed." -ForegroundColor Yellow
    Write-Host "> Primary Domain Controller" -ForegroundColor Green
}
elseif ((Get-WmiObject -Class Win32_ComputerSystem).DomainRole -eq 4) {
    # Backup Domain Controller
    Write-Host "> Warining: A forest is already installed." -ForegroundColor Yellow
    Write-Host "> Backup Domain Controller" -ForegroundColor Green
}
else {
    $ans = Read-Host "Do you want to create a Primary or a Backup Domain Controller? (P/B)"
    while ($true) {
        if ($ans.ToLower() -eq "p") {
            install-PrimaryDC
            break
        }
        elseif ($ans.ToLower() -eq "b") {
            install-BackupDC
            break
        }
        Write-Host "> Error: Invalid answer. Please enter P or B" -ForegroundColor Red
        $ans = Read-Host "Do you want to create a Primary or a Backup Domain Controller? (P/B)"
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
        while (!(checkValidIP($secDNS))) {
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
        Add-DnsServerPrimaryZone -NetworkID $netID -ReplicationScope "Domain" -DynamicUpdate "Secure"
        Write-Host "> Creating PTR record" -ForegroundColor Yellow 
        # Create the PTR record
        $PtrDomainName = (Get-WmiObject win32_computersystem).DNSHostName + "." + (Get-WmiObject win32_computersystem).Domain;
        Add-DnsServerResourceRecordPtr -ZoneName $zoneName -Name $env:computername -PtrDomainName $PtrDomainName
        Write-Host "> Reverse lookup zone $zoneName created successfully." -ForegroundColor Green   

        Register-DnsClient
    }
}
catch {
    Write-Host "> Error: Something went wrong while creating the reverse lookup zone." -ForegroundColor Red
    Write-Error $_.Exception.Message
}
#endregion

#
# rename the default-first-site-name
#region
Write-Host "> Renaming the default-first-site-name" -ForegroundColor Yellow
$current = (Get-ADObject -SearchBase (Get-ADRootDSE).ConfigurationNamingContext -Filter 'objectclass -like "site"').name
Write-Host "> The current name of the default-first-site-name is $current" -ForegroundColor Yellow
$ans = Read-Host "Do you want to rename the default-first-site-name? (Y/N)"
while ($true) {
    if ($ans.ToLower() -eq "y") {
        $siteName = Read-Host "Enter the name of the site"
        while ($true) {
            if ($siteName -eq "") {
                Write-Host "> Error: Site name cannot be empty." -ForegroundColor Red
            }
            else {
                if (((Get-ADObject -SearchBase (Get-ADRootDSE).ConfigurationNamingContext -Filter 'objectclass -like "site"').name).ToUpper() -eq $siteName.ToUpper()) {
                    Write-Host "> Error: Site name already exists." -ForegroundColor Red
                    continue
                }
                else {
                    break
                }
            }
            $siteName = Read-Host "Enter the name of the site"
        }

        Get-ADObject -SearchBase (Get-ADRootDSE).ConfigurationNamingContext -Filter 'objectclass -like "site"' | Rename-ADObject -NewName $SiteName;
        break
    }
    elseif ($ans.ToLower() -eq "n") {
        break
    }
    Write-Host "> Error: Invalid answer. Please enter Y or N" -ForegroundColor Red
    $ans = Read-Host "Do you want to rename the default-first-site-name? (Y/N)"
}
#endregion

#
# Configure DHCP
#region
if (Get-WindowsFeature -Name DHCP -erroraction SilentlyContinue) {
    Write-Host "> DHCP server role already installed." -ForegroundColor Green
}
else {
    try {
        Write-Host "> DHCP not installed. Installing DHCP server role" -ForegroundColor Yellow
        Install-WindowsFeature -Name DHCP -IncludeManagementTools
        Write-Host "> DHCP server role installed." -ForegroundColor Green
    }
    catch {
        Write-Host "> Error: Something went wrong while installing the DHCP server role." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
}
#endregion

#
#check if dhcp server is authorized on the domain
#region
if (Get-DhcpServerInDC -erroraction SilentlyContinue) {
    Write-Host "> DHCP server is authorized on the domain." -ForegroundColor Green
}
else {
    try {
        Write-Host "> DHCP server is not authorized on the domain. Authorizing DHCP server on the domain" -ForegroundColor Yellow
        Add-DhcpServerInDC
        Write-Host "> DHCP server authorized on the domain." -ForegroundColor Green
        Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2
        Write-Host "> Removed PendingXmlIdentifier registry key." -ForegroundColor Green
    }
    catch {
        Write-Host "> Error: Something went wrong while authorizing the DHCP server on the domain." -ForegroundColor Red
        Write-Error $_.Exception.Message
    }
}
#endregion

#
#check if there is a scope configured
#region
try {
    if (Get-DhcpServerv4Scope) {
        Write-Host "> DHCP scope already configured." -ForegroundColor Green
    }
    else {
        Write-Host "> DHCP scope not configured. Configuring DHCP scope" -ForegroundColor Yellow
        $ipAddress = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $nic | Select-Object -ExpandProperty IPAddress
        $subnet = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $nic | Select-Object -ExpandProperty PrefixLength
        $subnetmask = ConvertTo-SubnetMask $subnet
        $networkAddress = ($ipAddress.Split(".")[0..2] -join ".") + ".0"
        $netID = "$networkAddress/$subnet"
        $startRange = ($ipAddress.Split(".")[0..2] -join ".") + ".1"
        $endRange = ($ipAddress.Split(".")[0..2] -join ".") + ".254"
        #TODO check for subnet and clal the max range
        Add-DhcpServerv4Scope -ComputerName $env:computername -Name "Main scope" -StartRange $startRange -EndRange $endRange -SubnetMask $subnetmask -State Active -Confirm:$false
        Write-Host "> DHCP scope configured." -ForegroundColor Green
    }
}
catch {
    Write-Host "> Error: Something went wrong while configuring the DHCP scope." -ForegroundColor Red
    Write-Error $_.Exception.Message
}

try {
    Write-Host "> Configuring DHCP options" -ForegroundColor Yellow
    if (Get-DhcpServerv4OptionValue -OptionId 15 -ErrorAction Ignore) {
        Write-Host "> DHCP option 15 already configured." -ForegroundColor Green
    }
    else {
        Set-DhcpServerv4OptionValue -OptionId 15 -Value (Get-WmiObject win32_computersystem).DNSHostName + "." + (Get-WmiObject win32_computersystem).Domain -Force
        Write-Host "> DHCP option 15 configured." -ForegroundColor Green
    }
    if (Get-DhcpServerv4OptionValue -OptionId 6 -ErrorAction Ignore) {
        Write-Host "> DHCP option 6 already configured." -ForegroundColor Green
    }
    else {
        Set-DhcpServerv4OptionValue -OptionId 6 -Value ($primDNS, $secDNS) -Force
        Write-Host "> DHCP option 6 configured." -ForegroundColor Green
    }

    if (Get-DhcpServerv4OptionValue -OptionId 3 -ErrorAction Ignore) {
        Write-Host "> DHCP option 3 already configured." -ForegroundColor Green
    }
    else {
        Set-DhcpServerv4OptionValue -OptionId 3 -Value ((Get-NetRoute -InterfaceIndex $nic).NextHop -split '0.0.0.0') -Force
        Write-Host "> DHCP option 3 configured." -ForegroundColor Green
    }
    Write-Host "> DHCP options configured." -ForegroundColor Green
}
catch {
    Write-Host "> Error: Something went wrong while configuring the DHCP options." -ForegroundColor Red
    Write-Error $_.Exception.Message
}
#endregion

function ConvertTo-SubnetMask {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 32)]
        [Int] $MaskBits
    )
    $mask = ([Math]::Pow(2, $MaskBits) - 1) * [Math]::Pow(2, (32 - $MaskBits))
    $bytes = [BitConverter]::GetBytes([UInt32] $mask)
    return (($bytes.Count - 1)..0 | ForEach-Object { [String] $bytes[$_] }) -join "."
}