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