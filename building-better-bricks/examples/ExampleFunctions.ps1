Function Get-UserData {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [Alias('Name')]
        [string]$UserName
    )

    [PSCustomObject]@{
        UserName = $Username
        PSTypeName = 'UserData'
        UserPrincipalName = "${UserName}@Domain.tld"
        OU = "OU=Users,DC=Domain,DC=tld"
    }
}

Function Set-UserData {
    [cmdletbinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline, ParameterSetName='UserData')]
        [PSTypeName('UserData')]$UserData,

        [parameter(Mandatory, ValueFromPipeline, ParameterSetName='Username')]
        [String[]]$Username

    )

    process {
    if ($PSCmdlet.ParameterSetName -eq 'UserData'){
        Foreach ($User in $UserData) {
            $User.OU = "OU=Computers,DC=Domain,DC=tld"
            $User
        }
    }
    else {
        foreach ($User in $Username) {
            Get-UserData -UserName $User | Set-UserData
        }
    }
}
}
