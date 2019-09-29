Using Namespace System.Management.Automation.Language

$Tokens = @()
$Errors = @()
$NodeScript = [Parser]::ParseFile("$PWD\config.ps1", [ref]$Tokens, [ref]$Errors)
  
$NodeScript.FindAll({
    param (
        $Ast
    )
    $Ast -is [DynamicKeywordStatementAst] -and
    $Ast.CommandElements[0].Value -eq 'Import-DscResource' -and
    $Ast.CommandElements.Value -notcontains 'PSDesiredStateConfiguration'
}, $true) |
    Select-Object @(
        @{
            Name = 'ModuleName'
            Expression = {$_.CommandElements.Where({$_.StringConstantType -eq 'BareWord' -and $_.Value -ne 'Import-DscResource'})[0]}
        }
        @{
            Name = 'ModuleVersion'
            Expression = {$_.CommandElements.Where({$_.StringConstantType -eq 'BareWord' -and $_.Value -ne 'Import-DscResource'})[1]}
        }
    )
