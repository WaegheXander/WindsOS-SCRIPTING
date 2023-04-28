#
# Making a share remotely
# - name: public
# - share perms: everyone - full control
# - NTFS perms: Administrators - full control and DL-Personeel - modify
#

$fileServer = "win09-ms"

$systemShare = "C$"
$driveLetter = $systemShare.replace("$", ":")
$shareName = "Public"
$localPath = $driveLetter + "\" + $shareName
$UNCPath = "\\" + $fileServer + "\" + $systemShare + "\" + $shareName

$modifyGroup = "personeel"

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

# Setting Modify for a Domain Local Group
$Identity=$modifyGroup
$Permission="Modify"
$Inheritance="ContainerInherit, ObjectInherit"
$Propagation="None"
$AccessControlType="Allow"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
$acl.AddAccessRule($rule)
Set-Acl $UNCPath $acl
Write-Host "> Added permissions" -ForegroundColor Green

