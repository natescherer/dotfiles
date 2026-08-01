#Requires -Version 5.1

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator."
}

Write-Host "`nEnsuring Microsoft.AppInstaller is up-to-date..." -ForegroundColor Green

winget settings --enable BypassCertificatePinningForMicrosoftStore
winget upgrade Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements
winget settings --disable BypassCertificatePinningForMicrosoftStore
winget source reset --force

Write-Host "`nMicrosoft.AppInstaller updated! Continue with  init-windows2.ps1 in a non-admin Terminal." -ForegroundColor Green
