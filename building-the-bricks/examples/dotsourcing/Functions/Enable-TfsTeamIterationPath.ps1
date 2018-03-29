function Enable-TfsTeamIterationPath
{
    <#  
        .SYNOPSIS
            This function will enable all iteration paths in the selected team project

        .DESCRIPTION
            This function will enable all iteration paths in the selected team project

            There is currently no REST api for this functionality so it has to use the horrible
            InternetExplorer comobject to do all it's work. You need to pass it a username and password
            so it can login to the actual web page (for VSTS).

        .PARAMETER Team
            The name of the team

        .PARAMETER Project
            The name of the project under which the team can be found

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Credential
            Credentials of user with permissions to update iteration path

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE 
            Enable-TfsTeamIterationPath -Team 'Engineering' -Project 'Super Product' -Credential (Get-Credential) -Uri 'https://test.visualstudio.com/defaultcollection'

            This will enable all the iteration paths for the Engineering team under the Super Product project.

        .EXAMPLE
            Enable-TfsTeamIterationPath -Uri 'https://test.localtfsserver.co.uk/defaultcollection' -UseDefaultCredentials -Team 'Engineering' -Project 'Super Product'

            This will enable all the iteration paths for the Engineering team under the Super Product project using the logged in users credentials.

    #>
    [cmdletbinding()]
    param
    (
        #[Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        #[Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Team,

        [parameter(Mandatory)]
        [String]$Project,

        [Parameter(ParameterSetName='SingleConnection',Mandatory)]
        [Parameter(ParameterSetName='LocalConnection',Mandatory)]
        [String]$uri,

        [Parameter(ParameterSetName='SingleConnection',Mandatory)]
        [System.Management.Automation.PSCredential]$Credential,

        [parameter(ParameterSetName='LocalConnection',Mandatory)]
        [switch]$UseDefaultCredentials

    )
    Process
    {

        $Browser = New-Object -ComObject InternetExplorer.Application

        switch ($PsCmdlet.ParameterSetName) 
        {
            'SingleConnection'
            {
                $Browser.Navigate("$uri/$project/$team/_admin/_iterations")
                while ($Browser.Busy)
                {
                    Start-Sleep -Seconds 1
                }

                if ($Browser.LocationURL -like '*login.live.com*' )
                {
                    $Elements = $Browser.Document
                    $Elements.getElementsByTagName('input') | foreach-object {
                        if ($_.name -eq 'loginfmt') {
                            $_.value = $Credential.Username
                            $UsernameEnterred = $true
                        }
                        if ($_.name -eq 'passwd') {
                            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
                            $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                            Remove-Variable -Name BSTR
                            $_.value = $password
                            Remove-Variable -Name Password
                            $PasswordEnterred = $true
                        }
                        if ($_.Name -eq 'SI' -and $UsernameEnterred -and $PasswordEnterred)
                        {
                            $_.click()
                        }
                    }
                }

                while ($Browser.Busy)
                {
                    Start-Sleep -Seconds 1
                }

            }
            'LocalConnection'
            {
            }
        }
        
        $Browser.Navigate("$uri/$project/$team/_admin/_iterations")
        while ($Browser.Busy)
        {
            Start-Sleep -Seconds 1
        }

        $Elements = $Browser.Document
        $Elements.body.getElementsByTagName('input') | Where-Object Type -eq checkbox | ForEach-Object {
            $_.click()
        }

    }
}
