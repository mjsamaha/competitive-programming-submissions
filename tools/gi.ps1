
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

$script:AppName  = 'GI'
$script:Version = '1.1.1'

# ------------------------------------------------------------
# Console UI
# ------------------------------------------------------------

function Write-Header {
    Clear-Host

    Write-Host ''
    Write-Host '  +--------------------------------------------------+' -ForegroundColor DarkCyan
    Write-Host '  |  GI  /  GIT INTEGRATION                          |' -ForegroundColor Cyan
    Write-Host '  |  Automated Git workflow                          |' -ForegroundColor DarkCyan
    Write-Host '  +--------------------------------------------------+' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host '  Author: lobsterchops | Date: 2026-10-24'
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)

    Write-Host ''
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "  $('-' * $Title.Length)" -ForegroundColor DarkGray
}

function Write-Info {
    param(
        [Parameter(Mandatory)][string]$Label,
        [AllowEmptyString()][string]$Value = ''
    )

    Write-Host '  ' -NoNewline
    Write-Host $Label.PadRight(15) -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor White
}

function Write-Status {
    param(
        [Parameter(Mandatory)][string]$Message,
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
        'OK'   { '[OK]  ' }
        'WARN' { '[!!]  ' }
        'FAIL' { '[FAIL] ' }
        'INFO' { '[..]  ' }
    }

    Write-Host "  $symbol" -ForegroundColor $color -NoNewline
    Write-Host $Message -ForegroundColor Gray
}

function Write-Fatal {
    param([Parameter(Mandatory)][string]$Message)

    $lines = @($Message -split '\r?\n')

    if ($lines.Count -gt 0) {
        Write-Status $lines[0] 'FAIL'

        foreach ($line in ($lines | Select-Object -Skip 1)) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-Host "         $line" -ForegroundColor Red
            }
        }
    }

    Write-Host ''
    Write-Host '  Workflow stopped. Review the error above.' -ForegroundColor Yellow
    exit 1
}

function Show-Help {
    Write-Header

    Write-Host '  USAGE' -ForegroundColor Cyan
    Write-Host '    gip <commit-message>'
    Write-Host ''
    Write-Host '  OPTIONS' -ForegroundColor Cyan
    Write-Host '    -Help       Display this help message'
    Write-Host '    -DryRun     Preview changes without modifying Git state'
    Write-Host ''
    Write-Host '  EXAMPLES' -ForegroundColor Cyan
    Write-Host '    gip "Add binary search implementation"'
    Write-Host '    gip "Fix input validation" -DryRun'
    Write-Host '    gip -Help'
    Write-Host ''
    Write-Host '  WORKFLOW' -ForegroundColor Cyan
    Write-Host '    1. Inspect the repository'
    Write-Host '    2. Stage all changes'
    Write-Host '    3. Create a commit'
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

    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    $hasNativePreference = Test-Path variable:PSNativeCommandUseErrorActionPreference
    $previousNativePreference = $null

    if ($hasNativePreference) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $output = @(& git @GitArgs 2>&1)
        $exitCode = $LASTEXITCODE

        $lines = @(
            foreach ($item in $output) {
                if ($null -ne $item) {
                    $item.ToString()
                }
            }
        )

        if ($exitCode -ne 0) {
            $details = $lines -join [Environment]::NewLine

            if ([string]::IsNullOrWhiteSpace($details)) {
                $details = "Git exited with code $exitCode."
            }

            throw "git $($GitArgs -join ' ') failed (exit code ${exitCode}).`n$details"
        }

        return $lines
    }
    finally {
        $ErrorActionPreference = $previousErrorPreference

        if ($hasNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }

}

function Show-GitOutput {
    param([AllowNull()][object[]]$Lines)

    foreach ($line in $Lines) {
        if (-not [string]::IsNullOrWhiteSpace("$line")) {
            Write-Host "         $line" -ForegroundColor DarkGray
        }
    }
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
    Write-Host '  Usage: gip "Your commit message"' -ForegroundColor Gray
    Write-Host '  Help:  gip -Help' -ForegroundColor Gray
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fatal 'Git was not found. Install Git or check your PATH.'
}

# Locate repository root.

try {
    $repoRoot = (
        Invoke-Git -GitArgs @('rev-parse', '--show-toplevel') |
        Select-Object -Last 1
    ).ToString().Trim()
}
catch {
    Write-Fatal 'The current directory is not inside a Git repository.'
}

# Resolve current branch and configured remote.

try {
    $branch = (
        Invoke-Git -GitArgs @('branch', '--show-current') |
        Select-Object -Last 1
    ).ToString().Trim()

    $remoteLines = @(Invoke-Git -GitArgs @('remote'))
    $remote = if ($remoteLines.Count -gt 0) {
        $remoteLines[0].ToString().Trim()
    }
    else {
        $null
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

# Inspect working tree.

Write-Section 'WORKFLOW'

Write-Status 'Inspecting working tree...' 'INFO'

try {
    $changes = @(Invoke-Git -GitArgs @('status', '--porcelain'))
}
catch {
    Write-Fatal $_.Exception.Message
}

if ($changes.Count -eq 0) {
    Write-Status 'Working tree is clean. Nothing to commit.' 'WARN'
    Write-Host ''
    Write-Host '  No changes were staged, committed, or pushed.' -ForegroundColor Gray
    exit 0
}

$entryLabel = if ($changes.Count -eq 1) { 'entry' } else { 'entries' }
Write-Status "$($changes.Count) changed file $entryLabel detected." 'OK'

# Dry-run preview.

if ($DryRun) {
    Write-Status 'Dry-run enabled. No changes will be staged or committed.' 'WARN'

    foreach ($change in $changes) {
        Write-Host "         $change" -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host '  Preview complete. No Git changes were made by GI.' -ForegroundColor Yellow
    exit 0
}

# Stage all changes, including new files and deletions.

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
    Invoke-Git -GitArgs @('commit', '-m', $Message) | Out-Null

    $commit = (
        Invoke-Git -GitArgs @('rev-parse', '--short', 'HEAD') |
        Select-Object -Last 1
    ).ToString().Trim()

    Write-Status "Commit created: $commit" 'OK'
}
catch {
    Write-Fatal $_.Exception.Message
}

# Push current branch.
# Preserve the existing upstream when present; otherwise configure one.

Write-Status "Pushing to $remote/$branch..." 'INFO'

try {
    $upstreamLines = @(
        Invoke-Git -GitArgs @(
            'rev-parse',
            '--abbrev-ref',
            '--symbolic-full-name',
            '@{u}'
        )
    )

    $hasUpstream = $upstreamLines.Count -gt 0 -and
        -not [string]::IsNullOrWhiteSpace($upstreamLines[0].ToString())
}
catch {
    # A missing upstream is expected for a newly created local branch.
    $hasUpstream = $false
}

$previousErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

$hasNativePreference = Test-Path variable:PSNativeCommandUseErrorActionPreference
$previousNativePreference = $null

if ($hasNativePreference) {
    $previousNativePreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
}

try {
    # Do not merge stderr into the PowerShell error stream here. Git commonly
    # writes normal push progress to stderr, which can look like a failure.
    if ($hasUpstream) {
        & git push $remote $branch
    }
    else {
        & git push -u $remote $branch
    }

    $pushExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorPreference

    if ($hasNativePreference) {
        $PSNativeCommandUseErrorActionPreference = $previousNativePreference
    }
}

if ($pushExitCode -ne 0) {
    Write-Fatal "git push failed (exit code $pushExitCode). Check the Git output above."
}

Write-Status 'Push completed successfully.' 'OK'

# Final summary: reached only after a successful push.

Write-Section 'SUMMARY'

Write-Info 'Commit' $commit
Write-Info 'Message' $Message
Write-Info 'Branch' "$remote/$branch"

Write-Host ''
Write-Host '  +--------------------------------------------------+' -ForegroundColor Green
Write-Host '  |  SUCCESS: Changes committed and pushed.          |' -ForegroundColor Green
Write-Host '  +--------------------------------------------------+' -ForegroundColor Green
Write-Host ''
