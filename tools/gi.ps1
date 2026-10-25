[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message,

    [switch]$Help,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================
# GI - Git Integration
# Automated Git add, commit, and push utility
# ============================================================

$script:AppName    = 'GI'
$script:Version    = '1.0.0'
$script:ExitCode   = 0

# ------------------------------------------------------------
# Console UI
# ------------------------------------------------------------

function Write-Header {
    Clear-Host

    Write-Host ''
    Write-Host '  +--------------------------------------------------+' `
        -ForegroundColor DarkCyan
    Write-Host '  |  GI  /  GIT INTEGRATION                          |' `
        -ForegroundColor Cyan
    Write-Host '  |  Automated Git workflow                          |' `
        -ForegroundColor DarkCyan
    Write-Host '  +--------------------------------------------------+' `
        -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-Section {
    param([string]$Title)

    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "  $('-' * $Title.Length)" -ForegroundColor DarkGray
}

function Write-Info {
    param(
        [string]$Label,
        [string]$Value
    )

    Write-Host '  '
    Write-Host "  $Label".PadRight(15) -NoNewline `
        -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor White
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('OK', 'WARN', 'FAIL', 'INFO')]
        [string]$Status = 'INFO'
    )

    $color = switch ($Status) {
        'OK'   { 'Green' }
        'WARN' { 'Yellow' }
        'FAIL' { 'Red' }
        'INFO' { 'Cyan' }
    }

    $symbol = switch ($Status) {
        'OK'   { '[OK]' }
        'WARN' { '[!!]' }
        'FAIL' { '[FAIL]' }
        'INFO' { '[..]' }
    }

    Write-Host "  $symbol " -ForegroundColor $color -NoNewline
    Write-Host $Message -ForegroundColor Gray
}

function Write-Fatal {
    param([string]$Message)

    Write-Status $Message 'FAIL'
    exit 1
}

function Show-Help {
    Write-Header

    Write-Host '  USAGE' -ForegroundColor Cyan
    Write-Host '    gi <commit-message>'
    Write-Host ''
    Write-Host '  OPTIONS' -ForegroundColor Cyan
    Write-Host '    -Help       Display this help message'
    Write-Host '    -DryRun     Preview the workflow without changes'
    Write-Host ''
    Write-Host '  EXAMPLES' -ForegroundColor Cyan
    Write-Host '    gi "Add binary search implementation"'
    Write-Host '    gi "Fix input validation" -DryRun'
    Write-Host '    gi -Help'
    Write-Host ''
    Write-Host '  WORKFLOW' -ForegroundColor Cyan
    Write-Host '    1. Inspect the repository'
    Write-Host '    2. Stage changes'
    Write-Host '    3. Commit changes'
    Write-Host '    4. Push to the remote repository'
    Write-Host ''
    Write-Host "  GI v$script:Version" -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# Git command execution
# ------------------------------------------------------------

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string[]]$GitArgs
    )

    # Execute Git without invoking a PowerShell alias or function.
    $output = & git @GitArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $details = ($output | ForEach-Object {
            "$_"
        }) -join [Environment]::NewLine

        if ([string]::IsNullOrWhiteSpace($details)) {
            $details = "Git exited with code $exitCode."
        }

        throw "git $($GitArgs -join ' ') failed.`n$details"
    }

    return $output
}

# ------------------------------------------------------------
# Main workflow
# ------------------------------------------------------------

if ($Help) {
    Show-Help
    exit 0
}

Write-Header

# Step 0: Validate input and prerequisites.

if ([string]::IsNullOrWhiteSpace($Message)) {
    Write-Host '  A commit message is required.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Usage: gi "Your commit message"' -ForegroundColor Gray
    Write-Host '  Help:  gi -Help' -ForegroundColor Gray
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fatal 'Git was not found. Install Git or check your PATH.'
}

# Locate the repository from the current directory.
try {
    $repoRoot = (Invoke-Git -GitArgs @(
        'rev-parse', '--show-toplevel'
    ) | Select-Object -Last 1).ToString().Trim()
}
catch {
    Write-Fatal 'The current directory is not inside a Git repository.'
}

# Resolve branch and remote.
try {
    $branch = (Invoke-Git -GitArgs @(
        'branch', '--show-current'
    ) | Select-Object -Last 1).ToString().Trim()

    $remote = (Invoke-Git -GitArgs @(
        'remote'
    ) | Select-Object -First 1)

    if ($null -ne $remote) {
        $remote = $remote.ToString().Trim()
    }
}
catch {
    Write-Fatal $_.Exception.Message
}

if ([string]::IsNullOrWhiteSpace($branch)) {
    Write-Fatal 'Detached HEAD detected. Check out a branch before using GI.'
}

if ([string]::IsNullOrWhiteSpace($remote)) {
    Write-Fatal 'No Git remote is configured. Add a remote before pushing.'
}

# Show repository details.
Write-Section 'REPOSITORY'

Write-Info 'Name' (Split-Path $repoRoot -Leaf)
Write-Info 'Branch' $branch
Write-Info 'Remote' $remote

# Inspect changes.
Write-Section 'WORKFLOW'

Write-Status 'Inspecting working tree...' 'INFO'

try {
    $changes = @(Invoke-Git -GitArgs @(
        'status', '--porcelain'
    ))
}
catch {
    Write-Fatal $_.Exception.Message
}

if ($changes.Count -eq 0) {
    Write-Status 'Working tree is clean. Nothing to commit.' 'WARN'
    Write-Host ''
    Write-Host '  No changes were staged, committed, or pushed.' `
        -ForegroundColor Gray
    exit 0
}

Write-Status "$($changes.Count) changed file entr$(if ($changes.Count -eq 1) { 'y' } else { 'ies' }) detected." 'OK'

if ($DryRun) {
    Write-Status 'Dry-run enabled: no files will be staged or committed.' 'WARN'

    foreach ($change in $changes) {
        Write-Host "    $change" -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host '  Preview complete. No Git changes were made by GI.' `
        -ForegroundColor Yellow
    exit 0
}

# Stage all changes, including deletions and untracked files.
Write-Status 'Staging changes...' 'INFO'

try {
    Invoke-Git -GitArgs @('add', '-A') | Out-Null
    Write-Status 'Changes staged successfully.' 'OK'
}
catch {
    Write-Fatal $_.Exception.Message
}

# Commit staged changes.
Write-Status 'Creating commit...' 'INFO'

try {
    Invoke-Git -GitArgs @(
        'commit', '-m', $Message
    ) | Out-Null

    $commit = (Invoke-Git -GitArgs @(
        'rev-parse', '--short', 'HEAD'
    ) | Select-Object -Last 1).ToString().Trim()

    Write-Status "Commit created: $commit" 'OK'
}
catch {
    Write-Fatal $_.Exception.Message
}

# Push the current branch.
Write-Status "Pushing to $remote/$branch..." 'INFO'

try {
    $upstream = & git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
    $hasUpstream = ($LASTEXITCODE -eq 0)

    if ($hasUpstream) {
        Invoke-Git -GitArgs @(
            'push'
        ) | Out-Null
    }
    else {
        # Publish the branch and establish its upstream.
        Invoke-Git -GitArgs @(
            'push', '-u', $remote, $branch
        ) | Out-Null
    }

    Write-Status 'Push completed successfully.' 'OK'
}
catch {
    Write-Fatal $_.Exception.Message
}

# Final summary.
Write-Section 'SUMMARY'

Write-Info 'Commit' $commit
Write-Info 'Message' $Message
Write-Info 'Branch' "$remote/$branch"

Write-Host ''
Write-Host '  +--------------------------------------------------+' `
    -ForegroundColor Green
Write-Host '  |  SUCCESS: Changes committed and pushed.          |' `
    -ForegroundColor Green
Write-Host '  +--------------------------------------------------+' `
    -ForegroundColor Green
Write-Host ''