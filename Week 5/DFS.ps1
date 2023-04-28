#
# check if DFS is installed
#region
if (Get-WindowsFeature -Name FS-DFS-Namespace | Select-Object InstallState) {
    Write-Host "> DFS is installed" -ForegroundColor Green
}
else {
    try {
        Write-Host "> DFS is not installed" -ForegroundColor Yellow
        Install-WindowsFeature -Name FS-DFS-Namespace -IncludeManagementTools
        Write-Host "> Instaltion of DFS succesfull" -ForegroundColor Yellow
    }
    catch {
        Write-Host "> Instaltion of DFS failed" -ForegroundColor Red
    }
}

#
# Creating a new DFS Namespaces
#
$UserDNSDomain = "intranet.mct.be"
$LocalPath = "C:\XYZ"
$ShareName = "XYZ"

$Target = "\\$env:COMPUTERNAME\$ShareName"
$Path = "\\$UserDNSDomain\$ShareName"

# Check if DFSRoot already exists
if (!(Test-Path $Target)) {
    # Check if local folder already exists
    if (!(Test-Path $LocalPath)) {
        # Create local folder
        New-Item -Path $LocalPath -ItemType Directory | Out-Null
        Write-Host "> Created $LocalPath path" -ForegroundColor Green
    }
    # Share local folder
    New-SmbShare -Path $LocalPath -Name $ShareName -FullAccess Everyone | Out-Null
    Write-Host "> Shared $LocalPath on $env:COMPUTERNAME as $ShareName" -ForegroundColor Green
}

New-DfsnRoot -TargetPath "$Target" -Type DomainV2 -Path "$Path" | Out-Null
Write-Host "> Created DFSRoot $Target on $Path" -ForegroundColor Green

#
# Removing a DFSRoot
#
#Write-Host "Removing the DFSRoot $Target ..." -ForegroundColor Cyan
#Remove-DfsnRoot -Path "$Path" -Force | Out-Null
#Remove-SmbShare -Name $ShareName -Force | Out-Null
#Remove-Item -Path $LocalPath -Recurse -Force | Out-Null

#
# Finding DFS Namespaces and Folders
#
$UserDNSDomain = "intranet.mct.be"
$DFSRoot = Get-DfsnRoot -Domain $UserDNSDomain | Where-object ( { $_.State -eq 'Online' } ) | Select-Object -ExpandProperty Path
Write-Host "> The DFSRoot is $DFSRoot" -ForegroundColor Yellow

Get-DfsnFolder -Path "$DFSRoot\*" | Select-Object -ExpandProperty Path
Write-Host "> The DFSRoot contains the following folders: $DFSRoot" -ForegroundColor Yellow

#
# Creating a DFS Link Folder
#
$UserDNSDomain = "intranet.mct.be"
$ShareName = "XYZ"
$DFSRoot = "\\$env:COMPUTERNAME\$ShareName"


### to do : check if foldertarget exists ???

$Folder = "$DFSRoot\General"
$FolderTarget = "\\win09-ms\ABCco"

try {
    Get-DfsnFolderTarget -Path $Folder -ErrorAction Stop
}
catch {
    Write-Host "$Folder not found. Clear to proceed" -ForegroundColor Green
}

$NewDFSFolder = @{
    Path                  = $Folder
    State                 = 'Online'
    TargetPath            = $FolderTarget
    TargetState           = 'Online'
    ReferralPriorityClass = 'globalhigh'
}

New-DfsnFolder @NewDFSFolder | Out-Null

# Check that folder now exists:
Get-DfsnFolderTarget -Path $Folder -TargetPath $FolderTarget


#
# Remove DFS Folder Target or Remove DFS Link Folder
#
#Remove-DfsnFolderTarget -Path $Folder -TargetPath $FolderTarget -Force
# or
#Remove-DfsnFolder -Path $Folder -Force