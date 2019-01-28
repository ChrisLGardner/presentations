break

#region building arrays

#region bad (sort of)

$array = @()
foreach ($user in $userlist) {
    $array += [pscustomobject]@{
        Username = $User.Name
        Email = $User.SamAccountName
    }
}
#endregion

#region good
$array = foreach ($user in $userlist) {
    [pscustomobject]@{
        Username = $User.Name
        Email = $User.SamAccountName
    }
}

$Array = [System.Collections.Generic.List[PSObject]]::New()
foreach ($user in $userlist) {
    $Array.add([pscustomobject]@{
        Username = $User.Name
        Email = $User.SamAccountName
    })
}
#endregion

#endregion
