#Requires -Version 7.0

# Sets the taskbar pin order via the "Start Layout" Group Policy setting (User Configuration >
# Administrative Templates > Start Menu and Taskbar > Start Layout), which under the hood is just
# HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer\StartLayoutFile pointing at an XML file. This
# is Local Group Policy, not Active Directory -- no domain needed to just write the registry value
# by hand. That value still needs an elevated process to set even though it's under HKCU: that key
# is ACL'd to ReadKey-only for the owning user on every Windows install, regardless of whether any
# GPO is configured. The one-time pointer itself is set by winget configuration's
# TaskbarStartLayoutFile resource, not by this script, which only ever writes the XML file content
# it points at (an unprivileged operation) and must keep that file present at a stable path
# indefinitely, since the registry value is a standing pointer re-read on every policy refresh.
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
# so it's special-cased below via its well-known AppUserModelID. Windows Terminal is a packaged app
# matched by an AppID substring (its stable package family name) rather than by Start Menu display
# name, since display names drift -- its Start Menu entry was renamed from "Windows Terminal" to
# plain "Terminal" at one point. Name is kept as a fallback match in case the package family name
# ever changes too.
$Pins = @(
  @{ Label = 'Explorer' }
  @{ Label = 'Windows Terminal'; AppIdLike = '*WindowsTerminal*'; Name = 'Terminal' }
  @{ Label = 'Discord'; Name = 'Discord' }
  @{ Label = 'Proton Mail'; Name = 'Proton Mail' }
  @{ Label = 'Firefox'; Name = 'Firefox' }
  @{ Label = 'Brave'; Name = 'Brave' }
  @{ Label = 'Obsidian'; Name = 'Obsidian' }
  @{ Label = 'VSCodium'; Name = 'VSCodium' }
  @{ Label = 'VSCode'; Name = 'Visual Studio Code' }
  @{ Label = 'YouTube'; Name = 'YouTube' }
)

# Get-StartApps' AppID comes in three different shapes, each needing its own XML element:
#   1. A packaged (MSIX/UWP) app's AUMID, PackageFamilyName!AppId -- e.g. Windows Terminal's
#      "Microsoft.WindowsTerminal_8wekyb3d8bbwe!App". The "!" reliably signals this shape.
#      XML element: UWA.
#   2. A literal path to a classic .lnk shortcut file (drive-letter or UNC prefix).
#      XML element: DesktopApplicationLinkPath.
#   3. A classic (non-packaged) app's own self-registered AUMID, which looks nothing like either
#      of the above -- e.g. Discord ("com.squirrel.Discord.Discord"), Firefox
#      ("308046B0AF4A39CB"), Brave ("Brave.AKBOGHEVCXMTZPESA6L3C34SMA"), Obsidian ("md.obsidian").
#      XML element: DesktopApplicationID (not limited to Microsoft's own hardcoded names, despite
#      its use for plain "Microsoft.Windows.Explorer" below -- it's the general slot for any
#      non-path, non-packaged app identifier).
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

# Must persist indefinitely at this exact path -- see the StartLayoutFile note at the top of the
# file.
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
