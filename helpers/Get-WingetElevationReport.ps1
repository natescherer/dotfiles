#Requires -Version 7.0

# Reports which Microsoft.WinGet/Package resources in a *.configuration.winget file actually
# require elevation to install, based on the real upstream winget-pkgs manifest
#
# For each winget-sourced package this looks up the installed source's latest version (`winget
# show`, local/offline) and fetches that version's installer manifest directly from
# raw.githubusercontent.com/microsoft/winget-pkgs (no GitHub API/auth needed, so no rate limit
# beyond the CDN's own). It reads that manifest's Scope/ElevationRequirement fields rather than
# guessing from installer type, since those are the fields winget itself uses to decide.
#
# Usage:
#   ./helpers/Get-WingetElevationReport.ps1 -Path path/to/configuration.winget

param(
  [string]$Path
)

$ResolvedPath = Resolve-Path -Path $Path -ErrorAction Stop

# Line-based, not a real YAML parser -- matches the same lightweight approach the repo's other
# winget scripts use (run_onchange_after_winget-configure.ps1.tmpl) rather than pulling in a
# powershell-yaml dependency for a handful of predictable, flat fields.
function Get-WingetPackageResources {
  param([string]$FilePath)

  $Resources = [System.Collections.Generic.List[PSCustomObject]]::new()
  $Current = $null

  function Flush {
    if ($null -ne $Current -and $Current.Type -eq 'Microsoft.WinGet/Package') {
      $Resources.Add([PSCustomObject]@{
        Name            = $Current.Name
        Id              = $Current.Id
        Source          = $Current.Source
        SecurityContext = $($Current.SecurityContext ? $Current.SecurityContext : 'default')
      })
    }
  }

  foreach ($Line in Get-Content -Path $FilePath) {
    if ($Line -match '^\s*-\s*type:\s*(\S+)\s*$') {
      Flush
      $Current = [PSCustomObject]@{ Type = $Matches[1]; Name = $null; Id = $null; Source = $null; SecurityContext = $null }
      continue
    }
    if ($null -eq $Current) { continue }
    if ($null -eq $Current.Name -and $Line -match '^\s*name:\s*(.+?)\s*$') { $Current.Name = $Matches[1]; continue }
    if ($Line -match '^\s*securityContext:\s*(\S+)\s*$') { $Current.SecurityContext = $Matches[1]; continue }
    if ($Line -match '^\s*id:\s*(.+?)\s*$') { $Current.Id = $Matches[1]; continue }
    if ($Line -match '^\s*source:\s*(\S+)\s*$') { $Current.Source = $Matches[1]; continue }
  }
  Flush

  return $Resources
}

function Get-WingetPackageVersion {
  param([string]$Id)
  $Output = & winget show --id $Id --source winget --exact --accept-source-agreements 2>$null
  foreach ($Line in $Output) {
    if ($Line -match '^Version:\s*(.+)$') { return $Matches[1].Trim() }
  }
  return $null
}

# winget-pkgs lays manifests out as manifests/<lowercase first letter>/<Id split on '.', one
# directory per segment>/<version>/<Id>.installer.yaml -- e.g. AgileBits.1Password 8.12.30.21 ->
# manifests/a/AgileBits/1Password/8.12.30.21/AgileBits.1Password.installer.yaml.
function Get-WingetManifestElevation {
  param([string]$Id, [string]$Version)

  $Segments = $Id -split '\.'
  $FirstLetter = $Segments[0].Substring(0, 1).ToLowerInvariant()
  $IdPath = $Segments -join '/'
  $Url = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/$FirstLetter/$IdPath/$Version/$Id.installer.yaml"

  try {
    $Content = (Invoke-WebRequest -Uri $Url -ErrorAction Stop).Content
  } catch {
    return [PSCustomObject]@{ Category = 'Unknown'; Detail = "manifest fetch failed: $($_.Exception.Message)" }
  }

  $Scopes = [System.Collections.Generic.HashSet[string]]::new()
  $ElevationRequirements = [System.Collections.Generic.HashSet[string]]::new()
  foreach ($Line in ($Content -split "`n")) {
    if ($Line -match '^\s*Scope:\s*(\S+)') { [void]$Scopes.Add($Matches[1]) }
    if ($Line -match '^\s*ElevationRequirement:\s*(\S+)') { [void]$ElevationRequirements.Add($Matches[1]) }
  }
  $ScopeList = @($Scopes) -join ', '
  $ElevList = @($ElevationRequirements) -join ', '
  $Detail = "Scope: $($ScopeList ? $ScopeList : '(none)'); ElevationRequirement: $($ElevList ? $ElevList : '(none)')"

  # Priority mirrors what actually determines whether winget must launch elevated: an explicit
  # elevationRequired always wins; elevatesSelf means the installer prompts its own UAC so winget
  # itself doesn't need to be elevated even at machine scope; a machine-only installer with neither
  # flag has no other way to land at machine scope than winget running elevated; a mix of scopes is
  # genuinely ambiguous since winget's default (no --scope passed) selection between them isn't
  # something this script can predict from the manifest alone.
  if ($ElevationRequirements.Contains('elevationRequired')) {
    return [PSCustomObject]@{ Category = 'Elevation required'; Detail = $Detail }
  }
  if ($ElevationRequirements.Contains('elevatesSelf')) {
    return [PSCustomObject]@{ Category = 'Self-elevating (installer prompts its own UAC)'; Detail = $Detail }
  }
  if ($Scopes.Contains('machine') -and -not $Scopes.Contains('user')) {
    return [PSCustomObject]@{ Category = 'Elevation required'; Detail = $Detail }
  }
  if ($Scopes.Contains('machine') -and $Scopes.Contains('user')) {
    return [PSCustomObject]@{ Category = 'Mixed (user + machine variants available)'; Detail = $Detail }
  }
  if ($Scopes.Count -eq 0 -and $ElevationRequirements.Count -eq 0) {
    return [PSCustomObject]@{ Category = 'Unknown'; Detail = $Detail }
  }
  return [PSCustomObject]@{ Category = 'No elevation needed'; Detail = $Detail }
}

$Packages = Get-WingetPackageResources -FilePath $ResolvedPath
if ($Packages.Count -eq 0) {
  Write-Host "No Microsoft.WinGet/Package resources found in $ResolvedPath" -ForegroundColor Yellow
  exit 0
}

$Report = [System.Collections.Generic.List[PSCustomObject]]::new()
$i = 0
foreach ($Package in $Packages) {
  $i++
  Write-Host "[$i/$($Packages.Count)] Checking $($Package.Name) ($($Package.Id))..." -ForegroundColor Cyan

  if ($Package.Source -eq 'msstore') {
    $Category = 'No elevation needed'
    $Detail = 'Microsoft Store app -- always installs per-user'
  } elseif ($Package.Source -eq 'winget') {
    $Version = Get-WingetPackageVersion -Id $Package.Id
    if (-not $Version) {
      $Category = 'Unknown'
      $Detail = 'winget show returned no version (package not found on this machine''s winget source)'
    } else {
      $Result = Get-WingetManifestElevation -Id $Package.Id -Version $Version
      $Category = $Result.Category
      $Detail = $Result.Detail
    }
  } else {
    $Category = 'Unknown'
    $Detail = "unrecognized source '$($Package.Source)'"
  }

  $Report.Add([PSCustomObject]@{
    Name              = $Package.Name
    Id                = $Package.Id
    Declared          = $Package.SecurityContext
    ActualElevation   = $Category
    Detail            = $Detail
  })
}

Write-Host ""

# Only packages worth a second look: where the manifest gives a definite answer that disagrees
# with what the config declares, or where it doesn't give a definite answer at all (Mixed/Unknown
# -- there's no single manifest verdict to compare against). Everything else is already correct
# and would just be noise.
$Flagged = $Report | Where-Object {
  $NeedsElevation = switch ($_.ActualElevation) {
    'Elevation required' { $true }
    'No elevation needed' { $false }
    # Self-elevating installers still pop their own UAC prompt -- declaring elevated here too
    # means winget configure is already elevated when that happens, so the user is only prompted
    # once instead of twice.
    'Self-elevating (installer prompts its own UAC)' { $true }
    default { $null } # Mixed (user + machine variants available) / Unknown -- indeterminate
  }
  $DeclaredElevated = ($_.Declared -eq 'elevated')
  ($null -eq $NeedsElevation) -or ($NeedsElevation -ne $DeclaredElevated)
}

if ($Flagged.Count -eq 0) {
  Write-Host "All $($Report.Count) packages' declared securityContext matches their actual elevation requirement." -ForegroundColor Green
} else {
  Write-Host "Declared securityContext disagrees with (or can't be confirmed against) the real manifest:" -ForegroundColor Yellow
  $Flagged | Format-Table -Property Name, Id, Declared, ActualElevation, Detail -AutoSize
}
