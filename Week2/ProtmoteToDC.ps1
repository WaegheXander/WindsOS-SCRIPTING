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
# ask if it wants a remote connection
#region
$ans = Read-Host "Do you want to connect to a remote computer? (Y/N)"
while ($true) {
    if ($ans.ToLower() -eq "y") {
        Enable-PSRemoting -Force
        $computer = Read-Host "Enter the name of the remote computer"
        while ($true) {
            if ($computer -ne "") {
                Write-Host "> Error: The computer name cannot be empty" -ForegroundColor Red
                $computer = Read-Host "Enter the name of the remote computer"
            }
            else {
                # test if the computer is reachable
                try {
                    Test-Connection -ComputerName $computer -Count 3 -Quiet
                    Write-Host "> Computer $computer is reachable" -ForegroundColor Green
                    Start-RemoteSession $computer
                }
                catch {
                    Write-Host "> Error: Computer $computer is not reachable" -ForegroundColor Red
                    $computer = Read-Host "Enter the name of the remote computer"
                }
            }
        }
        break
    } elseif ($ans.ToLower() -eq "n") {
        break
    } else {
        Write-Host "> Error: Invalid answer. Please enter Y or N" -ForegroundColor Red
        $ans = Read-Host "Do you want to connect to a remote computer? (Y/N)"
    }
}
#endregion

#
# start a remote session
#region
function Start-RemoteSession {
    param (
        $ComputerName
    )

    # check if a remote session is already open
    if (Get-PSSession -ComputerName $ComputerName) {
        Write-Host "> Error: A remote session is already open" -ForegroundColor Red
        $ans = Read-Host "Do you want to close the remote session? (Y/N)"
        while ($true) {
            if ($ans.ToLower() -eq "y") {
                # close the remote session
                try {
                    Remove-PSSession -ComputerName $ComputerName
                    Write-Host "> Remote session closed successfully" -ForegroundColor Green
                    break
                }
                catch {
                    Write-Host "> Error: Something went wrong while closing the remote session" -ForegroundColor Red
                    Write-Error $_.Exception.Message
                    break
                }
            }
            elseif ($ans.ToLower() -eq "n") {
                break
            }
            else {
                Write-Host "> Error: Invalid answer. Please enter Y or N" -ForegroundColor Red
                $ans = Read-Host "Do you want to close the remote session? (Y/N)"
            }
        }
    }
    else {
        # open a remote session
        try {
            $session = New-PSSession -ComputerName $ComputerName
            Write-Host "> Remote session opened successfully" -ForegroundColor Green
            Write-Host "> Connecting to remote session..." -ForegroundColor Yellow
            Enter-PSSession -Session $session
            Write-Host "> Connected to remote session" -ForegroundColor Green
        }
        catch {
            Write-Host "> Error: Something went wrong while opening the remote session" -ForegroundColor Red
            Write-Error $_.Exception.Message
        }
    }
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
#region
Import-Module ADDSDeployment
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

# install a Primary Domain Controller 
function install-PrimaryDC {
    $NetBiosName | Read-Host "Enter the name of the NetBiosName (ex. INTRANET)"
    $NetBiosName = $NetBiosName.ToUpper()

    $DomainName | Read-Host "Enter the name of the new forest ($NetBiosName.???)"
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
            -NoRebootOnCompletion:$True `
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
            -NoRebootOnCompletion:$True `
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
try {
    $siteName = (Get-ADSite -Identity "Default-First-Site-Name").Name
    if ($siteName -ne $SiteName) {
        Write-Host "> Renaming the default-first-site-name to $SiteName" -ForegroundColor Yellow
        Rename-ADSite -Identity "Default-First-Site-Name" -NewName $SiteName
        Write-Host "> Default-first-site-name renamed successfully." -ForegroundColor Green
    }
}
catch {
    Write-Host "> Error: Something went wrong while renaming the default-first-site-name." -ForegroundColor Red
    Write-Error $_.Exception.Message
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
    #check if dhcp server is authorized on the domain
    if (Get-DhcpServerInDC -erroraction SilentlyContinue) {
        Write-Host "> DHCP server is authorized on the domain." -ForegroundColor Green
    }
    else {
        try {
            Write-Host "> DHCP server is not authorized on the domain. Authorizing DHCP server on the domain" -ForegroundColor Yellow
            Add-DhcpServerInDC -DnsName (Get-WmiObject win32_computersystem).DNSHostName + "." + (Get-WmiObject win32_computersystem).Domain -IPAddress Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $nic | Select-Object -ExpandProperty IPAddress
            Write-Host "> DHCP server authorized on the domain." -ForegroundColor Green
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager\Roles" -Name "PendingXmlIdentifier" -Force
            Write-Host "> Removed PendingXmlIdentifier registry key." -ForegroundColor Green
        }
        catch {
            Write-Host "> Error: Something went wrong while authorizing the DHCP server on the domain." -ForegroundColor Red
            Write-Error $_.Exception.Message
        }
    }

    #check if there is a scope configured
    if (Get-DhcpServerv4Scope -erroraction SilentlyContinue) {
        Write-Host "> DHCP scope already configured." -ForegroundColor Green
    }
    else {
        try {
            Write-Host "> DHCP scope not configured. Configuring DHCP scope" -ForegroundColor Yellow
            $ipAddress = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $nic | Select-Object -ExpandProperty IPAddress
            $subnet = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $nic | Select-Object -ExpandProperty Prefix
            $networkAddress = ($ipAddress.Split(".")[0..2] -join ".") + ".0"
            $netID = "$networkAddress/$subnet"
            $startRange = ($ipAddress.Split(".")[0..2] -join ".") + ".1"
            $endRange = ($ipAddress.Split(".")[0..2] -join ".") + ".254"
            #TODO check for subnet and clal the max range
            Add-DhcpServerv4Scope -ComputerName $env:computername -Name "Main scope" -StartRange $startRange -EndRange $endRange -SubnetMask ConvertTo-SubnetMask-MaskBits $subnet
        }
        catch {
            Write-Host "> Error: Something went wrong while configuring the DHCP scope." -ForegroundColor Red
            Write-Error $_.Exception.Message
        }

        try {
            Set-DhcpServerv4OptionValue -OptionId 15 -Value (Get-WmiObject win32_computersystem).DNSHostName + "." + (Get-WmiObject win32_computersystem).Domain
            Set-DhcpServerv4OptionValue -OptionId 6 -Value ($primDNS, $secDNS)
            Set-DhcpServerv4OptionValue -OptionId 3 -Value (Get-NetRoute -InterfaceIndex 9 | Select-Object -ExpandProperty NextHop)
        }
        catch {
            Write-Host "> Error: Something went wrong while configuring the DHCP options." -ForegroundColor Red
            Write-Error $_.Exception.Message
        }
    }   
}

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