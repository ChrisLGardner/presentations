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