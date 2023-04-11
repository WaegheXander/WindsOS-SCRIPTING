$ans = Read-Host "Enter the UPN suffix you want to add to the forest"
$forest = Get-ADForest
$forest.UPNSuffixes.Add($ans)
$forest | Set-ADForest
Get-ADForest
