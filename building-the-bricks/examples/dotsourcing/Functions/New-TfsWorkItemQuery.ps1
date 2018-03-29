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
