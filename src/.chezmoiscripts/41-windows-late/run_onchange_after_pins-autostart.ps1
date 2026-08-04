#Requires -Version 7.0

# Registers taskbar-pins.ps1, tray-pins.ps1, and desktop-icons.ps1 (at their stable path,
# %LOCALAPPDATA%\WindowsWorkstationDSC\) to rerun quietly at every login, so newly-installed
# software (or an app someone finally signed into) gets pinned/cleaned up without waiting for
# someone to remember to run `chezmoi apply`. A plain HKCU Run key entry, not a Scheduled Task --
# nothing here needs elevation, complex triggers, or Task Scheduler's run-history UI, and a Run key
# is the same mechanism this machine's own installed apps already use for "run something at login"
# (see e.g. the ProtonDrive/UniGetUI/Docker Desktop entries already in this same registry key).
#
# The Run key command invokes the three stable-path scripts directly (no chezmoi involved at all)
# -- all three are self-contained specifically so this works: the future standalone
# WindowsWorkstationDSC module this is the seed of won't have chezmoi available either, and can
# register this exact same kind of Run key pointing at its own installed copies.
#
# -WindowStyle Hidden suppresses the wrapping PowerShell console; pwsh.exe may still flash a
# console window very briefly on some Windows builds since it's a separate console subprocess --
# a cosmetic quirk shared by every "hide a console app at login" mechanism on Windows, Scheduled
# Tasks included, not something specific to this approach. The two pin scripts only emit a toast
# (via Send-Toast.ps1 -> BurntToast) when they actually change something, and desktop-icons.ps1
# never emits one at all (Write-Host only -- see its own comments), so running all three
# unconditionally at every login stays silent in the common case.
#
# BurntToast itself is installed declaratively by winget configuration, and will need to be set as a dependency when this is built into a DSC module.

Write-Host "`nRegistering tray/taskbar pin and desktop-icon-cleanup scripts for login autostart..." -ForegroundColor Green

$PwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $PwshExe) {
  throw "Could not resolve pwsh.exe on PATH -- cannot register the login autostart entry."
}

$StableDir = Join-Path $env:LOCALAPPDATA 'WindowsWorkstationDSC'
$Targets = @(
  (Join-Path $StableDir 'taskbar-pins.ps1')
  (Join-Path $StableDir 'tray-pins.ps1')
  (Join-Path $StableDir 'desktop-icons.ps1')
)
$QuotedTargets = ($Targets | ForEach-Object { "& '$_'" }) -join '; '

# -EncodedCommand sidesteps the quoting mess of nesting a multi-statement command line inside a
# single Run key string value -- the inner command is plain PowerShell syntax, not something that
# has to survive cmd.exe/registry-string escaping rules.
$EncodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($QuotedTargets))
$Command = "`"$PwshExe`" -NoProfile -WindowStyle Hidden -EncodedCommand $EncodedCommand"

$RunKeyName = 'WindowsWorkstationDSC'
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $RunKeyName -Value $Command

Write-Host "Registered -- pin and desktop-icon-cleanup scripts will rerun quietly at every login from now on." -ForegroundColor Green
