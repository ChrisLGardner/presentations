function Add-TfsTaskToWorkItem
{
    <#
        .SYNOPSIS
            This function will add the specified task or tasks to a specified work item

        .DESCRIPTION
            This function will add the task or tasks to the work item specified.

            The function will take either a websession object or a uri and
            credentials. The web session can be piped to the fuction from the
            Connect-TfsServer function.

        .PARAMETER ID
            The ID of the work item to add the task(s) to

        .PARAMETER Task
            The name of the task or tasks to add to the work item

        .PARAMETER WorkRemaining
            The work remaining for the work item to be added, defaults to 0

        .PARAMETER IterationPath
            The iteration path to add the tasks to

        .EXAMPLE
            Add-TfsTasskToWorkItem -WebSession $Session -Task 'Code Review' -id 3

            This will add a task named 'Code Review' to the work item with an id of 3.

        .EXAMPLE
            Add-TfsTasskToWorkItem -Uri 'https://test.visualstudio.com/DefaultCollection' -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -Task 'Code Review' -id 3 -WorkRemaining 4

            This will add a task named 'Code Review' to the work item with an id of 3 and set the work remaining to 4.
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory)]
        [String]$Id,

        [Parameter(Mandatory)]
        [String]$IterationPath,

        [Parameter(Mandatory)]
        [String[]]$Task,

        [int]$WorkRemaining = 0

    )
    Process
    {
        $headers = @{'Content-Type'='application/json-patch+json'}
        $Parameters = @{}
        $Parameters.add('WebSession',$WebSession)
        $Parameters.add('Headers',$headers)

        $uri = "$Uri/$($IterationPath.split('\')[0])/_apis/wit/workitems/`$Task?api-version=1.0"
        $Parameters.add('Uri', $Uri)
        $jsondata = @()

        foreach ($TaskToAdd in $task)
        {
            $data = @(@{op = 'add'; path = '/fields/System.Title'; value = "$TaskToAdd" } ; `
                      @{op = 'add'; path = '/fields/System.Description'; value = "$TaskToAdd" };  `
                      @{op = 'add'; path = '/fields/Microsoft.VSTS.Scheduling.RemainingWork'; value = "$WorkRemaining" }  ;  `
                      @{op = 'add'; path = '/fields/System.IterationPath'; value = "$IterationPath" }  ;  `
                      @{op = 'add'; path = '/relations/-'; value = @{ 'rel' = 'System.LinkTypes.Hierarchy-Reverse' ; 'url' = "$($WebSession.Uri)/_apis/wit/workItems/$id"} }   ) | ConvertTo-Json

            try
            {
                $jsondata += Invoke-RestMethod @parameters -Method Patch -Body $data -ErrorAction Stop
            }
            catch
            {
                Throw
            }
        }

        Write-Output $jsondata
    }
}
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
function Add-TfsTeamProjectDashboardReleaseChart
{
    <#
        .SYNOPSIS
            This function will create a chart for either the specified release or a blank chart and add it to the dashboard.

        .DESCRIPTION
            This function will create a chart for either the specified release or a blank chart and add it to the dashboard.

            First creates a blank chart object on the dashboard and then updates it to use the specified release definition if one is specified.
        .PARAMETER WebSession
            Web session object for the target TFS server.

        .PARAMETER Team
            The name of the team

        .PARAMETER Project
            The name of the project under which the team can be found

        .PARAMETER Dashboard
            The name of the dashboard for the team project

        .PARAMETER ReleaseName
            The Release definition name

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            Username to connect to TFS with

        .PARAMETER AccessToken
            AccessToken for VSTS to connect with.

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE
            Add-TfsTeamProjectDashboardBuildChart -WebSession $session -Team 'Engineering' -Project 'Super Product' -Dashboard 'Overview' -Release 'Project1.Build.CI'

            This will add a new build chart to the Overview dashboard for the Project1.Build.CI build definition using the specified web session.

        .EXAMPLE
            Add-TfsTeamProjectDashboardBuildChart -Team 'Engineering' -Project 'Super Product' -Dashboard 'Overview' -Release 'Project1.Build.CI' -Uri 'https://product.visualstudio.com/DefaultCollection' -Username 'MainUser' -AccessToken (Get-Content c:\accesstoken.txt | Out-String)

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

        [String]$ReleaseName,

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
        $Parameters.add('Uri',$WidgetUri)

        $ReleaseWidgetJson = @"
@"
{
    "isEnabled":true,
    "_links":null,
    "contentUri":null,
    "contributionId":"ms.vss-releaseManagement-web.release-definition-summary-widget",
    "configurationContributionId":"ms.vss-releaseManagement-web.release-definition-summary-widget-configuration",
    "isNameConfigurable":true,
    "url":null,
    "name":"Release Definition Overview",
    "id":null,
    "size":{
        "rowSpan":2,
        "columnSpan":3
    },
    "position":{
        "column":0,
        "row":0
    },
    "settings":null,
    "typeId":"release-definition-summary-widget"
}
"@

        try
        {
          $JsonData = Invoke-RestMethod @Parameters -Method Post -Body $ReleaseWidgetJson -ErrorAction Stop

        }
        catch
        {
          Write-Error "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          Write-Error "Error was in Line $line"
        }

        if ($ReleaseName)
        {
            $Release = Get-TfsReleaseDefinition -WebSession $WebSession -Project $Project | Where-Object {$_.Name -eq $ReleaseName}
            $Parameters.uri = "$($JsonData.Url)?api-version=2.2-preview.1"

            $UpdateBuild = @"
{
    "id":"$($JsonData.id)",
    "name":"$($Release.name)",
    "position":{"row":2,"column":3},
    "size":{"rowSpan":2,"columnSpan":3},
    "settings":"{\"releaseDefinitionId\":$($Release.id)}",
    "artifactId":"",
    "dashboard":{"eTag":"$($JsonData.Dashboard.eTag)"},
    "isEnabled":true,
    "contentUri":null,
    "contributionId":"ms.vss-releaseManagement-web.release-definition-summary-widget",
    "typeId":"release-definition-summary-widget",
    "configurationContributionId":"ms.vss-releaseManagement-web.release-definition-summary-widget-configuration",
    "isNameConfigurable":true,
    "loadingImageUrl":null,
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
Function Add-TfsTeamProjectDashboardSprintWidget
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

        [ValidateSet('Burndown','Capacity','Overview')]
        [String]$SprintWidget,

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

        $SprintWidgetJson = @"
{
    "isEnabled":true,
    "_links":null,
    "contentUri":null,
    "contributionId":"ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.Sprint$($SprintWidget)Widget",
    "configurationContributionId":null,
    "isNameConfigurable":false,
    "url":null,
    "name":"Sprint $SprintWidget",
    "id":null,
    "size":{
        "rowSpan":1,
        "columnSpan":2
    },
    "position":{
        "column":0,
        "row":0
    },
    "settings":null,
    "typeId":"Microsoft.VisualStudioOnline.Dashboards.Sprint$($SprintWidget)Widget"
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
            $JsonData = Invoke-RestMethod @Parameters -Method Post -Body $SprintWidgetJson -ErrorAction Stop

        }
        catch
        {
            Write-Error "Error was $_"
            $line = $_.InvocationInfo.ScriptLineNumber
            Write-Error "Error was in Line $line"
        }
    }
}
function Add-TfsTeamProjectDashboardWorkItemQuery
{
    <#
        .SYNOPSIS
            This function will add a work item query to a dashboard.

        .DESCRIPTION
            This function will add a work item query to a dashboard, either using an existing query or a new query when passed a wiql string.

            First creates a object on the dashboard and then updates it to use the specified query.
        .PARAMETER WebSession
            Web session object for the target TFS server.

        .PARAMETER Team
            The name of the team

        .PARAMETER Project
            The name of the project under which the team can be found

        .PARAMETER Dashboard
            The name of the dashboard for the team project

        .PARAMETER QueryPath
            The path to the query, either existing or new, including folders and seperated with /'s

        .PARAMETER Query
            The wiql query string to create and use for the widget

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            Username to connect to TFS with

        .PARAMETER AccessToken
            AccessToken for VSTS to connect with.

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE
            New-TfsTeamProjectDashboardWorkItemQuery -WebSession $session -Team 'Engineering' -Project 'Super Product' -Dashboard 'Overview' -QueryPath 'Shared Queries/Assigned To You'

            This will add a new query to the Overview dashboard for the Assigned To You work item query using the specified web session.

        .EXAMPLE
            $WiqlString = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.AssignedTo],[System.State],[System.Tags] FROM WorkItemLinks WHERE ([Source].[System.TeamProject] = @project AND ( [Source].[System.WorkItemType] = 'Product Backlog Item' OR [Source].[System.WorkItemType] = 'Bug' ) AND [Source].[System.State] <> 'Done' AND [Source].[System.State] <> 'Removed' AND [Source].[System.IterationPath] = @currentIteration) AND ([Target].[System.TeamProject] = @project AND [Target].[System.WorkItemType] = 'Task' AND [Target].[System.AssignedTo] = @me AND [Target].[System.State] <> 'Done' AND [Target].[System.State] <> 'Removed' AND [Target].[System.IterationPath] = @currentIteration) mode(MustContain)"
            New-TfsTeamProjectDashboardWorkItemQuery -Team 'Engineering' -Project 'Super Product' -Dashboard 'Overview' -QueryPath 'Shared Queries/Assigned For Sprint' -Query $WiqlString -Uri 'https://product.visualstudio.com/DefaultCollection' -Username 'MainUser' -AccessToken (Get-Content c:\accesstoken.txt | Out-String)

            This will add a new query to the dashboard using the specified query string on the target VSTS account using the provided creds.

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

        [Parameter(Mandatory)]
        [String]$QueryPath,

        [String]$Query,

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

        $QueryPath = $QueryPath -replace '\\','/'
        $QueryFolder = ($QueryPath -split '/' | Select-Object -SkipLast 1) -join '/'
        $QueryName = ($QueryPath -split '/')[-1]

        #Either create the new Query or get the details for the existing one
        if ($Query)
        {

            $NewQueryBody = @{ Name = $QueryName; wiql = $Query} | ConvertTo-Json -Depth 10

            $QueryUrl = "$Uri/$Project/_apis/wit/queries/$($QueryFolder -replace ' ','%20')?api-version=1.0"
            try
            {
                $JsonData = Invoke-Restmethod -Uri $QueryUrl @Parameters -Method Post -Body $NewQueryBody -ErrorAction Stop

            }
            catch
            {
                Write-Error "Error was $_"
                $line = $_.InvocationInfo.ScriptLineNumber
                Write-Error "Error was in Line $line"
            }
        }
        else
        {
            $JsonData = Get-TfsWorkItemQuery -WebSession $WebSession -Project $Project -Folder $QueryFolder -Name $QueryName
        }

        #Add the widget to the dashboard and then update it to use the correct query
        $NewQueryTileJson = @"
{
    "isEnabled":true,
    "_links":null,
    "contentUri":null,
    "contributionId":"ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.QueryScalarWidget",
    "configurationContributionId":"ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.QueryScalarWidget.Configuration",
    "isNameConfigurable":true,
    "url":null,
    "name":"Query Tile",
    "id":null,
    "size":{
        "rowSpan":1,
        "columnSpan":1
    },
    "position":{
        "column":0,
        "row":0
    },
    "settings":null,
    "typeId":"Microsoft.VisualStudioOnline.Dashboards.QueryScalarWidget"
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
        try
        {
          $NewWidget = Invoke-RestMethod -uri $Widgeturi @parameters -Method Post -Body $NewQueryTileJson
        }
        catch
        {
          "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          "Error was in Line $line"
        }

        $UpdateQueryJson = @"
{
    "id":"$($NewWidget.id)",
    "name":"$($JsonData.Name)",
    "eTag":"$($NewWidget.eTag)",
    "dashboard":{
        "eTag":"$($NewWidget.dashboard.eTag)"
    },
    "position":{
        "row":0,
        "column":0
    },
    "size":{
        "rowSpan":1,
        "columnSpan":1
    },
    "settings":"{\"queryId\":\"$($JsonData.id)\",\"queryName\":\"$($JsonData.Name)\",\"colorRules\":[{\"isEnabled\":false,\"backgroundColor\":\"#339933\",\"thresholdCount\":10,\"operator\":\"<=\"},{\"isEnabled\":false,\"backgroundColor\":\"#E51400\",\"thresholdCount\":20,\"operator\":\">\"}],\"lastArtifactName\":\"$($JsonData.name)\"}",
    "artifactId":"",
    "isEnabled":true,
    "contributionId":"ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.QueryScalarWidget",
    "typeId":"Microsoft.VisualStudioOnline.Dashboards.QueryScalarWidget",
    "configurationContributionId":"ms.vss-dashboards-web.Microsoft.VisualStudioOnline.Dashboards.QueryScalarWidget.Configuration",
    "isNameConfigurable":true,
    "loadingImageUrl":"$($Websession.uri)/_static/Widgets/scalarLoading.png",
    "allowedSizes":[{
        "rowSpan":1,
        "columnSpan":1
    }]
}
"@
        try
        {
            if ($NewWidget.url -match 'visualstudio.com')
            {
                $UpdateQuery = Invoke-RestMethod -Uri "$($NewWidget.url)?api-version=3.1-preview.2" -Method Patch -Body $UpdateQueryJson -Headers @{'Content-Type'='application/json; charset=utf-8'} -WebSession $WebSession
            }
            else
            {
                $UpdateQuery = Invoke-RestMethod -Uri "$($NewWidget.url)?api-version=2.2-preview.1" -Method Patch -Body $UpdateQueryJson -Headers @{'Content-Type'='application/json; charset=utf-8'} -WebSession $WebSession
            }
        }
        catch
        {
          "Error was $($_.Exception)"
          $line = $_.InvocationInfo.ScriptLineNumber
          "Error was in Line $line"
        }
    }
}
function Add-TfsWorkItemHyperlink
{
    <#
        .SYNOPSIS
            This function will add a hyperlink to a work item.

        .DESCRIPTION
            This function will add a hyperlink to a work item.

            Additional comments can be added to the history and the hyperlink itself using the
            parameters provided. This will auto-increment the revision number as needed based on the existing
            one on the work item.

        .PARAMETER Id
            ID of the work item to modify.

        .PARAMETER Hyperlink
            Hyperlink to add, can be a file:/// link or anything similar

        .PARAMETER Comment
            Comment to appear in the history for adding this link. Will default to "Added a hyperlink"

        .PARAMETER HyperlinkComment
            Comment to add to the hyperlink.

        .EXAMPLE
            Add-TfsWorkItemHyperlink -WebSession $session -Id 123 -Hyperlink 'http://www.bbc.co.uk'

            This will add a hyperlink to bbc.co.uk to the work item using an existing web session for authenticating.

        .EXAMPLE
            Add-TfsWorkItemHyperlink -Id 123 -Hyperlink 'http://www.bbc.co.uk' -Uri 'https://product.visualstudio.com/DefaultCollection' -Username 'MainUser' -AccessToken (Get-Content c:\accesstoken.txt | Out-String)

            This will add a hyperlink to bbc.co.uk to the work item using the provided credentials.

    #>
    [cmdletbinding()]
    param(

        [Parameter(Mandatory)]
        [String]$Id,

        [Parameter(Mandatory)]
        [String]$Hyperlink,

        [string]$Comment = "Added a hyperlink",

        [string]$HyperlinkComment

    )

    Process
    {
        $headers = @{'Content-Type'='application/json-patch+json';'accept'='api-version=2.2'}
        $Parameters = @{}
        $Parameters.add('WebSession',$WebSession)
        $Parameters.add('Headers',$headers)

        $WorkItem = Get-TfsWorkItemDetail -WebSession $WebSession -ID $Id

        $JsonBody = @"
[
    {
        "op": "test",
        "path": "/rev",
        "value": $($WorkItem.Rev)
    },
    {
        "op": "add",
        "path": "/fields/System.History",
        "value": "$Comment"
    },
    {
        "op": "add",
        "path": "/relations/-",
        "value": {
            "rel": "Hyperlink",
            "url": "$Hyperlink",
            "attributes": {
                "comment":"$HyperlinkComment"
            }
        }
    }
]
"@

        $uri = "$Uri/_apis/wit/workitems/$id"
        $Parameters.Add('Uri',$uri)

        try
        {
            $JsonOutput = Invoke-RestMethod -Method Patch -Body $JsonBody @Parameters -ErrorAction Stop
        }
        catch
        {
            Write-Error "Failed to update work item $id."
        }

        Write-Output $JsonOutput
    }
}
function Add-TfsWorkItemParentChildLink
{
    <#
        .SYNOPSIS
            This function will add a hyperlink to a work item.

        .DESCRIPTION
            This function will add a hyperlink to a work item.

            Additional comments can be added to the history and the hyperlink itself using the
            parameters provided. This will auto-increment the revision number as needed based on the existing
            one on the work item.

        .PARAMETER ParentId
        ID of the parent work item to add a link to.

        .PARAMETER ChildId
        ID of the child work item to link to.

        .EXAMPLE
            Add-TfsWorkItemHyperlink -WebSession $session -Id 123 -Hyperlink 'http://www.bbc.co.uk'

            This will add a hyperlink to bbc.co.uk to the work item using an existing web session for authenticating.

        .EXAMPLE
            Add-TfsWorkItemHyperlink -Id 123 -Hyperlink 'http://www.bbc.co.uk' -Uri 'https://product.visualstudio.com/DefaultCollection' -Username 'MainUser' -AccessToken (Get-Content c:\accesstoken.txt | Out-String)

            This will add a hyperlink to bbc.co.uk to the work item using the provided credentials.

    #>
    [cmdletbinding()]
    param(

        [parameter(Mandatory)]
        [int]$ParentId,

        [parameter(Mandatory)]
        [int]$ChildId

    )

    Process
    {
        $headers = @{'Content-Type'='application/json-patch+json';'accept'='api-version=2.2'}
        $Parameters = @{}
        $Parameters.add('WebSession',$WebSession)
        $Parameters.add('Headers',$headers)

        $ParentWorkItem = Get-TfsWorkItemDetail -WebSession $WebSession -ID $ParentId
        $ChildWorkItem = Get-TfsWorkItemDetail -WebSession $WebSession -ID $ChildId

        $JsonBody = @"
[
    {
        "op": "test",
        "path": "/rev",
        "value": $($ParentWorkItem.Rev)
    },
    {
    "op": "add",
    "path": "/relations/-",
    "value": {
      "rel": "System.LinkTypes.Hierarchy-forward",
      "url": "$($ChildWorkItem.url)",
      "attributes": {
        "comment": "Making a new link for the dependency"
      }
    }
  }
]
"@

        $Parameters.Add('Uri',$ParentWorkItem.url)

        try
        {
            $JsonOutput = Invoke-RestMethod -Method Patch -Body $JsonBody @Parameters -ErrorAction Stop
        }
        catch
        {
            Write-Error "Failed to update work item $ParentId."
        }

        Write-Output $JsonOutput
    }
}
#function Add-TfsWorkItemRelatedLink
#{
    <#
        .SYNOPSIS
            This function will add a hyperlink to a work item.

        .DESCRIPTION
            This function will add a hyperlink to a work item.

            Additional comments can be added to the history and the hyperlink itself using the
            parameters provided. This will auto-increment the revision number as needed based on the existing
            one on the work item.

        .PARAMETER ParentId
            ID of the parent work item to add a link to.

        .PARAMETER ChildId
            ID of the child work item to link to.

        .EXAMPLE
            Add-TfsWorkItemHyperlink -WebSession $session -Id 123 -Hyperlink 'http://www.bbc.co.uk'

            This will add a hyperlink to bbc.co.uk to the work item using an existing web session for authenticating.

        .EXAMPLE
            Add-TfsWorkItemHyperlink -Id 123 -Hyperlink 'http://www.bbc.co.uk' -Uri 'https://product.visualstudio.com/DefaultCollection' -Username 'MainUser' -AccessToken (Get-Content c:\accesstoken.txt | Out-String)

            This will add a hyperlink to bbc.co.uk to the work item using the provided credentials.

    #><#
    [cmdletbinding()]
    param(

        [parameter(Mandatory)]
        [ValidateCount(2,2)]
        [int[]]$RelatedId

    )

    Process
    {
        $headers = @{'Content-Type'='application/json-patch+json';'accept'='api-version=2.2'}
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


        $PrimaryWorkItem = Get-TfsWorkItemDetail -WebSession $WebSession -ID $RelatedId[0]
        $SecondaryWorkItem = Get-TfsWorkItemDetail -WebSession $WebSession -ID $RelatedId[1]

        $JsonBody = @"
[
    {
        "op": "test",
        "path": "/rev",
        "value": $($PrimaryWorkItem.Rev)
    },
    {
    "op": "add",
    "path": "/relations/-",
    "value": {
      "rel": "System.LinkTypes.Related-forward",
      "url": "$($SecondaryWorkItem.url)",
      "attributes": {
        "comment": "Making a new link for the relation"
      }
    }
  }
]
"@

        $Parameters.Add('Uri',$PrimaryWorkItem.url)

        try
        {
            $JsonOutput = Invoke-RestMethod -Method Patch -Body $JsonBody @Parameters -ErrorAction Stop
        }
        catch
        {
            Write-Error "Failed to update work item $($PrimaryWorkItem.Id)"
        }

        Write-Output $JsonOutput
    }
}
#>
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
function Get-TfsBuildDefinition
{
    <#
        .SYNOPSIS
            This function will find either all build definitions of a specific project or just the requested one.

        .DESCRIPTION
            This function will find either all build definitions of a specific project or just the requested one.

            The function will take either a websession object or a uri and
            credentials. The web session can be piped to the fuction from the
            Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER ID
            The ID of the build definition to find

        .PARAMETER Project
            The name of the project containing the build definitions

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE
            Get-TfsBuildDefinition -WebSession $Session -Project 'Engineering'

            This will return all build definitions under the Engineering project.

        .EXAMPLE
            Get-TfsBuildDefinition -Uri 'https://test.visualstudio.com/DefaultCollection'  -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -Project 'Engineering' -Id 10

            This will return the build definition with an Id of 10 under the Engineering Project.
    #>
[cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Project,

        [int]$BuildDefinitionID,

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

        #construct uri
        if ($BuildDefinitionID -gt 0)
        {
            $uri = "$uri/$project/_apis/build/definitions/$($BuildDefinitionID)?api-version=2.0"
        }
        else
        {
            $uri = "$uri/$project/_apis/build/definitions?api-version=2.0"
        }

        $Parameters.add('Uri', $Uri)

        try
        {
            $jsondata = Invoke-restmethod @Parameters -ErrorAction Stop
        }
        catch
        {
            throw
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
function Get-TfsGitRepository
{
    <#
        .SYNOPSIS
            This function gets the git repos in a TFS team project

        .DESCRIPTION
            This function gets the git repos in a TFS team project from a target
            TFS server, using either the WebSession provided or manually specified
            URI and credentials.

            If the project doesn't exist then an error will be returned. Wildcard searches are
            not currently available.

            You can also pipe the a WebSession object into the command to, either from a normal variable
            or from the Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER TeamProject
            Existing Team Project Name


        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE

            Get-TfsGitRepository -WebSession $Session -Project t1

            This will get all the git repos currently on the T1 project on the TFS server
            in the WebSession variable.

        .EXAMPLE

            Get-TfsTeam  -Uri https://test.visualstudio.com/DefaultCollection  -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -Project t1

            This will get all the git repos currently on the T1 project on the TFS server
            specified using the credentials provided.

        .EXAMPLE

            Connect-TfsServer -Uri "https://test.visualstudio.com/DefaultCollection -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) |  Get-TfsTeam -Project t1

            This will get all the git repos currently on the T1 project on the TFS server
            in the WebSession provided by the Connect-TfsServer output.
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Project,

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
        $uri = "$uri/$Project/_apis/git/repositories?api-version=1.0"
        $Parameters.add('Uri', $Uri)

        try
        {
            $jsondata = Invoke-RestMethod @Parameters -ErrorAction Stop
        }
        catch
        {
            Throw
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
function Get-TfsProject
{
    <#
        .SYNOPSIS
            This function gets a list of TFS team projects

        .DESCRIPTION
            This function gets a list of all the team projects from
            the target TFS server that the user has access to.

            The function will take either a websession object or a uri and
            credentials. The web session can be piped to the fuction from the
            Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .PARAMETER Project
            Get details of a specific project.

        .PARAMETER IncludeCapabilities
            Get full details of a project, include source control method used and process template.

        .EXAMPLE
            Get-TfsTeamProject -WebSession $Session

            This will get all the Projects that the user in the Web Session object has access to.

        .EXAMPLE
            Get-TfsTeamProject -Uri 'https://test.visualstudio.com/DefaultCollection'  -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt)

            This will get all the Projects that the user has access to.
    #>
    [cmdletbinding()]
    param
    (
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
        [switch]$UseDefaultCredentials,

        [string]$Project,

        [switch]$IncludeCapabilities

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
        if ($Project)
        {
            $uri = "$uri/_apis/projects/$($Project)?api-version=1.0"
            if ($IncludeCapabilities)
            {
                $Uri = "$Uri&includeCapabilities=true"
            }
        }
        else
        {
            $uri = "$uri/_apis/projects?api-version=1.0"
        }

        $parameters.add('Uri',$uri)

        #Attempt to get the data from the Rest API
        try
        {
            $jsondata = Invoke-RestMethod @Parameters -ErrorAction Stop
        }
        catch
        {
            Throw
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
function Get-TfsReleaseDefinition
{
    <#
        .SYNOPSIS
            This function will find either all release definitions of a specific project or just the requested one.

        .DESCRIPTION
            This function will find either all release definitions of a specific project or just the requested one.

            The function will take either a websession object or a uri and
            credentials. The web session can be piped to the fuction from the
            Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER ID
            The ID of the release definition to find

        .PARAMETER Project
            The name of the project containing the release definitions

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE
            Get-TfsReleaseDefinition -WebSession $Session -Project 'Engineering'

            This will return all release definitions under the Engineering project.

        .EXAMPLE
            Get-TfsReleaseDefinition -Uri 'https://test.visualstudio.com/DefaultCollection'  -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -Project 'Engineering' -Id 10

            This will return the release definition with an Id of 10 under the Engineering Project.
    #>
[cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Project,

        [int]$Id,

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

        $Uri = $Uri -replace 'visualstudio.com','vsrm.visualstudio.com'

        #construct uri
        if ($Id)
        {
            $uri = "$uri/$project/_apis/release/definitions/$($id)?api-version=3.0-preview.1"
        }
        else
        {
            $uri = "$uri/$project/_apis/release/definitions?api-version=3.0-preview.1"
        }

        $Parameters.add('Uri', $Uri)

        try
        {
            $jsondata = Invoke-restmethod @Parameters -ErrorAction Stop
        }
        catch
        {
            throw
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
function Get-TfsTeam
{
    <#
        .SYNOPSIS
            This function gets the teams in a TFS team project

        .DESCRIPTION
            This function gets the teams in a TFS team project from a target
            TFS server, using either the WebSession provided or manually specified
            URI and credentials.

            If the project doesn't exist then an error will be returned. Wildcard searches are
            not currently available.

            You can also pipe the a WebSession object into the command to, either from a normal variable
            or from the Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER TeamProject
            Existing Team Project Name


        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE

            Get-TfsTeam -WebSession $Session -TeamProject t1

            This will get all the teams currently on the T1 project on the TFS server
            in the WebSession variable.

        .EXAMPLE

            Get-TfsTeam  -Uri https://test.visualstudio.com/DefaultCollection  -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -TeamProject t1

            This will get all the teams currently on the T1 project on the TFS server
            specified using the credentials provided.

        .EXAMPLE

            Connect-TfsServer -Uri "https://test.visualstudio.com/DefaultCollection -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) |  Get-TfsTeam -TeamProject t1

            This will get all the teams currently on the T1 project on the TFS server
            in the WebSession provided by the Connect-TfsServer output.
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Project,

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
        $uri = "$uri/_apis/projects/$Project/teams?api-version=1.0"
        $Parameters.add('Uri', $Uri)

        try
        {
            $jsondata = Invoke-RestMethod @Parameters -ErrorAction Stop
        }
        catch
        {
            Throw
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
function Get-TfsTeamProjectDashboard
{
    <#
        .SYNOPSIS
            This function will return all dashboards associated with a specific team project.

        .DESCRIPTION
            This function will return all dashboards associated with a specific team project.

            The function will take either a websession object or a uri and
            credentials. The web session can be piped to the fuction from the
            Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER Team
            The name of the team who's dashboards should be returned

        .PARAMETER Project
            The name of the project containing the dashboard

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE
            Get-TfsTeamProjectDashboard -WebSession $Session -Team 'Engineering' -Project 'Super Product'

            This will return any dashboards that are on the Super Product project and linked to the Engineering team
            using the already established session.

        .EXAMPLE
            Get-TfsTeamProjectDashboard -Uri 'https://test.visualstudio.com/defaultcollection'  -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -Team 'Engineering' -Project 'Super Product'

            This will return any dashboards that are on the Super Product project and linked to the Engineering team
            using the provided credentials and uri.

    #>
    [cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Team,

        [Parameter(Mandatory)]
        [String]$Project,

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
        $headers = @{'Content-Type'='application/json-patch+json'}
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

        #Construct the uri and add it to paramaters block
        $TeamId = Get-TfsTeam -WebSession $Websession -Project $Project | Where-Object Name -eq "$Team" | Select-Object -ExpandProperty id
        $uri = "$uri/$($Project)/_apis/Dashboard/Groups/$($TeamId)"
        $Parameters.add('Uri',$uri)


        try
        {
            $jsondata = Invoke-restmethod @Parameters -erroraction Stop
        }
        catch
        {
            throw
        }

        Write-Output $jsondata.dashboardentries

    }
}
function Get-TfsTeamProjectDashboardWidget
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

        if ($Uri -match 'visualstudio.com')
        {
            $ProjectId = Get-TfsProject -WebSession $WebSession -Project $Project | Select-Object -ExpandProperty Id
            $TeamId = Get-TfsTeam -WebSession $WebSession -Project $Project | Where-Object {$_.Name -eq $Team} | Select-Object -ExpandProperty Id
            $DashboardId = Get-TfsTeamProjectDashboard -WebSession $WebSession -Team $Team -Project $Project | Where-Object {$_.Name -eq $Dashboard} | Select-Object -ExpandProperty Id
            $QueryUri = "{0}/{1}/{2}/_apis/Dashboard/dashboards/{3}/Widgets?api-version=3.1-preview.2" -f $uri,$ProjectId,$TeamId,$DashboardId
        }
        else
        {
            $QueryUri = "{0}/widgets?api-version=2.2-preview.1" -f (Get-TfsTeamProjectDashboard -WebSession $WebSession -Team $Team -Project $Project | Where-Object Name -eq $Dashboard | select-object -ExpandProperty url)
        }
        $Parameters.add('Uri',$QueryUri)

        try
        {
            $JsonData = Invoke-RestMethod @Parameters -ErrorAction Stop
        }
        catch
        {
            Write-Error "Error was $_"
            $line = $_.InvocationInfo.ScriptLineNumber
            Write-Error "Error was in Line $line"
        }

        Write-output $JsonData
    }
}
function Get-TfsWorkItemDetail
{
    <#
        .SYNOPSIS
            This function gets the details of the specified work item

        .DESCRIPTION
            This function gets the details of the specified work item from either the target
            server, using the specified credentials, or to the specified WebSession.

            The function will return the raw JSON output as a PS object, if an invalid ID is
            provided then an error will be returned.

        .PARAMETER ID
            ID of work item to look up

        .EXAMPLE
            Get-TfsWorkItemDetail -id 1

            This will get the details of the work item with ID 1, connecting to the target TFS server using the specified username
            and password
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory)]
        [String]$ID
    )

    Process
    {
        write-verbose "Getting details for WI $id via $($WebSession.Uri) "

        $headers = @{'Content-Type'='application/json'}
        $Parameters = @{}
        $Parameters.add('WebSession',$WebSession)
        $Parameters.add('Headers',$headers)

        $uri = "$Uri/_apis/wit/workitems/$id"
        $Parameters.add('Uri', $Uri)
        try
        {
            $jsondata = Invoke-RestMethod @Parameters -ErrorAction Stop
        }
        catch
        {
            Write-Error "No work item with ID: $Id found in the target instance ($Uri)"
        }
        Write-Output $jsondata
    }
}
Function Get-TfsWorkItemInIteration
{
    <#
        .SYNOPSIS
            This function gets any work items in the specified Iteration

        .DESCRIPTION
            This function gets any work items in the specified iteration.

            The function accepts input from the pipeline in the form of a WebSession object, such as generated by the Connect-TfsServer
            function.

        .PARAMETER IterationPath
            The exact path of the iteration to look up, such as 'test\Sprint 1'

        .PARAMETER IdOnly
            Switch that will cause function to only return the Ids of the Work Items

        .PARAMETER IncludeClosed
            Switch that will cause function to also return closed work items

        .EXAMPLE
            Get-TfsWorkItemInIteration -Uri https://test.visualstudio.com/DefaultCollection -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -IterationPath 'Test\Sprint 1'

            This will get all the work items in Sprint 1 of the Test project that are in the New state, using the specified credentials and Uri.

        .EXAMPLE
            Get-TfsWorkItemInIteration -WebSession $Session -IterationPath 'Test\Sprint 4'

            This will get all the work items in Sprint 4 of the Test project with the New or Approved state, using the WebSession object for the Uri and credentials.

        .EXAMPLE
            Connect-TfsServer -Uri "https://test.visualstudio.com/DefaultCollection  -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) |  Get-TfsWorkItemInIterationWithNoTask -IterationPath 'Test\Sprint 4'

            This will connect to the specified TFS server and then pass the WebSession object into the pipeline and get all the work items in Sprint 4 of the Test project.
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory)]
        [String]$IterationPath,

        [switch]$IdOnly,

        [switch]$IncludeClosed

    )
    Process
    {
        $headers = @{'Content-Type'='application/json'}
        $Parameters = @{}
        $Parameters.add('WebSession',$WebSession)
        $Parameters.add('Headers',$headers)

        write-verbose "Getting Backlog Items under $iterationpath via $uri that have no child tasks"

        $queryuri = "$($uri)/_apis/wit/wiql?api-version=1.0"
        if ($IncludeClosed)
        {
            $wiq = "SELECT [System.Id], [System.Links.LinkType], [System.WorkItemType], [System.Title], [System.AssignedTo], [System.State], [System.Tags] FROM WorkItemLinks WHERE ([Source].[System.IterationPath] UNDER '$iterationpath') And ([System.Links.LinkType] <> '') And ([Target].[System.WorkItemType] IN GROUP 'Microsoft.RequirementCategory') ORDER BY [System.Id] mode(MayContain)"
        }
        else
        {
            $wiq = "SELECT [System.Id], [System.Links.LinkType], [System.WorkItemType], [System.Title], [System.AssignedTo], [System.State], [System.Tags] FROM WorkItemLinks WHERE ([Source].[System.IterationPath] UNDER '$iterationpath') And ([Source].[System.State] <> 'Done') And ([Source].[System.State] <> 'Removed') And ([System.Links.LinkType] <> '') And ([Target].[System.WorkItemType] IN GROUP 'Microsoft.RequirementCategory') ORDER BY [System.Id] mode(MayContain)"
        }
        $data = @{query = $wiq } | ConvertTo-Json

        $Parameters.add('Uri', $queryUri)

        Try
        {
            $jsondata = Invoke-RestMethod  @parameters -Method Post -Body $data -ErrorAction Stop
        }
        catch
        {
            Throw
        }

        if ($IdOnly)
        {
            Write-Output $jsondata.workItemRelations.target | Select-Object -ExpandProperty Id -Unique
        }
        else
        {
            Write-Output $jsondata
        }
    }
}
function Get-TfsWorkItemInIterationWithNoTask
{
    <#
        .SYNOPSIS
            This function gets any work items in the specified Iteration with no tasks linked

        .DESCRIPTION
            This function gets any work items which have no tasks linked to them in the specified iteration.
            It will query TFS for all the tasks in the specified Iteration path with the specified states,
            and then iterate over them to find which ones are root items, which are parents and which are children.
            Then it can compare the list of root items with the list of parent items and find any which are root items
            but not parents. It will then use the Get-WorkItemDetails function to get all the details of these items
            and return that data to the pipeline.

            The function accepts input from the pipeline in the form of a WebSession object, such as generated by the Connect-TfsServer
            function.

        .PARAMETER IterationPath
            The exact path of the iteration to look up, such as 'test\Sprint 1'

        .PARAMETER States
            String of states to query, for multiple states use double quotes around a comma seperated list of single quoted strings.
            Accepted states are: Approved, Committed, Done, In Test, New, Removed

        .EXAMPLE
            Get-TfsWorkItemInIterationWithNoTask -Uri https://test.visualstudio.com/DefaultCollection -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -IterationPath 'Test\Sprint 1' -States 'New'

            This will get all the work items with no tasks in Sprint 1 of the Test project that are in the New state, using the specified credentials and Uri.

        .EXAMPLE
            Get-TfsWorkItemInIterationWithNoTask -WebSession $Session -IterationPath 'Test\Sprint 4' -States "'New','Approved'"

            This will get all the work items with no tasks in Sprint 4 of the Test project with the New or Approved state, using the WebSession object for the Uri and credentials.

        .EXAMPLE
            Connect-TfsServer -Uri "https://test.visualstudio.com/DefaultCollection -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) |  Get-TfsWorkItemInIterationWithNoTask -IterationPath 'Test\Sprint 4' -States "'New','Approved'"

            This will connect to the specified TFS server and then pass the WebSession object into the pipeline and get all the work items with no tasks in Sprint 4 of the Test project with the New or Approved state.
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory)]
        [String]$IterationPath,

        [Parameter(Mandatory)]
        [String]$States

    )
    Process
    {
        $headers = @{'Content-Type'='application/json'}
        $Parameters = @{}
        $Parameters.add('WebSession',$WebSession)
        $Parameters.add('Headers',$headers)

        write-verbose "Getting Backlog Items under $iterationpath via $uri that have no child tasks"

        $queryuri = "$($uri)/_apis/wit/wiql?api-version=1.0"
        $wiq = "SELECT [System.Id], [System.Links.LinkType], [System.WorkItemType], [System.Title], [System.AssignedTo], [System.State], [System.Tags] FROM WorkItemLinks WHERE (  [Source].[System.State] IN ($states)  AND  [Source].[System.IterationPath] UNDER '$iterationpath') And ([System.Links.LinkType] <> '') And ([Target].[System.WorkItemType] = 'Task') ORDER BY [System.Id] mode(MayContain)"
        $data = @{query = $wiq } | ConvertTo-Json

        $Parameters.add('Uri', $queryUri)

        try
        {
            $jsondata = Invoke-RestMethod @parameters -Method Post -Body $data   #$wc.UploadString($uri,'POST', $data) | ConvertFrom-Json
        }
        catch
        {
            Throw
        }

        # work out which root items have no child tasks
        # might be a better way to do this
        $rootItems = @()
        $childItems = @()
        $parentItems = @()

        foreach($wi in $jsondata.workItemRelations)
        {
            if ($wi.rel -eq $null)
            {
                $rootItems += $wi.target.id
            } else
            {
                $childItems += $wi.target.id
                $parentItems += $wi.source.id
            }
        }

        $ids = (Compare-Object -ReferenceObject ($rootItems |  Sort-Object) -DifferenceObject ($parentItems | Select-Object -uniq |  Sort-Object)).InputObject
        $retItems = @()

        foreach ($id in $ids)
        {
            if ($WebSession)
            {
                $item = Get-TfsWorkItemDetail -WebSession $WebSession -id $id
            }
            else
            {
                $item = Get-TfsWorkItemDetail -uri $uri -id $id -username $username -password $password
            }
            $retItems += $item | Select-Object id, @{ Name = 'WIT' ;Expression ={$_.fields.'System.WorkItemType'}} , @{ Name = 'Title' ;Expression ={$_.fields.'System.Title'}}

        }

        Write-Output $retItems
    }
}
function Get-TfsWorkItemQuery
{
    <#
        .SYNOPSIS
            This function will get a work item query from a folder on a project.

        .DESCRIPTION
            This function will get a work item query from a folder on a project.

        .PARAMETER Project
            The name of the project under which the team can be found

        .PARAMETER Folder
            The name of the folder to store the query.

        .PARAMETER Name
            The name of the query to create.

        .EXAMPLE
            New-TfsWorkItemQuery -WebSession $session -Project 'Super Product' -Folder 'Shared Queries' -Name 'In Test' -Wiql $Wiql

            This will add a new query to the Shared Queries folder with the specified wiql using the specified web session.

        .EXAMPLE
            New-TfsTeamProjectDashboardWorkItemQuery -Project 'Super Product' -Folder 'Shared Queries' -Name 'In Test' -Wiql $WiqlString -Uri 'https://product.visualstudio.com/DefaultCollection' -Username 'MainUser' -AccessToken (Get-Content c:\accesstoken.txt | Out-String)

            This will add a new query to the Shared Queries folder with the specified wiql on the target VSTS account using the provided creds.

    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [String]$Project,

        [Parameter(Mandatory)]
        [String]$Folder,

        [Parameter(Mandatory)]
        [string]$Name

    )

    Process
    {
        $headers = @{'Content-Type'='application/json';'accept'='api-version=2.2;application/json'}
        $Parameters = @{}
        $Parameters.add('WebSession',$WebSession)
        $Parameters.add('Headers',$headers)

        #Make the variables web safe
        $Name = $Name -replace ' ','%20'
        $Folder = $Folder -replace ' ','%20'

        #Get queries to check if one already exists in that location
        $Uri = "$($WebSession.uri)/$Project/_apis/wit/queries/$Folder/$($Name)?api-version=2.2"
        $Parameters.Add('uri',$uri)

        try
        {
            $JsonData = Invoke-RestMethod @Parameters -Method GET -ErrorAction Stop

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
function New-TfsBuildDefinition
{
    <#
        .SYNOPSIS
            This function creates a new build definition in a TFS team project

        .DESCRIPTION
            This function creates a new build definition in a TFS team project from a target
            TFS server, using either the WebSession provided or manually specified
            URI and credentials.

            If the project doesn't exist then an error will be returned. Wildcard searches are
            not currently available.

            You can also pipe the a WebSession object into the command to, either from a normal variable
            or from the Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER Project
            Existing Team Project Name

        .PARAMETER Definition
            JSON specifying the defintion to create

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

    #>
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
        $uri = "$uri/$Project/_apis/build/definitions?api-version=2.0"
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
function New-TfsGitRepository
{
    <#
        .SYNOPSIS
            This function creates a git repo in a TFS team project

        .DESCRIPTION
            This function creates a git repo in a TFS team project from a target
            TFS server, using either the WebSession provided or manually specified
            URI and credentials.

            If the project doesn't exist then an error will be returned. Wildcard searches are
            not currently available.

            You can also pipe the a WebSession object into the command to, either from a normal variable
            or from the Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER Project
            Existing Team Project Name

        .PARAMETER Name
            Name of the git repo to create

        .PARAMETER Uri
            Uri of TFS serverm, including /DefaultCollection (or equivilent)

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE

            New-TfsGitRepository -WebSession $Session -Project t1 -Name 'WebApplication'

            This will create a git repo named 'WebApplication' on the T1 project on the TFS server
            in the WebSession variable.

        .EXAMPLE

            New-TfsTeam  -Uri https://test.visualstudio.com/DefaultCollection  -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -Project t1 -Name 'Services'

            This will create a git repo named 'Services' on the T1 project on the TFS server
            specified using the credentials provided.

        .EXAMPLE

            Connect-TfsServer -Uri "https://test.visualstudio.com/DefaultCollection -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) |  New-TfsGitRepository -Project t1  -Name 'MainRepository'

            This will create a git repo named 'MainRepository' on the T1 project on the TFS server
            in the WebSession provided by the Connect-TfsServer output.
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

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

        $ProjectDetails = Get-TfsProject -WebSession $WebSession -Project $Project
        #create the REST url
        $Project = $Project.Replace(' ','%20')
        $uri = "$uri/$Project/_apis/git/repositories?api-version=1.0"
        $Parameters.add('Uri', $Uri)

        $Body = [pscustomobject]@{
            name = $Name
            project = @{
                id = $ProjectDetails.id
            }
        } | ConvertTo-Json

        $Parameters.Add('body',$Body)

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
function New-TfsProject
{
    <#
        .SYNOPSIS
            This function will create a new team project.

        .DESCRIPTION
            This function will create a new team project.

            The function will take either a websession object or a uri and
            credentials. The web session can be piped to the fuction from the
            Connect-TfsServer function.

        .PARAMETER WebSession
            Websession with connection details and credentials generated by Connect-TfsServer function

        .PARAMETER Name
            The name of the Project to be created

        .PARAMETER Description
            The description for the newly created project, defaults to match the name of the project

        .PARAMETER Process
            Process to use for the project, options are Agile, CMMI and Scrum

        .PARAMETER VersionControl
            Method of version control to use, options are tfvc or git

        .PARAMETER Username
            The username to connect to the remote server with

        .PARAMETER AccessToken
            Access token for the username connecting to the remote server

        .PARAMETER Credential
            Credential object for connecting to the target TFS server

        .PARAMETER UseDefaultCredentails
            Switch to use the logged in users credentials for authenticating with TFS.

        .EXAMPLE
            New-TfsProject -Name 'Engineering' -Description 'Engineering project' -Process Agile -VersionControl Git -WebSession $Session

            This will create a new Engineering Project using git for source control and Agile process. The already created Web Session is used for authentication.

        .EXAMPLE
            New-TfsProject -Uri 'https://test.visualstudio.com/defaultcollection' -Username username@email.com -AccessToken (Get-Content C:\AccessToken.txt) -Name 'Engineering' -Description 'Engineering project' -Process Scrum -VersionControl tfvc

            This will create a new Engineering Project using tfvc for source control and Scrum process on the specified server using the provided login details.

    #>
    [cmdletbinding()]
    param
    (
        [Parameter(ParameterSetName='WebSession', Mandatory,ValueFromPipeline)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,

        [Parameter(Mandatory)]
        [String]$Name,

        [String]$Description = $Name,

        [parameter(Mandatory)]
        #[ValidateSet('Agile','CMMI','Scrum','Scrum 2')]
        [string]$Process,

        [parameter(Mandatory)]
        [ValidateSet('tfvc','Git')]
        [string]$VersionControl,

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
            $ProjectExists = Invoke-RestMethod -Uri "$uri/_apis/projects/$($name)?api-version=1.0" @Parameters -ErrorAction Stop
        }
        catch
        {
            $ErrorObject = $_ | ConvertFrom-Json

            if (-not($ErrorObject.Message -like '*The following project does not exist*'))
            {
                Throw $_
            }
        }

        if ($ProjectExists)
        {
            #Write-Error 'The project already exists, please choose a new unique name'
            Throw 'The project already exists, please choose a new unique name'
        }

        #Construct the uri and add it to paramaters block
        $uri = "$uri/_apis/projects?api-version=2.0-preview"
        $Parameters.Add('uri',$uri)

        #Construct Json data to post
        Switch ($Process)
        {
            'Agile'
            {
                $ProcessId = 'adcc42ab-9882-485e-a3ed-7678f01f66bc'
            }
            'Scrum'
            {
                $ProcessId = '6b724908-ef14-45cf-84f8-768b5384da45'
            }
            'CMMI'
            {
                $ProcessId = '27450541-8e31-4150-9947-dc59f998fc01'
            }
            default
            {
                $ProcessId = Invoke-RestMethod -Uri "$($Websession.uri)/_apis/process/processes?api-version=1.0" -WebSession $WebSession |
                            Select-Object -Expand Value |
                            Where-Object {$_.Name -eq $Process} |
                            Select-Object -Expand id

                If (-not($ProcessId)) {
                    throw "Process template $Process doesn't exist on target server"
                }

            }
        }

        $Json = @"
{
  'name': '$Name',
  'description': '$Descrption',
  'capabilities': {
    'versioncontrol': {
      'sourceControlType': '$VersionControl'
    },
    'processTemplate': {
      'templateTypeId': '$ProcessId'
    }
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
function New-TfsWorkItemQuery
{
    <#
        .SYNOPSIS
            This function will add a work item query to a folder.

        .DESCRIPTION
            This function will add a work item query to a folder when passed a wiql string.

        .PARAMETER Project
            The name of the project under which the team can be found

        .PARAMETER Folder
            The name of the folder to store the query.

        .PARAMETER Name
            The name of the query to create.

        .PARAMETER Wiql
            The wiql query string to create and use for the widget

        .EXAMPLE
            $WiqlString = "select [System.Id], [System.WorkItemType], [System.Title], [System.AssignedTo], [System.State], [System.Tags] from WorkItems where [System.TeamProject] = @project and [System.WorkItemType] <> '' and [System.State] = 'In Test' order by [System.WorkItemType] desc"

            New-TfsWorkItemQuery -WebSession $session -Project 'Super Product' -Folder 'Shared Queries' -Name 'In Test' -Wiql $Wiql

            This will add a new query to the Shared Queries folder with the specified wiql using the specified web session.

        .EXAMPLE
            $WiqlString = "SELECT [System.Id],[System.WorkItemType],[System.Title],[System.AssignedTo],[System.State],[System.Tags] FROM WorkItemLinks WHERE ([Source].[System.TeamProject] = @project AND ( [Source].[System.WorkItemType] = 'Product Backlog Item' OR [Source].[System.WorkItemType] = 'Bug' ) AND [Source].[System.State] <> 'Done' AND [Source].[System.State] <> 'Removed' AND [Source].[System.IterationPath] = @currentIteration) AND ([Target].[System.TeamProject] = @project AND [Target].[System.WorkItemType] = 'Task' AND [Target].[System.AssignedTo] = @me AND [Target].[System.State] <> 'Done' AND [Target].[System.State] <> 'Removed' AND [Target].[System.IterationPath] = @currentIteration) mode(MustContain)"

            New-TfsWorkItemQuery -Project 'Super Product' -Folder 'Shared Queries' -Name 'In Test' -Wiql $WiqlString -Uri 'https://product.visualstudio.com/DefaultCollection' -Username 'MainUser' -AccessToken (Get-Content c:\accesstoken.txt | Out-String)

            This will add a new query to the Shared Queries folder with the specified wiql on the target VSTS account using the provided creds.

    #>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [String]$Project,

        [Parameter(Mandatory)]
        [String]$Folder,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Wiql

    )

    Process
    {
        $headers = @{'Content-Type'='application/json';'accept'='api-version=2.2;application/json'}
        $Parameters = @{}
        $Parameters.add('WebSession',$WebSession)
        $Parameters.add('Headers',$headers)

        #Make the variables web safe
        $NameParsed = $Name -replace ' ','%20'
        $FolderParsed = $Folder -replace ' ','%20'

        #Get queries to check if one already exists in that location
        if (Get-TfsWorkItemQuery -WebSession $WebSession -Project $Project -Folder $FolderParsed -Name $NameParsed)
        {
            Write-Error "$name already exists in the location specified. Please try again with a different name."
            break
        }
        else
        {
            Write-verbose -Verbose "Creating query: $name"
            try
            {
                $uri = "$uri/$project/_apis/wit/queries/$($Folder)?api-version=2.2"
                $Parameters.Add('Uri',$uri)
                $Body = @{
                    name = $Name
                    wiql = $Wiql
                } | ConvertTo-Json

               $JsonData = Invoke-RestMethod @Parameters -Method Post -Body $Body
            }
            catch
            {
                $ErrorMessage = $_
                $ErrorMessage = ConvertFrom-Json -InputObject $ErrorMessage.ErrorDetails.Message
                if ($ErrorMessage.TypeKey -eq 'LegacyQueryItemException')
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

        }

        Write-Output $JsonData

    }
}
function Remove-TfsTeamProjectDashboardWidget
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

        [parameter(Mandatory)]
        [validateScript({
            if ($_ -notmatch '^([0-9A-Fa-f]{8}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{4}[-][0-9A-Fa-f]{12})$')
            {
                return $false
            }
            else
            {
                return $true
            }
        })]
        [string]$WidgetId,

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

        Write-Verbose "Attempting to remove widget from $Dashboard"

        if ($Uri -match 'visualstudio.com')
        {
            $ProjectId = Get-TfsProject -WebSession $WebSession -Project $Project | Select-Object -ExpandProperty Id
            $TeamId = Get-TfsTeam -WebSession $WebSession -Project $Project | Where-Object {$_.Name -eq $Team} | Select-Object -ExpandProperty Id
            $DashboardId = Get-TfsTeamProjectDashboard -WebSession $WebSession -Team $Team -Project $Project | Where-Object {$_.Name -eq $Dashboard} | Select-Object -ExpandProperty Id
            $QueryUri = "{0}/{1}/{2}/_apis/Dashboard/dashboards/{3}/Widgets/{4}?api-version=3.1-preview.2" -f $uri,$ProjectId,$TeamId,$DashboardId,$WidgetId
        }
        else
        {
            $QueryUri = "{0}/widgets?api-version=2.2-preview.1" -f (Get-TfsTeamProjectDashboard -WebSession $WebSession -Team $Team -Project $Project | Where-Object Name -eq $Dashboard | select-object -ExpandProperty url)
        }
        $Parameters.add('Uri',$QueryUri)

        try
        {
            $JsonData = Invoke-RestMethod @Parameters -ErrorAction Stop -Method Delete
        }
        catch
        {
            Write-Error "Error was $_"
            $line = $_.InvocationInfo.ScriptLineNumber
            Write-Error "Error was in Line $line"
        }
        Write-Verbose "Widget removed from $Dashboard"
    }
}
