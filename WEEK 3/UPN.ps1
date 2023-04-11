#
# Description: This script will add a UPN suffix to the Active Directory forest
#region
$ans = Read-Host "Do you want to add a UPN suffix? (y/n)";
while ($true) {
    if ($ans.ToLower() -eq "y") {
        $upn = Read-Host "Enter the UPN suffix you want to add";
        while ($true) {
            if ($upn -eq "") {
                Write-Host "> UPN suffix cannot be empty" -ForegroundColor Red
                $upn = Read-Host "Enter the UPN suffix you want to add";
            }
            else {
                if (Get-ADForest | Select-Object -ExpandProperty UPNSuffixes | Where-Object { $_ -eq $ans }) {
                    Write-Host "UPN suffix already exists" -ForegroundColor Yellow
                }
                else {
                    try {
                        Get-ADForest | Set-ADForest -UPNSuffixes @{add="$upn"};
                        Write-Host "> UPN suffix successfully created" -ForegroundColor Green
                        break;
                    }
                    catch {
                        Write-Host "Error creating UPN suffix" -ForegroundColor Red
                        Write-Host "> Try again" -ForegroundColor Red
                    }
                }
            }
        }
    }
    elseif ($ans.ToLower() -eq "n") {
        break;
    }
    else {
        Write-Host "Invalid input please enter y or n" -ForegroundColor Red
        $ans = Read-Host "Do you want to add a UPN suffix? (y/n)";
    }
}
#endregion
