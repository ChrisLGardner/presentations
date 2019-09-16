Show-Ast -InputObject "'this is a string'"

Show-Ast -InputObject "Get-Command -Name Get-Help -Syntax"
 
Show-Ast -InputObject '$var = 1234'

[ScriptBlock]::Create(@'
function Get-User {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Username
    )

    Get-LocalUser | Where-Object Name -eq $Username | Select-Object Name,Enabled
}
'@) | Show-Ast
 