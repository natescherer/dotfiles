#Requires -Version 7.0

# Promotes ("always show", never collapsed into the overflow flyout) the system tray icons for
# apps that are meant to live in the tray permanently. There is no supported way to pre-seed this
# the way LayoutModification.xml pre-seeds taskbar pins in run_onchange_after_taskbar-pins.ps1 --
# the per-icon state lives in registry subkeys under HKCU:\Control Panel\NotifyIconSettings, keyed
# by an opaque ID that Windows only creates once an app has actually registered a tray icon at
# least once. So this script launches each target app first (if it isn't already running), waits
# for its NotifyIconSettings entry to show up, then flips that entry's IsPromoted value to 1 --
# the same value the "Select which icons appear on the taskbar" Settings page itself edits. This
# is undocumented and could break in a future Windows update, same caveat as the taskbar-pins
# script. Verified by hand against the live registry on this machine before writing this script.
#
# Depends on run_onchange_after_winget-configure.ps1.tmpl (installs ProtonDrive and
# AdobeCreativeCloud via 7.apps-personal, UniGetUI and PowerToys via 7.apps-core-elevated) in
# 40-windows/ -- sorts before this script and so already ran earlier in this same `chezmoi apply`.
# ASUS DriverHub isn't installed via winget -- it's OEM-bundled software this machine already has
# preinstalled. PowerToys Awake needs no separate enablement step -- confirmed on a fresh VM that
# its module (and tray icon) ships enabled by default, unlike some other PowerToys utilities.
#
# Runs after run_onchange_after_taskbar-pins.ps1 (alphabetically later) and, like that script,
# ends by restarting Explorer so the promotions are visible immediately rather than only after the
# next logon -- meaning a `chezmoi apply` that touches both pin scripts flickers Explorer twice.
# Accepted as a minor cost of keeping the two scripts independently correct and rerunnable.

Write-Host "`nSetting system tray pins..." -ForegroundColor Green

# IconPathLike matches NotifyIconSettings' ExecutablePath, which is stored with a KNOWNFOLDERID
# GUID prefix instead of a drive letter (e.g. "{6D809377-...}\Adobe\Adobe Creative
# Cloud\ACC\Creative Cloud.exe" for Program Files) -- matching on the stable tail avoids having to
# resolve which known folder each GUID means.
$Targets = @(
  @{ Label = 'Proton Drive'; StartAppName = 'Proton Drive'; ProcessName = 'ProtonDrive'; IconPathLike = '*\Proton\Drive\ProtonDrive.exe' }
  @{ Label = 'Creative Cloud'; StartAppName = 'Adobe Creative Cloud'; ProcessName = 'Creative Cloud'; IconPathLike = '*\Adobe Creative Cloud\ACC\Creative Cloud.exe' }
  @{ Label = 'UniGetUI'; StartAppName = 'UniGetUI'; ProcessName = 'UniGetUI'; IconPathLike = '*\UniGetUI\UniGetUI.exe' }
  @{ Label = 'ASUS DriverHub'; StartAppName = 'ASUS DriverHub'; ProcessName = 'ASUS DriverHub'; IconPathLike = '*\AsusDriverHub\ASUS DriverHub.exe' }
  # Launching "PowerToys (Preview)" starts the main hub process; PowerToys itself spawns
  # PowerToys.Awake.exe (a separate process, hence the different ProcessName) since the Awake
  # module ships enabled by default.
  @{ Label = 'PowerToys Awake'; StartAppName = 'PowerToys (Preview)'; ProcessName = 'PowerToys.Awake'; IconPathLike = '*\PowerToys\PowerToys.Awake.exe'; LaunchProcessName = 'PowerToys' }
)

# Finds the NotifyIconSettings subkey (if any) matching a predicate, returning its PSPath and
# current IsPromoted value.
function Find-NotifyIconEntry {
  param([scriptblock] $Predicate)
  Get-ChildItem 'HKCU:\Control Panel\NotifyIconSettings' -ErrorAction SilentlyContinue | ForEach-Object {
    $Properties = Get-ItemProperty -Path $_.PSPath
    if (& $Predicate $Properties) {
      return @{ PSPath = $_.PSPath; IsPromoted = $Properties.IsPromoted }
    }
  } | Select-Object -First 1
}

function Set-NotifyIconPromoted {
  param([string] $PSPath)
  New-ItemProperty -Path $PSPath -Name 'IsPromoted' -Value 1 -PropertyType DWord -Force | Out-Null
}

$PromotedCount = 0

foreach ($Target in $Targets) {
  Write-Host "`n$($Target.Label):" -ForegroundColor Cyan

  $Entry = Find-NotifyIconEntry -Predicate { param($p) $p.ExecutablePath -like $Target.IconPathLike }

  if (-not $Entry) {
    $LaunchProcessName = if ($Target.LaunchProcessName) { $Target.LaunchProcessName } else { $Target.ProcessName }
    if (-not (Get-Process -Name $LaunchProcessName -ErrorAction SilentlyContinue)) {
      $StartApp = Get-StartApps | Where-Object { $_.Name -eq $Target.StartAppName } | Select-Object -First 1
      if (-not $StartApp) {
        Write-Host "  Warning: could not find '$($Target.StartAppName)' in the Start Menu -- skipping (it may not be installed yet)." -ForegroundColor Yellow
        continue
      }
      Write-Host "  Launching to register its tray icon..." -ForegroundColor DarkGray
      Start-Process "shell:AppsFolder\$($StartApp.AppID)"
    }

    # Poll rather than a fixed sleep -- first-ever launch of a freshly-installed app can take a
    # few seconds to reach the point of registering a tray icon, and most apps are much faster.
    $Deadline = (Get-Date).AddSeconds(20)
    while (-not $Entry -and (Get-Date) -lt $Deadline) {
      Start-Sleep -Seconds 1
      $Entry = Find-NotifyIconEntry -Predicate { param($p) $p.ExecutablePath -like $Target.IconPathLike }
    }
  }

  if (-not $Entry) {
    Write-Host "  Warning: no tray icon appeared within 20s -- skipping. Rerun 'chezmoi apply' after using the app once by hand." -ForegroundColor Yellow
    continue
  }

  if ($Entry.IsPromoted -eq 1) {
    Write-Host "  Already always-shown." -ForegroundColor DarkGray
  } else {
    Set-NotifyIconPromoted -PSPath $Entry.PSPath
    Write-Host "  Promoted to always-shown." -ForegroundColor Green
  }
  $PromotedCount++
}

# Safely Remove Hardware isn't an installable app -- it's a built-in icon that explorer.exe itself
# registers, identified by the documented GUID_HARDWARE_REMOVAL icon GUID (confirmed against this
# machine's own registry) rather than by ExecutablePath, since explorer.exe hosts several distinct
# built-in tray icons under that same path. It can only be promoted if Windows has already created
# its entry, which itself only happens after removable/quick-removal hardware has been present at
# least once -- there's no way to force that from a script, unlike the apps above.
Write-Host "`nSafely Remove Hardware:" -ForegroundColor Cyan
$HardwareRemovalGuid = '{7820AE78-23E3-4229-82C1-E41CB67D5B9C}'
$HardwareEntry = Find-NotifyIconEntry -Predicate { param($p) $p.IconGuid -eq $HardwareRemovalGuid }
if (-not $HardwareEntry) {
  Write-Host "  Warning: no registry entry for this icon yet -- Windows only creates one after removable/quick-removal hardware has been connected at least once. Connect a USB drive (or similar) once, then rerun 'chezmoi apply'." -ForegroundColor Yellow
} elseif ($HardwareEntry.IsPromoted -eq 1) {
  Write-Host "  Already always-shown." -ForegroundColor DarkGray
  $PromotedCount++
} else {
  Set-NotifyIconPromoted -PSPath $HardwareEntry.PSPath
  Write-Host "  Promoted to always-shown." -ForegroundColor Green
  $PromotedCount++
}

if ($PromotedCount -eq 0) {
  Write-Host "`nWarning: none of the desired tray pins could be resolved -- skipping Explorer restart." -ForegroundColor Yellow
  exit 0
}

# Registry-only edits here aren't picked up by the already-running tray host until Explorer
# restarts, the same reason taskbar-pins.ps1 restarts it -- this closes every open File Explorer
# window and flickers the desktop/taskbar for a few seconds.
Write-Host "`nRestarting Explorer to apply tray icon changes..." -ForegroundColor Cyan
Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
  Start-Process explorer.exe
}
Start-Sleep -Seconds 3

Write-Host "Tray pins applied ($PromotedCount/$($Targets.Count + 1) resolved)." -ForegroundColor Green
