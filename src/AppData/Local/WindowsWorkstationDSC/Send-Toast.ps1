# Posts a Windows toast notification via the BurntToast module (installed by pins-autostart.ps1).
#
# Native WinRT toast APIs ([Windows.UI.Notifications.*], loaded via the
# "ContentType = WindowsRuntime" type-loading trick) are not available in PowerShell 7/pwsh --
# confirmed by hand: pwsh's .NET-based runtime cannot resolve WinRT-projected types that way.
# BurntToast works around this by bundling real, pre-compiled CsWinRT-projected assemblies
# (Microsoft.Toolkit.Uwp.Notifications.dll and Microsoft.Windows.SDK.NET.dll) rather than relying
# on that runtime reflection trick, so it works fine under pwsh 7 -- confirmed by hand.
#
# An earlier version of this script avoided the module dependency entirely by registering a
# custom "WindowsWorkstationDSC" AUMID by hand (COM interop: IShellLinkW + IPropertyStore) and
# shelling out to the built-in Windows PowerShell 5.1 (which *does* support the WinRT type-loading
# trick natively) just for the toast call. That traded one dependency for a meaningfully more
# fragile one -- hand-rolled PROPVARIANT marshaling and a cross-PowerShell-version subprocess --
# for no real gain, since BurntToast 1.0+ removed custom AppId/branding support anyway (so the
# custom AUMID wasn't even buying distinct branding over BurntToast's own identity). Not worth it.
# Since there's no custom AUMID to make the notification visually identifiable as ours, the title
# is prefixed with "WindowsWorkstationDSC:" below instead -- the cheap substitute for real
# branding.
#
# Tried -Scenario Reminder (via the New-BTContent/Submit-BTNotification pipeline -- the simpler
# New-BurntToastNotification cmdlet has no -Scenario parameter) to make the toast stay on screen
# until manually dismissed. Confirmed by hand this doesn't actually work here: per Microsoft's own
# docs on unpackaged-app toast activation, on-screen persistence needs a registered COM "Toast
# Activator" CLSID on the AUMID's shortcut, not just the AUMID itself -- without one, Windows
# silently downgrades the scenario to default, ordinary auto-dismiss behavior regardless of what
# was requested. A CLSID stub means implementing INotificationActivationCallback and registering
# an actual COM server, a meaningfully bigger step up in complexity than the AUMID work already
# abandoned above, for what's ultimately a cosmetic nicety. Not worth it -- reverted. Every toast,
# regardless of scenario, still remains in the Action Center bell icon after it auto-dismisses
# from the screen, so nothing is actually lost.
#
# Still uses the New-BTBinding/New-BTContent/Submit-BTNotification pipeline rather than the
# simpler New-BurntToastNotification cmdlet, now for a different reason: New-BurntToastNotification
# unconditionally shows an app logo, defaulting to BurntToast's own branded PNG
# (config.json's AppLogo) whenever -AppLogo isn't given -- confirmed by hand in its source
# (BurntToast.psm1) that this fallback is baked into that cmdlet specifically, not into
# New-BTBinding itself. Simply never setting -AppLogoOverride on the binding avoids the logo
# entirely, which the simple cmdlet has no parameter to do directly.
#
# This is a plain script file (not a function-only module) meant to be dot-sourced:
#   . (Join-Path $PSScriptRoot 'Send-Toast.ps1')
#   Send-WindowsWorkstationDSCToast -Text 'Title', 'Body'

function Send-WindowsWorkstationDSCToast {
  param([Parameter(Mandatory)] [string[]] $Text)

  try {
    Import-Module BurntToast -ErrorAction Stop
    $Lines = @("WindowsWorkstationDSC: $($Text[0])") + $Text[1..($Text.Count - 1)]
    $TextElements = $Lines | ForEach-Object { New-BTText -Text $_ }
    $Binding = New-BTBinding -Children $TextElements
    $Visual = New-BTVisual -BindingGeneric $Binding
    $Content = New-BTContent -Visual $Visual
    Submit-BTNotification -Content $Content
  } catch {
    # Notification delivery must never break the caller's actual pin-promotion logic -- e.g. if
    # BurntToast somehow isn't installed yet, or the notification platform is unavailable.
    Write-Host "  (toast notification failed: $($_.Exception.Message))" -ForegroundColor DarkGray
  }
}
