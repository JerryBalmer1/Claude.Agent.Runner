BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    $script:Graph = Export-RunnerGraph -InputPath $FixturePath
    $script:Steps = @($Graph.nodes | Where-Object kind -eq 'Step')
    # The fixture with every agent: Rule id rewritten, so no Step follows a Rule: an improvised run.
    $script:Improvised = Join-Path $TestDrive 'improvised.stream.jsonl'
    (Get-Content -LiteralPath $FixturePath -Raw) -replace 'agent:CLAUDE\.md#rules/rule-', 'line-' | Set-Content -LiteralPath $Improvised -NoNewline
}

Describe 'Export-RunnerGraph on the fixture' {
    It 'yields one Plan, one Run and three or more Steps' {
        $Graph.counts.byKind.Plan | Should -Be 1
        $Graph.counts.byKind.Run | Should -Be 1
        $Graph.counts.byKind.Step | Should -BeGreaterOrEqual 3
        $Steps.Count | Should -Be 3 -Because 'the fixture has three assistant messages, written as eight lines'
    }

    It 'builds ids from the file name, the session id and the step number' {
        $Graph.root | Should -Be 'runner:three-turns'
        $run = @($Graph.nodes | Where-Object kind -eq 'Run')[0]
        $run.id | Should -Be 'runner:three-turns/70c11582-dade-4bbc-9cab-4999f761dc1a'
        $run.properties.driver | Should -Be (Import-PowerShellDataFile -Path (Join-Path $ModuleRoot 'drivers' 'drivers.psd1')).Default
        $Steps.id | Should -Be @(1..3 | ForEach-Object { "$($run.id)/step-$_" })
    }

    It 'stamps the layer with the run''s first stream timestamp' {
        $Graph.layer | Should -Be '2026-10-09T05:10:02Z'
    }

    It 'chains the Steps with order edges, and the Plan contains the Run contains each Step' {
        $order = @($Graph.edges | Where-Object kind -eq 'order')
        $order.Count | Should -Be ($Steps.Count - 1)
        for ($i = 0; $i -lt $order.Count; $i++) {
            $order[$i].from | Should -Be $Steps[$i].id
            $order[$i].to | Should -Be $Steps[$i + 1].id
        }
        $contains = @($Graph.edges | Where-Object kind -eq 'contains')
        $contains.Count | Should -Be (1 + $Steps.Count)
        @($contains | Where-Object from -eq $Graph.root).Count | Should -Be 1
    }

    It 'gives every Step its token counts and metered true' {
        foreach ($s in $Steps) {
            $s.properties.metered | Should -BeTrue
            foreach ($p in 'tokensInput', 'tokensOutput', 'tokensCache') { $s.properties[$p] | Should -BeOfType [int] -Because "$($s.id) $p" }
        }
        $Steps[0].properties.tokensInput | Should -Be 10
        $Steps[0].properties.tokensOutput | Should -Be 6
        $Steps[0].properties.tokensCache | Should -Be (26314 + 10396)
        $Steps[0].properties.tools | Should -Be 'Read'
        $Steps[2].properties.tools | Should -Be ''
    }

    It 'stores no token totals on the Run or the Plan' {
        foreach ($n in $Graph.nodes | Where-Object kind -in 'Plan', 'Run') {
            @($n.properties.Keys | Where-Object { $_ -like 'tokens*' }) | Should -BeNullOrEmpty -Because $n.id
        }
    }

    It 'adds follows onto the agent: Rule a Step names, and none for the improvised Step' {
        $follows = @($Graph.edges | Where-Object kind -eq 'follows')
        $follows.from | Should -Be @($Steps[0].id, $Steps[1].id)
        $follows.to | Should -Be @('agent:CLAUDE.md#rules/rule-1', 'agent:CLAUDE.md#rules/rule-2')
        @($follows | Where-Object from -eq $Steps[2].id) | Should -BeNullOrEmpty
    }
}

Describe 'Export-RunnerGraph -Strict' {
    It 'throws on the fixture''s two dangling follows edges' {
        { Export-RunnerGraph -InputPath $FixturePath -Strict } | Should -Throw '2 dangling follows edge(s)*'
    }

    It 'passes an improvised run, which has no follows edges' {
        $g = Export-RunnerGraph -InputPath $Improvised -Strict
        @($g.edges | Where-Object kind -eq 'follows') | Should -BeNullOrEmpty
        $g.counts.byKind.Step | Should -Be 3
    }
}

Describe 'Export-RunnerGraph -LayersPath' {
    It 'writes the layer-stamp .graph.json and the ontology copy, and tolerates only the follows dangling-edge errors' {
        $layers = Join-Path $TestDrive 'layers'
        $g = Export-RunnerGraph -InputPath $FixturePath -LayersPath $layers
        $file = Join-Path $layers '2026-10-09T05-10-02Z.graph.json'
        Test-Path -LiteralPath $file | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $layers 'ontology.yaml') -Raw | Should -Be (Get-Content -LiteralPath (Join-Path $RepoRoot 'ontology.yaml') -Raw)
        (Import-Graph $file).counts.nodes | Should -Be $g.counts.nodes
        $errors = @((Test-Graph -Path $file -Strict).Problems | Where-Object Severity -eq 'error')
        $errors.Code | Sort-Object -Unique | Should -Be 'dangling-edge'
        $errors.Count | Should -Be 2
    }

    It 'writes a layer Test-Graph -Strict finds valid for an improvised run' {
        $layers = Join-Path $TestDrive 'layers-improvised'
        Export-RunnerGraph -InputPath $Improvised -LayersPath $layers -Strict | Out-Null
        (Test-Graph -Path (Join-Path $layers '2026-10-09T05-10-02Z.graph.json') -Strict).Valid | Should -BeTrue
    }

    It 'leaves an existing ontology.yaml in the layers directory alone' {
        $layers = Join-Path $TestDrive 'layers-existing'
        New-Item -ItemType Directory -Path $layers | Out-Null
        Set-Content -LiteralPath (Join-Path $layers 'ontology.yaml') -Value 'kinds: {}' -NoNewline
        Export-RunnerGraph -InputPath $FixturePath -LayersPath $layers | Out-Null
        Get-Content -LiteralPath (Join-Path $layers 'ontology.yaml') -Raw | Should -Be 'kinds: {}'
    }
}

Describe 'Export-RunnerGraph -Driver' {
    It 'takes the default driver by name' {
        $default = (Import-PowerShellDataFile -Path (Join-Path $ModuleRoot 'drivers' 'drivers.psd1')).Default
        (Export-RunnerGraph -InputPath $FixturePath -Driver $default).counts.nodes | Should -Be $Graph.counts.nodes
    }

    It 'throws on an unknown driver, naming the drivers there are' {
        { Export-RunnerGraph -InputPath $FixturePath -Driver 'nope' } | Should -Throw "unknown driver 'nope'*"
    }

    It 'throws on a stream with no session' {
        $empty = Join-Path $TestDrive 'empty.stream.jsonl'
        Set-Content -LiteralPath $empty -Value 'not json'
        { Export-RunnerGraph -InputPath $empty } | Should -Throw '*found no session*'
    }
}
