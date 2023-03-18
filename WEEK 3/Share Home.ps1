$folderPath = "C:\Home"

New-SmbShare -Name "ShareName" -Path $folderPath -FullAccess "Authenticated Users"

Get-Acl -Path $folderPath | Set-Acl -Path $folderPath -DisableInheritance

$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Authenticated Users","FullControl","Allow")
(Get-Acl -Path $folderPath).SetAccessRule($rule)
Set-Acl -Path $folderPath -AclObject (Get-Acl -Path $folderPath)
