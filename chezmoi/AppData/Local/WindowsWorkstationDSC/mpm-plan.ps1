#Requires -Version 7.0

# Checks for pending winget updates (via mpm) and posts a toast when updates are pending or the check
# fails. Only checks; installing is manual.
#
# Run by the mpm-plan Scheduled Task, which winget configuration registers. Unlike Homebrew under
# mpm, winget refreshes its own source metadata when stale, so no separate refresh step is needed.

$Mpm = Join-Path $HOME 'bin\mpm.exe'
$CacheDir = Join-Path $env:LOCALAPPDATA 'mpm-plan'
$PlanPath = Join-Path $CacheDir 'plan.json'
$TmpPath = "$PlanPath.tmp"
$LogPath = Join-Path $CacheDir 'plan.log'

New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null

# Checks weekly: the task fires daily so a failed check is retried, and this skips while the
# last successful check (plan.json is rewritten only on success) is newer
if ((Test-Path $PlanPath) -and (Get-Item $PlanPath).LastWriteTime -gt (Get-Date).AddDays(-7)) { return }
. (Join-Path $PSScriptRoot 'Send-Toast.ps1')

try {
  & $Mpm --no-color --table-format json outdated > $TmpPath 2> $LogPath
  $Status = $LASTEXITCODE
}
catch {
  $_ | Out-File -FilePath $LogPath
  $Status = 'not run'
}

if ($Status -eq 0) {
  Move-Item -Path $TmpPath -Destination $PlanPath -Force
  $Total = (Get-Content -Path $PlanPath -Raw | ConvertFrom-Json).PSObject.Properties.Value |
    ForEach-Object { @($_.packages).Count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
  if ($Total -gt 0) {
    Send-WindowsWorkstationDSCToast -Text 'Update(s) available', "mpm found $Total update(s). Run 'mpm sync && mpm outdated' to review them."
  }
}
else {
  Remove-Item -Path $TmpPath -ErrorAction SilentlyContinue
  Send-WindowsWorkstationDSCToast -Text "Couldn't check for updates", "mpm exited $Status; see $LogPath."
}
