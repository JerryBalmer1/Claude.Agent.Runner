BeforeDiscovery {
    $script:KindShapes = @(
        @{ Kind = 'Plan'; Shape = 'hexagon' }
        @{ Kind = 'Run'; Shape = 'square' }
        @{ Kind = 'Step'; Shape = 'circle' }
    )
    # Each copied skill, compared with Graph's committed (HEAD) copy.
    $script:Skills = @(
        @{ Skill = 'run-report'; Source = 'C:\__Code\Graph' }
        @{ Skill = 'graph-node'; Source = 'C:\__Code\Graph' }
        @{ Skill = 'git-guard'; Source = 'C:\__Code\Graph' }
    )
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    $script:Manifest = Import-PowerShellDataFile -Path (Join-Path $ModuleRoot 'Claude.Agent.Runner.psd1')
    $script:Ontology = Get-Content -LiteralPath (Join-Path $RepoRoot 'ontology.yaml') -Raw
    # The text of one top-level entry (two-space indent) of ontology.yaml, up to the next one.
    function Get-OntologyBlock([string] $Name) {
        [regex]::Match($Ontology, "(?ms)^  $([regex]::Escape($Name)):\s*\r?\n(.*?)(?=^  \S|^\S|\z)").Groups[1].Value
    }
}

Describe 'Module' {
    It 'is version 0.1.1 and needs PowerShell 7.4' {
        $Manifest.ModuleVersion | Should -Be '0.1.1'
        $Manifest.PowerShellVersion | Should -Be '7.4'
    }

    It 'exports exactly the functions the manifest lists' {
        $exported = @((Get-Module Claude.Agent.Runner).ExportedFunctions.Keys | Sort-Object)
        $exported | Should -Be @($Manifest.FunctionsToExport | Sort-Object)
        @(Get-ChildItem -Path (Join-Path $ModuleRoot 'Public') -Filter '*.ps1' | ForEach-Object BaseName | Sort-Object) | Should -Be @($Manifest.FunctionsToExport | Sort-Object)
    }

    It 'every Public and Private file defines exactly one function named for the file' {
        foreach ($file in Get-ChildItem -Path (Join-Path $ModuleRoot 'Public'), (Join-Path $ModuleRoot 'Private') -Filter '*.ps1') {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $functions = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
            $functions.Count | Should -Be 1 -Because "$($file.Name) holds one function"
            $functions[0].Name | Should -BeExactly $file.BaseName
        }
    }

    It 'every exported function has a Pester file' {
        foreach ($name in $Manifest.FunctionsToExport) {
            Test-Path -LiteralPath (Join-Path $PSScriptRoot "$name.Tests.ps1") | Should -BeTrue -Because $name
        }
    }

    It 'imports Graph.Node from the sibling checkout' {
        (Get-Module GraphNode).Path | Should -BeLike (Join-Path (Split-Path $RepoRoot -Parent) 'Graph.Node' 'src' '*')
    }
}

Describe 'Vendor names stay under drivers/ (design.md 4)' {
    It 'Public/, Private/ and the manifest never say "claude", the module name aside' {
        $files = @(Get-ChildItem -Path (Join-Path $ModuleRoot 'Public'), (Join-Path $ModuleRoot 'Private') -Filter '*.ps1' -File) +
            (Get-Item -LiteralPath (Join-Path $ModuleRoot 'Claude.Agent.Runner.psd1'))
        $files.Count | Should -BeGreaterThan 2
        $hits = foreach ($file in $files) {
            $n = 0
            foreach ($line in Get-Content -LiteralPath $file.FullName) {
                $n++
                if (($line -replace 'Claude\.Agent\.Runner', '') -match 'claude') { "$($file.Name):${n}: $line" }
            }
        }
        @($hits).Count | Should -Be 0 -Because ($hits -join '; ')
    }

    It 'the default driver is named in drivers/drivers.psd1 and has a driver.ps1' {
        $default = (Import-PowerShellDataFile -Path (Join-Path $ModuleRoot 'drivers' 'drivers.psd1')).Default
        $default | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath (Join-Path $ModuleRoot 'drivers' $default 'driver.ps1') | Should -BeTrue
    }
}

Describe 'ontology.yaml' {
    It 'passes graphnode validate-ontology with [] (no errors, no warnings)' {
        $rid, $name = if ($IsWindows) { 'win-x64', 'graphnode.exe' } else { 'linux-x64', 'graphnode' }
        $bin = Join-Path (Split-Path $GraphNodeManifest) 'bin' $rid $name
        Test-Path -LiteralPath $bin | Should -BeTrue -Because 'the graphnode binary must be built in the Graph.Node checkout (Invoke-Build Build there)'
        $out = & $bin validate-ontology (Join-Path $RepoRoot 'ontology.yaml')
        $LASTEXITCODE | Should -Be 0 -Because ($out -join ' ')
        ($out -join '').Trim() | Should -Be '[]'
    }

    It 'is module Claude.Agent.Runner at the module version' {
        $Ontology | Should -Match '(?m)^module: Claude\.Agent\.Runner\s*$'
        $Ontology | Should -Match "(?m)^version: $([regex]::Escape($Manifest.ModuleVersion))\s*$"
    }

    It 'declares <Kind> as a <Shape> with a colour and a runner: id rule' -ForEach $KindShapes {
        $block = Get-OntologyBlock $Kind
        $block | Should -Not -BeNullOrEmpty
        $block | Should -Match "display: \{ color: `"#[0-9A-Fa-f]{6}`", shape: $Shape\b"
        $block | Should -Match 'idRule: "'
    }

    It 'gives Step the optional properties tokensInput, tokensOutput, tokensCache and metered, metered default true' {
        $step = Get-OntologyBlock 'Step'
        foreach ($p in 'tokensInput', 'tokensOutput', 'tokensCache') {
            $step | Should -Match "\{ name: $p, type: integer, description:" -Because "$p is optional"
        }
        $step | Should -Match '\{ name: metered, type: boolean, description: "[^"]*Default true'
    }

    It 'stores no token totals on Run or Plan' {
        foreach ($k in 'Run', 'Plan') { (Get-OntologyBlock $k) | Should -Not -Match 'name: tokens' -Because $k }
    }

    It 'declares contains (Plan to Run to Step), order (Step to Step) and follows (Step to Rule)' {
        $contains = Get-OntologyBlock 'contains'
        $contains | Should -Match 'from: \[Plan, Run\]'
        $contains | Should -Match 'to: \[Run, Step\]'
        $order = Get-OntologyBlock 'order'
        $order | Should -Match 'from: \[Step\]'
        $order | Should -Match 'to: \[Step\]'
        $follows = Get-OntologyBlock 'follows'
        $follows | Should -Match 'from: \[Step\]'
        $follows | Should -Match 'to: \[Rule\]'
        foreach ($b in $contains, $order, $follows) { $b | Should -Match 'display: \{ color: "#[0-9A-Fa-f]{6}", style: (solid|dashed|dotted) \}' }
    }

    It 'proposes the runner: prefix in design.md 1, still unregistered in Graph.Node' {
        $design = Get-Content -LiteralPath (Join-Path $RepoRoot 'docs' 'design.md') -Raw
        $one = [regex]::Match($design, '(?ms)^## 1\. (.*?)(?=^## 2\.|\z)').Groups[1].Value
        $one | Should -Match '`runner:`'
        $one | Should -Match 'Graph\.Node registers'
        (Get-GraphIdPrefix).Prefix | Should -Not -Contain 'runner:' -Because 'this repo does not edit Graph.Node; when it registers runner:, replace this with a shape check'
    }
}

Describe 'Two doors' {
    It 'README first line links ONTOLOGY.md' {
        (Get-Content (Join-Path $RepoRoot 'README.md') -First 1) | Should -Match '\]\(ONTOLOGY\.md\)'
    }
    It 'ONTOLOGY.md first line links README.md' {
        (Get-Content (Join-Path $RepoRoot 'ONTOLOGY.md') -First 1) | Should -Match '\]\(README\.md\)'
    }
    It 'ONTOLOGY.md says Run and Plan totals are sums at query time, not stored' {
        $text = Get-Content -LiteralPath (Join-Path $RepoRoot 'ONTOLOGY.md') -Raw
        $text | Should -Match 'not stored'
        $text | Should -Match 'sums? .*at query time'
    }
}

Describe 'Copied skills (read-only here)' {
    It '<Skill> has the version: of the committed copy in <Source>' -ForEach $Skills {
        $committed = Get-CommittedText -Repo $Source -RelativePath ".claude/skills/$Skill/SKILL.md"
        if ($null -eq $committed) {
            Set-ItResult -Skipped -Because "$Source is not a git checkout with .claude/skills/$Skill committed"
            return
        }
        $mine = Get-FrontVersion -Path (Join-Path $RepoRoot '.claude' 'skills' $Skill 'SKILL.md')
        $mine | Should -Match '^\d+\.\d+\.\d+$'
        $mine | Should -Be (Get-FrontVersion -Text $committed) -Because "recopy .claude/skills/$Skill from $Source\.claude\skills\$Skill"
    }

    It '<Skill> is the full text of the committed copy in <Source>, every file, line endings aside' -ForEach $Skills {
        $committed = Get-CommittedText -Repo $Source -RelativePath ".claude/skills/$Skill/SKILL.md"
        if ($null -eq $committed) {
            Set-ItResult -Skipped -Because "$Source is not a git checkout with .claude/skills/$Skill committed"
            return
        }
        $theirs = @(& git -C $Source ls-tree -r --name-only HEAD ".claude/skills/$Skill" | Sort-Object)
        $dir = Join-Path $RepoRoot '.claude' 'skills' $Skill
        $mine = @(Get-ChildItem -LiteralPath $dir -Recurse -File | ForEach-Object {
                ".claude/skills/$Skill/" + [System.IO.Path]::GetRelativePath($dir, $_.FullName).Replace('\', '/')
            } | Sort-Object)
        $mine | Should -Be $theirs
        foreach ($path in $theirs) {
            (Get-Content -LiteralPath (Join-Path $RepoRoot $path)) -join "`n" | Should -BeExactly (Get-CommittedText -Repo $Source -RelativePath $path) -Because "$path is a copy; do not edit it here"
        }
    }
}
