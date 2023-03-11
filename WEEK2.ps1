# Variables
$domainName = "mynewdomain.local"
$domainNetBIOSName = "MYNEWDOMAIN"
$domainAdminName = "Administrator"
$domainAdminPassword = "MyPassword123!"
$subnetCIDR = "192.168.1.0/24"
$serverIP = "192.168.1.10"
$dnsServerIP = "192.168.1.10"
$dhcpServerIP = "192.168.1.10"
$dhcpScopeStart = "192.168.1.50"
$dhcpScopeEnd = "192.168.1.100"
$dhcpSubnetMask = "255.255.255.0"
$dhcpRouter = "192.168.1.1"
$dhcpDNS1 = "192.168.1.10"
$dhcpDNS2 = "192.168.1.11"

# Install Active Directory Domain Services feature
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Promote the first server to the first DC for the new forest/domain
Install-ADDSForest `
    -DomainName $domainName `
    -DomainNetbiosName $domainNetBIOSName `
    -InstallDNS `
    -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText $domainAdminPassword -Force) `
    -Force

# Check if the necessary role(s) is/are installed. If not, install them.
if (-not (Get-WindowsFeature RSAT-AD-PowerShell)) {
    Install-WindowsFeature RSAT-AD-PowerShell
}

# Check and correct local DNS server settings
$nic = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.InterfaceDescription -notlike "*Hyper-V*"}
$dnsServers = $nic | Get-DnsClientServerAddress
if ($dnsServers.ServerAddresses[0] -ne $dnsServerIP) {
    $dnsServers.ServerAddresses = $dnsServerIP
    Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $dnsServers.ServerAddresses
}

# Create the reverse lookup zone for the subnet and add pointer record for the first DC
Add-DnsServerPrimaryZone -Name (ConvertTo-DnsName -Name $subnetCIDR -Type Reverse) -ZoneFile "192.168.1.in-addr.arpa.dns" -DynamicUpdate Secure
Add-DnsServerResourceRecordPtr -ZoneName (ConvertTo-DnsName -Name $subnetCIDR -Type Reverse) -Name $serverIP.Split('.')[3] -PTRDomainName (ConvertTo-DnsName -Name "$serverIP.$domainName" -Type FQDN) -CreatePtr

# Rename the default site and add subnet to it
$siteName = "My Site"
$subnet = $subnetCIDR
Set-ADReplicationSite -Identity "Default-First-Site-Name" -Name $siteName
$subnetObject = Get-ADReplicationSubnet -Filter {Name -like $subnet}
if ($subnetObject -eq $null) {
    New-ADReplicationSubnet -Name $subnet -Site $siteName -Location "My Location"
} else {
    Set-ADReplicationSubnet -Identity $subnetObject -Site $siteName
}

# Configure the first server as the first DHCP server in the Windows network
Install-WindowsFeature DHCP
Add-DhcpServerInDC

# Check if the necessary server role(s) is/are installed. If not, install them.
if (-not ( Get-WindowsFeature -Name DHCP -ComputerName $DC1)) {
    Install-WindowsFeature -Name DHCP -ComputerName $DC1
}


# Configure the second server

# Set hostname
$hostname = "DC2"
Rename-Computer -NewName $hostname -Restart

# Set static IP address and preferred DNS server
$ipAddress = "192.168.1.2"
$subnetMask = "255.255.255.0"
$defaultGateway = "192.168.1.1"
$dnsServer = "192.168.1.1"
$dnsSuffix = "domain.local"
$networkAdapter = Get-NetAdapter | Where-Object { $_.Name -eq "Ethernet" }
New-NetIPAddress -InterfaceAlias $networkAdapter.Name -IPAddress $ipAddress -PrefixLength 24 -DefaultGateway $defaultGateway
Set-DnsClientServerAddress -InterfaceAlias

