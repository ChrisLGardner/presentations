break

#region aliases

#region bad
gps | ? name -like p*w* | % na*
#endregion

#region good
Get-Process |
    Where-Object name -like p*w* |
    Foreach-Object -MemberName Name
#endregion

$var | foreach { $_ -eq $PsItem}
#endregion

#region positional

#region bad
Get-ChildItem c:\Backups *.bak | Copy-Item D:\Backups
#endregion

#region good
Get-ChildItem -Path c:\Backups -Filter *.bak | Copy-Item -Destination D:\Backups
#endregion
#endregion

#region Objects

#region bad creation
$Object = "" | Select-Object -Property Int,Ext,AddText,RemText,FileName,FilePath,Error

$Object = New-Object PSObject @{
    Int = ''
    Ext = ''
    AddText = ''
    RemText = ''
    FileName = ''
    FilePath = ''
    Error = ''
}

$CustomObject = [PSCustomObject]@{}
foreach ($Param in $PSBoundParameters.GetEnumerator())
{
    Add-Member -InputObject $CustomObject -MemberType NoteProperty -Name $Param.Key -Value $Param.Value
}
#endregion

#region good creation
[PSCustomObject]@{
    Int = ''
    Ext = ''
    AddText = ''
    RemText = ''
    FileName = ''
    FilePath = ''
    Error = ''
}

#region V2 needs to do:
New-Object psobject @{
    Int = ''
    Ext = ''
    AddText = ''
    RemText = ''
    FileName = ''
    FilePath = ''
    Error = ''
}

$CustomObject = [PSCustomObject]@{
    Param     = $Param
}
#endregion
#endregion

#region bad properties
$LameObject = $FullBodiedObject  | Select SingleProperty
#endregion

#region good properties
$FullBodiedObject.SingleProperty
#endregion

#endregion

#region scopes

#region bad global
$Global:Var = 1234
#endregion

#region good "global"
$Script:Var = 1234
#endregion

#region magic function variables
$variable = 'Dave'

function Get-something {
    write-host "hello $variable"
}
#endregion

#region function parameters
function Get-Something {
    param (
        $Variable
    )

    write-host "hello $variable"
}

Get-Something -Variable 'Dave'
#endregion

#endregion

#region naming  

#region bad
$v = $i + 1
$alllowercasename

$strName
#endregion

#region good
$AllLowerCaseName
#endregion

#endregion
