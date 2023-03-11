# Variables
$forestName = "intranet"
$domainName = "intranet"
$domainNetBIOSName = "INTRANET"
$dcName = "DC1"
$dcIPAddress = "192.168.100.254"
$dc2IPAddress = "192.168.100.253"
$dcSiteName = "Kortrijk"
$adminCreds = Get-Credential

# Promote first server to DC
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment
Install-ADDSForest `
    -DomainName $forestName `
    -DomainNetbiosName $domainNetBIOSName `
    -DomainMode Win2016 `
    -ForestMode Win2016 `
    -InstallDns `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssword1" -AsPlainText -Force) `
    -Force:$true `
    -NoRebootOnCompletion:$true `
    -Confirm:$false

# Check if necessary role(s) are installed
$roles = Get-WindowsFeature | Where-Object {$_.Name -eq "AD-Domain-Services" -or $_.Name -eq "DNS"}
foreach ($role in $roles) {
    if ($role.Installed -ne $true) {
        # Install necessary role(s)
        Install-WindowsFeature $role.Name
    }
}

# Create first DC in new forest/domain
try {
    Install-ADDSDomainController `
        -Credential $adminCreds `
        -DomainName $domainName `
        -InstallDNS:$true `
        -SiteName $dcSiteName `
        -NoGlobalCatalog:$false `
        -CreateDnsDelegation:$false `
        -Force:$true `
        -Confirm:$false `
        -AllowPasswordReplicationAccountCreation:$true `
        -CriticalReplicationOnly:$false `
        -DatabasePath "C:\Windows\NTDS" `
        -LogPath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -Force:$true `
        -NoRebootOnCompletion:$true `
        -SkipPreCheck:$false `
        -Path "C:\Windows\NTDS" `
        -DomainAdministratorCredential $adminCreds `
        -Server $dcName `
        -IPAddress $dcIPAddress `
        -InstallDns:$true
}
catch {
    Write-Error $_.Exception.Message
}

# Variables
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

# Variables
$subnet = "255.255.255.0/24"
$zoneName = "mct.be"
$dnsServer = "mct.be"

# Create reverse lookup zone for subnet
Add-DnsServerPrimaryZone -NetworkId "$subnet" -ZoneName $zoneName

# Add pointer record for domain controller in reverse lookup zone
$ptrRecord = "$dcIPAddress.in-addr.arpa"
Add-DnsServerResourceRecordPtr -ZoneName $zoneName -Name $ptrRecord -PtrDomainName $dnsServer -CreatePtr
Write-Host "Pointer record added for $dnsServer in $zoneName."

# Rename default first site
Set-ADSite -Identity "Default-First-Site-Name" -Name $dcsiteName

# Add subnet to site
Set-ADSite -Identity $dcsiteName -Add @{"Subnets" = $subnet}
Write-Host "Subnet $subnet added to $dcsiteName."

# Variables
$dhcpScope = "192.168.100.0"
$dhcpRangeStart = "192.168.100.2"
$dhcpRangeEnd = "192.168.100.252"
$dhcpSubnetMask = "255.255.255.0"
$dhcpRouter = "192.168.100.0"
$dhcpDNSServers = "192.168.100.254", "192.168.100.253"

# Check if DHCP server role is installed and install if necessary
if ((Get-WindowsFeature -Name DHCP).Installed -ne "True") {
    Install-WindowsFeature -Name DHCP
    Write-Host "DHCP server role installed."
} else {
    Write-Host "DHCP server role already installed."
}

# Configure DHCP server and scope
Add-DhcpServerv4Scope -Name "Main Scope" -StartRange $dhcpRangeStart -EndRange $dhcpRangeEnd -SubnetMask $dhcpSubnetMask -ScopeId $dhcpScope -State Active
Set-DhcpServerv4OptionValue -OptionId 3 -Value $dhcpRouter -ScopeId $dhcpScope
Set-DhcpServerv4OptionValue -OptionId 6 -Value $dhcpDNSServers -ScopeId $dhcpScope

# Authorize DHCP server and remove warning in Server Manager
Add-DhcpServerInDC -DnsName $env:COMPUTERNAME -IPAddress $dcIPAddress
Set-DhcpServerDnsCredential -Credential (Get-Credential)
Set-DhcpServerMode -DhcpServerMode "Both"
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\ServerManager\Roles" -Name "PendingXmlIdentifier" -Force
Write-Host "DHCP server authorized and configured."
