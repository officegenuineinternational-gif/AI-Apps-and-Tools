[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'GenuineWorkflowTools'),
    [switch]$CheckOnly,
    [ValidateSet('jev-ultrafast','laya','ax','hindsight','paperclip')]
    [string[]]$Only = @('jev-ultrafast','laya','ax','hindsight','paperclip')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$RepoRoot = Split-Path -Parent $PSScriptRoot
function Run-Native {
    param([string]$Exe, [string[]]$Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe failed with exit code $LASTEXITCODE" }
}
function Require-Command {
    param([string]$Name)
    $found = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $found -and $Name -eq 'go') {
        foreach ($base in @($env:ProgramFiles, [Environment]::GetFolderPath('ProgramFiles'))) {
            if ($base) {
                $candidate = Join-Path $base 'Go/bin/go.exe'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
            }
        }
    }
    if (-not $found) { throw "Required command missing: $Name" }
    return $found.Source
}

function Get-PreservedInstallResults {
    param([object[]]$Previous, [string[]]$Selected)
    $preserved = [System.Collections.Generic.List[object]]::new()
    foreach ($prior in $Previous) {
        if ($null -eq $prior) { continue }
        # Keep legacy or unknown records, but do not assume every older status has a tool field.
        $priorTool = $prior.PSObject.Properties['tool']
        if ($null -eq $priorTool -or $Selected -notcontains [string]$priorTool.Value) {
            $preserved.Add($prior)
        }
    }
    return ,$preserved.ToArray()
}

function Prepare-Paperclip {
    param([string]$Source, [string]$Root, [string]$ExpectedTree)
    $runtime = Join-Path $Root 'apps/paperclip'
    $marker = Join-Path $runtime '.genuine-source-tree'
    if (Test-Path -LiteralPath $runtime) {
        if (-not (Test-Path -LiteralPath $marker) -or (Get-Content -LiteralPath $marker -Raw).Trim() -ne $ExpectedTree) {
            throw 'Existing Paperclip installation does not match the pinned source; preserving it.'
        }
    } else {
        New-Item -ItemType Directory -Path $runtime -Force | Out-Null
        & robocopy.exe $Source $runtime /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XD node_modules .git
        if ($LASTEXITCODE -gt 7) { throw "Paperclip source copy failed: $LASTEXITCODE" }
        Set-Content -LiteralPath $marker -Value $ExpectedTree -Encoding ASCII
    }
    # Keep the pinned vendor snapshot unchanged; patch only the runnable Windows copy.
    $node = Require-Command 'node'
    Run-Native $node @((Join-Path $RepoRoot 'scripts/Prepare-Paperclip-Windows.mjs'), $runtime)
    $pnpm = Require-Command 'pnpm'
    Push-Location $runtime
    try {
        # Repair only the disposable installation copy; preserve verified vendor source.
        # Subsequent dependency installation still requires a consistent frozen lockfile.
        Run-Native $pnpm @('install','--lockfile-only','--ignore-scripts','--no-frozen-lockfile')
        Run-Native $pnpm @('install','--lockfile-only','--ignore-scripts','--frozen-lockfile')
    } finally { Pop-Location }
    return $runtime
}

$Tools = @(
    @{ Name='jev-ultrafast'; Tree='987b481ed8ef400911ca471bce38c7adfdabc45c' },
    @{ Name='laya'; Tree='a3c658bd9c314962e37e7c486585ee09e3bab840' },
    @{ Name='ax'; Tree='ffe94f99495ee1e1900829e2555d97a1f74f58bf' },
    @{ Name='hindsight'; Tree='f74d1427607d7c3a9fb16b5d3ce56e806da5ccf8' },
    @{ Name='paperclip'; Tree='7f167a38e898b90855890fc609adf5267d4ea981' }
)
$git = Require-Command 'git'
foreach ($tool in $Tools) {
    $actual = & $git -C $RepoRoot rev-parse ("HEAD:vendors/" + $tool.Name)
    if ($LASTEXITCODE -ne 0 -or $actual.Trim() -ne $tool.Tree) {
        throw "Source integrity check failed: $($tool.Name)"
    }
}
Run-Native $git @('-C', $RepoRoot, 'diff', '--quiet', 'HEAD', '--', 'vendors')
if ($CheckOnly) {
    Write-Output 'PASS: five pinned source tree hashes match and tracked source is unchanged.'
    foreach ($name in @('uv','node','pnpm','go')) {
        $available = [bool](Get-Command $name -ErrorAction SilentlyContinue)
        Write-Output ("{0}: {1}" -f $name, $available)
    }
    return
}
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
$Results = [System.Collections.Generic.List[object]]::new()
$statusPath = Join-Path $InstallRoot 'installation-status.json'
if (Test-Path -LiteralPath $statusPath) {
    $previous = @(Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json)
    foreach ($prior in (Get-PreservedInstallResults -Previous $previous -Selected $Only)) {
        $Results.Add($prior)
    }
}
foreach ($tool in $Tools) {
    if ($Only -notcontains $tool.Name) { continue }
    $name = $tool.Name
    $source = Join-Path $RepoRoot ("vendors/" + $name)
    $environment = Join-Path $InstallRoot ("envs/" + $name)
    $state = 'FAILED'
    $detail = ''
    Push-Location $source
    try {
        switch ($name) {
            'jev-ultrafast' {
                $uv = Require-Command 'uv'
                $previous = [Environment]::GetEnvironmentVariable('UV_PROJECT_ENVIRONMENT','Process')
                try {
                    $env:UV_PROJECT_ENVIRONMENT = $environment
                    Run-Native $uv @('sync','--locked','--no-dev')
                    Run-Native $uv @('run','--no-sync','python','-I','-c','import jev_ultrafast; print(jev_ultrafast.__name__)')
                } finally {
                    [Environment]::SetEnvironmentVariable('UV_PROJECT_ENVIRONMENT',$previous,'Process')
                }
                $state='INSTALLED'
                $detail='Import passed. Browser connection and API configuration remain pending.'
            }
            'laya' {
                $uv = Require-Command 'uv'
                if (-not (Test-Path (Join-Path $environment 'Scripts/python.exe'))) {
                    Run-Native $uv @('venv','--python','3.12',$environment)
                }
                $python = Join-Path $environment 'Scripts/python.exe'
                Run-Native $uv @('pip','install','--python',$python,'--torch-backend=cpu',($source + '[serve,mcp]'))
                Run-Native $python @('-I','-c','import laya; print(laya.__version__)')
                Run-Native $uv @('pip','check','--python',$python)
                $state='INSTALLED'
                $detail='Import and dependency checks passed. Model download and inference validation remain pending.'
            }
            'ax' {
                $go = Require-Command 'go'
                $bin = Join-Path $InstallRoot 'bin'
                New-Item -ItemType Directory -Path $bin -Force | Out-Null
                # This upstream revision uses Unix-only syscalls; build for Linux/WSL.
                $binary = Join-Path $bin 'ax-linux-amd64'
                $previousOS = [Environment]::GetEnvironmentVariable('GOOS','Process')
                $previousArch = [Environment]::GetEnvironmentVariable('GOARCH','Process')
                try {
                    $env:GOOS = 'linux'
                    $env:GOARCH = 'amd64'
                    Run-Native $go @('build','-o',$binary,'./cmd/ax')
                } finally {
                    [Environment]::SetEnvironmentVariable('GOOS',$previousOS,'Process')
                    [Environment]::SetEnvironmentVariable('GOARCH',$previousArch,'Process')
                }
                if (-not (Test-Path $binary)) { throw 'AX Linux binary not produced.' }
                $state='BUILT'
                $detail='Linux CLI built for WSL. Linux execution, Kubernetes and Agent Substrate readiness remain pending.'
            }
            'hindsight' {
                $uv = Require-Command 'uv'
                $previous = [Environment]::GetEnvironmentVariable('UV_PROJECT_ENVIRONMENT','Process')
                try {
                    $env:UV_PROJECT_ENVIRONMENT = $environment
                    Run-Native $uv @('sync','--locked','--no-dev','--package','hindsight-all')
                    Run-Native $uv @('run','--no-sync','--package','hindsight-all','python','-I','-c','import hindsight; print(hindsight.__name__)')
                } finally {
                    [Environment]::SetEnvironmentVariable('UV_PROJECT_ENVIRONMENT',$previous,'Process')
                }
                $state='INSTALLED'
                $detail='Import passed. Database, model provider and local service setup remain pending.'
            }
            'paperclip' {
                $node = Require-Command 'node'
                $pnpm = Require-Command 'pnpm'
                $version = & $node -p 'process.versions.node'
                if ($LASTEXITCODE -ne 0 -or [version]$version -lt [version]'24.11.0') {
                    throw 'Paperclip requires Node 24.11 or newer.'
                }
                $runtimeOutput = @(Prepare-Paperclip -Source $source -Root $InstallRoot -ExpectedTree $tool.Tree)
                $runtime = $runtimeOutput[-1]
                Push-Location $runtime
                try {
                    Run-Native $pnpm @('install','--frozen-lockfile')
                    Run-Native $pnpm @('build')
                } finally { Pop-Location }
                $state='BUILT'
                $detail='Dependencies and build passed. Service startup and runtime testing remain pending.'
            }
        }
    } catch {
        $detail = $_.Exception.Message
    } finally {
        Pop-Location
    }
    $Results.Add([pscustomobject]@{tool=$name;state=$state;detail=$detail})
    $Results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $InstallRoot 'installation-status.json') -Encoding UTF8
    Write-Output ("{0}: {1} - {2}" -f $name,$state,$detail)
}
Write-Output ('Results: ' + (Join-Path $InstallRoot 'installation-status.json'))
if (@($Results | Where-Object {
    $stateProperty = $_.PSObject.Properties['state']
    $null -ne $stateProperty -and $stateProperty.Value -eq 'FAILED'
}).Count -gt 0) {
    throw 'One or more tool installations failed. See installation-status.json.'
}
