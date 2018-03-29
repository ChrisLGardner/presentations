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
