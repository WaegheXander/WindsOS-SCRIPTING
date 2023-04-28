$OUNames = Import-Csv ".\csv\OUs.csv" -Delimiter ";"
 
Foreach ($OU in $OUNames) { 
	$Name = $OU.Name
	$DisplayName = $OU.DisplayName
	$Description = $OU.Description
	$Path = $OU.Path
	$Identity = "OU=" + $Name + "," + $Path

	try {
		Get-ADOrganizationalUnit -Identity $Identity | Out-Null
		Write-Output "> OU $Name already exists in $Path !" -ForegroundColor Yellow
	}
	catch {
		New-ADOrganizationalUnit -Name $Name -DisplayName $DisplayName  -Description $Description -Path $Path -ProtectedFromAccidentalDeletion:$false
		Write-Output "> Created OU $Name in $Path !" -ForegroundColor Green
	}
}
