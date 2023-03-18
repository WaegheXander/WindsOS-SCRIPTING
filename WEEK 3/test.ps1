Import-Module ActiveDirectory

# Define the share path and name
$SharePath = "C:\DepartmentData"
$ShareName = "DepartmentData"

#check if the share not exists
if (Test-Path $SharePath) {
    Write-Host "The share already exists"
    exit
} else
{
    # Create the share
    New-SmbShare -Name $ShareName -Path $SharePath -ChangeAccess Everyone -FullAccess Administrators -CachingMode None
    
    # Set the share permissions
    $Acl = Get-Acl $SharePath
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","Allow")
    $acl.SetAccessRuleProtection($true, $false)
    $Acl.SetAccessRule($AccessRule)
    Set-Acl $SharePath $Acl
}


while ( $who -ne "exit" -or $foldername -ne "exit") {
    Write-Host "type exit to quit"
    $who = ""
    while ( $who -eq "" ) {
        $who = Read-Host "Enter the name of the group you want to give access to"
        if (-not (Get-ADGroup -Filter "Name -eq '$who'")) {
            Write-Host "Group $who does not exist. Please enter a valid group name."
            $who = ""
        }
    }
    $foldername = ""
    while ( $foldername -eq "" ) {
        $foldername = Read-Host "Enter the name of the folder you want to create"
    }

    # Create department subfolders
    New-Item -ItemType Directory -Path "$SharePath\$foldername"

    # Set permissions for HR department folder
    $Acl = Get-Acl "$SharePath\$foldername"
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($who,"ReadAndExecute","Allow")
    $Acl.SetAccessRule($AccessRule)
    $Acl | Set-Acl "$SharePath\$foldername"
}
