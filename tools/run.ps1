param(
    [Parameter(Mandatory)][string]$Name,
    [string]$In = 'input.txt',
    [switch]$Dbg
)

$src = if ($Name.EndsWith('.cpp')) { $Name } else { "$Name.cpp" }
if (-not (Test-Path $src)) { Write-Error "$src not found"; exit 1 }

$exe = [IO.Path]::ChangeExtension($src, 'exe')
Get-Process ([IO.Path]::GetFileNameWithoutExtension($src)) -ErrorAction SilentlyContinue | Stop-Process -Force

$flags = @('-O2', '-std=c++17', '-Wall', '-Wextra')
if ($Dbg) { $flags += '-DLOCAL' }

$log = & g++ @flags $src -o $exe 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { $log; exit $LASTEXITCODE }

if (Test-Path $In) { Get-Content $In | & (Resolve-Path $exe) } else { & (Resolve-Path $exe) }