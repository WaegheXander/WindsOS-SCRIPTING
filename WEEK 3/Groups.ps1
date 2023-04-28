$GroupNames = Import-Csv ".\csv\Groups.csv" -Delimiter ";"
 
Foreach ($Group in $GroupNames)
{ 
	$Name = $Group.Name
	$DisplayName = $Group.DisplayName
	$Path = $Group.Path
	$GroupCategory = $Group.GroupCategory
	$GroupScope = $Group.GroupScope

	try
	{
	    Get-ADGroup -Identity $Name | Out-Null
	    Write-Host "> Warning: group $Name in $Path already exists" -ForegroundColor Yellow
	}
	catch
	{
		New-ADGroup -Name $Name -SamAccountName $Name -GroupCategory $GroupCategory -GroupScope $GroupScope -DisplayName $DisplayName -Path $Path
	    Write-Host "> Group $Name created in $Path" -ForegroundColor Green
	}
}
