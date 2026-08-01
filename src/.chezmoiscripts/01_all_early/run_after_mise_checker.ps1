# Checks whether any tools declared in mise's config (src/dot_config/mise/config.toml,
# applied by chezmoi before any run_after_ script executes) are missing, and runs `mise install`
# to install them if so. Checking first via `mise ls --missing` keeps the common no-op case quiet
# and fast instead of invoking a full `mise install` on every apply.
#
# Why is this in a folder called '01_all_early'? Directory order is what determines script
# execution order, and 01 is lower than every OS-specific folder (10-linux, 20-linux_and_macos,
# 30-macos, 40-windows, 41-windows_late, 99-all_late), so mise-managed tools get installed as
# early as possible for anything later in the apply run that wants them.
#
# PowerShell, not Python: this script's job is making sure mise-managed tools -- which can
# include Python itself, see config.toml -- are installed, so it can't depend on one of those
# tools already being present just to run. pwsh is a documented prerequisite installed before
# chezmoi itself ever runs (see README), so it's safe to assume here; a mise-installed
# interpreter wouldn't be.
#
# This script never exits non-zero: a failing run_after_ script aborts the rest of the apply run,
# and on a fresh machine mise itself isn't installed until winget-configure runs later in this
# same apply. It warns and defers to the next apply instead.

# Installs from earlier chezmoi runs (or a winget install done in another window) write PATH
# changes straight to the registry, but this process inherits whatever PATH chezmoi's own process
# was started with. Rebuilding PATH from the registry (Machine + User, same precedence Windows
# itself uses) picks up a mise that the launching shell hasn't seen yet.
$MachinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$UserPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$MachinePath;$UserPath"

$Mise = Get-Command mise -ErrorAction SilentlyContinue
if (-not $Mise) {
    Write-Host "Warning: 'mise' is not found; skipping mise tool install. It should be installed later in this apply run - re-run 'chezmoi apply' afterward to install mise-managed tools.`n" -ForegroundColor Yellow
    exit 0
}

$Missing = & $Mise.Source ls --missing 2>$null
$MissingStatus = $LASTEXITCODE

if ($MissingStatus -eq 0 -and [string]::IsNullOrWhiteSpace(($Missing -join "`n"))) {
    exit 0
}

if ($MissingStatus -ne 0) {
    Write-Host "Warning: 'mise ls --missing' failed; running 'mise install' anyway.`n" -ForegroundColor Yellow
} else {
    Write-Host "mise tools missing; running 'mise install'...`n" -ForegroundColor Cyan
    $Missing | Write-Host
}

& $Mise.Source install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: 'mise install' exited with code $LASTEXITCODE. It will be retried on the next 'chezmoi apply'.`n" -ForegroundColor Yellow
}

exit 0
