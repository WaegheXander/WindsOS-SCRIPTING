#
# Creating users in AD
#
$userNames = Import-Csv ".\csv\UserAccounts.csv" -Delimiter ";"

$UPNSuffix = 'mct.be'

$homeServer = "win09-ms"
$homeShare = "Homedirs"

Foreach ($User in $userNames) { 
    $userName = $User.Name
    $samAccountName = $User.SamAccountName
    $userPrincipalName = $User.Name + "@" + $UPNSuffix
    $displayName = $User.DisplayName
    $givenName = $User.GivenName
    $surName = $User.SurName
    $homeDrive = $User.HomeDrive
    $homeDirectory = "\\" + $homeServer + "\" + $homeShare + "\" + $User.Name
    $objectPath = $User.Path

    $accountPassword = ConvertTo-SecureString $User.AccountPassword -AsPlainText -force

    try {
        Get-ADUser -identity $samAccountName | Out-Null
        Write-Host "> Warning: $userName already exists in $objectPath" -ForegroundColor Yellow
    }
    catch {

        New-ADUser -Name $userName -SamAccountName $samAccountName -UserPrincipalName $userPrincipalName -DisplayName $displayName -GivenName $givenName -Surname $surName -HomeDrive $homeDrive -HomeDirectory $homeDirectory -Path $objectPath -AccountPassword $accountPassword -Enabled:$true
	    
        New-Item -Path $homeDirectory -type directory -Force
        Write-Host "> Created $userName and home directory $homeDirectory" -ForegroundColor Green

        $acl = Get-Acl $homeDirectory

        # Enable inheritance and copy permissions
        $acl.SetAccessRuleProtection($False, $True)
        # Setting Modify for the User account
        $Identity = $userPrincipalName
        $Permission = "Modify"
        $Inheritance = "ContainerInherit, ObjectInherit"
        $Propagation = "None"
        $AccessControlType = "Allow"
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
        $acl.AddAccessRule($rule)

        Set-Acl $HomeDirectory $acl
        Write-Host "> Set permissions on $homeDirectory succesfull" -ForegroundColor Green
    }
}