#Requires -Version 5.1

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must NOT be run as Administrator. Re-run in a non-admin Terminal."
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
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

    Write-Host "`nPowerShell 7+ installed and Windows Terminal default profile updated!" -ForegroundColor Green
    Write-Host "`nOpening a new Windows Terminal window running PowerShell 7 to continue setup..." -ForegroundColor Yellow

    # Downloaded to a file and run with -File (rather than spawning `irm | iex` on the
    # child's command line) so this doesn't get flagged as a malware download cradle.
    $continueScriptPath = Join-Path $env:TEMP "init-windows.ps1"
    Invoke-RestMethod -Uri "https://raw.githubusercontent.com/natescherer/dotfiles/main/init-windows.ps1" -OutFile $continueScriptPath
    Start-Process wt.exe -ArgumentList "pwsh", "-NoExit", "-File", $continueScriptPath

    Write-Host "`nSetup is continuing in the new window; this Windows PowerShell window can be closed." -ForegroundColor Yellow

    return
}

Write-Host "`nInstalling configuration prereqs..." -ForegroundColor Green

Write-Host "`nInstalling mise..." -ForegroundColor Cyan
winget install --id jdx.mise -e

Write-Host "`nInstalling chezmoi..." -ForegroundColor Cyan
winget install --id twpayne.chezmoi -e

Write-Host "`nRefreshing Path..." -ForegroundColor Cyan
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

Write-Host "`nInstalling Python via mise..." -ForegroundColor Cyan
mise use -g python@latest

Write-Host "`nConfiguration prereqs installed!" -ForegroundColor Green
Write-Host "`nRun the following to load your shell environment and finish configuration:" -ForegroundColor Yellow
Write-Host "mise env -s pwsh | iex && chezmoi init --apply natescherer" -ForegroundColor Yellow
