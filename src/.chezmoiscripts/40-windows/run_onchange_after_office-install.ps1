#Requires -Version 7.0

# Installs Microsoft 365 via the Office Deployment Tool (ODT) directly, instead of winget's
# Microsoft.Office package (see the comment above it in
# AppData/Local/winget-configuration-chezmoi/2.apps.ep.winget for why). ODT drives the same
# officecdn.microsoft.com setup.exe winget uses, just without a pinned hash to go stale.
#
# Product ID is O365HomePremRetail -- the (unrebranded) product ID for Microsoft 365 Family/
# Personal. It's not in Microsoft's headline ODT documentation, which focuses on tenant/volume-
# licensed plans, but is in their own supported-product-ID list and is the documented way to
# deploy a consumer subscription with ODT:
# https://learn.microsoft.com/en-us/troubleshoot/microsoft-365-apps/office-suite-issues/product-ids-supported-office-deployment-click-to-run
#
# This only gets Office onto disk -- Family/Personal licenses are tied to a Microsoft Account, not
# a device or tenant, so activation still needs an interactive sign-in the first time an Office
# app is launched, same as any other install method.

$ErrorActionPreference = 'Stop'

# Click-to-Run setup registers its configuration under this key regardless of which product ID
# provisioned it -- reused as the "already installed" check so reruns (e.g. after editing this
# script) don't reinstall over a working install.
$ClickToRunKey = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
if (Test-Path $ClickToRunKey) {
  Write-Host "`nMicrosoft Office is already installed (Click-to-Run configuration found) -- skipping." -ForegroundColor DarkGray
  exit 0
}

Write-Host "`nInstalling Microsoft 365 via the Office Deployment Tool..." -ForegroundColor Green
Write-Host "This downloads and streams the full Office install -- it can take a while, and will show a UAC prompt.`n" -ForegroundColor Green

$WorkDir = Join-Path $env:LOCALAPPDATA 'office-deployment-tool'
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

$ConfigPath = Join-Path $WorkDir 'configuration.xml'
@'
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365HomePremRetail">
      <Language ID="en-us" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@ | Set-Content -Path $ConfigPath -Encoding utf8

# This is the same setup.exe winget's Microsoft.Office package downloads -- ODT is just this
# bootstrapper driven directly, with no hash pinned against it.
$SetupPath = Join-Path $WorkDir 'setup.exe'
Write-Host "Downloading Office Deployment Tool bootstrapper..." -ForegroundColor Cyan
Invoke-WebRequest -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile $SetupPath

# Needs elevation -- writes to Program Files and registers the ClickToRun service. Runs as its own
# elevated process (same pattern as the ConfigurationProcessorPath admin setting in
# run_onchange_after_winget-configure.ps1.tmpl) rather than requiring this whole script to run
# elevated.
$Proc = Start-Process -FilePath $SetupPath -ArgumentList @('/configure', $ConfigPath) -Verb RunAs -Wait -PassThru
if ($Proc.ExitCode -ne 0) {
  throw "Office Deployment Tool exited with code $($Proc.ExitCode). See %TEMP% for its own logs (SetupExe*.log / Microsoft Office Setup*.log)."
}

Write-Host "Microsoft 365 installed. Sign in with the Microsoft Account holding the Family/Personal subscription the first time you open an Office app to activate it." -ForegroundColor Green
