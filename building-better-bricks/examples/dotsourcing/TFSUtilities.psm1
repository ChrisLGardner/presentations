$script:Template = [PSCustomObject]@{}

foreach ($function in (Get-ChildItem -file -Path(Join-Path -Path $PSScriptRoot -ChildPath .\Functions)))
{
    Write-Verbose -Message "Importing function $($function.FullName)"
    . $function.FullName
}