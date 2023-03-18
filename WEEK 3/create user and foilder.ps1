$FullName = ""
while ( $FullName -eq "" ) {
    $FullName = Read-Host "Enter the full name of the user"
}

# Try to split the full name into first and last names
$Names = $FullName -split " "
if ($Names.Count -eq 2) {
    $SamName = "$($Names[0]).$($Names[1])"
} else {
    $SamName = $FullName
}

# Create the user objects for Finance department in New York
New-ADUser -Name $FullName -Path "OU=Finance,OU=New York,OU=ABC,DC=contoso,DC=com" -SamAccountName $SamName -AccountPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -Enabled $true

# Create the home folders for each user
$user = Get-ADUser -Filter $FullName -SearchBase "OU=ABC,DC=contoso,DC=com" -Properties HomeDirectory

$homeFolder = $user.HomeDirectory
# Create the home folder if it does not exist and assign the correct permissions
if (-not (Test-Path $homeFolder)) {
    New-Item -ItemType Directory -Path $homeFolder
    # Secure the home folder
    $acl = Get-Acl $homeFolder
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user.SamAccountName, "FullControl", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl -Path $homeFolder -AclObject $acl
}