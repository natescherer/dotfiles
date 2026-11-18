## WARNING: This file is chezmoi-managed and should not be manually edited!

#Requires -Version 7.0

# Shrinks Docker Desktop's data disk (docker_data.vhdx), which grows as images and build cache
# pile up but never shrinks on its own:
# 1. Prunes all build cache and every image no container uses (and, with -PruneVolumes, every
#    unused volume), freeing space inside the disk's ext4 file system.
# 2. Runs fstrim in the docker-desktop distro to mark that space unused. Windows compaction
#    can't read free space in ext4, so it reclaims only trimmed or zeroed blocks.
# 3. Stops Docker Desktop and WSL, then compacts the file with diskpart, which needs no Hyper-V
#    tools. diskpart needs elevation, so this shows one UAC prompt.
# Leaves Docker Desktop stopped. Asks for confirmation first; pass -Confirm:$false to skip it.
function Compress-DockerData {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param(
    # Docker Desktop's default location; pass the file under Settings > Resources > Advanced >
    # Disk image location if that was changed.
    [string] $Path = (Join-Path $env:LOCALAPPDATA 'Docker\wsl\disk\docker_data.vhdx'),
    [switch] $PruneVolumes
  )
  $ErrorActionPreference = 'Stop'
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "No Docker data disk at $Path. Pass -Path if Docker Desktop's disk image location was changed."
  }
  $Before = (Get-Item -LiteralPath $Path).Length
  $Removes = if ($PruneVolumes) { 'unused images, build cache, and volumes' } else { 'unused images and build cache' }
  if (-not $PSCmdlet.ShouldProcess("$Path ($([math]::Round($Before / 1GB, 1)) GB)", "Remove $Removes, then compact")) {
    return
  }

  # Pruning and trimming need the engine running, so the data disk is mounted.
  docker info *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Host 'Starting Docker Desktop...' -ForegroundColor Cyan
    docker desktop start
    if ($LASTEXITCODE -ne 0) { throw "Couldn't start Docker Desktop (exit code $LASTEXITCODE)." }
  }
  docker system df

  Write-Host "`nRemoving $Removes..." -ForegroundColor Cyan
  docker builder prune --all --force
  if ($LASTEXITCODE -ne 0) { throw "docker builder prune failed (exit code $LASTEXITCODE)." }
  docker image prune --all --force
  if ($LASTEXITCODE -ne 0) { throw "docker image prune failed (exit code $LASTEXITCODE)." }
  if ($PruneVolumes) {
    docker volume prune --all --force
    if ($LASTEXITCODE -ne 0) { throw "docker volume prune failed (exit code $LASTEXITCODE)." }
  }

  Write-Host "`nTrimming free space..." -ForegroundColor Cyan
  wsl.exe -d docker-desktop -- fstrim -av
  if ($LASTEXITCODE -ne 0) { throw "fstrim in the docker-desktop distro failed (exit code $LASTEXITCODE)." }

  Write-Host "`nStopping Docker Desktop and WSL..." -ForegroundColor Cyan
  docker desktop stop
  if ($LASTEXITCODE -ne 0) { throw "Couldn't stop Docker Desktop (exit code $LASTEXITCODE)." }
  wsl.exe --shutdown
  # diskpart can't attach the file while anything holds it open.
  $Deadline = (Get-Date).AddSeconds(60)
  while ($true) {
    try {
      [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None').Dispose()
      break
    }
    catch [System.IO.IOException] {
      if ((Get-Date) -gt $Deadline) { throw "$Path is still in use 60 seconds after shutting down WSL." }
      Start-Sleep -Seconds 2
    }
  }

  Write-Host "`nCompacting $Path (approve the UAC prompt)..." -ForegroundColor Cyan
  $Script = Join-Path $env:TEMP 'compress-dockerdata.diskpart.txt'
  $Log = Join-Path $env:TEMP 'compress-dockerdata.diskpart.log'
  @("select vdisk file=`"$Path`"", 'attach vdisk readonly', 'compact vdisk', 'detach vdisk') |
    Set-Content -LiteralPath $Script -Encoding ascii
  # Start-Process can't capture an elevated process's output, so cmd redirects it to a file.
  $Diskpart = Start-Process -FilePath cmd.exe -ArgumentList "/c diskpart /s `"$Script`" > `"$Log`" 2>&1" `
    -Verb RunAs -WindowStyle Hidden -Wait -PassThru
  Get-Content -LiteralPath $Log -ErrorAction SilentlyContinue | Where-Object { $_.Trim() } | ForEach-Object { "  $_" }
  Remove-Item -LiteralPath $Script, $Log -ErrorAction SilentlyContinue
  if ($Diskpart.ExitCode -ne 0) { throw "diskpart failed (exit code $($Diskpart.ExitCode))." }

  $After = (Get-Item -LiteralPath $Path).Length
  Write-Host ("`n{0:N1} GB -> {1:N1} GB, {2:N1} GB reclaimed. Docker Desktop is stopped; start it when you need it." -f
    ($Before / 1GB), ($After / 1GB), (($Before - $After) / 1GB)) -ForegroundColor Green
}
