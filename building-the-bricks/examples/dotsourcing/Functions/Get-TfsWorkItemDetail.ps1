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
