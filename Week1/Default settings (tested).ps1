$IPType = "IPv4"

#
# Check if the input is a valid IP address
#
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
while ($MaskBits -le 0 -or $MaskBits -ge 32) {
    Write-Host "> Error: Invalid MaskBit" -ForegroundColor Red
    $MaskBits = Read-Host "Enter a maskbits (ex 24))"
}

Write-Host "> Setting IP address"
# Get the network adapter
Get-NetAdapter -Name *
$adapterNR = Read-Host "Enter the number of the network adapter"
while ($True) {
    if ($adapterNR -ge 0) {
        $adapterName = "Ethernet$adapterNR"
        break
    }
    else {
        Write-Host "> Error: Invalid input" -ForegroundColor Red
        Get-NetAdapter -Name *
        $adapterNR = Read-Host "Enter the number of the network adapter"
    }
}  

try {
    # Disable DHCP
    Set-NetIPInterface -InterfaceAlias $adapterName -Dhcp Disabled
    Write-Host "> DHCP disabled" -ForegroundColor Green
}
catch {
    Write-Host "> Something went wrong with disabling DHCP" -ForegroundColor Red
    Write-Error $_.Exception.Message
}
    
try {
    # Remove old ip address 
    Remove-NetRoute -AddressFamily $IPType -InterfaceAlias $adapterName -Confirm:$false 
    Remove-NetIPAddress -AddressFamily $IPType -InterfaceAlias $adapterName -Confirm:$false
    Write-Host "> Old IP address removed" -ForegroundColor Green
}
catch {
    Write-Host "> Error: Something went wrong with removing old IP address" -ForegroundColor Red
    Write-Error $_.Exception.Message
}

try {
    # Set the IP address
    New-NetIPAddress -IPAddress $ip -PrefixLength $MaskBits -DefaultGateway $gateway -InterfaceAlias $adapterName -AddressFamily $IPType
    Write-Host "> IP address set successfully" -ForegroundColor Green
}
catch {
    Write-Host "> Error: Something went wrong with setting the IP address" -ForegroundColor Red
    Write-Error $_.Exception.Message
}
    
try {
    # Set the DNS servers
    Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses ($dnsPrim, $dnsSecd)
    Write-Host "> IP address & DNS servers set successfully" -ForegroundColor Green
}
catch {
    Write-Host "> Error: Something went wrong with setting the DNS servers" -ForegroundColor Red
    Write-Error $_.Exception.Message
}

#
# Setting correct timezone
#
$timezone = "Central European Standard Time"
Write-Host "> Setting correct timezone"
# check if the timezone is correct
if ((Get-TimeZone).BaseUtcOffset -eq ([TimeSpan]::FromHours(1))) {
    Write-Host "> Timezone is already set" -ForegroundColor Green 
}
else {
    Write-Host "> Warning: Timezone is not correct" -ForegroundColor Yellow
    # set the timezone
    Set-TimeZone -TimeZone $timezone
    Write-Host "> Timezone set to Central European Standard Time" -ForegroundColor Green
}

#
# Enable/Disable remote desktop
#
$ans = Read-Host "Do you want to enable remote desktop? (y/n)"
while ($True) {
    if ($ans.ToLower() -eq "y") {
        try {
            Write-Host "> Enabling remote desktop"
            # enable remote desktop
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
            # enable firewall rule
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
            Write-Host "> Remote desktop enabled successfully" -ForegroundColor Green
            break
        }
        catch {
            Write-Host "> Error: Something went wrong with enabling remote desktop" -ForegroundColor Red
            Write-Error $_.Exception.Message
        }
    }
    elseif ($ans.ToLower() -eq "n") {
        try {
            Write-Host "> Disabling remote desktop"
            # disable remote desktop
            Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 1
            # disable firewall rule
            Disable-NetFirewallRule -DisplayGroup "Remote Desktop"
            Write-Host "> Remote desktop disabled successfully" -ForegroundColor Green
            break
        }
        catch {
            Write-Host "> Error: Something went wrong with disabling remote desktop" -ForegroundColor Red
            Write-Error $_.Exception.Message
        }
    }
    else {
        Write-Host "> Error: Invalid input" -ForegroundColor Red
        $ans = Read-Host "Do you want to enable remote desktop? (y/n)"
    }
}

#
# Disable IE Enhanced Security
#
try {
    Write-Host "> Disabling IE Enhanced Security"
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Write-Host "IE Enhanced Security Setting disabled successfully" -ForegroundColor Green 
}
catch {
    Write-Host "> Error: Something went wrong with disabling IE Enhanced Security" -ForegroundColor Red
    Write-Error $_.Exception.Message
}

#
# Setting Control Panel view to small icons
#
try {
    Write-Output "> Setting Control Panel view to small icons"
    # check if the key exists if not create it
    If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel")) {
        Write-Host "> Warning: Control Panel key does not exist" -ForegroundColor Yellow
        Write-Host "> Creating Control Panel key" -ForegroundColor Yellow
        New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" | Out-Null
    }
    # setting the view to small icons
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "StartupPage" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name "AllItemsIconView" -Type DWord -Value 1
    Write-Host "> Control Panel view set to small icons" -ForegroundColor Green
}
catch {
    Write-Host "> Error: Something went wrong with setting Control Panel view to small icons" -ForegroundColor Red
    Write-Error $_.Exception.Message
}


#
# enable the file extension to be shown
#
try {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 1
    Write-Host "File extension shown successfully" -ForegroundColor Green
}
catch {
    Write-Host "> Error: Something went wrong with enabling the file extension to be shown" -ForegroundColor Red
    Write-Error $_.Exception.Message
}

#
# Setting the hostname
#
$ans = Read-Host "> Do you want to change the hostname? (y/n)"
while ($True) {
    if ($ans.ToLower() -eq "y") {
        $ans = Read-Host "> What do you want the new hostname to be?"
        if ($ans -eq $env:computername) {
            Write-Host "> That's the current name!" -ForegroundColor Yellow
            break
        }
        else {
            try {
                Rename-Computer -NewName $ans
                Write-Host "> Hostname changed successfully" -ForegroundColor Green
                break
            }
            catch {
                Write-Host "> Error: Something went wrong with changing the hostname" -ForegroundColor Red
                Write-Error $_.Exception.Message
            }
        }
    }
    elseif ($ans.ToLower() -eq "n") {
        Write-Host "> Hostname not changed" -ForegroundColor Green
        break
    }
}
Write-Host "> Hostname set to $env:computername" -ForegroundColor Green

Write-Host ">" -ForegroundColor Green
Write-Host "> Alle Setting Set" -ForegroundColor Green
Write-Host "> The pc will reboot now to apply the changes" -ForegroundColor Green
Write-Host ">" -ForegroundColor Green
Pause
Restart-Computer -Force