#Requires -Version 7.4
Set-StrictMode -Version Latest

$script:ModuleRoot    = $PSScriptRoot
$script:RepoRoot      = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:OntologyPath  = Join-Path $script:RepoRoot 'ontology.yaml'
$script:ModuleName    = 'Claude.Agent.Runner'
$script:Version       = (Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot "$script:ModuleName.psd1")).ModuleVersion
$script:IdPrefix      = 'runner:'
# Vendors live under drivers/ only (design.md 4); the default driver's name is read from there, never written here.
$script:DriversRoot   = Join-Path $PSScriptRoot 'drivers'
$script:DefaultDriver = (Import-PowerShellDataFile -Path (Join-Path $script:DriversRoot 'drivers.psd1')).Default

foreach ($dir in 'Private', 'Public') {
    Get-ChildItem -Path (Join-Path $PSScriptRoot $dir) -Filter '*.ps1' -ErrorAction SilentlyContinue |
        ForEach-Object { . $_.FullName }
}

# Graph.Node builds the envelope and validates it; load it now so a missing checkout fails at import.
$script:GraphNodeModule = Get-GraphNodeModule

Export-ModuleMember -Function (
    Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' |
        ForEach-Object { $_.BaseName }
)
