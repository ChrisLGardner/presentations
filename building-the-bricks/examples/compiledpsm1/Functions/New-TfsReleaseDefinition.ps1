function New-TfsReleaseDefinition
{
    [cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Project,

        [Parameter(Mandatory)]
        [String]$Definition,

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

        #create the REST url
        $Project = $Project.Replace(' ','%20')
        $uri = "$uri/$Project/_apis/release/definitions?api-version=2.2-preview.1"
        $uri = $uri -replace 'visualstudio.com','vsrm.visualstudio.com'

        $Parameters.add('Uri', $Uri)
        $Parameters.Add('body',$Definition)

        try
        {
            $jsondata = Invoke-RestMethod @Parameters -Method Post -ErrorAction Stop
        }
        catch
        {
            Throw $_
        }
        
        #Output data to the pipeline
        if ($jsondata.count -gt 0)
        {
            write-output $jsondata.value
        }
        else
        {
            Write-Output $jsondata 
        }
    }
}
