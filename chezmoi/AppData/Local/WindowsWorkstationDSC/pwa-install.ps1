#Requires -Version 7.0

# Installs a list of PWAs as standalone apps with PWAsForFirefox, which runs them on a separate
# Firefox runtime with Widevine DRM. Every app goes into one dedicated PWAsForFirefox profile, so
# the DRM component is set up once; apps in that profile that are no longer listed get uninstalled.
# Idempotent: apps are matched to list entries by URL, and only missing ones are installed.
#
# A standalone, self-contained script: no chezmoi-specific assumptions. It's installed at a stable
# path (%LOCALAPPDATA%\WindowsWorkstationDSC\pwa-install.ps1) and reads the list from a JSON file,
# an array of { url, name?, icon_url? } objects. This is also the seed of a planned standalone
# WindowsWorkstationDSC DSC module.
#
# Exits 1 when PWAsForFirefox is missing or any app fails, so a caller can retry.

param(
  # JSON array of PWAs: url (required), name and icon_url (optional)
  [string] $PwasPath = (Join-Path $PSScriptRoot 'pwas.json'),
  # PWAsForFirefox profile that holds these apps (and only these apps)
  [string] $ProfileName = 'pwas'
)

$ErrorActionPreference = 'Stop'

Write-Host "`nInstalling PWAs..." -ForegroundColor Green

$UserDataDir = Join-Path $env:APPDATA 'FirefoxPWA'
$ConfigPath = Join-Path $UserDataDir 'config.json'
$RuntimeExe = Join-Path $UserDataDir 'runtime\firefox.exe'
# Some sites serve a stripped page (or no <link> tags) to unrecognized clients
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0'

function Invoke-FirefoxPwa {
  $Output = & firefoxpwa @args 2>&1 | Out-String
  $Output = $Output -replace "`e\[[0-9;]*m", ''
  if ($LASTEXITCODE -ne 0) {
    throw "firefoxpwa $($args -join ' ') failed (exit $LASTEXITCODE):`n$Output"
  }
  $Output
}

# PWAsForFirefox's own state: profiles (with their site IDs) and sites (with their config).
function Get-FirefoxPwaConfig {
  if (Test-Path $ConfigPath) {
    return Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json -AsHashtable
  }
  @{ profiles = @{}; sites = @{} }
}

# PWAsForFirefox stores URLs normalized (lowercase host, trailing slash on a bare origin).
function ConvertTo-UrlKey {
  param([string] $Url)
  ([uri]$Url).AbsoluteUri.TrimEnd('/').ToLowerInvariant()
}

# Finds the site's manifest the way the browser does: a <link rel="manifest"> in the page. Sites
# without one get a minimal manifest as a data: URL, which the CLI accepts with --document-url.
function Resolve-SiteManifest {
  param([string] $Url, [string] $Name)

  # Best-effort: bot checks (e.g. Cloudflare) can block a scripted fetch, which just means no
  # manifest or icon is found here; the app itself loads the page in a real browser engine.
  $Html = try {
    (Invoke-WebRequest -Uri $Url -UserAgent $UserAgent -SkipHttpErrorCheck).Content
  }
  catch {
    ''
  }
  $Links = [regex]::Matches($Html, '<link\b[^>]*>', 'IgnoreCase').Value

  $ManifestLink = $Links | Where-Object { $_ -match 'rel=["'']?manifest\b' } | Select-Object -First 1
  if ($ManifestLink -and $ManifestLink -match 'href=["'']([^"'']+)') {
    return @{ ManifestUrl = [uri]::new([uri]$Url, $Matches[1]).AbsoluteUri; IconUrl = $null }
  }

  # The largest icon the page declares. sizes="NxN" gives the size; an unsized apple-touch-icon is
  # conventionally 180x180; other unsized icons (usually favicon.ico) rank last.
  $Icon = $Links | Where-Object { $_ -match 'rel=["'']?[^"''>]*icon' } | ForEach-Object {
    if ($_ -notmatch 'href=["'']([^"'']+)') { return }
    $Href = $Matches[1]
    $Size = if ($_ -match 'sizes=["'']?(\d+)x') { [int]$Matches[1] } elseif ($_ -match 'apple-touch-icon') { 180 } else { 0 }
    [pscustomobject]@{ Href = $Href; Size = $Size }
  } | Sort-Object -Property Size -Descending -Stable | Select-Object -First 1
  $IconUrl = if ($Icon) {
    [uri]::new([uri]$Url, $Icon.Href).AbsoluteUri
  }
  else {
    [uri]::new([uri]$Url, '/favicon.ico').AbsoluteUri
  }

  $Manifest = @{
    name      = if ($Name) { $Name } else { ([uri]$Url).Host }
    start_url = $Url
    scope     = $Url
    display   = 'standalone'
  } | ConvertTo-Json -Compress
  $Encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Manifest))
  @{ ManifestUrl = "data:application/manifest+json;base64,$Encoded"; IconUrl = $IconUrl }
}

if (-not (Get-Command firefoxpwa -ErrorAction SilentlyContinue)) {
  Write-Host "Warning: PWAsForFirefox (firefoxpwa) isn't installed; skipping PWAs. Install it with 'winget install --id filips.FirefoxPWA --exact', then rerun." -ForegroundColor Yellow
  exit 1
}

$Pwas = @(Get-Content -Raw -Path $PwasPath | ConvertFrom-Json)

if (-not (Test-Path $RuntimeExe)) {
  Write-Host "Installing the PWAsForFirefox runtime..." -ForegroundColor Cyan
  Invoke-FirefoxPwa runtime install | Out-Null
}

$Config = Get-FirefoxPwaConfig
$ProfileId = ($Config.profiles.Values | Where-Object { $_.name -eq $ProfileName } | Select-Object -First 1).ulid
if (-not $ProfileId) {
  Write-Host "Creating PWAsForFirefox profile '$ProfileName'..." -ForegroundColor Cyan
  $Output = Invoke-FirefoxPwa profile create --name $ProfileName --description 'PWAs managed by pwa-install.ps1'
  if ($Output -notmatch 'Profile created: ([0-9A-Z]{26})') { throw "Couldn't find the profile ID in:`n$Output" }
  $ProfileId = $Matches[1]
  $Config = Get-FirefoxPwaConfig
}

# URL key -> site ID, for apps already in the profile
$Installed = @{}
foreach ($SiteId in $Config.profiles[$ProfileId].sites) {
  $Installed[(ConvertTo-UrlKey $Config.sites[$SiteId].config.document_url)] = $SiteId
}
$Wanted = @($Pwas | ForEach-Object { ConvertTo-UrlKey $_.url })

$Results = @(foreach ($Pwa in $Pwas) {
  if ($Installed.ContainsKey((ConvertTo-UrlKey $Pwa.url))) {
    continue
  }

  Write-Host "Installing $($Pwa.url)..." -ForegroundColor Cyan
  try {
    $Resolved = Resolve-SiteManifest -Url $Pwa.url -Name $Pwa.name
    $InstallArgs = @('site', 'install', $Resolved.ManifestUrl, '--document-url', $Pwa.url, '--profile', $ProfileId)
    if ($Pwa.name) { $InstallArgs += '--name', $Pwa.name }
    $IconUrl = if ($Pwa.icon_url) { $Pwa.icon_url } else { $Resolved.IconUrl }
    if ($IconUrl) { $InstallArgs += '--icon-url', $IconUrl }
    Invoke-FirefoxPwa @InstallArgs | Out-Null
    [pscustomobject]@{ App = $Pwa.url; Result = 'installed' }
  }
  catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    [pscustomobject]@{ App = $Pwa.url; Result = 'FAILED' }
  }
})

$Results += @(foreach ($UrlKey in $Installed.Keys) {
  if ($UrlKey -in $Wanted) {
    continue
  }

  $SiteId = $Installed[$UrlKey]
  Write-Host "Uninstalling $UrlKey (no longer listed)..." -ForegroundColor Cyan
  try {
    Invoke-FirefoxPwa site uninstall $SiteId --quiet | Out-Null
    [pscustomobject]@{ App = $UrlKey; Result = 'uninstalled' }
  }
  catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    [pscustomobject]@{ App = $UrlKey; Result = 'FAILED' }
  }
})

if (-not $Results) {
  Write-Host "All PWAs are already installed." -ForegroundColor DarkGray
  exit 0
}

$Results | Format-Table -AutoSize | Out-Host
if ($Results | Where-Object { $_.Result -eq 'FAILED' }) {
  exit 1
}
