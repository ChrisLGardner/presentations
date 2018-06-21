[cmdletbinding()]
param (
    $SourceFolder = $PSScriptRoot
)
#Write-Verbose -Message "Working in $SourceFolder" -verbose
$Module = Get-ChildItem -Path $SourceFolder -Filter *.psd1 -Recurse | Select-Object -First 1

$DestinationModule = "$($Module.Directory.FullName)\$($Module.BaseName).psm1"
#Write-Verbose -Message "Attempting to work with $DestinationModule" -verbose

if (Test-Path -Path $DestinationModule ) {
    Remove-Item -Path $DestinationModule -Confirm:$False -force
}

$PublicFunctions = Get-ChildItem -Path $SourceFolder -Include 'Public', 'External','Functions' -Recurse -Directory | Get-ChildItem -Include *.ps1 -File
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
    Select-String -Pattern 'Function (\w+-\w+)$' -AllMatches |
    Foreach-Object {
    $_.Matches.Groups[1].Value
}
Write-Verbose -Message "Making $($PublicFunctionNames.Count) functions available via Export-ModuleMember"

"Export-ModuleMember -Function {0}" -f ($PublicFunctionNames -join ',') | Add-Content $DestinationModule

$var = Invoke-Pester -Script $SourceFolder -Show Fails #-CodeCoverage $DestinationModule -CodeCoverageOutputFile "$SourceFolder\..\$($Module.Basename)CodeCoverage.xml" -CodeCoverageOutputFileFormat JaCoCo -PassThru -Show Fails

Invoke-ScriptAnalyzer -Path $DestinationModule

