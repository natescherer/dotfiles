#Requires -Version 7.0

# Real logic lives at the stable path below (a regular chezmoi-managed file, guaranteed already on
# disk by the time any run_after_ script executes -- see
# https://www.chezmoi.io/reference/application-order/) so it can be invoked identically from here
# (during `chezmoi apply`) and directly by the login-autostart Run key registered in
# pins-autostart.ps1, which has no chezmoi available. Plain run_after_, not run_onchange_after_, for
# the same reason as run_after_tray-pins.ps1: this needs to self-heal and run every time, not just
# when its own content changes -- see the "runs unconditionally" note atop desktop-icons.ps1 itself.
#
# Depends on run_onchange_after_winget-configure.ps1.tmpl (installs the apps whose shortcuts this
# cleans up) in 40-windows/ -- sorts before this script and so already ran earlier in this same
# `chezmoi apply`.
& (Join-Path $env:LOCALAPPDATA 'WindowsWorkstationDSC\desktop-icons.ps1')
exit $LASTEXITCODE
