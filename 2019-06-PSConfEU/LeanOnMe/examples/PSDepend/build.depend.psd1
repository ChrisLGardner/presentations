@{
    PSDependOptions = @{
        Target = '.\Dependencies'
        AddToPath = $true
    }
    Configuration = '1.3.1'
    Pester = @{
        Name = 'Pester'
        Parameters = @{
            SkipPublisherCheck = $true
        }
        Version = '4.8.0'
    }
    PlatyPS = 'latest'
    PSScriptAnalyzer = '1.17.1'
}
