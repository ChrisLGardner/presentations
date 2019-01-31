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

#region using arrays

#region bad
$array = @(
    'thing1'
    'thing2'
    'thing3'
)

0..(($array.count) -1) | % {
    $setVar = Get-Something -Parameter ($array[$_]) -ErrorAction Silentlycontinue

    if (!$setVar) {
        throw "Something broke yo!"
    }
}
#endregion

#region good
foreach ($item in $array) {
    $setVar = Get-Something -Parameter $Item -ErrorAction Silentlycontinue

    if (!$setVar) {
        throw "Something broke yo!"
    }
}

#OR (v4+)

$array.foreach({
    $setVar = Get-Something -Parameter $_ -ErrorAction Silentlycontinue

    if (!$setVar) {
        throw "Something broke yo!"
    }
})
#endregion

#endregion
