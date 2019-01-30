break

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

    if ($PSCmdlet.ParameterSetName = 'Set1') {
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

        [ValidateSet('True','False')]
        [bool]$ChangePassword
    )
}
#endregion

#region good
function New-User {
    param (
        [string]$Name,

        [switch]$ChangePassword
    )
}
#endregion

#endregion
