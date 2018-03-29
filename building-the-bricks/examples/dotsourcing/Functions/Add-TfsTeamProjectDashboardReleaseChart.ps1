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
