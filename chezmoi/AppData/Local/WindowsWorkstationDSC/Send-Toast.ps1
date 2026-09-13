# Posts a Windows toast notification via the BurntToast module (installed by pins-autostart.ps1).
#
# Native WinRT toast APIs aren't usable from pwsh's .NET runtime; BurntToast works around this by
# bundling pre-compiled CsWinRT assemblies instead of relying on runtime type-loading.
#
# BurntToast 1.0+ has no custom AppId/branding support, so there's no way to make a notification
# visually identifiable as ours via AUMID -- the title is prefixed with "WindowsWorkstationDSC:"
# instead, as a cheap substitute.
#
# Uses the New-BTBinding/New-BTContent/Submit-BTNotification pipeline rather than the simpler
# New-BurntToastNotification cmdlet because that cmdlet unconditionally shows an app logo
# (BurntToast's own branded PNG) whenever -AppLogo isn't given; never setting -AppLogoOverride on
# the binding avoids the logo entirely.
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
