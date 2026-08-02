#Requires -Version 5.1

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must NOT be run as Administrator. Re-run in a non-admin Terminal."
}

Write-Host "`nInstalling PowerShell 7+..." -ForegroundColor Green

winget install --id Microsoft.PowerShell --source winget --installer-type wix

Write-Host "`nSetting Windows Terminal default profile to PowerShell..." -ForegroundColor Green

# Well-known GUID Windows Terminal assigns to the generated PowerShell 7 (pwsh) profile.
$pwshProfileGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"

$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (-not (Test-Path $settingsPath)) {
    Write-Host "`nCould not find Windows Terminal settings.json. Skipping default profile change." -ForegroundColor Yellow
}
else {
    $settingsContent = Get-Content -Path $settingsPath -Raw

    if ($settingsContent -match '"defaultProfile"\s*:\s*"[^"]*"') {
        $settingsContent = $settingsContent -replace '"defaultProfile"\s*:\s*"[^"]*"', "`"defaultProfile`": `"$pwshProfileGuid`""
    }
    else {
        $settingsContent = $settingsContent -replace '\{', "{`n    `"defaultProfile`": `"$pwshProfileGuid`",", 1
    }

    Set-Content -Path $settingsPath -Value $settingsContent -NoNewline
}

Write-Host "`nPowerShell 7+ installed and Windows Terminal default profile updated!." -ForegroundColor Green
Write-Host "`nClose and reopen Windows Terminal, then run the following:" -ForegroundColor Yellow
Write-Host "irm https://raw.githubusercontent.com/natescherer/dotfiles/main/init-windows2.ps1 | iex" -ForegroundColor Yellow
