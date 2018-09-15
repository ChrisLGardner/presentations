function Add-TfsTeamProjectDashboardBuildChart
{
    <#  
    .SYNOPSIS
        This function will create a chart for the specified build and add it to the dashboard.

    .DESCRIPTION
        This function will create a chart for the specified build and add it to the dashboard.

        First creates a blank chart object on the dashboard and then updates it to use the specified build definition.
    .PARAMETER WebSession
        Web session object for the target TFS server.

    .PARAMETER Team
        The name of the team

    .PARAMETER Project
        The name of the project under which the team can be found

    .PARAMETER Dashboard
        The name of the dashboard for the team project

    .PARAMETER BuildName
        The build definition name

    .PARAMETER Uri
        Uri of TFS serverm, including /DefaultCollection (or equivilent)

    .PARAMETER Username
        Username to connect to TFS with

    .PARAMETER AccessToken
        AccessToken for VSTS to connect with.

    .PARAMETER UseDefaultCredentails
        Switch to use the logged in users credentials for authenticating with TFS.

    .EXAMPLE 
        New-TfsTeamProjectDashboardBuildChart -WebSession $session -Team 'Engineering' -Project 'Super Product' -Dashboard 'Overview' -BuildName 'Project1.Build.CI'

        This will add a new build chart to the Overview dashboard for the Project1.Build.CI build definition using the specified web session.

    .EXAMPLE
        New-TfsTeamProjectDashboardBuildChart -Team 'Engineering' -Project 'Super Product' -Dashboard 'Overview' -BuildName 'Project1.Build.CI' -Uri 'https://product.visualstudio.com/DefaultCollection' -Username 'MainUser' -AccessToken (Get-Content c:\accesstoken.txt | Out-String)

        This will add a new build chart to the Overview dashboard for the Project1.Build.CI build definition on the target VSTS account using the provided creds.

    #>
    [cmdletbinding()]
    param (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Team,

        [Parameter(Mandatory)]
        [String]$Project,

        [Parameter(Mandatory)]
        [String]$Dashboard,

        [String]$BuildName,

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
        $headers = @{'Content-Type'='application/json';'accept'='api-version=2.2-preview.1;application/json'}
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

        $DashboardObject = Get-TfsTeamProjectDashboard -WebSession $WebSession -Team $Team -Project $Project | Where-Object Name -eq $Dashboard

        $Uri = "$($DashboardObject.url)/widgets"
        $Parameters.add('Uri',$uri)

        $BuildWidgetJson = @"
{
    "isEnabled": true,
    "_links": null,
    "contentUri": null,
    "contributionId": "ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.BuildChartWidget",
    "configurationContributionId": "ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.BuildChartWidget.Configuration",
    "isNameConfigurable": true,
    "url": null,
    "name": "Chart for Build History",
    "id": null,
    "size": {
        "rowSpan": 1,
        "columnSpan": 2
    },
    "position": {
        "column": 0,
        "row": 0
    },
    "settings": null,
    "typeId": "Microsoft.VisualStudioOnline.Dashboards.BuildChartWidget"
}
"@

        try
        {
          $JsonData = Invoke-RestMethod @Parameters -Method Post -Body $BuildWidgetJson -ErrorAction Stop
    
        }
        catch
        {
          Write-Error "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          Write-Error "Error was in Line $line"
        }
        
        if ($BuildName)
        {
            $BuildObject = Get-TfsBuildDefinition -WebSession $WebSession -Project $Project | Where-Object Name -eq $BuildName
            $Parameters.uri = $JsonData.Url
            
            $UpdateBuild = @"
{
    "url": null,
    "id": "$($jsondata.id)",
    "name": "$BuildName",
    "position": {
        "row": 0,
        "column": 0
    },
    "size": {
        "rowSpan": 1,
        "columnSpan": 2
    },
    "settings": "{\"name\":\"$BuildName\",\"projectId\":\"$($BuildObject.Project.id)\",\"id\":$($BuildObject.id),\"type\":$(if ($BuildObject.Type -eq 'xaml') { '1'} else { '2'}) ,\"uri\":\"$($BuildObject.Uri)\",\"providerName\":\"Team favorites\",\"lastArtifactName\":\"$($BuildObject.Name)\"}",
    "artifactId": "",
    "isEnabled": true,
    "contentUri": null,
    "contributionId": "ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.BuildChartWidget",
    "typeId": "Microsoft.VisualStudioOnline.Dashboards.BuildChartWidget",
    "configurationContributionId": "ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.BuildChartWidget.Configuration",
    "isNameConfigurable": true,
    "loadingImageUrl": "$($Websession.uri)/_static/Widgets/sprintBurndown-buildChartLoading.png",
    "allowedSizes": [{
        "rowSpan": 1,
        "columnSpan": 2
    }]
}
"@
            try
            {
            $UpdatedBuildJson = Invoke-RestMethod @Parameters -Method Patch -Body $UpdateBuild -ErrorAction Stop
            }
            catch
            {
            Write-Error "Error was $_"
            $line = $_.InvocationInfo.ScriptLineNumber
            Write-Error "Error was in Line $line"
            }

            Write-Output $UpdatedBuildJson
        }
        else
        {
            Write-Output $JsonData
        }
    }
}