$fileServer = "win09-ms"
$systemShare = "C$"
$driveLetter = $systemShare.replace("$", ":")
$rootShare = "Homedirs"
$localPath = $driveLetter + "\" + $rootShare
$UNCPath = "\\" + $fileServer + "\" + $systemShare + "\" + $rootShare

#
# Create the root share
#
if (Get-Item -Path $UNCPath -ErrorAction SilentlyContinue) {
    Write-Host "> Warning: $UNCPath already exists ..." -ForegroundColor Yellow 
}
else {
    New-Item -Path $UNCPath -type directory -Force | Out-Null
    Write-Host "> Created $UNCPath" -ForegroundColor Green 
}

#
# Share the root share and set permissions
#
if (Get-SmbShare -CimSession $fileServer -Name $rootShare -ErrorAction SilentlyContinue) {
    Write-Host "> Warning $localPath already shared" -ForegroundColor Yellow
}
else {
    New-SmbShare -CimSession $fileServer -Name $rootShare -Path $localPath -FullAccess Everyone | Out-Null
    
    $acl = Get-Acl $UNCPath
    
    # Disable inheritance and remove all permissions
    $acl.SetAccessRuleProtection($True, $False)
    
    # Setting Full Control for Administrators
    $Identity = "Administrators"
    $Permission = "FullControl"
    $Inheritance = "ContainerInherit, ObjectInherit"
    $Propagation = "None"
    $AccessControlType = "Allow"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule
    ($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
    $acl.AddAccessRule($rule)
    
    # Setting Read & Execute for Authenticated Users on This Folder only
    $Identity = "Authenticated Users"
    $Permission = "ReadAndExecute"
    $Inheritance = "None"
    $Propagation = "NoPropagateInherit"
    $AccessControlType = "Allow"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule
    ($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
    $acl.AddAccessRule($rule)
    
    Set-Acl $UNCPath $acl

    Write-Host "> Shared $localPath on $fileServer as $rootShare" -ForegroundColor Green
}

#
# Making the root share for storing the roaming user profiles
#

$fileServer = "win09-ms"

$systemShare = "C$"
$driveLetter = $systemShare.replace("$", ":")
$rootShare = "Profiles$"
$localPath = $driveLetter + "\" + $rootShare
$UNCPath = "\\" + $fileServer + "\" + $systemShare + "\" + $rootShare

#
# Create the root share
#
if (Get-Item -Path $UNCPath -ErrorAction SilentlyContinue) {
    Write-Host "> Warning: $UNCPath already exists ..." -ForegroundColor Yellow 
}
else {
    New-Item -Path $UNCPath -type directory -Force | Out-Null
    Write-Host "> Created $UNCPath" -ForegroundColor Green 
}


#
# Share the root share and set permissions
#
if (Get-SmbShare -CimSession $fileServer -Name $rootShare -ErrorAction SilentlyContinue) {
    Write-Output "> $localPath already shared on $fileServer" -ForegroundColor Yellow
}
else {
    New-SmbShare -CimSession $fileServer -Name $rootShare -Path $localPath -FullAccess Everyone | Out-Null

    $acl = Get-Acl $UNCPath

    # Disable inheritance and remove all permissions
    $acl.SetAccessRuleProtection($True, $False)

    # Setting Full Control for Administrators
    $Identity = "Administrators"
    $Permission = "FullControl"
    $Inheritance = "ContainerInherit, ObjectInherit"
    $Propagation = "None"
    $AccessControlType = "Allow"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule
    ($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
    $acl.AddAccessRule($rule)

    # Setting Modify for Authenticated Users
    $Identity = "Authenticated Users"
    $Permission = "Modify"
    $Inheritance = "ContainerInherit, ObjectInherit"
    $Propagation = "None"
    $AccessControlType = "Allow"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule
	    ($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
    $acl.AddAccessRule($rule)

    Set-Acl $UNCPath $acl

    Write-Host "> Shared $localPath on $fileServer as $rootShare" -ForegroundColor Green
}

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
        Write-Output "$Name already exists in $Path!"
    }
    catch {
        Write-Output "Making $User.Name in $Path ..." 

        New-ADUser -Name $userName -SamAccountName $samAccountName -UserPrincipalName $userPrincipalName -DisplayName $displayName -GivenName $givenName -Surname $surName -HomeDrive $homeDrive -HomeDirectory $homeDirectory -Path $objectPath -AccountPassword $accountPassword -Enabled:$true
	    
        New-Item -Path $homeDirectory -type directory -Force
    
        $acl = Get-Acl $homeDirectory

        # Enable inheritance and copy permissions
        $acl.SetAccessRuleProtection($False, $True)
        # Setting Modify for the User account
        $Identity = $userPrincipalName
        $Permission = "Modify"
        $Inheritance = "ContainerInherit, ObjectInherit"
        $Propagation = "None"
        $AccessControlType = "Allow"
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule
        ($Identity, $Permission, $Inheritance, $Propagation, $AccessControlType)
        $acl.AddAccessRule($rule)

        Set-Acl $HomeDirectory $acl
    }
}
