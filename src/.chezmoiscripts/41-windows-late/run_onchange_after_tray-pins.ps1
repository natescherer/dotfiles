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
# Depends on run_onchange_after_winget-configure.ps1.tmpl (installs ProtonDrive, AdobeCreativeCloud,
# DockerDesktop, iCloud, and Claude via 7.apps-personal, UniGetUI and PowerToys via
# 7.apps-core-elevated) in 40-windows/ -- sorts before this script and so already ran earlier in
# this same `chezmoi apply`. ASUS DriverHub and VMware Workstation aren't installed via winget --
# they're preinstalled/manually-installed software this machine already has. PowerToys Awake needs
# no separate enablement step -- confirmed on a fresh VM that its module (and tray icon) ships
# enabled by default, unlike some other PowerToys utilities.
#
# Runs after run_onchange_after_taskbar-pins.ps1 (alphabetically later) and, like that script,
# ends by restarting Explorer so the promotions are visible immediately rather than only after the
# next logon -- meaning a `chezmoi apply` that touches both pin scripts flickers Explorer twice.
# Accepted as a minor cost of keeping the two scripts independently correct and rerunnable.

Write-Host "`nSetting system tray pins..." -ForegroundColor Green

# IconPathLike matches NotifyIconSettings' ExecutablePath, which is stored with a KNOWNFOLDERID
# GUID prefix instead of a drive letter (e.g. "{6D809377-...}\Adobe\Adobe Creative
# Cloud\ACC\Creative Cloud.exe" for Program Files) -- matching on the stable tail avoids having to
# resolve which known folder each GUID means. "Already running" checks below match Get-Process's
# .Path against this same pattern (drive-letter form, but the tail is identical) rather than a
# bare process Name -- Claude's bare process name ("claude") collides with the Claude Code CLI's
# own bundled native-binary claude.exe, which is also running throughout a chezmoi apply driven by
# Claude Code itself and made the naive Name-only check think the desktop app was already running
# when it wasn't (or vice versa). RunningCheckPathLike overrides this default only where the
# process that indicates "no need to launch" genuinely differs from the icon's own owning process
# (PowerToys' hub vs. its Awake child process, below).
$Targets = @(
  @{ Label = 'Proton Drive'; StartAppName = 'Proton Drive'; IconPathLike = '*\Proton\Drive\ProtonDrive.exe' }
  @{ Label = 'Creative Cloud'; StartAppName = 'Adobe Creative Cloud'; IconPathLike = '*\Adobe Creative Cloud\ACC\Creative Cloud.exe' }
  @{ Label = 'UniGetUI'; StartAppName = 'UniGetUI'; IconPathLike = '*\UniGetUI\UniGetUI.exe' }
  @{ Label = 'ASUS DriverHub'; StartAppName = 'ASUS DriverHub'; IconPathLike = '*\AsusDriverHub\ASUS DriverHub.exe' }
  # Launching "PowerToys (Preview)" starts the main hub process; PowerToys itself spawns
  # PowerToys.Awake.exe (a separate process) since the Awake module ships enabled by default.
  @{ Label = 'PowerToys Awake'; StartAppName = 'PowerToys (Preview)'; IconPathLike = '*\PowerToys\PowerToys.Awake.exe'; RunningCheckPathLike = '*\PowerToys\PowerToys.exe' }
  @{ Label = 'Docker Desktop'; StartAppName = 'Docker Desktop'; IconPathLike = '*\Docker\Docker\frontend\Docker Desktop.exe' }
  # VMware's Start Menu tile ("VMware Workstation Pro") launches the full VM manager UI, not the
  # background helper that actually owns the tray icon -- vmware-tray.exe is a separate process
  # Windows launches directly at every login via its own HKLM Run key entry, confirmed against
  # this machine. RunKeyName below reuses that same entry to launch it here instead of going
  # through Get-StartApps/shell:AppsFolder like every other target.
  @{ Label = 'VMware Workstation'; RunKeyName = 'vmware-tray.exe'; IconPathLike = '*\VMware\VMware Workstation\vmware-tray.exe' }
  @{ Label = 'iCloud'; StartAppName = 'iCloud'; IconPathLike = '*\WindowsApps\AppleInc.iCloud_*\iCloud\iCloudHome.exe' }
  # winget's Anthropic.Claude package is a per-user Squirrel-style installer (same pattern as
  # Discord/Slack), not a Store/MSIX package -- confirmed against an actual winget-provisioned VM,
  # after an earlier version of this pattern (based on this machine's own Claude install, which
  # turned out to be a different, unrelated Store install) never matched and made the script
  # falsely conclude Claude was never running. IconPathLike has a wildcard version segment
  # ("app-1.24012.9") since that folder name changes on every app update.
  @{ Label = 'Claude'; StartAppName = 'Claude'; IconPathLike = '*\AnthropicClaude\app-*\claude.exe' }
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
    $RunningCheckPathLike = if ($Target.RunningCheckPathLike) { $Target.RunningCheckPathLike } else { $Target.IconPathLike }
    if (-not (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like $RunningCheckPathLike })) {
      if ($Target.RunKeyName) {
        $RunCommand = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).($Target.RunKeyName)
        if (-not $RunCommand) {
          Write-Host "  Warning: no '$($Target.RunKeyName)' autostart entry found -- skipping (it may not be installed yet)." -ForegroundColor Yellow
          continue
        }
        Write-Host "  Launching to register its tray icon..." -ForegroundColor DarkGray
        # Just the bare quoted path in every case seen so far -- not general command-line parsing.
        Start-Process -FilePath $RunCommand.Trim('"')
      } else {
        $StartApp = Get-StartApps | Where-Object { $_.Name -eq $Target.StartAppName } | Select-Object -First 1
        if (-not $StartApp) {
          Write-Host "  Warning: could not find '$($Target.StartAppName)' in the Start Menu -- skipping (it may not be installed yet)." -ForegroundColor Yellow
          continue
        }
        Write-Host "  Launching to register its tray icon..." -ForegroundColor DarkGray
        Start-Process "shell:AppsFolder\$($StartApp.AppID)"
      }
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

$TotalCount = $Targets.Count + 1

if ($PromotedCount -gt 0) {
  # Registry-only edits here aren't picked up by the already-running tray host until Explorer
  # restarts, the same reason taskbar-pins.ps1 restarts it -- this closes every open File
  # Explorer window and flickers the desktop/taskbar for a few seconds.
  Write-Host "`nRestarting Explorer to apply tray icon changes..." -ForegroundColor Cyan
  Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 2
  if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe
  }
  Start-Sleep -Seconds 3
}

Write-Host "Tray pins applied ($PromotedCount/$TotalCount resolved)." -ForegroundColor Green

if ($PromotedCount -lt $TotalCount) {
  # A "rerun chezmoi apply" warning above is only true if this actually happens: run_onchange_
  # scripts are gated on this script's own content hash, not on any external state, so chezmoi
  # won't rerun it just because the user reran `chezmoi apply` -- exiting non-zero is what makes
  # chezmoi retry it on the next apply regardless of hash, the same technique
  # run_onchange_after_winget-configure.ps1.tmpl uses (see Stop-ForPendingReboot there).
  exit 1
}
