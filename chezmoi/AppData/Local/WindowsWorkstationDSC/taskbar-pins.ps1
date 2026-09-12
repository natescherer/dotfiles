#Requires -Version 7.0

# Sets the taskbar pin order via the "Start Layout" Group Policy setting (User Configuration >
# Administrative Templates > Start Menu and Taskbar > Start Layout), which under the hood is just
# HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer\StartLayoutFile pointing at an XML file --
# this is Local Group Policy, not Active Directory: Microsoft's own docs
# (https://learn.microsoft.com/en-us/windows/configuration/taskbar/pinned-apps) explicitly
# distinguish "use the Local Group Policy Editor" (standalone machines) from "create/edit a GPO"
# (AD-joined machines) as two separate deployment options for the exact same registry-backed
# setting -- no domain needed to just write the registry value by hand. That registry value itself
# still needs to be set by an elevated process even though it's under HKCU, though: confirmed by
# hand that HKCU:\SOFTWARE\Policies\* is ACL'd to ReadKey-only for the owning user, full control
# is SYSTEM/Administrators-only, on every Windows install regardless of whether any GPO is
# actually configured. That one-time pointer is set by winget configuration's
# TaskbarStartLayoutFile resource, not by this script, which only ever writes the XML file content
# it points at (an unprivileged operation).
#
# This replaces an earlier version that dropped a LayoutModification.xml file directly into
# %LOCALAPPDATA%\Microsoft\Windows\Shell\ and restarted Explorer -- confirmed by hand (both on
# this machine and a fresh VM) that this no longer does anything at all on modern Windows 11:
# that specific file-drop mechanism has been broken/ignored since Windows 11 24H2 (build 26100+),
# per multiple corroborating community reports. The Group Policy path above is the one Microsoft
# still actively documents and patches (e.g. the PinGeneration attribute below, added in 2025).
#
# Unlike the old file-drop method (a one-time seed, deleted after applying), the XML file here
# must persist at a stable path indefinitely -- the registry value is a standing pointer to it,
# re-read on every policy refresh, not a one-shot trigger.
#
# A standalone, self-contained script -- no chezmoi-specific assumptions (no `chezmoi apply`
# invocations, no chezmoi source-dir references). It's installed at a stable path
# (%LOCALAPPDATA%\WindowsWorkstationDSC\taskbar-pins.ps1) and invoked identically two ways: a thin
# wrapper in .chezmoiscripts/ during `chezmoi apply`, and directly by the login-autostart Run key
# registered by pins-autostart.ps1 (which has no chezmoi available at login time). This is also
# the seed of a planned standalone WindowsWorkstationDSC DSC module, hence the self-contained
# design even though only chezmoi consumes it today.
#
# Runs unconditionally every time it's invoked (not gated on "did my own content change") so an
# app installed later (e.g. VSCodium showing up after this last ran) gets pinned automatically.
# Since it can run far more often than "once per content change" (every login, via the Run key),
# $StatePath below tracks the last-applied, ordered pin label list so the disruptive
# Explorer-restart (and the toast notification) only happens when the resolved set actually
# differs from last time -- not on every single invocation.

Write-Host "`nSetting taskbar pins..." -ForegroundColor Green

# Desired left-to-right order. Explorer has no Start Menu entry (Get-StartApps never returns it),
# so it's special-cased below via its well-known AppUserModelID. Windows Terminal and Outlook are
# packaged apps matched by an AppID substring (their stable package family name) rather than by
# Start Menu display name, since display names drift -- Windows Terminal's Start Menu entry was
# renamed from "Windows Terminal" to plain "Terminal" at one point. Name is kept as a fallback
# match for both in case the package family name ever changes too.
$Pins = @(
  @{ Label = 'Explorer' }
  @{ Label = 'Windows Terminal'; AppIdLike = '*WindowsTerminal*'; Name = 'Terminal' }
  @{ Label = 'Discord'; Name = 'Discord' }
  @{ Label = 'Outlook'; AppIdLike = '*OutlookForWindows*'; Name = 'Outlook' }
  @{ Label = 'Firefox'; Name = 'Firefox' }
  @{ Label = 'Brave'; Name = 'Brave' }
  @{ Label = 'Obsidian'; Name = 'Obsidian' }
  @{ Label = 'VSCodium'; Name = 'VSCodium' }
  @{ Label = 'VSCode'; Name = 'Visual Studio Code' }
  @{ Label = 'YouTube'; Name = 'YouTube' }
)

# Get-StartApps' AppID comes in three different shapes, not two -- confirmed by hand
# (Get-StartApps on this machine):
#   1. A packaged (MSIX/UWP) app's AUMID, PackageFamilyName!AppId -- e.g. Windows Terminal's
#      "Microsoft.WindowsTerminal_8wekyb3d8bbwe!App". The "!" is the reliable signal for this;
#      it's a real requirement of the PackageFamilyName!AppId format, not just a convention.
#   2. A literal path to a classic .lnk shortcut file (drive-letter or UNC prefix).
#   3. A classic (non-packaged) app's own self-registered AUMID, which looks nothing like either
#      of the above -- e.g. Discord ("com.squirrel.Discord.Discord"), Firefox
#      ("308046B0AF4A39CB"), Brave ("Brave.AKBOGHEVCXMTZPESA6L3C34SMA"), Obsidian ("md.obsidian").
# An earlier version of this function only distinguished (1) vs "everything else is a file path"
# (garbage for every case-3 app: none of those strings are real filesystem paths, so nothing
# resolved and they silently failed to pin), then a later fix only distinguished (2) vs "everything
# else is UWA/AppUserModelID" -- which mis-tags case-3 AUMIDs as packaged-app identifiers, equally
# unresolvable. All three cases need their own XML shape: UWA for (1), DesktopApplicationLinkPath
# for (2), and DesktopApplicationID for (3) -- confirmed DesktopApplicationID isn't limited to
# Microsoft's own hardcoded names (its use for plain "Microsoft.Windows.Explorer" below made that
# look like the case), it's the general slot for any non-path, non-packaged app identifier.
function Resolve-Pin {
  param($Pin, $StartApps)

  if ($Pin.Label -eq 'Explorer') {
    return @{ Element = 'DesktopApp'; Attribute = 'DesktopApplicationID'; Value = 'Microsoft.Windows.Explorer' }
  }

  $Match = $null
  if ($Pin.AppIdLike) {
    $Match = $StartApps | Where-Object { $_.AppID -like $Pin.AppIdLike } | Select-Object -First 1
  }
  if (-not $Match -and $Pin.Name) {
    $Match = $StartApps | Where-Object { $_.Name -eq $Pin.Name } | Select-Object -First 1
  }
  if (-not $Match) { return $null }

  if ($Match.AppID -match '!') {
    return @{ Element = 'UWA'; Attribute = 'AppUserModelID'; Value = $Match.AppID }
  }
  if ($Match.AppID -match '^[A-Za-z]:\\' -or $Match.AppID -match '^\\\\') {
    return @{ Element = 'DesktopApp'; Attribute = 'DesktopApplicationLinkPath'; Value = $Match.AppID }
  }
  return @{ Element = 'DesktopApp'; Attribute = 'DesktopApplicationID'; Value = $Match.AppID }
}

$StartApps = Get-StartApps
$Resolved = @()
$ResolvedLabels = [System.Collections.Generic.List[string]]::new()
foreach ($Pin in $Pins) {
  $Target = Resolve-Pin -Pin $Pin -StartApps $StartApps
  if ($Target) {
    $Resolved += $Target
    $ResolvedLabels.Add($Pin.Label)
  } else {
    Write-Host "Warning: could not resolve '$($Pin.Label)' to a Start Menu entry -- skipping it (it may not be installed yet)." -ForegroundColor Yellow
  }
}

if ($Resolved.Count -eq 0) {
  Write-Host "Warning: none of the desired taskbar pins could be resolved -- skipping." -ForegroundColor Yellow
  exit 0
}

# Order-sensitive: a pure reorder of $Pins above (no additions/removals) is still a real change
# that needs to be reapplied to take effect, so this compares the joined, ordered list rather than
# just set membership.
$StateDir = Join-Path $env:LOCALAPPDATA 'WindowsWorkstationDSC'
$StatePath = Join-Path $StateDir 'taskbar-pins.state'
$PreviousLabels = if (Test-Path $StatePath) { @(Get-Content -Path $StatePath) } else { @() }
$Changed = ($ResolvedLabels -join '|') -ne ($PreviousLabels -join '|')

if (-not $Changed) {
  Write-Host "Taskbar pins already up to date ($($Resolved.Count)/$($Pins.Count) resolved) -- nothing to do." -ForegroundColor DarkGray
  exit 0
}

#region Build the Start Layout XML

$Xml = New-Object System.Xml.XmlDocument
$Root = $Xml.CreateElement('LayoutModificationTemplate', 'http://schemas.microsoft.com/Start/2014/LayoutModification')
$Xml.AppendChild($Root) | Out-Null
$Root.SetAttribute('xmlns:defaultlayout', 'http://schemas.microsoft.com/Start/2014/FullDefaultLayout')
$Root.SetAttribute('xmlns:taskbar', 'http://schemas.microsoft.com/Start/2014/TaskbarLayout')
$Root.SetAttribute('Version', '1')

$Collection = $Xml.CreateElement('CustomTaskbarLayoutCollection', $Root.NamespaceURI)
$Collection.SetAttribute('PinListPlacement', 'Replace')
$Root.AppendChild($Collection) | Out-Null

$Layout = $Xml.CreateElement('defaultlayout:TaskbarLayout', $Root.GetAttribute('xmlns:defaultlayout'))
$Collection.AppendChild($Layout) | Out-Null

$PinList = $Xml.CreateElement('taskbar:TaskbarPinList', $Root.GetAttribute('xmlns:taskbar'))
$Layout.AppendChild($PinList) | Out-Null

foreach ($Target in $Resolved) {
  $Element = $Xml.CreateElement("taskbar:$($Target.Element)", $Root.GetAttribute('xmlns:taskbar'))
  $Element.SetAttribute($Target.Attribute, $Target.Value)
  # Lets the user permanently unpin an app without policy refresh re-pinning it -- without this,
  # policy-provisioned pins are silently restored on every refresh even after being unpinned,
  # which fights the user rather than just seeding an initial layout. Needs Windows 11 24H2 with
  # KB5060829 or 23H2 with KB5060826; harmless on older/unpatched builds, which per Microsoft's
  # docs just ignore the unrecognized attribute rather than failing.
  $Element.SetAttribute('PinGeneration', '1')
  $PinList.AppendChild($Element) | Out-Null
}

# Must persist indefinitely at this exact path -- unlike the old LayoutModification.xml file-drop
# approach, HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer\StartLayoutFile (set once, elevated,
# by winget configuration's TaskbarStartLayoutFile resource -- not here, since
# HKCU:\SOFTWARE\Policies\* is locked down against unelevated writes even for the owning user,
# confirmed by hand) is a standing pointer re-read on every policy refresh, not a one-shot trigger.
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
$LayoutPath = Join-Path $StateDir 'TaskbarLayout.xml'
$Xml.Save($LayoutPath)

#endregion

# Confirmed on this machine (Windows 11 build 26200.8875, past the documented 26200.5722 threshold
# for "applied instantly, without requiring sign out/sign in") that policy-based taskbar pins take
# effect without a full logoff. Restarting Explorer is still cheap insurance for older builds that
# fall back to the pre-instant-apply behavior of "applies at next sign-in" -- this can't make that
# case any worse, and may still help it along.
Write-Host "Restarting Explorer to apply the new taskbar layout..." -ForegroundColor Cyan
Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
  Start-Process explorer.exe
}
Start-Sleep -Seconds 3

Set-Content -Path $StatePath -Value $ResolvedLabels

$Added = $ResolvedLabels | Where-Object { $_ -notin $PreviousLabels }
$Removed = $PreviousLabels | Where-Object { $_ -notin $ResolvedLabels }

Write-Host "Taskbar pins applied ($($Resolved.Count)/$($Pins.Count) resolved)." -ForegroundColor Green

. (Join-Path $PSScriptRoot 'Send-Toast.ps1')
$ChangeLines = [System.Collections.Generic.List[string]]::new()
if ($Added.Count -gt 0) { $ChangeLines.Add("Added: $($Added -join ', ')") }
if ($Removed.Count -gt 0) { $ChangeLines.Add("Removed: $($Removed -join ', ')") }
if ($ChangeLines.Count -eq 0) { $ChangeLines.Add('Pin order changed') }
Send-WindowsWorkstationDSCToast -Text 'Taskbar pins updated', ($ChangeLines -join '; ')
