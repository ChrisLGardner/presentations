#Requires -Modules @{ModuleName='AWS.Tools.Common';ModuleVersion='4.0.5.0'}

Write-Host "Got this input $($LambdaInput.Records[0].Body)"
