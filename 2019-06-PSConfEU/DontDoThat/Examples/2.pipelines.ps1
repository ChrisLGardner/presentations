break

#region backticks

#region bad endline
Get-ChildItem -Path C:\Some\Really\Long\Path\Here `
              -Filter *.ps1 `
              -Recurse `
              -Depth 5 `
              -ErrorAction SilentlyContinue

Get-ChildItem -Path C:\Some\Really\Long\Path\Here `
        | Where-Object {$_.Name -like '*.ps1'}

if ($SomeVar -eq '1234' -and $OtherVar -eq 'abcd' -and $ThirdVar -like '*abc*123') {
    Do-TheThing
}
#endregion

#region good
$GetChildItemParams = @{
    Path = 'C:\Some\Really\Long\Path\Here'
    Filter = '*.ps1'
    Recurse = $true
    Depth = 5
    ErrorAction = 'SilentlyContinue'
}
Get-ChildItem @GetChildItemParams

Get-ChildItem -Path C:\Some\Really\Long\Path\Here |
        Where-Object {$_.Name -like '*.ps1'}

if ($SomeVar.member -eq '1234' -and
    $OtherVar -eq 'abcd' -and
    $ThirdVar.otherproperty -like '*abc*123') {

    Do-TheThing
}
#endregion

https://get-powershellblog.blogspot.com/2017/07/bye-bye-backtick-natural-line.html

#endregion

#region output

#region bad
function Get-Data {
    Get-ADUser -Filter * -Properties * | Format-List *
}

Get-Data
#endregion

#region good
function Get-Data {
    Get-ADUser -Filter * -Properties LastLogonDate,PasswordExpiryDate
}

Get-Data | Format-List *
#endregion

#endregion
