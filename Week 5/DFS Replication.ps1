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
    $MemberServer = $args[1]

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
} -ArgumentList $domainCredential, $MemberServer


$DFSRGroup="demo"
$DFSRFolder="little_demo"

$DFSRMembers=@("win09-ms","win09-dc2")
$DFSRContentPaths=@("c:\demofolder","c:\demofolder")

try {
    New-DfsReplicationGroup -GroupName $DFSRGroup -ErrorAction Stop | Out-Null                                                                                      
    Write-Host "> Created the DFSR Group $DFSRGroup" -ForegroundColor Green
} catch {
    Write-Host "> DFSR Group $DFSRGroup already exists" -ForegroundColor Green
}

try {
    New-DfsReplicatedFolder -FolderName $DFSRFolder -GroupName $DFSRGroup -ErrorAction Stop | Out-Null
    Write-Host "> Created the DFSR Folder $DFSRFolder in the DFSR Group $DFSRGroup" -ForegroundColor Green
} catch {
    Write-Host "DFSR Folder $DFSRFolder already exists in DFSR Group $DFSRGroup" -ForegroundColor Green
}

for ($i=0; $i -lt $DFSRMembers.Length; ++$i)
{
    $DFSRMember=$DFSRMembers[$i]
    try {
        Add-DfsrMember -ComputerName $DFSRMember -GroupName $DFSRGroup -ErrorAction Stop | Out-Null
        Write-Host "> Adding the DFSR Member $DFSRMember in the DFSR Group $DFSRGroup" -ForegroundColor Green
    } catch {
        Write-Host "> The DFSR Member $DFSRMember is already member of the DFSR Group $DFSRGroup" -ForegroundColor Yellow
    }
}

$Source=$DFSRMembers[0]
$Destination=$DFSRMembers[1]

try {
    Add-DfsrConnection -SourceComputerName $Source -DestinationComputerName $Destination -GroupName $DFSRGroup -ErrorAction Stop | Out-Null
    Write-Host "> Adding the DFSR Connection between $Source and $Destination" -ForegroundColor Green
} catch {
    Write-Host "> The DFSR Connection between $Source and $Destination already exists" -ForegroundColor Yellow
}

for ($i=0; $i -lt $DFSRMembers.Length; ++$i)
{
    try {
        $DFSRMember=$DFSRMembers[$i]
        $DFSRContentPath=$DFSRContentPaths[$i]
        Set-DfsrMembership -ComputerName $DFSRMember -FolderName $DFSRFolder -GroupName $DFSRGroup -ContentPath $DFSRContentPath -Force -ErrorAction Stop | Out-Null
        Write-Host "> Adding the DFSR Member $DFSRMember with the local path $DFSRContentPath to the DFSR Folder $DFSRFolder in the DFSR Group $DFSRGroup" -ForegroundColor Green
    } catch {
        Write-Host "> The DFSR Member $DFSRMember with the local path $DFSRContentPath already added to the DFSR Folder $DFSRFolder in the DFSR Group $DFSRGroup" -ForegroundColor Yellow
    }
}
sleep 5

try {
    Sync-DfsReplicationGroup -GroupName $DFSRGroup -SourceComputerName $Source -DestinationComputerName $Destination -DurationInMinutes 15 | Out-Null
    Write-Host "> Synced the DFSR Group $DFSRGroup" -ForegroundColor Green
} catch{
    Write-Host "> The DFSR Group $DFSRGroup is already synced of was to fast" -ForegroundColor Yellow
}