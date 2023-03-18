Import-Module ActiveDirectory

$Name = ""
while ( $Name -eq "" ) {
    $Name = Read-Host "Enter the full name of the user"
}

New-ADGroup -Name $Name -GroupScope Security -Path "OU=Groups,DC=abc,DC=com"
