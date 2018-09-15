[cmdletbinding()]
param (
    $SourceFolder = $PSScriptRoot
)

if (-not (Get-Module PSDepend -ListAvailable)) {
    Install-Module PSDepend -Repository (Get-PSRepository)[0].Name -Scope CurrentUser
}
Push-Location $PSScriptRoot -StackName BuildScript
Invoke-PSDepend -Path $SourceFolder -Confirm:$false
Pop-Location -StackName BuildScript

Write-Verbose -Message "Working in $SourceFolder" -verbose
$Module = Get-ChildItem -Path $SourceFolder -Filter *.psd1 -Recurse |
    Where-Object {$_.FullName -notlike '*Output*'} |
    Select-String -Pattern 'RootModule' |
    Select-Object -First 1 -ExpandProperty Path

$Module = Get-Item -Path $Module

$OutputFolder = Join-Path -Path $($Module.Directory.FullName) -ChildPath "..\Output\"
$null = New-Item -Path $OutputFolder -ItemType Directory -Force -Confirm:$false
$DestinationModule = Join-Path -Path $($Module.Directory.FullName) -ChildPath "..\Output\$($Module.BaseName).psm1"
$OutputManifest = Join-Path -Path $($Module.Directory.FullName) -ChildPath "..\Output\$($Module.BaseName).psd1"
Copy-Item -Path $Module.FullName -Destination $OutputManifest -Force

Write-Verbose -Message "Attempting to work with $DestinationModule" -verbose

if (Test-Path -Path $DestinationModule ) {
    Remove-Item -Path $DestinationModule -Confirm:$False -force
}

$PublicFunctions = Get-ChildItem -Path $SourceFolder -Include 'Public', 'External' -Recurse -Directory | Get-ChildItem -Include *.ps1 -File
$PrivateFunctions = Get-ChildItem -Path $SourceFolder -Include 'Private', 'Internal' -Recurse -Directory | Get-ChildItem -Include *.ps1 -File

if ($PublicFunctions -or $PrivateFunctions) {
    Write-Verbose -message "Found Private or Public functions. Will compile these into the psm1 and only export public functions."

    Foreach ($PrivateFunction in $PrivateFunctions) {
        Get-Content -Path $PrivateFunction.FullName | Add-Content -Path $DestinationModule
    }
    Write-Verbose -Message "Found $($PrivateFunctions.Count) Private functions and added them to the psm1."
}
else {
    Write-Verbose -Message "Didnt' find any Private or Public functions, will assume all functions should be made public."

    $PublicFunctions = Get-ChildItem -Path $SourceFolder -Include *.ps1 -Recurse -File
}

Foreach ($PublicFunction in $PublicFunctions) {
    Get-Content -Path $PublicFunction.FullName | Add-Content -Path $DestinationModule
}
Write-Verbose -Message "Found $($PublicFunctions.Count) Public functions and added them to the psm1."

$PublicFunctionNames = $PublicFunctions |
    Select-String -Pattern 'Function (\w+-\w+) {' -AllMatches |
    Foreach-Object {
    $_.Matches.Groups[1].Value
}
Write-Verbose -Message "Making $($PublicFunctionNames.Count) functions available via Export-ModuleMember"

"Export-ModuleMember -Function $($PublicFunctionNames -join ',')" | Add-Content -Path $DestinationModule
$Null = Get-Command -Module Configuration
Update-Metadata -Path $OutputManifest -PropertyName FunctionsToExport -Value $PublicFunctionNames

Invoke-Pester -Script $SourceFolder -CodeCoverage $DestinationModule

Invoke-ScriptAnalyzer -Path $DestinationModule
