#
# Making a shared folder remotely
# - name: desktops
# - share perms: everyone - full control
# - NTFS perms: Administrators - full control and Authenticated Users - Read
#

$FileServer = "win09-dc2"

$systemShare = "C$"
$driveLetter = $systemShare.replace("$", ":")
$shareName = "Desktops"
$LocalPath = $driveLetter + "\" + $shareName
$UNCPath = "\\" + $FileServer + "\" + $systemShare + "\" + $shareName

$Group = "secretariaat"
$Folder = "secretariaat"

if (Get-Item -Path $UNCPath -ErrorAction SilentlyContinue) {
    Write-Host "> $UNCPath already exists" -ForegroundColor Yellow   
}
else {
    New-Item -Path $UNCPath -type directory -Force | Out-Null
    Write-Host "> Created $UNCPath" -ForegroundColor Green
}

if (Get-SmbShare -CimSession $FileServer -Name $shareName -ErrorAction SilentlyContinue) {
    Write-Host "> Warning: $LocalPath already shared on $FileServer" -ForegroundColor Yellow
}
else {
    New-SmbShare -CimSession $fileServer -Name $shareName -Path $localPath -FullAccess Everyone | Out-Null
    Write-Host "> Shared $localPath on $fileServer as $shareName" -ForegroundColor Green
}

$acl = Get-Acl $UNCPath

# Disable inheritance and remove all permissions
$acl.SetAccessRuleProtection($True, $False)

# Setting Full Control for Administrators
$Identity = "Administrators"
$Permission = "Fullcontrol"
$Inheritance = "ContainerInherit, ObjectInherit"
$Propagation = "None"
$AccessControlType = "Allow"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
$acl.AddAccessRule($rule)

# Setting Read & Execute for Authenticated Users on This Folder only
$Identity = "Authenticated Users"
$Permission = "ReadAndExecute"
$Inheritance = "None"
$Propagation = "NoPropagateInherit"
$AccessControlType = "Allow"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
$acl.AddAccessRule($rule)

Set-Acl $UNCPath $acl
Write-Host "> Added permissions to root folder" -ForegroundColor Green

#
# Making a subfolder for $Folder
# - name: $Folder
# - NTFS perms: Administrators - full control and $Group - read
#
$UNCPath = $UNCPath + "\" + $Folder

if (Get-Item -Path $UNCPath -ErrorAction SilentlyContinue) {
    Write-Host "> Warning: $UNCPath already exists" -ForegroundColor Yellow 
}
else {
    New-Item -Path $UNCPath -type directory -Force | Out-Null
    Write-Host "> Created $UNCPath path" -ForegroundColor Green 
}

$acl = Get-Acl $UNCPath

# Enable inheritance and copy permissions
$acl.SetAccessRuleProtection($False, $True)

# Setting Read & Execute for a Domain Local Group
$Identity = $Group
$Permission = "ReadAndExecute"
$Inheritance = " ContainerInherit, ObjectInherit"
$Propagation = "None"
$AccessControlType = "Allow"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
$acl.AddAccessRule($rule)

Set-Acl $UNCPath $acl
Write-Host "> Added permissions to subfolder" -ForegroundColor Green