Describe "Testing everything is ready for presentations" {

    $ProcessesToStop = @(
        @{
            Name = 'Slack'
        }
        @{
            Name = 'Outlook'
        }
        @{
            Name = 'Spotify'
        }
        @{
            Name = 'Firefox'
        }
        @{
            Name = 'Chrome'
        }
        @{
            Name = 'Lync'
        }
        @{
            Name = 'Teams'
        }
    )

    It "Should not have <Name> running" {
        param ($Name)

        Get-Process -Name "*$Name*" | Should -Be $Null
    } -TestCases $ProcessesToStop
}
