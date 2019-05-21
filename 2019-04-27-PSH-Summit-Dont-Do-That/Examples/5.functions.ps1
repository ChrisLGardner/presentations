break

#region parameters

#region bad
function get-data{
    $UserName = read-host "Enter a username"
}
#endregion

#region good
function get-data{
    param(
        [parameter(Mandatory)]
        [string]$UserName
    )
}
#endregion

#endregion

#region parameter sets

#region bad
Function Get-Data {
    param (

        [string]$Name,

        [Parameter(ParameterSetName = 'Set1')]
        [string]$Set1,

        [Parameter(ParameterSetName = 'Set2')]
        [string]$Set2
    )

    if ($PSCmdlet.ParameterSetName = 'Set1') {
        "$Name : $Set1"
    }
    else {
        "$Name : $Set2"
    }
}
#endregion

#region good
Function Get-Data {
    [Cmdletbinding(DefaultParameterSetName='Set1')]
    param (

        [string]$Name,

        [Parameter(ParameterSetName = 'Set1')]
        [string]$Set1,

        [Parameter(ParameterSetName = 'Set2')]
        [string]$Set2
    )

    if ($PSCmdlet.ParameterSetName -eq 'Set1') {
        "$Name : $Set1"
    }
    else {
        "$Name : $Set2"
    }
}
#endregion

#endregion

#region whatif/confirm

#region bad
function Set-Data {
    param (
        [string]$Name,

        [string]$NewName,

        [switch]$WhatIf,
        [switch]$Confirm
    )

    if ($WhatIf) {
        Write-Host "$Name will become $NewName"
        return
    }
    elseif ($Confirm) {
        $UserInput = Read-Host "Are you sure you want to rename $Name to $NewName?"

        if ($UserInput -eq 'N') {
            return
        }
    }

    $Name = $NewName
    Write-Host "Changed to $Name"
}
#endregion

#region good
function Set-Data {
    [cmdletbinding(SupportsShouldProcess, ConfirmImpact='High')]
    param (
        [string]$Name,

        [string]$NewName
    )

    if ($PSCmdlet.ShouldProcess("Changing $Name to $NewName")) {
        $Name = $NewName
        Write-Host "Changed to $Name"
    }
}
#endregion

#endregion

#region switch

#region bad
function New-User {
    param (
        [string]$Name,

        [ValidateSet($True,$False)]
        [bool]$ChangePassword
    )

    $ChangePassword
}
#endregion

#region good
function New-User {
    param (
        [string]$Name,

        [switch]$ChangePassword
    )

    $ChangePassword
}
#endregion

#endregion

#region output types

#region bad

function Get-data {
    param (
        $Computers
    )

    $Users = Get-ADUser -Filter * | Where { $_.ComputerName -in $Computers }
    Invoke-Command -ComputerName $Computers -Scriptblock {
        Get-CimInstance -ClassName Win32_OperatingSystem
    }

    return $Users
}

#endregion

#region good
function Get-data {
    param (
        $Computers
    )

    $Users = Get-ADUser -Filter * | Where { $_.ComputerName -in $Computers }
    $ComputerData = Invoke-Command -ComputerName $Computers -Scriptblock {
        Get-CimInstance -ClassName Win32_OperatingSystem
    }

    [PSCustomObject]@{
        Users = $Users
        Computers = $ComputerData
    }
}
#endregion

#endregion

#region parameter types

#region less good
param (
    [string]$path
)
#endregion

#region good
param (
    [System.IO.FileInfo]$path
)
#endregion

#endregion

#region credentials

#region bad
param (
    $Username,

    $Password
)
#endregion

#region bad
param (
    [PSCredential]$Credetial
)
#endregion

#endregion
