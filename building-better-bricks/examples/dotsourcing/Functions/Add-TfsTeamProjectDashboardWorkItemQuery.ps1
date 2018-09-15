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