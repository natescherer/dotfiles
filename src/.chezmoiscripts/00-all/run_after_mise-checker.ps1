# Checks whether any tools declared in mise's config (src/dot_config/mise/config.toml,
# applied by chezmoi before any run_after_ script executes) are missing, and runs `mise install`
# to install them if so. Checking first via `mise ls --missing` keeps the common no-op case quiet
# and fast instead of invoking a full `mise install` on every apply.
#
# Why is this in a folder called '00-all'? Directory order is what determines script
# execution order, and 00 is lower than every OS-specific folder (10-linux, 20-linux-and-macos,
# 30-macos, 40-windows, 41-windows, 49-windows, 90-all), so mise-managed tools get installed as
# early as possible for anything later in the apply run that wants them.
#
# PowerShell, not Python: this script's job is making sure mise-managed tools -- which can
# include Python itself, see config.toml -- are installed, so it can't depend on one of those
# tools already being present just to run. pwsh is a documented prerequisite installed before
# chezmoi itself ever runs (see README), so it's safe to assume here; a mise-installed
# interpreter wouldn't be.
#
# mise itself is also a documented prerequisite (see README), installed before `chezmoi init
# --apply` is ever run for the first time -- so a missing mise, or a failed `mise install`, is a
# real environment problem rather than a bootstrapping race. This script exits non-zero in those
# cases, which aborts the rest of the apply run.

# Installs from earlier chezmoi runs (or a winget install done in another window) write PATH
# changes straight to the registry, but this process inherits whatever PATH chezmoi's own process
# was started with. Rebuilding PATH from the registry (Machine + User, same precedence Windows
# itself uses) picks up a mise that the launching shell hasn't seen yet.
$MachinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$UserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$MachinePath;$UserPath"

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    Write-Error "'mise' is not found on PATH. It is a required prerequisite (see README) and must be installed before running 'chezmoi apply'."
    exit 1
}

$Missing = mise ls --missing 2>$null
$MissingStatus = $LASTEXITCODE

if ($MissingStatus -eq 0 -and [string]::IsNullOrWhiteSpace(($Missing -join "`n"))) {
    exit 0
}

if ($MissingStatus -ne 0) {
    Write-Host "Warning: 'mise ls --missing' failed; running 'mise install' anyway.`n" -ForegroundColor Yellow
} else {
    Write-Host "`nmise tools missing; running 'mise install'..." -ForegroundColor Cyan
}

mise install
if ($LASTEXITCODE -ne 0) {
    Write-Error "'mise install' exited with code $LASTEXITCODE."
    exit $LASTEXITCODE
}

exit 0
