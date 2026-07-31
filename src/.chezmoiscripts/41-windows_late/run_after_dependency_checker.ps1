#Requires -Version 7.0

# Why is this in a folder called '41-windows_late' instead of '40-windows' with the other Windows
# scripts? Directory order is what determines script execution order, and this needs to run after
# run_onchange_after_winget-configure.ps1.tmpl (in 40-windows/) -- winget configure is what actually
# installs mise/starship/coreutils, so checking for them beforehand would just warn about tools that
# are about to be installed later in the same apply run.

# Being ordered after winget-configure isn't enough on its own: installers write PATH changes to
# the registry, but this script's process still inherits whatever PATH chezmoi's own process had
# at its own startup (env vars never propagate from a child process backward into an
# already-running parent, or forward into a sibling that already branched off it) -- so a tool
# installed moments ago in this same apply run is genuinely on PATH per the registry, just not
# yet visible to this process's in-memory copy. Rebuilding $env:Path from the registry (Machine +
# User, same precedence Windows itself uses) picks up anything installed earlier in this run.
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

$Dependencies = @(
    @{Name = "grep"; WinGetId = "Microsoft.Coreutils"},
    @{Name = "starship"; WinGetId = "Starship.Starship"},
    @{Name = "mise"; WinGetId = "jdx.mise" }
)

foreach ($Dep in $Dependencies) {
    if ($null -eq (Get-Command $Dep.Name -ErrorAction SilentlyContinue)) {
        Write-Host "Warning: '$($Dep.Name)' is not found. Install it via 'winget install $($Dep.WinGetId)'" -ForegroundColor Yellow
    }
}

# mise older than v2026.7.15 has a bug with its pwsh profile that
# interacts badly with chezmoi
$MiseMinVersion = [version]"2026.7.15"
if (Get-Command mise -ErrorAction SilentlyContinue) {
    $MiseVersionLine = (mise --version 2>$null | Select-Object -First 1)
    if ($MiseVersionLine -match '^(\d+\.\d+\.\d+)') {
        if ([version]$Matches[1] -lt $MiseMinVersion) {
            Write-Host "Warning: mise $($Matches[1]) is older than $MiseMinVersion, which fixes a pwsh profile issue. Run 'mise self-update' or 'winget upgrade jdx.mise'." -ForegroundColor Yellow
        }
    }
}
