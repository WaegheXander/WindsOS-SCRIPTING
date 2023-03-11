$ComputerName = "DC01"
# Rename the computer
Rename-Computer -NewName $ComputerName -WhatIf
Write-Host "Computer renamed to $ComputerName successfully a reboot is required" -ForegroundColor Green

$ip = '192.168.1.100'
$gateway = '192.168.1.1'
$MaskBits = '24'
$IPType = "IPv4"

# get ethernet adapter
$adapter = Get-NetAdapter -Name Ethernet 

# disable dhcp
$adapter | Set-NetIPInterface -Dhcp Disabled 

#remove old ip address
$adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false 
$adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false 

# Set the IP address
$adapter | New-NetIPAddress `
    -IPAddress $ip `
    -PrefixLength $MaskBits `
    -DefaultGateway $gateway `
    -InterfaceAlias Ethernet `
    -AddressFamily $IPType -WhatIf

# Set the DNS
$dnsPrim = '192.168.1.100'
$dnsSecd = '192.168.1.101'

Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses ($dnsPrim,$dnsSecd) -WhatIf

Write-Host "IP address & DNS servers set successfully" -ForegroundColor Green

#check if the timezone is correct
if((Get-TimeZone).BaseUtcOffset -eq ([TimeSpan]::FromHours(1))) {
    Write-Host "Timezone is correct" -ForegroundColor Green 
} else {
    Write-Host "Timezone is not correct" -ForegroundColor Red
    Set-TimeZone -TimeZone "Central European Standard Time" -WhatIf
    Write-Host "Timezone set to Central European Standard Time" -ForegroundColor Green
}


# enable remote desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -WhatIf

# enable firewall rule
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -WhatIf

# restart the remote desktop service to apply the changes
Restart-Service -Name TermService -WhatIf

Write-Host "Remote desktop enabled successfully" -ForegroundColor Green

# disable the IE Enhanced Security Setting
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -WhatIf
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -WhatIf

#stop internet explorer to apply the changes
Stop-Process -Name Explorer -WhatIf

Write-Host "IE Enhanced Security Setting disabled successfully" -ForegroundColor Green 

# enable the control panel view to be set to small icons
# Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 1 -WhatIf

Write-Host "Control panel view set to small icons successfully" -ForegroundColor Green

# enable the file extension to be shown
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -WhatIf

Write-Host "File extension shown successfully" -ForegroundColor Green

# reboot the computer
Restart-Computer -WhatIf

Pause

