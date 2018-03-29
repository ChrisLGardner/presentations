function New-TfsTeam
{
    <#  
        .SYNOPSIS
            This function will create a new Team in tfs under a specified Project.

        .DESCRIPTION
            This function will create a new Team in tfs under a specified Project.

            There is currently no REST api for this functionality so it has to use the horrible
            InternetExplorer comobject to do all it's work. You need to pass it a username and password
            so it can login to the actual web page (for VSTS).

        .PARAMETER Name
            The name of the team to be created

        .PARAMETER Description
            The description of the team to be created

        .PARAMETER Permissions
            The permission group to apply to the team for a small set available.

        .PARAMETER Project
            The name of the project under which to create the team

        .PARAMETER CreateArea
            Switch to specify if TFS should create the area path automatically

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER Password
            Password for the provided username when logging into VSTS

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE 
            New-TfsTeam -Team 'Engineering' -Project 'Super Product' -Descrition 'Engineering stuff goes here' -Credential (Get-Credential) -Uri 'https://test.visualstudio.com/defaultcollection'

            This will create an Engineering team under the Super Project project with the specified description.

        .EXAMPLE
            New-TfsTeam -Uri 'https://test.visualstudio.com/defaultcollection' -UseDefaultCredentials -Team 'Engineering' -Project 'Super Product' -Descrition 'Engineering stuff goes here'

            This will create an Engineering team under the Super Project project with the specified description using the provided credentials and uri.

    #>
    [cmdletbinding()]
    param
    (
        #[Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        #[Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Name,

        [String]$Description,

        [parameter(Mandatory)]
        [String]$Project,

        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(ParameterSetName='SingleConnection',Mandatory)]
        [Parameter(ParameterSetName='LocalConnection',Mandatory)]
        [String]$uri,

        [Parameter(ParameterSetName='SingleConnection',Mandatory)]
        [string]$Username,

        [Parameter(ParameterSetName='SingleConnection',Mandatory)]
        [string]$AccessToken,

        [parameter(ParameterSetName='LocalConnection',Mandatory)]
        [switch]$UseDefaultCredentials

    )
    Process
    {

        $headers = @{'Content-Type'='application/json'}
        $Parameters = @{}

        #Use Hashtable to create param block for invoke-restmethod and splat it together
        switch ($PsCmdlet.ParameterSetName) 
        {
            'SingleConnection'
            {
                $WebSession = Connect-TfsServer -Uri $uri -Username $Username -AccessToken $AccessToken
                $Parameters.add('WebSession',$WebSession)
                $Parameters.add('Headers',$headers)

            }
            'LocalConnection'
            {
                $WebSession = Connect-TfsServer -uri $Uri -UseDefaultCredentials
                $Parameters.add('WebSession',$WebSession)
                $Parameters.add('Headers',$headers)
            }
            'WebSession'
            {
                $Uri = $WebSession.uri
                $Parameters.add('WebSession',$WebSession)
                $Parameters.add('Headers',$headers)
                #Connection details here from websession, no creds needed as already there
            }
        }
        
        try
        {
            $TeamExists = Invoke-RestMethod -Uri "$uri/_apis/projects/$Project/teams/$($Name)?api-version=2.2" @Parameters -ErrorAction Stop
        }
        catch
        {
            $ErrorObject = $_ | ConvertFrom-Json

            if (-not($ErrorObject.Message -like "*The team with id '$Name' does not exist*"))
            {
                Throw $_
            }
        }
        
        if ($TeamExists)
        {
            #Write-Error 'The Team already exists, please choose a new unique name'
            Throw 'The Team already exists, please choose a new unique name'
        }        

        #Construct the uri and add it to paramaters block
        $uri = "$uri/_apis/projects/$Project/teams?api-version=2.2"
        $Parameters.Add('uri',$uri)

        $Json = @"
{
  'name': '$Name',
  'description': '$Descrption'
  }
}
"@

        try
        {
            $jsondata = Invoke-restmethod @Parameters -erroraction Stop -Method Post -Body $Json
        }
        catch
        {
            throw $_
        }

        Write-Output $jsondata
    }
}
