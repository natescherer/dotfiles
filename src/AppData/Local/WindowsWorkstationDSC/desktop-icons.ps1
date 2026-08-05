#Requires -Version 7.0

# Apps' own installers frequently drop a Desktop shortcut independent of `winget configure`'s
# installMode: silent -- there's no Microsoft.WinGet/Package property to suppress it, and the
# mechanism (if the installer even exposes one) differs per installer technology (NSIS, Inno
# Setup, MSI...). Rather than chase that per-package -- or hand-maintain a list of exactly which
# apps are currently misbehaving -- this sweeps every shortcut off the Desktop unconditionally,
# every time it runs, regardless of what put it there (winget-installed or not). Sent to the
# Recycle Bin rather than permanently deleted, so a shortcut that turns out to matter is a Recycle
# Bin restore away, not gone -- confirmed by hand this genuinely matters: an earlier hand-test of
# the recycle-bin API against a live Public Desktop shortcut worked, i.e. this really does touch
# real files, not just ones this repo happens to manage.
#
# A standalone, self-contained script -- no chezmoi-specific assumptions (no `chezmoi apply`
# invocations, no chezmoi source-dir references). It's installed at a stable path
# (%LOCALAPPDATA%\WindowsWorkstationDSC\desktop-icons.ps1) and invoked identically two ways: a thin
# wrapper in .chezmoiscripts/ during `chezmoi apply`, and directly by the login-autostart Run key
# registered by pins-autostart.ps1 (which has no chezmoi available at login time). Runs
# unconditionally every time it's invoked, same reasoning as taskbar-pins.ps1/tray-pins.ps1: a
# shortcut dropped by an app installed or updated later gets swept without waiting on someone to
# remember to rerun `chezmoi apply`.

Write-Host "`nCleaning up desktop icons..." -ForegroundColor Green

# Microsoft.VisualBasic.FileIO.FileSystem, not Remove-Item -- the only built-in way to send a file
# to the Recycle Bin instead of deleting it outright. Confirmed by hand this works fine under pwsh
# 7 (the assembly ships as part of the shared .NET framework, not something Windows-PowerShell-only
# like the WinRT toast trick Send-Toast.ps1 has to work around).
Add-Type -AssemblyName Microsoft.VisualBasic

# Per-user (non-elevated) installs land their shortcut on the current user's own Desktop.
# All-users/elevated installs land theirs on the Public Desktop instead -- confirmed by hand that
# an unelevated login session (how this script normally runs -- see pins-autostart.ps1) *can*
# delete an existing shortcut there via the Recycle Bin API even though it can't create a new file
# there (that asymmetry is real, not a guess: hand-verified both directions against a live Public
# Desktop shortcut). So no elevation gating is needed here -- every shortcut on both roots is a
# fair target, and any that genuinely can't be removed (locked file, unexpected ACL, etc.) is
# caught and reported below rather than assumed away.
$DesktopRoots = @(
  (Join-Path $env:USERPROFILE 'Desktop')
  'C:\Users\Public\Desktop'
)

$Removed = [System.Collections.Generic.List[string]]::new()
$Failed = [System.Collections.Generic.List[string]]::new()

foreach ($Root in $DesktopRoots) {
  if (-not (Test-Path $Root)) { continue }
  # -File, not -Recurse: only shortcuts sitting directly on the Desktop are installer-dropped
  # icons -- anything inside a subfolder is a folder the user made themselves, out of scope here.
  # Filtering via Where-Object rather than -Include: -Include silently matches nothing unless the
  # -Path itself ends in a wildcard or -Recurse is also passed, neither of which applies here.
  $Shortcuts = Get-ChildItem -Path $Root -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.lnk', '.url' }

  foreach ($Shortcut in $Shortcuts) {
    try {
      [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
        $Shortcut.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
      Write-Host "Removed: $($Shortcut.FullName)" -ForegroundColor DarkGray
      $Removed.Add($Shortcut.BaseName)
    } catch {
      Write-Host "Warning: could not remove '$($Shortcut.FullName)' -- $($_.Exception.Message)" -ForegroundColor Yellow
      $Failed.Add("$($Shortcut.BaseName) ($($_.Exception.Message))")
    }
  }
}

if ($Removed.Count -eq 0 -and $Failed.Count -eq 0) {
  Write-Host "No desktop icons to clean up." -ForegroundColor DarkGray
  exit 0
}

if ($Removed.Count -gt 0) {
  Write-Host "Removed $($Removed.Count) desktop icon(s): $($Removed -join ', ')" -ForegroundColor Green
}
if ($Failed.Count -gt 0) {
  Write-Host "Could not remove $($Failed.Count) desktop icon(s) -- see warnings above." -ForegroundColor Yellow
}

# Toast fires whenever anything happened (removed and/or failed) -- a failure the user never sees
# is worse than one extra notification, and this only runs on genuine changes (never on a no-op
# run), same as taskbar-pins.ps1/tray-pins.ps1.
. (Join-Path $PSScriptRoot 'Send-Toast.ps1')
$ToastLines = [System.Collections.Generic.List[string]]::new()
if ($Removed.Count -gt 0) { $ToastLines.Add("Sent to Recycle Bin: $($Removed -join ', ')") }
if ($Failed.Count -gt 0) { $ToastLines.Add("Could not remove: $($Failed -join ', ')") }
Send-WindowsWorkstationDSCToast -Text 'Desktop icons cleaned up', ($ToastLines -join ' | ')

# Non-zero so a failure is visible in `chezmoi apply`'s own output too, not just the toast. Unlike
# the other pin script's unresolved-target count, $Failed here is a genuine error (a shortcut that
# threw on removal -- locked file, unexpected ACL), not an expected steady-state, so it's fine for
# this one to fail the run.
if ($Failed.Count -gt 0) {
  exit 1
}
exit 0
