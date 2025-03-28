$BadPaths = @(
    "$PSHOME\Profile.ps1",
    "$PSHOME\Microsoft.PowerShell_profile.ps1",
    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
)

foreach ($Path in $BadPaths) {
    if (Test-Path $Path) {
        Write-Host -Object "A file was found at '$Path' which might conflict with chezmoi config. Please review and delete this file!" -ForegroundColor Red
    }
}