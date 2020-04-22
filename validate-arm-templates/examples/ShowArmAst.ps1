$Template = Invoke-ArmTemplateValidation -Path C:\Source\github\ArmTemplateValidation\tests\unit\TestData\ExampleTemplate.json -Parameters @{VirtualMachineName='abc123'}
 function write-template {
    param (
        $Template,
        $TemplateName
    )
    node $TemplateName @{shape='house'}
    foreach ($param in $Template.Parameters) {
        write-parameter $param $TemplateName
    }
    foreach ($var in $Template.Variables) {
        write-variable $var $TemplateName
    }
    foreach ($output in $Template.Outputs) {
        write-outputnode $output $TemplateName
    }
    foreach ($func in $Template.Functions) {
        write-function $param $TemplateName
    }
    foreach ($res in $Template.Resources) {
        Write-resource $res $TemplateName
    }
}

function write-parameter {
    param (
        $parameter,
        $Parent
    )

    node $parameter.name @{shape='pentagon'}
    edge $parent $parameter.name
}

function write-variable {
    param (
        $variable,
        $Parent
    )

    node $variable.name @{shape='hexagon'}
    edge $parent $variable.name
}

function write-function {
    param (
        $function,
        $Parent
    )

    node $function.name @{shape='invtriangle'}
    edge $parent $function.name
}

function write-outputnode {
    param (
        $output,
        $Parent
    )

    node $output.name @{shape='invhouse'}
    edge $parent $output.name
}

function Write-resource {
    param (
        $resource,
        $parent
    )

    node $resource.name @{shape='box'}
    edge $parent $resource.name

    if ($resource.type -eq "Microsoft.Resources/deployments") {
        SubGraph $script:SubGraph -Attributes @{label = $resource.name} {
            write-template -Template $resource.Properties.Template "$($resource.Name)-template"
        }
        edge $resource.name "$($resource.Name)-template"
    }
}

graph g {
    $script:SubGraph = 0
    write-template $Template PrimaryTemplate

} | Export-PSGraph -ShowGraph


$Template2 = Invoke-ArmTemplateValidation -Path C:\Source\github\presentations\build-your-own-ast\Examples\ComplexTemplate.json -Parameters @{
    AdminPassword = 'abc123'
} -Ea Break


graph g {
    $script:SubGraph = 0
    write-template $Template2 PrimaryTemplate

} | Export-PSGraph -ShowGraph
