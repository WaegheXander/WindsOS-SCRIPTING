#
# Removing a DFS Replication Group and its members
#
$DFSRGroup="demo"
$DFSRFolder="little_demo"
$DFSRMembers=@("win00-ms","win00-dc2")

foreach ($DFSRMember in $DFSRMembers)
{
    try {
        Remove-DfsrMember -ComputerName $DFSRMember -GroupName $DFSRGroup -Force -ErrorAction Stop
        Write-Host "> Removing the DFSR Member $DFSRMember from the DFSR Group $DFSRGroup" -ForegroundColor Green
    } catch {
        Write-Host "> The DFRS Member $DFSRMember already removed from the DFSR Group $DFSRGroup" -ForegroundColor Yellow
    }
}

try {
    Remove-DfsReplicatedFolder -FolderName $DFSRFolder -GroupName $DFSRGroup -Force -ErrorAction Stop
    Write-Host "> Removing the DFSR Folder $DFSRFolder from the DFSR Group $DFSRGroup" -ForegroundColor Green
} catch {
    Write-Host "> The DFSR Folder $DFSRFolder already removed from the DFSR Group $DFSRGroup" -ForegroundColor Yellow
}
 
try {    
    Remove-DfsReplicationGroup -GroupName $DFSRGroup -Force -ErrorAction Stop
    Write-Host "> Removing the DFSR Group $DFSRGroup" -ForegroundColor Green
} catch {
    Write-Host "> The DFSR Group $DFSRGroup already removed" -ForegroundColor Yellow
}
