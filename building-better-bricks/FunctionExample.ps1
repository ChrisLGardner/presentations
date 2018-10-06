function Get-UserData {
    [cmdletbinding()]
    [OutputType([PSCustomObject])]
    param (
        [string]$Name
    )

    [pscustomobject]@{
        Name = $Name
        Email = "${name}@domain.tld"
        Computer = 'Localhost'
        PSTypeName = 'Custom.UserData'
    }
}

function Set-UserData {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline,ParameterSetName='CustomObject')]
        [PSTypeName('Custom.UserData')]$inputobject,

        [Parameter(ValueFromPipeline,ParameterSetName='Name')]
        [string]$Name
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'CustomObject') {
            $inputobject.Computer = 'Server1'
            $inputobject
        }
        else {
            Get-UserData -Name $Name | Set-UserData
        }
    }
}
