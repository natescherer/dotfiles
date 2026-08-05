#Requires -Version 7.0

# Depends on winget configuration having already applied
& (Join-Path $env:LOCALAPPDATA 'WindowsWorkstationDSC\tray-pins.ps1')
exit $LASTEXITCODE
