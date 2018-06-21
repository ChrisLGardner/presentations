Function Add-TfsTeamProjectDashboardMarkdownWidget
{
    [cmdletbinding()]
    param(
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Team,

        [Parameter(Mandatory)]
        [String]$Project,

        [Parameter(Mandatory)]
        [String]$Dashboard,

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
        $headers = @{'Content-Type'='application/json';'accept'='application/json'}
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

        $MarkdownWidgetJson = @"
{
    "isEnabled":true,
    "_links":null,
    "contentUri":null,
    "contributionId":"ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.MarkdownWidget",
    "configurationContributionId":"ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.MarkdownWidget.Configuration",
    "isNameConfigurable":false,
    "url":null,
    "name":"Markdown",
    "id":null,
    "size":{"rowSpan":1,"columnSpan":2},
    "position":{"column":0,"row":0},
    "settings":null,
    "typeId":"Microsoft.VisualStudioOnline.Dashboards.MarkdownWidget",
    "lightboxOptions":{"width":600,"height":500,"resizable":true},
}
"@

        if ($Uri -match 'visualstudio.com')
        {
            $ProjectId = Get-TfsProject -WebSession $WebSession -Project $Project | Select-Object -ExpandProperty Id
            $TeamId = Get-TfsTeam -WebSession $WebSession -Project $Project | Where-Object {$_.Name -eq $Team} | Select-Object -ExpandProperty Id
            $DashboardId = Get-TfsTeamProjectDashboard -WebSession $WebSession -Team $Team -Project $Project | Where-Object {$_.Name -eq $Dashboard} | Select-Object -ExpandProperty Id
            $WidgetUri = "{0}/{1}/{2}/_apis/Dashboard/dashboards/{3}/Widgets?api-version=3.1-preview.2" -f $uri,$ProjectId,$TeamId,$DashboardId
        }
        else
        {
            $WidgetUri = "{0}/widgets?api-version=2.2-preview.1" -f (Get-TfsTeamProjectDashboard -WebSession $WebSession -Team $Team -Project $Project | Where-Object Name -eq $Dashboard | select-object -ExpandProperty url)
        }
        $Parameters.Add('uri',$WidgetUri)

        try
        {
            $JsonData = Invoke-RestMethod @Parameters -Method Post -Body $MarkdownWidgetJson -ErrorAction Stop
        }
        catch
        {
            Write-Error "Error was $_"
            $line = $_.InvocationInfo.ScriptLineNumber
            Write-Error "Error was in Line $line"
        }
    }
}
