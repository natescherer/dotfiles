$Dependencies = @(
    @{Name = "starship"; WinGetId = "Starship.Starship"},
    @{Name = "mise"; WinGetId = "jdx.mise" },
    @{Name = "fakedep"; WinGetId = "fake.dep" }
)

foreach ($Dep in $Dependencies) {
    if ($null -eq (Get-Command $Dep.Name -ErrorAction SilentlyContinue)) {
        Write-Host "Warning: '$($Dep.Name)' is not found. Install it via 'winget install $($Dep.WinGetId)'" -ForegroundColor Yellow
    }
}
