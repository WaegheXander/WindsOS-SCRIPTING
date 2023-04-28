#
# Install the Certificate Authority of the Active Directory Cerficate Services
#

$WindowsFeature = "ADCS-Cert-Authority"
if (Get-WindowsFeature $WindowsFeature | Where-Object { $_.installed -eq $false }) {
    Install-WindowsFeature $WindowsFeature -IncludeManagementTools
    Write-Host "Installed $WindowsFeature" -ForegroundColor Green
}
else {
    Write-Host "$WindowsFeature already installed" -ForegroundColor Yellow
}

#
# Configure a default Domain CA
#
$Credential = get-credential -Credential "$env:USERDOMAIN\$env:USERNAME"

$CryptoProviderName = "RSA#Microsoft Software Key Storage Provider"
$KeyLength = 4096
$HashAlgorithmName = "SHA256"
$ValidityPeriod = "Years"
$ValidityPeriodUnits = 10

Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -Credential $Credential -CryptoProviderName $CryptoProviderName -KeyLength $KeyLength -HashAlgorithmName $HashAlgorithmName -ValidityPeriod $ValidityPeriod -ValidityPeriodUnits $ValidityPeriodUnits -Confirm:$False | Out-Null
Write-Host "Installed Enterprise Root CA" -ForegroundColor Green

#
# Install Network Policy and Access Services
#
$WindowsFeature = "NPAS"
if (Get-WindowsFeature $WindowsFeature -ComputerName $env:COMPUTERNAME | Where-Object { $_.installed -eq $false }) {
    Install-WindowsFeature $WindowsFeature -ComputerName $env:COMPUTERNAME -IncludeManagementTools
    Write-Host "> Installed $WindowsFeature" -ForegroundColor Green
}
else {
    Write-Host "$WindowsFeature already installed on $env:COMPUTERNAME" -ForegroundColor Yellow
}

#
# Registering NPS in Active Directory by adding DC1 to the group ‘RAS and IAS Servers’
#
$Identity = "RAS and IAS Servers"
$Members = Get-ADComputer -identity $env:COMPUTERNAME

try {
    Add-ADGroupMember -Identity $Identity -Members $Members
    Write-Host "> Adding $Members to $Identity ..." -ForegroundColor Green
}
catch {
    Write-Host "> The NPS server $Members is already member of $Identity ..." -ForegroundColor Yellow
}

#
# Exporting the NPS Configuration
#
$File = "NPSConfiguration.xml"

Write-Host "> Exporting the NPS Configuration to the XML-file $File ... " -Foreground Cyan
Export-NpsConfiguration $File

#
# Importing the NPS Configuration
#
try {
    $File = "NPSConfiguration.xml"
    Import-NpsConfiguration $File
    Write-Host "Importing the NPS Configuration from the XML-file $File ... " -Foreground Cyan
}
catch {
    Write-Host "Unable to open the file $File ... " -Foreground Red
}

#
# Creating RADIUS clients
#
try {
    $File = ".\Radiusclients.csv"
    $RadiusClients = Import-Csv $File -Delimiter ";" -ErrorAction Stop
    Foreach ($RadiusClient in $RadiusClients) { 
        $IP = $RadiusClient.IP
        $Name = $RadiusClient.Name
        $Secret = $RadiusClient.Secret

        try {
            New-NpsRadiusClient -Address $IP -Name $Name -SharedSecret $Secret | Out-Null
            Write-Host "Creating RADIUS Client $Name with IP address $IP and secret $Secret ..."
        }
        catch {
            Write-Host "RADIUS Client $Name with IP address $IP and secret $Secret already exists ..."
        }
    }
}
catch {
    Write-Host "Unable to open the file $File ... " -Foreground Red
}

<#
#
# Removing RADIUS clients
#
try {
    $File=".\Radiusclients.csv"
    $RadiusClients=Import-Csv $File -Delimiter ";" -ErrorAction Stop
    Foreach ($RadiusClient in $RadiusClients)
    { 
	    $IP=$RadiusClient.IP
	    $Name=$RadiusClient.Name
	    $Secret=$RadiusClient.Secret

        try {
            Remove-NpsRadiusClient -Name $Name
            Write-Host "Removing RADIUS Client $Name ..."
        } catch {
            Write-Host "RADIUS Client $Name already removed ..."
        }
    }
} catch {
    Write-Host "Unable to open the file $File ... " -Foreground Red
}
#>

#
# Check if RADIUS traffic is allowed in the Windows Firewall
#

$Radius1812 = @(Get-NetFirewallPortFilter -PolicyStore ActiveStore -Protocol UDP | Where-Object { $_.LocalPort -eq 1812 })
$Radius1813 = @(Get-NetFirewallPortFilter -PolicyStore ActiveStore -Protocol UDP | Where-Object { $_.LocalPort -eq 1813 })

if ($Radius1812.Length -ge 1 -and $Radius1813.Length -ge 1) {
    Write-Host "The RADIUS Firewall rules are in place." -ForegroundColor Green
}
else {
    Write-Host "The RADIUS Firewall rules are missing!" -ForegroundColor Red
}
