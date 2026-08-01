#Requires -Version 7

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must NOT be run as Administrator. Re-run in a non-admin Terminal."
}

Write-Host "`nInstalling configuration prereqs..." -ForegroundColor BrightGreen

Write-Host "`nInstalling mise..." -ForegroundColor Cyan
winget install --id jdx.mise -e

Write-Host "`nInstalling chezmoi..." -ForegroundColor Cyan
winget install --id twpayne.chezmoi -e

Write-Host "`nRefreshing Path..." -ForegroundColor Cyan
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

Write-Host "`nInstalling Python via mise..." -ForegroundColor Cyan
mise use -g python@latest

Write-Host "`nConfiguration prereqs installed!" -ForegroundColor BrightGreen
Write-Host "`nRun the following to load your shell environment and finish configuration:" -ForegroundColor Yellow
Write-Host "    mise env -s pwsh | iex && chezmoi init --apply natescherer" -ForegroundColor Yellow
