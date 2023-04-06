#
# check if DFS is installed
#region
if (Get-WindowsFeature -Name FS-DFS-Namespace | Select-Object InstallState) {
    Write-Host "> DFS is installed" -ForegroundColor Green
} else {
    try {
        Write-Host "> DFS is not installed" -ForegroundColor Yellow
        Install-WindowsFeature -Name FS-DFS-Namespace -IncludeManagementTools
        Write-Host "> Instaltion of DFS succesfull" -ForegroundColor Yellow
    }
    catch {
        Write-Host "> Instaltion of DFS failed" -ForegroundColor Red
    }
}