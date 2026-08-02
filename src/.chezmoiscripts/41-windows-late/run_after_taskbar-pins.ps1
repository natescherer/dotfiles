#Requires -Version 7.0

# Real logic lives at the stable path below (a regular chezmoi-managed file, guaranteed already on
# disk by the time any run_after_ script executes -- see
# https://www.chezmoi.io/reference/application-order/) so it can be invoked identically from here
# (during `chezmoi apply`) and directly by the login-autostart Run key registered in
# pins-autostart.ps1, which has no chezmoi available. Plain run_after_, not run_onchange_after_,
# so this stays self-healing: see the "runs unconditionally" note atop taskbar-pins.ps1 itself for
# why the underlying script needs to run every time rather than only when its content changes.
& (Join-Path $env:LOCALAPPDATA 'WindowsWorkstationDSC\taskbar-pins.ps1')
exit $LASTEXITCODE
