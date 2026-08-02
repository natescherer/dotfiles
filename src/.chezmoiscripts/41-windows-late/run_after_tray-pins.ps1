#Requires -Version 7.0

# Real logic lives at the stable path below (a regular chezmoi-managed file, guaranteed already on
# disk by the time any run_after_ script executes -- see
# https://www.chezmoi.io/reference/application-order/) so it can be invoked identically from here
# (during `chezmoi apply`) and directly by the login-autostart Run key registered in
# pins-autostart.ps1, which has no chezmoi available. Plain run_after_, not run_onchange_after_,
# so this stays self-healing: see the "runs unconditionally" note atop tray-pins.ps1 itself for why
# the underlying script needs to run every time rather than only when its content changes.
#
# Depends on run_onchange_after_winget-configure.ps1.tmpl (installs ProtonDrive, AdobeCreativeCloud,
# DockerDesktop, iCloud, and Claude via 7.apps-personal, UniGetUI and PowerToys via
# 7.apps-core-elevated) in 40-windows/ -- sorts before this script and so already ran earlier in
# this same `chezmoi apply`.
& (Join-Path $env:LOCALAPPDATA 'WindowsWorkstationDSC\tray-pins.ps1')
exit $LASTEXITCODE
