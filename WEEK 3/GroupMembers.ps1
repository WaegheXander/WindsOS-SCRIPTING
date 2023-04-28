$Members = Import-Csv ".\csv\GroupMembers.csv" -Delimiter ";"
 
Foreach ($Member in $Members) { 
    $Identity = $Member.Identity
    $Members = $Member.Member

    try {
        Add-ADGroupMember -Identity $Identity -Members $Members
        Write-Host "> Added $Members to $Identity" -ForegroundColor Green
    }
    catch {
        Write-Host "> Error: $Members not added to $Identity" -ForegroundColor Red
    }
}
