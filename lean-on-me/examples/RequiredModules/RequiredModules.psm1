function Get-Data {
    [cmdletbinding()]
    param (
        $Username = $Env:USERNAME
    )

    [PSCustomObject]@{
        Username = $Username
        Computer = $Env:COMPUTERNAME
        OperatingSystem = ((Get-CimInstance -ClassName Win32_OperatingSystem).Name -split '\|')[0]
    }
}
