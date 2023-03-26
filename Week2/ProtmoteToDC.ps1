Write-Host "> Checking permissions"
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Insufficient permissions to run this script. Open the PowerShell console as an administrator and run this script again."
    Pause
    Exit
} else {
    Write-Host "Code is running as administrator" -ForegroundColor Green
}

# Check if AD-Domain-Services is installed
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

$forestMain = "INTRANET"
$forestName = Read-Host "Enter the name of the new forest (intranet.xxx)"
while ($forestName -eq "") {
    Write-Host "The forest name cannot be empty" -ForegroundColor Red
    $forestName = Read-Host "Enter the name of the new forest (intranet.xxx)"
}

Import-Module ADDSDeployment
Write-Host "> Creating new forest $forestMain.$forestName..." -ForegroundColor Yellow
Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainName "$forestMain.$forestName" `
    -DomainNetbiosName "$forestMain" `
    -ForestMode "Win2008R2" `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) `
    -InstallDns `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion: $false `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true

$Password = ConvertTo-SecureString -AsPlainText -String "P@ssw0rd" -Force
Install-ADDSForest -DomainName Corp.contoso.com -SafeModeAdministratorPassword $Password `
-DomainNetbiosName contoso -DomainMode Win2012R2 -ForestMode Win2012R2 -DatabasePath "%SYSTEMROOT%\NTDS" `
-LogPath "%SYSTEMROOT%\NTDS" -SysvolPath "%SYSTEMROOT%\SYSVOL" -NoRebootOnCompletion -InstallDns -Force
