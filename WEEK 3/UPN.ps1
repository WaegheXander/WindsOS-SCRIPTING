#
# Description: This script will add a UPN suffix to the Active Directory forest
#region
function addUPN { 
    $upn = Read-Host "Enter the UPN suffix you want to add";
    while ($true) {
        if ($upn -eq "") {
            Write-Host "> UPN suffix cannot be empty" -ForegroundColor Red
            $upn = Read-Host "Enter the UPN suffix you want to add";
        }
        else {
            try {
                Get-ADForest | Set-ADForest -UPNSuffixes @{add = "$upn" };
                Write-Host "> UPN suffix successfully created" -ForegroundColor Green
            }
            catch {
                Write-Host "Error creating UPN suffix" -ForegroundColor Red
            }
        }
    }
}
#endregion

addUPN;