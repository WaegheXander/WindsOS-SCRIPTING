# Write-Host "> Connecting..." -ForegroundColor Yellow;
# $ServerSession = New-PSSession -ComputerName "Win09-MS" -Credential (Get-Credential);
# Import-PSSession $ServerSession;
$SourceFile = "./Week 3/csv/UserAccounts.csv";

$Shares = Import-Csv -Delimiter ";" -Path $SourceFile;
foreach($Share in $Shares) {
    Write-Host "> Creating share $($Share.Name) on $($Share.HomeDirectory)" -ForegroundColor Yellow;
}