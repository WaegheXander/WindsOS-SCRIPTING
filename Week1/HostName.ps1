$IPType = "IPv4"

function checkValidIP {
    param (
        $ip
    )
    
    $ipRegex = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    if ($ip -match $ipRegex) {
        return $true
    } else {
        return $false
    }
}

#
# Setting Static IP address
#
$ip = Read-Host "Enter a valid IP address"
while (!(checkValidIP $ip)) {
    Write-Host "> Error: Invalid IP address" -ForegroundColor Red
    $ip = Read-Host "Enter a valid IP address"
}

$gateway = Read-Host "Enter a valid gateway address"
while (!(checkValidIP $gateway)) {
    Write-Host "> Error: Invalid gateway address" -ForegroundColor Red
    $gateway = Read-Host "Enter a valid gateway address"
}

$dnsPrim = Read-Host "Enter a valid DNS address"
while (!(checkValidIP $dnsPrim)) {
    Write-Host "> Error: Invalid DNS address" -ForegroundColor Red
    $dnsPrim = Read-Host "Enter a valid DNS address"
}

$dnsSecd = Read-Host "Enter a valid alternet DNS address"
while (!(checkValidIP $dnsSecd)) {
    Write-Host "> Error: Invalid DNS address" -ForegroundColor Red
    $dnsSecd = Read-Host "Enter a valid alternet DNS address"
}

$MaskBits = Read-Host "Enter a maskbits (ex 24))"
while ($MaskBits -lt 0 -or $MaskBits -gt 32) {
    Write-Host "> Error: Invalid MaskBit" -ForegroundColor Red
    $MaskBits = Read-Host "Enter a maskbits (ex 24))"
}

try {
    Write-Host "> Setting IP address"
    $adapterNR = Read-Host "Enter the number of the network adapter"    
    $adapter = "Ethernet$adapterNR"
    Write-Host "> adaptor name $adapter"
    break

    Set-NetIPInterface -InterfaceAlias $adapter -Dhcp Disabled
    Write-Host "> DHCP disabled" -ForegroundColor Green

    #remove old ip address 
    Get-NetIPAddress -InterfaceAlias $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
    Get-NetIPAddress -InterfaceAlias $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
    Write-Host "> Old IP address removed" -ForegroundColor Green

    # Set the IP address
    New-NetIPAddress -IPAddress $ip -PrefixLength $MaskBits -DefaultGateway $gateway -InterfaceAlias $adapter -AddressFamily $IPType
    Write-Host "> IP address set successfully" -ForegroundColor Green
    

    # Set the DNS servers
    Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses ($dnsPrim,$dnsSecd)
    Write-Host "> IP address & DNS servers set successfully" -ForegroundColor Green
}
catch {
    Write-Error $_.Exception.Message
}

$timezone = "Central European Standard Time"
Write-Host "> Setting correct timezone"
# check if the timezone is correct
if((Get-TimeZone).BaseUtcOffset -eq ([TimeSpan]::FromHours(1))) {
    Write-Host "> Timezone is already set" -ForegroundColor Green 
} else {
    Write-Host "> Warning: Timezone is not correct" -ForegroundColor Yellow
    Set-TimeZone -TimeZone $timezone
    Write-Host "> Timezone set to Central European Standard Time" -ForegroundColor Green
}

$ans = Read-Host "Do you want to enable remote desktop? (y/n)"
while (($ans.ToLower() -ne "y") -or ($ans.ToLower() -ne "n")) {
    if($ans.ToLower() -eq "y") {
        Write-Host "> Enabling remote desktop"
        # enable remote desktop
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
        # enable firewall rule
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Write-Host "> Remote desktop enabled successfully" -ForegroundColor Green
        break
    } elseif ($ans.ToLower() -eq "n")  {
        Write-Host "> Disabling remote desktop"
        # disable remote desktop
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 1
        # disable firewall rule
        Disable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Write-Host "> Remote desktop disabled successfully" -ForegroundColor Green
        break
    } else {
        Write-Host "> Error: Invalid input" -ForegroundColor Red
        $ans = Read-Host "Do you want to enable remote desktop? (y/n)"
    }
}

# disable the IE Enhanced Security Setting
Write-Host "> Disabling IE Enhanced Security"
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
Write-Host "IE Enhanced Security Setting disabled successfully" -ForegroundColor Green 


Write-Output "> Setting Control Panel view to small icons"
# check if the key exists
If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel")) {
    Write-Host "> Warning: Control Panel key does not exist" -ForegroundColor Yellow
    Write-Host "> Creating Control Panel key" -ForegroundColor Yellow
	New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" | Out-Null
}
# set the values
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 1
Write-Host "> Control Panel view set to small icons" -ForegroundColor Green

# enable the file extension to be shown
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 1
Write-Host "> File extension shown successfully" -ForegroundColor Green

$ans = Read-Host "> What do you want to change the Hostname to? (q to quit)"
while ($ans -ne "q") {
    if ($ans -eq $env:computername) {
        Write-Host "> That's the current name!" -ForegroundColor Yellow
    } else {
        Rename-Computer -NewName $ans -Force -Restart
        Write-Host "> Hostname changed successfully" -ForegroundColor Green
        Write-Host "> Restarting computer"
        break
    }
}
Write-Host ">" -ForegroundColor Green
Write-Host "> Alle Setting Set" -ForegroundColor Green
Write-Host ">" -ForegroundColor Green
Pause