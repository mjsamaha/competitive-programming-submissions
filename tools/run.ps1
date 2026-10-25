param(
    [Parameter(Mandatory)][string]$Name,
    [string]$In = 'input.txt',
    [switch]$Dbg
)

$src = if ($Name.EndsWith('.cpp')) { $Name } else { "$Name.cpp" }
if (-not (Test-Path $src)) { Write-Error "$src not found"; exit 1 }

$exe = [IO.Path]::ChangeExtension($src, 'exe')
Get-Process ([IO.Path]::GetFileNameWithoutExtension($src)) -ErrorAction SilentlyContinue | Stop-Process -Force

# 256 MB stack to match judges (Windows default is ~1 MB).
$flags = @('-O2', '-std=c++17', '-Wall', '-Wextra', '-Wl,--stack,268435456')
if ($Dbg) { $flags += '-DLOCAL' }

# Build. Warnings are shown even when the build succeeds.
$log = & g++ @flags $src -o $exe 2>&1 | ForEach-Object { "$_" }
$buildCode = $LASTEXITCODE
if ($log) { $log | ForEach-Object { Write-Host $_ } }
if ($buildCode -ne 0) { exit $buildCode }

# Resolve input. An explicit -In that doesn't exist is an error; the default is optional.
$inPath = $null
if (Test-Path $In) {
    $inPath = (Resolve-Path $In).Path
}
elseif ($PSBoundParameters.ContainsKey('In')) {
    Write-Error "$In not found"
    exit 1
}
else {
    Write-Host "no $In found, reading from console" -ForegroundColor DarkGray
}

# Run, feeding the input file as raw bytes (same as `exe < file`).
$psi = [Diagnostics.ProcessStartInfo]::new((Resolve-Path $exe).Path)
$psi.UseShellExecute = $false
$psi.WorkingDirectory = (Get-Location).Path
$psi.RedirectStandardInput = ($null -ne $inPath)

$sw = [Diagnostics.Stopwatch]::StartNew()
$proc = [Diagnostics.Process]::Start($psi)

if ($null -ne $inPath) {
    try {
        $bytes = [IO.File]::ReadAllBytes($inPath)
        $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    }
    catch {
        # The program exited before reading all input; its exit code is reported below.
    }
    finally {
        try { $proc.StandardInput.Close() } catch { }
    }
}

$proc.WaitForExit()
$sw.Stop()
$code = $proc.ExitCode

# Report.
# CPU time excludes time spent waiting on console input. Wall time is only
# meaningful when stdin comes from a file (no human typing delay).
$time = 'cpu {0:N3}s' -f $proc.TotalProcessorTime.TotalSeconds
if ($null -ne $inPath) { $time += '  wall {0:N3}s' -f $sw.Elapsed.TotalSeconds }

$reasons = @{
    '0xC0000005' = 'segfault (access violation)'
    '0xC00000FD' = 'stack overflow'
    '0xC0000094' = 'integer divide by zero'
    '0xC000001D' = 'illegal instruction'
    '0xC0000374' = 'heap corruption'
    '0xC0000409' = 'stack buffer overrun / fast fail'
    '0xC000013A' = 'interrupted (Ctrl+C)'
}

Write-Host ''
if ($code -eq 0) {
    Write-Host "[OK] $time" -ForegroundColor Green
}
else {
    $hex = '0x{0:X8}' -f $code
    $why = if ($reasons.ContainsKey($hex)) { $reasons[$hex] }
           elseif ($code -eq 3) { 'abort (failed assert, uncaught exception, or _GLIBCXX_DEBUG check)' }
           else { 'nonzero exit' }

    Write-Host "[RE] $time  exit $code ($hex): $why" -ForegroundColor Red
}

exit $code