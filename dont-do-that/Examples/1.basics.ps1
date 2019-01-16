break

#region aliases

#region bad
gps | ? name -like p*w* | % na*
#endregion

#region good
Get-Process | Where-Object name -like p*w* | Foreach-Object -MemberName Name
#endregion

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
$PortNat = "" | Select-Object -Property Int,Ext,AddText,RemText,FileName,FilePath,Error
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
#endregion
#endregion

#endregion

#region scopes

#region bad global
$Global:Var = 1234
#endregion

#region good global
$Script:Var = 1234
#endregion

#endregion
