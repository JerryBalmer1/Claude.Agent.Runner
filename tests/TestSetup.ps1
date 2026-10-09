# Dot-sourced by every *.Tests.ps1 in BeforeAll. Imports the module from src (which imports Graph.Node from the sibling
# checkout) and defines the helpers the tests share.

$script:RepoRoot   = Split-Path -Parent $PSScriptRoot
$script:ModuleRoot = Join-Path $script:RepoRoot 'src' 'Claude.Agent.Runner'
$script:GraphNodeManifest = 'C:\__Code\Graph.Node\src\GraphNode\GraphNode.psd1'
# A captured three-turn run (design.md 8): two turns name an agent: Rule, the third is improvised.
$script:FixturePath = Join-Path $PSScriptRoot 'fixtures' 'three-turns.stream.jsonl'

Get-Module Claude.Agent.Runner | Remove-Module -Force
Import-Module (Join-Path $script:ModuleRoot 'Claude.Agent.Runner.psd1') -Force -ErrorAction Stop

# The version: in a SKILL.md's front matter, from a path on disk or (with -Text) from text already read.
function Get-FrontVersion {
    param([string] $Path, [string] $Text)
    if ($Path) { $Text = Get-Content -LiteralPath $Path -Raw }
    $front = [regex]::Match($Text, '\A---\r?\n(.*?)\r?\n---', 'Singleline').Groups[1].Value
    [regex]::Match($front, '(?m)^version:\s*(\S+)\s*$').Groups[1].Value
}

# The committed (HEAD) text of a file in another checkout; $null when git or the checkout is missing.
function Get-CommittedText {
    param([Parameter(Mandatory)] [string] $Repo, [Parameter(Mandatory)] [string] $RelativePath)
    if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) { return $null }
    $text = & git -C $Repo show "HEAD:$RelativePath" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $text -join "`n"
}
