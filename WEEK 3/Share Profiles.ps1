$folderPath = "C:\RoamingProfiles"

# Create the shared folder
New-SmbShare -Name "RoamingProfiles" -Path $folderPath -Description "Roaming Profiles" -FullAccess "Everyone"

# Retrieve the Access Control List (ACL) for the shared folder
$acl = Get-Acl -Path $folderPath

# Remove the inheritance of permissions from the ACL
$acl.SetAccessRuleProtection($true, $false)

# Add the "Authenticated Users" group to the ACL with Read and Execute permissions
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Authenticated Users", "ReadAndExecute", "Allow")
$acl.SetAccessRule($rule)

# Set the ACL for the shared folder
Set-Acl -Path $folderPath -AclObject $acl
