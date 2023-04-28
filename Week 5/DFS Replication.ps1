#
# Install DFS Namespaces on all participating servers
#

$secondDC = "win09-DC2"
$MemberServer = "win09-ms"

$Credential = "$env:USERNAME"
$domainCredential = "$env:USERDOMAIN\$Credential"
$UserDNSDomain = $env:USERDNSDOMAIN.tolower()

$WindowsFeature = "FS-DFS-Replication"
if (Get-WindowsFeature $WindowsFeature | Where-Object { $_.installed -eq $false }) {
    Write-Host "> Installing $WindowsFeature" -ForegroundColor Yellow
    Install-WindowsFeature $WindowsFeature -IncludeManagementTools
    Write-Host "> Instaltion of $WindowsFeature succesfull" -ForegroundColor Yellow
}
else {
    Write-Host "$WindowsFeature already installed 0" -ForegroundColor Green
}

$remoteSession = New-PSSession -ComputerName $secondDC -Credential $domainCredential
Invoke-Command -Session $remoteSession -Scriptblock {

    $domainCredential = $args[0]
    $secondDC = $args[1]
    $MemberServer = $args[2]

    $WindowsFeature = "FS-DFS-Replication"
    if (Get-WindowsFeature $WindowsFeature | Where-Object { $_.installed -eq $false }) {
        Write-Host "> Installing $WindowsFeature" -ForegroundColor Yellow
        Install-WindowsFeature $WindowsFeature -IncludeManagementTools
        Write-Host "> Instaltion of $WindowsFeature succesfull" -ForegroundColor Yellow
    }
    else {
        Write-Host "$WindowsFeature already installed 1" -ForegroundColor Green
    }

    $remoteSession = New-PSSession -ComputerName $MemberServer -Credential $domainCredential
    Invoke-Command -Session $remoteSession -Scriptblock {
        $WindowsFeature = "FS-DFS-Replication"
        if (Get-WindowsFeature $WindowsFeature | Where-Object { $_.installed -eq $false }) {
            Write-Host "> Installing $WindowsFeature" -ForegroundColor Yellow
            Install-WindowsFeature $WindowsFeature -IncludeManagementTools
            Write-Host "> Instaltion of $WindowsFeature succesfull" -ForegroundColor Green
        }
        else {
            Write-Host "$WindowsFeature already installed 2" -ForegroundColor Green
        }
    }
} -ArgumentList $domainCredential, $secondDC, $MemberServer