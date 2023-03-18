Import-Module ActiveDirectory

$Name = ""
while ( $Name -eq "" ) {
    $Name = Read-Host "Enter the full name of the user u want to add to the group"
}

$NameGroup = ""
while ( $NameGroup -eq "" ) {
    $NameGroup = Read-Host "Enter the name of the group to add the user to (more than one group ex: group1,group2,group3))"
}

Add-ADGroupMember -Identity $NameGroup -Members $Name
