#Requires -Version 7.0

# Sets the taskbar pin order via the LayoutModification.xml mechanism. There is no supported
# winget/DSC resource for this -- Microsoft.Windows.Developer/Taskbar (used in
# 3.settings-elevated.configuration.winget) only covers things like search box mode, and Windows
# 11 deliberately blocks the old "pin to taskbar" shell-verb automation to stop malware/OEM abuse.
# This is the same unsupported-but-working community workaround documented at e.g.
# https://woshub.com/pin-unpin-apps-taskbar-windows-via-powershell/ and
# https://awakecoding.com/posts/pinning-apps-to-the-windows-11-taskbar-with-powershell/ -- it
# could break in a future Windows update.
#
# This replaces the *entire* taskbar pin list with exactly what's below (PinListPlacement=
# Replace), the same "clear then repin the whole desired set" approach as the macOS dock_pins
# Ansible role -- nothing pinned by hand outside this list survives a rerun.
#
# Depends on run_onchange_after_winget-configure.ps1.tmpl (installs Discord/Firefox/Brave/
# Obsidian/VSCodium/VSCode) in 40-windows/ and run_onchange_after_pwa-install.ps1.tmpl (installs
# the YouTube PWA shortcut) in this same directory -- both sort before this script and so already
# ran earlier in this same `chezmoi apply`.

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

# Get-StartApps' AppID is an AUMID (contains "!") for packaged apps and a plain .lnk path for
# classic desktop apps -- the same value plugs into either XML element below, just under a
# different attribute name, so branch on its shape rather than tracking app type per entry.
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
  return @{ Element = 'DesktopApp'; Attribute = 'DesktopApplicationLinkPath'; Value = $Match.AppID }
}

$StartApps = Get-StartApps
$Resolved = @()
foreach ($Pin in $Pins) {
  $Target = Resolve-Pin -Pin $Pin -StartApps $StartApps
  if ($Target) {
    $Resolved += $Target
  } else {
    Write-Host "Warning: could not resolve '$($Pin.Label)' to a Start Menu entry -- skipping it (it may not be installed yet)." -ForegroundColor Yellow
  }
}

if ($Resolved.Count -eq 0) {
  Write-Host "Warning: none of the desired taskbar pins could be resolved -- skipping." -ForegroundColor Yellow
  exit 0
}

#region Build LayoutModification.xml

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
  $PinList.AppendChild($Element) | Out-Null
}

$ShellDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Shell'
New-Item -ItemType Directory -Path $ShellDir -Force | Out-Null
$LayoutPath = Join-Path $ShellDir 'LayoutModification.xml'
$Xml.Save($LayoutPath)

#endregion

# Stale cached layout state (from an earlier run of this script, or from Windows' own taskbar
# handling) can make Explorer ignore the new XML or show blank icons -- clear it before
# restarting Explorer so the new layout applies cleanly.
Remove-Item -Path (Join-Path $ShellDir '*.dat') -Force -ErrorAction SilentlyContinue
Remove-Item -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband' -Recurse -Force -ErrorAction SilentlyContinue

# This is the disruptive part: killing Explorer closes every open File Explorer window and
# flickers the desktop/taskbar for a few seconds while it relaunches -- there's no supported way
# to make Explorer re-read the pin layout without it.
Write-Host "Restarting Explorer to apply the new taskbar layout..." -ForegroundColor Cyan
Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
# Windows normally relaunches explorer.exe on its own once it's killed, but that's not guaranteed
# in every session type (e.g. some remote sessions) -- start it explicitly if it didn't.
if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
  Start-Process explorer.exe
}
Start-Sleep -Seconds 3

# Leaving LayoutModification.xml in place would keep forcing this exact layout back on every
# future Explorer restart, fighting any pinning/unpinning done by hand afterward -- this script is
# meant to seed the initial pins once, not permanently lock the taskbar.
Remove-Item -Path $LayoutPath -Force -ErrorAction SilentlyContinue

Write-Host "Taskbar pins applied ($($Resolved.Count)/$($Pins.Count) resolved)." -ForegroundColor Green
