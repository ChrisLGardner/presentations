$modulePath = Split-Path $PSScriptRoot -Parent
$modulepath = Join-Path -Path $modulePath -ChildPath TFSUtilities.psd1
Import-Module $modulePath

Remove-Module -name TFSUtilities -ErrorAction SilentlyContinue
