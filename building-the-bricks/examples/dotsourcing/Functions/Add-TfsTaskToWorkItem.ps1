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