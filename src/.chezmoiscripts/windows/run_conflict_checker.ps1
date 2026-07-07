$BadPaths = @(
    "$PSHOME\Profile.ps1",
    "$PSHOME\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\.gitconfig",
    "$env:USERPROFILE\.nanorc"
)

foreach ($Path in $BadPaths) {
    if (Test-Path $Path) {
        Write-Host -Object "A file was found at '$Path' which might conflict with chezmoi config. Please review and delete this file!" -ForegroundColor Red
    }
}

# This is a special check for coreutils
$CoreUtilsCheckPath = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"

if (((Get-Content -Path $CoreUtilsCheckPath)[1] -notlike '*DO NOT MODIFY -- coreutils*') -and ((Get-Content -Path $CoreUtilsCheckPath)[-1] -notlike '*DO NOT MODIFY -- coreutils*')) {
    Write-Output "File at '$Path' appears to contain more than just coreutils config. Remove anything not coreutils-related."
}
