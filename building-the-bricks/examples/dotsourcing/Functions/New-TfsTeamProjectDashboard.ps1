Function New-TfsTeamProjectDashboard
{
    [cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Team,

        [Parameter(Mandatory)]
        [String]$Project,

        [Parameter(Mandatory)]
        [String]$Name,

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

        $Dashboards = Get-TfsTeamProjectDashboard -WebSession $WebSession -Team $Team -Project $Project 
        if ($Dashboards | Where-Object {$_.Name -eq $Name})
        {
            Write-Error "Dashboard $Name already exists."
            break
        }
        else
        {
            $NextDashboardSlot = $Dashboards.Position[-1] + 1
        }

        #Construct the uri and add it to paramaters block
        $TeamId = Get-TfsTeam -WebSession $Websession -Project $Project | Where-Object Name -eq "$Team" | Select-Object -ExpandProperty id
        if ($uri -like '*.visualstudio.com*')
        {
            $uri = "$uri/$($Project)/$($TeamId)/_apis/Dashboard/Dashboards?api-version=3.1-preview.2"
        }
        else
        { 
            $uri = "$uri/$($Project)/_apis/Dashboard/groups/$($TeamId)/dashboards/?api-version=2.2-preview.1"
        }
        $Parameters.add('Uri',$uri)

        $body = @{if = $null; name = $Name; position = $NextDashboardSlot;widgets=$null; refreshInterval = $null; eTag = $null; _links = $null; url = $null} | ConvertTo-Json

        try
        {
            $JsonData = Invoke-RestMethod @Parameters -Method Post -Body $body -ErrorAction Stop
        
        }
        catch
        {
            $ErrorMessage = $_
            $ErrorMessage = ConvertFrom-Json -InputObject $ErrorMessage.ErrorDetails.Message
            if ($ErrorMessage.TypeKey -eq 'QueryItemNotFoundException')
            {
                $JsonData = $null
            }
            Else
            {
                Write-Error "Error was $_"
                $line = $_.InvocationInfo.ScriptLineNumber
                Write-Error "Error was in Line $line"
            }
        }

        Write-output $JsonData
    }
}