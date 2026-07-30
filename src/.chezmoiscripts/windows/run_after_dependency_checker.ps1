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
