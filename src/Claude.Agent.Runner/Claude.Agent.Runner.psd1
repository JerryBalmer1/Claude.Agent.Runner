@{
    RootModule        = 'Claude.Agent.Runner.psm1'
    ModuleVersion     = '0.1.1'
    GUID              = '7cb3e13d-6a89-49f6-bde6-b2133627bbca'
    Author            = 'Jerry Balmer'
    CompanyName       = 'JerryBalmer1'
    Copyright         = '(c) 2026 Jerry Balmer. All rights reserved.'
    Description       = 'Graph.Node emitter for agent runs: a captured run stream becomes Plan, Run and Step nodes, Steps in order, each Step following the agent Rule that directed it.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Export-RunnerGraph'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('graph', 'agent', 'runner', 'emitter', 'ontology')
            ProjectUri = 'https://github.com/JerryBalmer1/Claude.Agent.Runner'
        }
    }
}
