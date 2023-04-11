#
# Description: This script will add a UPN suffix to the Active Directory forest
#region
$ans = Read-Host "Do you want to add a UPN suffix? (y/n)";
while ($true) {
    if ($ans.ToLower() -eq "y") {
        if (Get-ADForest | Select-Object -ExpandProperty UPNSuffixes | Where-Object {$_ -eq $ans}) {
            Write-Host "UPN suffix already exists" -ForegroundColor Yellow
            break;
        } else {
            try {
                Get-ADForest | Select-Object -ExpandProperty UPNSuffixes | Where-Object {$_ -eq '<UPN suffix>'}
                Write-Host "> UPN suffix successfully created" -ForegroundColor Green
                break;
            }
            catch {
                Write-Host "Error creating UPN suffix" -ForegroundColor Red
                Write-Host "> Try again" -ForegroundColor Red
            }
        }
    }
    elseif ($ans.ToLower() -eq "n") {
        break;
    }
    else {
        Write-Host "Invalid input - please enter 'y' or 'n'" -ForegroundColor Red
        $ans = Read-Host "Do you want to add a UPN suffix? (y/n)";
    }
}
#endregion
