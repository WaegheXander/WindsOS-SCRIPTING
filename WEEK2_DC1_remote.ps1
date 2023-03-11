# create a remote session to DC2
Enable-PSRemoting -Force
Enter-PSSession -ComputerName DC2 -Credential (Get-Credential)

# Set variables
$domainName = "INTRANET"
$domainAdmin = "INTRANET\administrator"
$domainAdminPassword = "P@ssword1"
$dnsServerIPAddress = "192.168.1.1"

# Check if Active Directory Domain Services is installed
$adRole = Get-WindowsFeature -Name AD-Domain-Services
if ($adRole.Installed -ne "True") {
    # Install Active Directory Domain Services
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
}

# Check if DNS Server is installed
$dnsRole = Get-WindowsFeature -Name DNS
if ($dnsRole.Installed -ne "True") {
    # Install DNS Server
    Install-WindowsFeature -Name DNS -IncludeManagementTools
}

# Promote server to additional domain controller
Install-ADDSDomainController `
    -InstallDNS:$true `
    -DomainName $domainName `
    -Credential (Get-Credential $domainAdmin) `
    -SafeModeAdministratorPassword (ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force) `
    -NoRebootOnCompletion:$false `
    -Force:$true

# Wait for server to reboot
Start-Sleep -s 60

# Set DNS server settings after reboot
$nic = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.PhysicalMediaType -eq "802.3"}
Set-DnsClientServerAddress -InterfaceIndex $nic.IfIndex -ServerAddresses $dnsServerIPAddress
Set-DnsClient -InterfaceIndex $nic.IfIndex -ConnectionSpecificSuffix $domainName -RegisterThisConnectionsAddress $true

# Install DHCP server role if not already installed
$DHCPInstalled = Get-WindowsFeature -Name DHCP | Select-Object -ExpandProperty InstallState
if ($DHCPInstalled -eq 'Available') {
    Install-WindowsFeature -Name DHCP
}

# Authorize the DHCP server
Add-DhcpServerInDC

# Remove warning in Server Manager
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ServerManager\Roles\12' -Name ConfigurationState -Value 2

# Configure the DHCP server for load balancing
$DHCPPartnerServerFQDN = "DC1"
$LoadBalancePercent = 60
Add-DhcpServerv4Failover -ScopeId 192.168.1.0 -PartnerServer $DHCPPartnerServerFQDN -LoadBalancePercent $LoadBalancePercent

# Configure DHCP server options
Set-DhcpServerv4OptionValue -OptionId 006 -Value "192.168.100.253","192.168.100.254" -ScopeId 192.168.100.0
Set-DhcpServerv4OptionValue -OptionId 015 -Value "DC1" -ScopeId 192.168.100.0

