[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message,

    [string[]]$Path,

    [switch]$NoPush,
    [switch]$Amend,
    [switch]$Pull,
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================
# GIP - Git Integration
# Automated Git add, commit, and push utility
# ============================================================

$script:AppName     = 'GIP'
$script:CommandName = 'gip'
$script:Version     = '1.2.0'

$script:LargeWarnBytes  = 50MB
$script:LargeBlockBytes = 100MB
$script:SubjectMax      = 72
$script:MaxListed       = 25
$script:GitExitCode     = 0

# Filename patterns that commonly hold secrets (matched against the leaf name).
$script:SensitivePatterns = @(
    '^\.env(\..+)?$',
    '\.(pem|key|pfx|p12|jks|keystore|ppk|kdbx)$',
    '^id_(rsa|dsa|ecdsa|ed25519)$',
    '^application-.+\.(properties|ya?ml)$',
    '^(credentials|secrets?)(\..+)?$'
)
# Template files that look sensitive but are meant to be committed.
$script:SensitiveAllow = '\.(example|sample|template|dist)$'

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# ------------------------------------------------------------
# Console UI
# ------------------------------------------------------------

function Write-Rule {
    param([Parameter(Mandatory)][string]$Color)
    Write-Host ('  +' + ('-' * 50) + '+') -ForegroundColor $Color
}

function Write-Banner {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Color
    )
    Write-Host "  |  $($Text.PadRight(48))|" -ForegroundColor $Color
}

function Write-Header {
    Write-Host ''
    Write-Rule 'DarkCyan'
    Write-Banner 'GIP  /  GIT INTEGRATION' 'Cyan'
    Write-Banner 'Automated Git workflow' 'DarkCyan'
    Write-Rule 'DarkCyan'
    Write-Host ''
    Write-Host "  Author: lobsterchops | v$script:Version"
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

    # All symbols share one width so messages line up.
    $symbol = switch ($Status) {
        'OK'   { '[OK]   ' }
        'WARN' { '[!!]   ' }
        'FAIL' { '[FAIL] ' }
        'INFO' { '[..]   ' }
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

function Show-GitOutput {
    param([AllowNull()][object[]]$Lines)

    foreach ($line in $Lines) {
        if (-not [string]::IsNullOrWhiteSpace("$line")) {
            Write-Host "         $line" -ForegroundColor DarkGray
        }
    }
}

function Show-Help {
    $cmd = $script:CommandName

    Write-Header
    Write-Host ''
    Write-Host '  USAGE' -ForegroundColor Cyan
    Write-Host "    $cmd <commit-message> [options]"
    Write-Host ''
    Write-Host '  OPTIONS' -ForegroundColor Cyan
    Write-Host '    -Path <p1,p2>   Stage and commit only these paths'
    Write-Host '    -NoPush         Stage and commit, but do not push'
    Write-Host '    -Pull           If behind the remote, rebase onto it after committing'
    Write-Host '    -Amend          Amend the last commit (message optional)'
    Write-Host '    -Yes            Skip the final commit confirmation'
    Write-Host '    -DryRun         Preview changes without modifying Git state'
    Write-Host '    -Help           Display this help message'
    Write-Host ''
    Write-Host '  EXAMPLES' -ForegroundColor Cyan
    Write-Host "    $cmd `"Add binary search implementation`""
    Write-Host "    $cmd `"Fix input validation`" -DryRun"
    Write-Host "    $cmd `"Update docs`" -Path README.md,docs -NoPush"
    Write-Host "    $cmd `"Fix typo`" -Amend"
    Write-Host "    $cmd `"Sync work`" -Pull -Yes"
    Write-Host ''
    Write-Host '  WORKFLOW' -ForegroundColor Cyan
    Write-Host '    1. Inspect the repository and run safety checks'
    Write-Host '    2. Stage changes'
    Write-Host '    3. Create a commit'
    Write-Host '    4. Push to the remote repository'
    Write-Host ''
    Write-Host '  SAFETY' -ForegroundColor Cyan
    Write-Host '    Sensitive-looking files and files over 50 MB always prompt,'
    Write-Host '    even with -Yes. Files over 100 MB are blocked. GI never'
    Write-Host '    force-pushes.'
    Write-Host ''
    Write-Host "  GI v$script:Version" -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

function Invoke-Git {
    param(
        [Parameter(Mandatory)]
        [string[]]$GitArgs,

        # Return output instead of throwing on a non-zero exit code.
        # The exit code is always available in $script:GitExitCode.
        [switch]$AllowFail
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
        $script:GitExitCode = $exitCode

        $lines = @(
            foreach ($item in $output) {
                if ($null -ne $item) {
                    $item.ToString()
                }
            }
        )

        if ($exitCode -ne 0 -and -not $AllowFail) {
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

function Confirm-Action {
    param([Parameter(Mandatory)][string]$Prompt)

    try {
        $answer = Read-Host "  $Prompt [y/N]"
    }
    catch {
        # Non-interactive host: treat as "no".
        return $false
    }

    return ($answer -match '^(y|yes)$')
}

function Format-Size {
    param([Parameter(Mandatory)][long]$Bytes)

    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Get-InProgressOperation {
    param([Parameter(Mandatory)][string]$GitDir)

    $checks = @(
        @('merge',       'MERGE_HEAD'),
        @('cherry-pick', 'CHERRY_PICK_HEAD'),
        @('revert',      'REVERT_HEAD'),
        @('rebase',      'rebase-merge'),
        @('rebase',      'rebase-apply')
    )

    foreach ($check in $checks) {
        if (Test-Path -LiteralPath (Join-Path $GitDir $check[1])) {
            return $check[0]
        }
    }

    return $null
}

function ConvertFrom-StatusLine {
    param([Parameter(Mandatory)][string]$Line)

    if ($Line.Length -lt 4) { return $null }

    $code = $Line.Substring(0, 2)
    $file = $Line.Substring(3)

    # Renames/copies are reported as "old -> new"; keep the new path.
    if ($code -match '[RC]') {
        $arrow = $file.LastIndexOf(' -> ')
        if ($arrow -ge 0) { $file = $file.Substring($arrow + 4) }
    }

    # Paths with special characters are wrapped in quotes.
    if ($file.Length -ge 2 -and $file.StartsWith('"') -and $file.EndsWith('"')) {
        $file = $file.Substring(1, $file.Length - 2)
        $file = $file.Replace('\"', '"').Replace('\\', '\')
    }

    $kind = 'modified'
    if ($code -eq '??') { $kind = 'new' }
    elseif ($code -match 'U' -or $code -eq 'AA' -or $code -eq 'DD') { $kind = 'conflict' }
    elseif ($code -match 'D') { $kind = 'deleted' }
    elseif ($code -match 'R') { $kind = 'renamed' }
    elseif ($code -match 'A') { $kind = 'new' }

    $staged = ($code[0] -ne ' ' -and $code[0] -ne '?')

    return [pscustomobject]@{
        Code   = $code
        Path   = $file
        Kind   = $kind
        Staged = $staged
    }
}

function Show-ChangeSummary {
    param([Parameter(Mandatory)][object[]]$Items)

    $kinds = @(
        @{ Name = 'modified'; Symbol = '~'; Color = 'Yellow' },
        @{ Name = 'new';      Symbol = '+'; Color = 'Green'  },
        @{ Name = 'deleted';  Symbol = '-'; Color = 'Red'    },
        @{ Name = 'renamed';  Symbol = '>'; Color = 'Cyan'   },
        @{ Name = 'conflict'; Symbol = '!'; Color = 'Red'    }
    )

    $parts = @()
    foreach ($k in $kinds) {
        $n = @($Items | Where-Object { $_.Kind -eq $k.Name }).Count
        if ($n -gt 0) { $parts += "$n $($k.Name)" }
    }

    $summary = $parts -join ', '
    $stagedCount = @($Items | Where-Object { $_.Staged }).Count
    if ($stagedCount -gt 0) { $summary += " ($stagedCount already staged)" }

    Write-Info 'Summary' $summary
    Write-Host ''

    $shown = 0
    foreach ($item in $Items) {
        if ($shown -ge $script:MaxListed) { break }

        $k = $kinds | Where-Object { $_.Name -eq $item.Kind } | Select-Object -First 1
        Write-Host '         ' -NoNewline
        Write-Host $k.Symbol -NoNewline -ForegroundColor $k.Color
        Write-Host " $($item.Path)" -ForegroundColor Gray
        $shown++
    }

    if ($Items.Count -gt $shown) {
        Write-Host "         ... and $($Items.Count - $shown) more" -ForegroundColor DarkGray
    }
}

function Test-SensitiveFile {
    param([Parameter(Mandatory)][string]$FilePath)

    $leaf = [System.IO.Path]::GetFileName($FilePath)

    if ($leaf -match $script:SensitiveAllow) { return $false }

    foreach ($pattern in $script:SensitivePatterns) {
        if ($leaf -match $pattern) { return $true }
    }

    return $false
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

$pathList   = @($Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$hasMessage = -not [string]::IsNullOrWhiteSpace($Message)

if (-not $hasMessage -and -not $Amend) {
    Write-Host ''
    Write-Host '  A commit message is required.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  Usage: $script:CommandName `"Your commit message`"" -ForegroundColor Gray
    Write-Host "  Help:  $script:CommandName -Help" -ForegroundColor Gray
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fatal 'Git was not found. Install Git or check your PATH.'
}

# Locate repository root and git directory.

try {
    $repoRoot = (
        Invoke-Git -GitArgs @('rev-parse', '--show-toplevel') |
        Select-Object -Last 1
    ).ToString().Trim()

    $gitDir = (
        Invoke-Git -GitArgs @('rev-parse', '--absolute-git-dir') |
        Select-Object -Last 1
    ).ToString().Trim()
}
catch {
    Write-Fatal 'The current directory is not inside a Git repository.'
}

# Refuse to run in the middle of another operation.

$operation = Get-InProgressOperation -GitDir $gitDir
if ($operation) {
    Write-Fatal "A $operation is in progress.`nFinish or abort it before using GI."
}

# Resolve current branch.

try {
    $branch = (
        Invoke-Git -GitArgs @('branch', '--show-current') |
        Select-Object -Last 1
    ).ToString().Trim()
}
catch {
    Write-Fatal $_.Exception.Message
}

if ([string]::IsNullOrWhiteSpace($branch)) {
    Write-Fatal 'Detached HEAD detected. Check out a branch before using GI.'
}

# Resolve remote: the branch's configured remote, then origin, then the first remote.

try {
    $remotes = @(
        Invoke-Git -GitArgs @('remote') |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ }
    )
}
catch {
    Write-Fatal $_.Exception.Message
}

$remote = $null

$configured = @(Invoke-Git -GitArgs @('config', '--get', "branch.$branch.remote") -AllowFail)
if ($script:GitExitCode -eq 0 -and $configured.Count -gt 0) {
    $candidate = $configured[0].ToString().Trim()
    if ($remotes -contains $candidate) { $remote = $candidate }
}

if (-not $remote -and ($remotes -contains 'origin')) { $remote = 'origin' }
if (-not $remote -and $remotes.Count -gt 0) { $remote = $remotes[0] }

if (-not $remote -and -not $NoPush) {
    Write-Fatal "No Git remote is configured.`nAdd a remote before pushing, or use -NoPush."
}

# Remote URL (credentials stripped) and upstream tracking branch.

$remoteUrl = ''
if ($remote) {
    $urlLines = @(Invoke-Git -GitArgs @('remote', 'get-url', $remote) -AllowFail)
    if ($script:GitExitCode -eq 0 -and $urlLines.Count -gt 0) {
        $remoteUrl = ($urlLines[0].ToString().Trim()) -replace '://[^@/]+@', '://'
    }
}

$upstream = $null
$upstreamLines = @(
    Invoke-Git -GitArgs @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') -AllowFail
)
if ($script:GitExitCode -eq 0 -and $upstreamLines.Count -gt 0 -and
    -not [string]::IsNullOrWhiteSpace($upstreamLines[0].ToString())) {
    $upstream = $upstreamLines[0].ToString().Trim()
}
$hasUpstream = ($null -ne $upstream)

# Show repository details.

Write-Section 'REPOSITORY'

Write-Info 'Name' (Split-Path $repoRoot -Leaf)
Write-Info 'Branch' $branch

if ($remote) {
    Write-Info 'Remote' $remote
    if ($remoteUrl) { Write-Info 'URL' $remoteUrl }
}
else {
    Write-Info 'Remote' 'none'
}

if ($hasUpstream) {
    Write-Info 'Upstream' $upstream
}
else {
    Write-Info 'Upstream' 'none (will be created on push)'
}

$modes = @()
if ($DryRun)  { $modes += 'dry-run' }
if ($NoPush)  { $modes += 'no-push' }
if ($Amend)   { $modes += 'amend' }
if ($Pull)    { $modes += 'pull' }
if ($Yes)     { $modes += 'yes' }
if ($pathList.Count -gt 0) { $modes += "paths: $($pathList -join ', ')" }
if ($modes.Count -gt 0) { Write-Info 'Options' ($modes -join ' | ') }

# Inspect working tree.

Write-Section 'WORKFLOW'

Write-Status 'Inspecting working tree...' 'INFO'

$statusArgs = @('-c', 'core.quotepath=false', 'status', '--porcelain', '--untracked-files=all')
if ($pathList.Count -gt 0) {
    $statusArgs += '--'
    $statusArgs += $pathList
}

try {
    $statusLines = @(Invoke-Git -GitArgs $statusArgs)
}
catch {
    Write-Fatal $_.Exception.Message
}

$items = @(
    $statusLines |
    ForEach-Object { ConvertFrom-StatusLine -Line $_ } |
    Where-Object { $null -ne $_ }
)

$conflicts = @($items | Where-Object { $_.Kind -eq 'conflict' })
if ($conflicts.Count -gt 0) {
    $list = ($conflicts | ForEach-Object { $_.Path }) -join "`n"
    Write-Fatal "Unresolved merge conflicts detected.`n$list"
}

if ($items.Count -eq 0) {
    if (-not $Amend) {
        Write-Status 'Working tree is clean. Nothing to commit.' 'WARN'
        Write-Host ''
        Write-Host '  No changes were staged, committed, or pushed.' -ForegroundColor Gray
        exit 0
    }

    if (-not $hasMessage) {
        Write-Fatal 'Nothing to amend: no changes and no new message.'
    }

    Write-Status 'Working tree is clean. Only the last commit message will change.' 'INFO'
}
else {
    $entryLabel = if ($items.Count -eq 1) { 'entry' } else { 'entries' }
    Write-Status "$($items.Count) changed file $entryLabel detected." 'OK'

    Write-Section 'PENDING CHANGES'
    Show-ChangeSummary -Items $items
}

# Safety checks: sensitive files and large files.

Write-Section 'CHECKS'

$sensitive = @(
    $items | Where-Object { $_.Kind -ne 'deleted' -and (Test-SensitiveFile -FilePath $_.Path) }
)

$large    = @()
$tooLarge = @()

foreach ($item in $items) {
    if ($item.Kind -eq 'deleted') { continue }

    $fullPath = Join-Path $repoRoot $item.Path
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        $size = (Get-Item -LiteralPath $fullPath -Force).Length

        if ($size -ge $script:LargeBlockBytes) {
            $tooLarge += [pscustomobject]@{ Path = $item.Path; Size = $size }
        }
        elseif ($size -ge $script:LargeWarnBytes) {
            $large += [pscustomobject]@{ Path = $item.Path; Size = $size }
        }
    }
}

if ($sensitive.Count -gt 0) {
    Write-Status "$($sensitive.Count) potentially sensitive file(s) detected:" 'WARN'
    foreach ($s in $sensitive) { Write-Host "         $($s.Path)" -ForegroundColor Yellow }
}

if ($large.Count -gt 0) {
    Write-Status "$($large.Count) large file(s) (over 50 MB) detected:" 'WARN'
    foreach ($l in $large) { Write-Host "         $($l.Path) ($(Format-Size $l.Size))" -ForegroundColor Yellow }
}

if ($tooLarge.Count -gt 0) {
    Write-Status "$($tooLarge.Count) file(s) over 100 MB (GitHub rejects these):" 'FAIL'
    foreach ($l in $tooLarge) { Write-Host "         $($l.Path) ($(Format-Size $l.Size))" -ForegroundColor Red }
}

if ($sensitive.Count -eq 0 -and $large.Count -eq 0 -and $tooLarge.Count -eq 0) {
    Write-Status 'No sensitive or oversized files found.' 'OK'
}

# Commit message checks (warnings only).

if ($hasMessage) {
    $subject = ($Message -split '\r?\n')[0]

    if ($subject.Length -gt $script:SubjectMax) {
        Write-Status "Subject line is $($subject.Length) characters (recommended max $script:SubjectMax)." 'WARN'
    }

    if ($subject -notmatch '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?:\s') {
        Write-Status 'Tip: no conventional prefix (feat:, fix:, docs:, ...). Not enforced.' 'INFO'
    }
}

# Push planning: fetch, ahead/behind, amend checks.

$pushing       = -not $NoPush
$ahead         = 0
$behind        = 0
$alreadyPushed = $false
$needPull      = $false

if ($pushing -and $hasUpstream) {
    if ($DryRun) {
        Write-Status 'Dry-run does not fetch; remote comparison uses the last fetched state.' 'INFO'
    }
    else {
        Write-Status "Fetching $remote..." 'INFO'
        Invoke-Git -GitArgs @('fetch', '--quiet', $remote) -AllowFail | Out-Null

        if ($script:GitExitCode -ne 0) {
            Write-Status 'Fetch failed. The behind-remote check may be out of date.' 'WARN'
        }
    }

    $counts = @(
        Invoke-Git -GitArgs @('rev-list', '--left-right', '--count', 'HEAD...@{u}') -AllowFail
    )

    if ($script:GitExitCode -eq 0 -and $counts.Count -gt 0) {
        $parts = @($counts[0].ToString().Trim() -split '\s+')
        if ($parts.Count -ge 2) {
            $ahead  = [int]$parts[0]
            $behind = [int]$parts[1]
        }
    }
}

if ($Amend) {
    Invoke-Git -GitArgs @('rev-parse', '--verify', '--quiet', 'HEAD') -AllowFail | Out-Null
    if ($script:GitExitCode -ne 0) {
        Write-Fatal 'There is no commit to amend.'
    }

    if ($hasUpstream) {
        $unpushed = @(Invoke-Git -GitArgs @('rev-list', '--count', '@{u}..HEAD') -AllowFail)
        if ($script:GitExitCode -eq 0 -and $unpushed.Count -gt 0 -and [int]$unpushed[0].ToString().Trim() -eq 0) {
            $alreadyPushed = $true
            $pushing = $false
            Write-Status "The last commit is already on $upstream." 'WARN'
            Write-Host '         Amending rewrites history. GI will amend locally and skip the push.' -ForegroundColor Yellow
        }
    }
}

if ($pushing -and $hasUpstream) {
    if ($behind -gt 0) {
        if ($Pull) {
            $needPull = $true
            Write-Status "Behind $upstream by $behind commit(s). Will rebase after committing." 'WARN'
        }
        elseif ($DryRun) {
            Write-Status "Behind $upstream by $behind commit(s). A real run would stop here (use -Pull)." 'WARN'
        }
        else {
            Write-Fatal "Branch is behind $upstream by $behind commit(s).`nRun 'git pull --rebase' first, or re-run with -Pull."
        }
    }
    elseif ($ahead -gt 0) {
        Write-Status "Ahead of $upstream by $ahead commit(s), not behind." 'OK'
    }
    else {
        Write-Status "In sync with $upstream." 'OK'
    }
}

# Dry-run preview ends here.

if ($DryRun) {
    Write-Host ''
    Write-Status 'Dry-run enabled. No changes will be staged or committed.' 'WARN'

    if ($tooLarge.Count -gt 0) {
        Write-Status 'A real run would stop: files over 100 MB are blocked.' 'WARN'
    }

    Write-Host ''
    Write-Host '  Preview complete. No Git changes were made by GI.' -ForegroundColor Yellow
    exit 0
}

# Blocking checks and confirmations.

if ($tooLarge.Count -gt 0) {
    Write-Fatal "Files over 100 MB cannot be pushed to GitHub.`nRemove them, add them to .gitignore, or use Git LFS."
}

Write-Host ''

if ($sensitive.Count -gt 0) {
    if (-not (Confirm-Action 'Stage and commit these sensitive-looking files anyway?')) {
        Write-Host ''
        Write-Host '  Aborted. Nothing was staged, committed, or pushed.' -ForegroundColor Gray
        exit 0
    }
}

if ($large.Count -gt 0) {
    if (-not (Confirm-Action 'Commit these large files anyway?')) {
        Write-Host ''
        Write-Host '  Aborted. Nothing was staged, committed, or pushed.' -ForegroundColor Gray
        exit 0
    }
}

if ($alreadyPushed) {
    if (-not (Confirm-Action 'Amend a commit that is already pushed? (local only, no push)')) {
        Write-Host ''
        Write-Host '  Aborted. Nothing was staged, committed, or pushed.' -ForegroundColor Gray
        exit 0
    }
}

if (-not $Yes) {
    $messageText = if ($hasMessage) { $Message } else { '(keep previous message)' }
    $action = if ($Amend) { 'Amend' } else { 'Commit' }
    $target = if ($pushing) { " and push to $remote/$branch" } else { '' }

    Write-Info 'Message' $messageText

    if (-not (Confirm-Action "${action}${target}?")) {
        Write-Host ''
        Write-Host '  Aborted. Nothing was staged, committed, or pushed.' -ForegroundColor Gray
        exit 0
    }
}

Write-Host ''

# Stage changes, including new files and deletions.

if ($items.Count -gt 0) {
    Write-Status 'Staging changes...' 'INFO'

    $addArgs = @('add', '-A')
    if ($pathList.Count -gt 0) {
        $addArgs += '--'
        $addArgs += $pathList
    }

    try {
        Invoke-Git -GitArgs $addArgs | Out-Null
        Write-Status 'Changes staged successfully.' 'OK'
    }
    catch {
        Write-Fatal $_.Exception.Message
    }
}

# Commit staged changes.

Write-Status $(if ($Amend) { 'Amending commit...' } else { 'Creating commit...' }) 'INFO'

$commitArgs = @('commit')
if ($Amend) { $commitArgs += '--amend' }

if ($hasMessage) {
    $commitArgs += '-m'
    $commitArgs += $Message
}
else {
    $commitArgs += '--no-edit'
}

# With -Path, commit only those paths so unrelated staged work stays out.
if ($pathList.Count -gt 0) {
    $commitArgs += '--'
    $commitArgs += $pathList
}

try {
    Invoke-Git -GitArgs $commitArgs | Out-Null

    $commit = (
        Invoke-Git -GitArgs @('rev-parse', '--short', 'HEAD') |
        Select-Object -Last 1
    ).ToString().Trim()

    Write-Status "Commit $(if ($Amend) { 'amended' } else { 'created' }): $commit" 'OK'
}
catch {
    Write-Fatal $_.Exception.Message
}

# Rebase onto the remote if we were behind and -Pull was given.

if ($needPull) {
    Write-Status "Rebasing onto $upstream..." 'INFO'

    try {
        Invoke-Git -GitArgs @('pull', '--rebase', '--autostash') | Out-Null

        $commit = (
            Invoke-Git -GitArgs @('rev-parse', '--short', 'HEAD') |
            Select-Object -Last 1
        ).ToString().Trim()

        Write-Status "Rebase completed. New HEAD: $commit" 'OK'
    }
    catch {
        Write-Fatal "$($_.Exception.Message)`nYour commit is saved locally.`nResolve conflicts, then run 'git rebase --continue' (or 'git rebase --abort')."
    }
}

# Push current branch, or explain why not.

$pushed     = $false
$pushNote   = ''

if ($NoPush) {
    $pushNote = 'No (-NoPush)'
    Write-Status 'Push skipped (-NoPush).' 'WARN'
}
elseif ($alreadyPushed) {
    $pushNote = 'No (amended commit was already pushed)'
    Write-Status 'Push skipped: the amended commit was already pushed.' 'WARN'
    Write-Host "         To replace it remotely, run 'git push --force-with-lease' yourself." -ForegroundColor DarkGray
}
else {
    Write-Status "Pushing to $remote/$branch..." 'INFO'

    $pushArgs = @('push')
    if (-not $hasUpstream) { $pushArgs += '-u' }
    $pushArgs += $remote
    $pushArgs += $branch

    try {
        $pushOutput = @(Invoke-Git -GitArgs $pushArgs)
        Write-Status 'Push completed successfully.' 'OK'
        Show-GitOutput $pushOutput

        if (-not $hasUpstream) {
            Write-Status "Upstream set to $remote/$branch (new branch)." 'OK'
        }

        $pushed   = $true
        $pushNote = 'Yes'
    }
    catch {
        Write-Fatal "Push failed. Commit $commit is saved locally.`n$($_.Exception.Message)"
    }
}

# Final summary: reached only after a successful commit (and push, if requested).

Write-Section 'SUMMARY'

$finalSubject = (Invoke-Git -GitArgs @('log', '-1', '--format=%s') -AllowFail | Select-Object -First 1)

Write-Info 'Commit' $commit
Write-Info 'Message' "$finalSubject"
Write-Info 'Branch' $(if ($pushed) { "$remote/$branch" } else { $branch })
Write-Info 'Pushed' $pushNote
Write-Info 'Elapsed' ("{0:N1}s" -f $stopwatch.Elapsed.TotalSeconds)

$stat = @(Invoke-Git -GitArgs @('show', '--stat', '--format=', 'HEAD') -AllowFail)
if ($stat.Count -gt 0) {
    Write-Section 'COMMIT STATS'
    Show-GitOutput $stat
}

Write-Host ''
if ($pushed) {
    Write-Rule 'Green'
    Write-Banner 'SUCCESS: Changes committed and pushed.' 'Green'
    Write-Rule 'Green'
}
else {
    Write-Rule 'Yellow'
    Write-Banner 'DONE: Changes committed locally.' 'Yellow'
    Write-Rule 'Yellow'
}
Write-Host ''