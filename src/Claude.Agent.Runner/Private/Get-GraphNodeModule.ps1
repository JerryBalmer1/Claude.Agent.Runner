function Get-GraphNodeModule {
    <# Finds the single manifest under <sibling Graph.Node checkout>\src\*\*.psd1, imports it globally and returns the module. Throws when the checkout or manifest is missing. #>
    [CmdletBinding()]
    [OutputType([psmoduleinfo])]
    param(
        [string] $GraphNodeRoot = (Join-Path (Split-Path $script:RepoRoot -Parent) 'Graph.Node')
    )
    if (-not (Test-Path -LiteralPath $GraphNodeRoot -PathType Container)) {
        throw "Graph.Node checkout not found at $GraphNodeRoot. Clone it beside this repo ($script:ModuleName expects ..\Graph.Node)."
    }
    $manifests = @(Get-ChildItem -Path (Join-Path $GraphNodeRoot 'src' '*' '*.psd1') -File -ErrorAction SilentlyContinue)
    if ($manifests.Count -ne 1) {
        throw "expected exactly one module manifest under $(Join-Path $GraphNodeRoot 'src\*\*.psd1'), found $($manifests.Count)"
    }
    Import-Module -Name $manifests[0].FullName -Global -PassThru -ErrorAction Stop
}
