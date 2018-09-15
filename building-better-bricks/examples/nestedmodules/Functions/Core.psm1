function Connect-TfsServer
{
    <#
        .Synopsis
            Connects to a TFS server and returns a websession object for future connections.
        .DESCRIPTION
            This function allows two options, test the connection to a TFS server to ensure it's a valid endpoint
            or it can connect to a TFS server and authenticate with either the specified username and access token or with the
            default credentials used to log on to the computer.

            To test the connection to a TFS server the script attempts to Invoke-Webrequest to it and then checks the status code
            of the response. If the Invoke fails then the status code is set to 404 and will return '<URL> Not available' to the user.
            If the invoke succeeds and returns a non-20x status code then it's assumed it's unavailable.

            When connecting to a TFS server there are two authentication methods available, for local servers you can use default credentials
            to connect using the domain credentials that you are logged in as (assuming you are on a domain computer and the TFS server authenticates
            with AD) or for remote servers you can use a personal access token, which can be generated from https://siteuri/_details/security/tokens.
            Once a connection has been established the function will return a websession object which can be used with other functions in the module,
            either by storing it in a variable or by piping this cmdlet to another.

        .PARAMETER Uri
            Uri of target TFS server

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentials
            Switch for using local credentials when connecting to on-prem TFS server

        .PARAMETER TestConnection
            Switch to test if TFS server is available to connect

        .EXAMPLE
            Connect-TfsServer -Uri 'https://test.visualstudio.com/DefaultCollection' -TestConnection

            This will attempt to connect to the target TFS server to ensure it's a valid connection. If the server returns a status code other
            than a 20x then the script will report that it's unavailable.

        .EXAMPLE
            $WebSession = Connect-TfsServer -Uri 'https://test.visualstudio.com/DefaultCollection' -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt)

            This will attempt to connect to the remote TFS server hosted on VisualStudio.com using the credentials specified and return a
            web session object for use with other functions

        .EXAMPLE
            $WebSession = Connect-TfsServer -Uri 'https://tfs.domain.local/DefaultCollection' -UseDefaultCredentials

            This will attempt to connect to the local TFS server hosted on your domain using your current domain account credentials. It will
            return a web session object for use with the other functions.

        .EXAMPLE
            $OutputData = Connect-TfsServer -Uri 'https://test.visualstudio.com/DefaultCollection' -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) | Get-TfsTeams -TeamProject 'TestProject'

            This will connect to the TFS server, create a web request object and then pipe it to the Get-TfsTeams and use it to complete the REST API check there.
    #>
    [cmdletbinding()]
    param(

        [parameter(Mandatory)]
        [String]$Uri,

        [Parameter(ParameterSetName='ConnectRemote',Mandatory)]
        [string]$Username,

        [Parameter(ParameterSetName='ConnectRemote',Mandatory)]
        [string]$AccessToken,

        [Parameter(ParameterSetName='ConnectLocal')]
        [switch]$UseDefaultCredentials

    )

    $Parameters = @{}

    switch ($PsCmdlet.ParameterSetName)
    {
        'ConnectRemote'
        {
            $AuthToken = [Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $Username,$AccessToken))
            $AuthToken = [Convert]::ToBase64String($AuthToken)
            $headers = @{Authorization=("Basic $AuthToken")}

            $Parameters.Add('Uri',$uri)
            $Parameters.Add('UseBasicParsing',$true)
            $Parameters.Add('SessionVariable','WebSession')
            $Parameters.Add('Headers',$headers)

            $Result = Invoke-WebRequest @Parameters
            if ($uri -like '*/tfs*' -and $uri -notlike '*/tfs/defaultcollection*') {
                $Uri = $uri -replace '/tfs','/tfs/defaultcollection'
            }
            $WebSession | Add-Member -MemberType NoteProperty -Name 'Uri' -Value $Uri

            $WebSession

        }

        'ConnectLocal'
        {
            $Parameters.Add('Uri',$uri)
            $Parameters.Add('UseBasicParsing',$true)
            $Parameters.Add('SessionVariable','WebSession')
            $Parameters.Add('UseDefaultCredentials',$True)

            $Result = Invoke-WebRequest @Parameters
            if ($uri -like '*/tfs*' -and $uri -notlike '*/tfs/defaultcollection*') {
                $Uri = $uri -replace '/tfs','/tfs/defaultcollection'
            }
            $WebSession | Add-Member -MemberType NoteProperty -Name 'Uri' -Value $Uri

            $WebSession
        }

    }

}
