Using Namespace System.Management.Automation.Language
 
 
#region Simple FindAll Parameters
    $ScriptBlock = [ScriptBlock]::Create(@'
    function Get-User {
        [cmdletbinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [String]$Username
        )

        Get-LocalUser | Where-Object Name -eq $Username | Select-Object Name,Enabled
    }
'@)
 
    $Result = $ScriptBlock.Ast.FindAll({
        param ($ast)

        $ast -is [ParameterAst]
    }, $true)

    $Result

    $Result.Name
    $Result.Attributes

#endregion


#region Multiple FindAll Parameters
    $ScriptBlock2 = [ScriptBlock]::Create(@'
    function Get-User {
        [cmdletbinding()]
        param (
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [String]$Username,

            [string]$Path
        )

        Get-LocalUser | Where-Object Name -eq $Username | Select-Object Name,Enabled
    }
'@)

    $Result2 = $ScriptBlock2.Ast.FindAll({
        param ($ast)

        $ast -is [ParameterAst]
    }, $true)

    $Result2


    $Result3 = $ScriptBlock2.Ast.Find({
        param ($ast)

        $ast -is [ParameterAst]
    }, $true)

    $Result3

    $Result4 = $ScriptBlock2.Ast.FindAll({
        param ($ast)

        $ast -is [ParameterAst] -and
        $ast.Name.Extent.Text -eq '$Path'
    }, $true)

    $Result4
#endregion
