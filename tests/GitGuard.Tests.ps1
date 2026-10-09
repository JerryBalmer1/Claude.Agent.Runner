BeforeDiscovery {
    # The commands Graph pins the hook to (git-guard SKILL.md, "Test it by hand"), plus gh pr merge.
    $script:Commands = @(
        @{ Command = 'git status'; Code = 0 }
        @{ Command = 'git add -A'; Code = 0 }
        @{ Command = 'git commit -m x'; Code = 2 }
        @{ Command = 'git push'; Code = 2 }
        @{ Command = 'git tag v1'; Code = 2 }
        @{ Command = 'gh pr merge 1'; Code = 2 }
        @{ Command = 'echo hi && git push'; Code = 2 }
    )
}

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    $script:Skill = Join-Path $RepoRoot '.claude' 'skills' 'git-guard'
    $script:Hook = Join-Path $Skill 'hook.ps1'
    $script:Message = 'git-guard: agents edit and stage only; commits are run by Jerry from a separate shell'
    # Pipes a Bash tool call's hook JSON into hook.ps1 in a fresh process; returns its exit code and stderr.
    function Invoke-Hook([string] $Command) {
        $raw = ConvertTo-Json -Compress -InputObject @{ tool_name = 'Bash'; tool_input = @{ command = $Command } }
        $err = Join-Path $TestDrive 'hook.err'
        $raw | & pwsh -NoProfile -File $Hook 2> $err | Out-Null
        [pscustomobject]@{ Code = $LASTEXITCODE; Error = (Get-Content -LiteralPath $err -Raw) }
    }
}

Describe 'git-guard hook (copied from Graph)' {
    It 'exits <Code> for <Command>' -ForEach $Commands {
        $r = Invoke-Hook -Command $Command
        $r.Code | Should -Be $Code -Because $r.Error
        if ($Code -eq 2) { $r.Error.Trim() | Should -Be $Message }
    }

    It '.claude/settings.json has the fragment''s PreToolUse entry' {
        $fragment = Get-Content -LiteralPath (Join-Path $Skill 'settings.fragment.json') -Raw | ConvertFrom-Json
        $settings = Get-Content -LiteralPath (Join-Path $RepoRoot '.claude' 'settings.json') -Raw | ConvertFrom-Json
        $want = @($fragment.hooks.PreToolUse)
        $want.Count | Should -Be 1
        $have = @($settings.hooks.PreToolUse | ForEach-Object { ConvertTo-Json -Depth 6 -Compress $_ })
        $have | Should -Contain (ConvertTo-Json -Depth 6 -Compress $want[0])
    }
}
