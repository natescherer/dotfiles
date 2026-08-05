#Requires -Version 7.0

# Promotes ("always show", never collapsed into the overflow flyout) the system tray icons for
# apps that are meant to live in the tray permanently. There is no supported way to pre-seed this
# the way LayoutModification.xml pre-seeds taskbar pins in taskbar-pins.ps1 -- the per-icon state
# lives in registry subkeys under HKCU:\Control Panel\NotifyIconSettings, keyed by an opaque ID
# that Windows only creates once an app has actually registered a tray icon at least once. So this
# script launches each target app first (if it isn't already running), waits for its
# NotifyIconSettings entry to show up, then flips that entry's IsPromoted value to 1 -- the same
# value the "Select which icons appear on the taskbar" Settings page itself edits. This is
# undocumented and could break in a future Windows update, same caveat as the taskbar-pins script.
# Verified by hand against the live registry on this machine before writing this script.
#
# A standalone, self-contained script -- no chezmoi-specific assumptions (no `chezmoi apply`
# invocations, no chezmoi source-dir references). It's installed at a stable path
# (%LOCALAPPDATA%\WindowsWorkstationDSC\tray-pins.ps1) and invoked identically two ways: a thin
# wrapper in .chezmoiscripts/ during `chezmoi apply`, and directly by the login-autostart Run key
# registered by pins-autostart.ps1 (which has no chezmoi available at login time). This is also
# the seed of a planned standalone WindowsWorkstationDSC DSC module, hence the self-contained
# design even though only chezmoi consumes it today.
#
# Runs unconditionally every time it's invoked: some targets here (VMware Workstation, ASUS
# DriverHub) are installed manually rather than by anything chezmoi controls, so there's nothing
# whose change could gate a rerun when one of them shows up later -- and even for the rest, a
# target can go from unresolved to resolved without this script's own content ever changing (e.g.
# the user finally signs into an app that was previously only running unauthenticated). This is
# safe/cheap to run every time: resolved targets are a fast registry read, genuinely-absent apps
# fail fast (see the Get-StartApps/RunKeyName checks below -- neither one waits out the 20s poll),
# and Explorer is only restarted when something was actually newly promoted this run (see
# $NewlyPromotedCount below), not merely confirmed as already done.

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

$ResolvedCount = 0
$NewlyPromotedCount = 0
$NewlyPromotedLabels = [System.Collections.Generic.List[string]]::new()

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
    Write-Host "  Warning: no tray icon appeared within 20s -- skipping. It'll be picked up automatically next time this runs." -ForegroundColor Yellow
    continue
  }

  if ($Entry.IsPromoted -eq 1) {
    Write-Host "  Already always-shown." -ForegroundColor DarkGray
  } else {
    Set-NotifyIconPromoted -PSPath $Entry.PSPath
    Write-Host "  Promoted to always-shown." -ForegroundColor Green
    $NewlyPromotedCount++
    $NewlyPromotedLabels.Add($Target.Label)
  }
  $ResolvedCount++
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
  Write-Host "  Warning: no registry entry for this icon yet -- Windows only creates one after removable/quick-removal hardware has been connected at least once. It'll be picked up automatically once that happens." -ForegroundColor Yellow
} elseif ($HardwareEntry.IsPromoted -eq 1) {
  Write-Host "  Already always-shown." -ForegroundColor DarkGray
  $ResolvedCount++
} else {
  Set-NotifyIconPromoted -PSPath $HardwareEntry.PSPath
  Write-Host "  Promoted to always-shown." -ForegroundColor Green
  $NewlyPromotedCount++
  $NewlyPromotedLabels.Add('Safely Remove Hardware')
  $ResolvedCount++
}

$TotalCount = $Targets.Count + 1

if ($NewlyPromotedCount -gt 0) {
  # Registry-only edits here aren't picked up by the already-running tray host until Explorer
  # restarts, the same reason taskbar-pins.ps1 restarts it -- this closes every open File
  # Explorer window and flickers the desktop/taskbar for a few seconds. Gated on
  # $NewlyPromotedCount (not $ResolvedCount) since this script runs unconditionally every time --
  # restarting Explorer every single run, even when everything was already promoted from a prior
  # run, would be needless disruption.
  Write-Host "`nRestarting Explorer to apply tray icon changes..." -ForegroundColor Cyan
  Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Seconds 2
  if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe
  }
  Start-Sleep -Seconds 3

  . (Join-Path $PSScriptRoot 'Send-Toast.ps1')
  Send-WindowsWorkstationDSCToast -Text 'System tray pins updated', "Promoted: $($NewlyPromotedLabels -join ', ')"
}

Write-Host "Tray pins applied ($ResolvedCount/$TotalCount resolved)." -ForegroundColor Green

# Deliberately no non-zero exit for $ResolvedCount -lt $TotalCount: every path that leaves a target
# unresolved (app not installed, no autostart entry yet, icon didn't register within the poll
# window) already warned above and is an expected steady-state, not a failure -- most machines will
# never have every target installed (VMware, ASUS DriverHub, etc. are manual installs). Exiting
# non-zero here would make `chezmoi apply` report failure on every ordinary run. A genuine error
# (an unhandled exception) still surfaces on its own: pwsh exits non-zero when a script terminates
# on one.
