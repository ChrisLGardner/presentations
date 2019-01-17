function Get-UserData {
    [cmdletbinding()]
    [OutputType([PSCustomObject])]
    param (
        [string]$UserName
    )

    [pscustomobject]@{
        Name = $UserName
        Email = "${name}@domain.tld"
        Computer = 'Localhost'
        PSTypeName = 'Custom.UserData'
    }
}

function Set-UserData {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline, ParameterSetName = 'CustomObject')]
        [PSTypeName('Custom.UserData')]$inputobject,

        [Parameter(ValueFromPipeline, ParameterSetName = 'Name')]
        [string[]]$UserName
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'CustomObject') {
            $inputobject.Computer = 'Server1'
            $inputobject
        }
        else {
            foreach ($User in $UserName) {
                Get-UserData -Name $User | Set-UserData
            }
        }
    }
}
