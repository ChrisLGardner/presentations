break

#region Get-WmiObject

#region bad
Get-WmiObject -Class Win32_OperatingSystem
#endregion

#region good
Get-CimInstance -Class Win32_OperatingSystem
#endregion

#endregion

#region Find Software

#region bad
(Get-WmiObject -Class Win32_Product | where name -eq $variable).Uninstall()
#endregion

#region good
Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall |
    Get-ItemProperty | Select-Object DisplayName,UninstallString
#endregion

#endregion
