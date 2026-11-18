#Requires -Version 7.0

# Elevated half of the winget configure chezmoi script. That script starts this worker once per
# run, so applying every elevated configuration file costs a single UAC prompt instead of one
# per file. The worker polls a queue directory for requests, runs each through winget, and
# reports back through files in the same directory:
#
#   request-<id>.json  written by the caller: { Kind, Args }
#   worker-<id>.log    winget's output, appended line by line as it runs
#   result-<id>.json   written last: { ExitCode }
#
# Requests come from a directory the unelevated user can write to, so the worker runs only
# winget, and only with arguments it validates itself: `configure` against a *.winget file
# directly under -ConfigDir. It exits on a `stop` request, or once the process that started it
# is gone.

param(
  [Parameter(Mandatory)] [string] $QueueDir,
  [Parameter(Mandatory)] [string] $ConfigDir,
  [Parameter(Mandatory)] [int] $ParentPid
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# `winget configure` flags that take no value and change nothing about what gets applied.
$AllowedConfigureFlags = @(
  '--accept-configuration-agreements'
  '--disable-interactivity'
  '--suppress-initial-details'
  '--verbose-logs'
  '--ignore-warnings'
)

# Whether $Path resolves to a file directly inside $Dir.
function Test-PathInDirectory {
  param([string] $Path, [string] $Dir)
  $FullPath = [System.IO.Path]::GetFullPath($Path)
  $FullDir = [System.IO.Path]::GetFullPath($Dir).TrimEnd('\') + '\'
  return ([System.IO.Path]::GetDirectoryName($FullPath) + '\') -ieq $FullDir
}

# Turns a request into the winget argument list to run, or throws if the request isn't allowed.
function Get-WingetArgumentList {
  param($Request)
  switch ($Request.Kind) {
    'configure' {
      $In = @($Request.Args)
      $Out = [System.Collections.Generic.List[string]]::new()
      $Out.Add('configure')
      $HasFile = $false
      for ($i = 0; $i -lt $In.Count; $i++) {
        $Arg = $In[$i]
        if ($Arg -eq '-f') {
          $Path = $In[++$i]
          if (-not ($Path -like '*.winget' -and (Test-PathInDirectory -Path $Path -Dir $ConfigDir) -and (Test-Path -LiteralPath $Path -PathType Leaf))) {
            throw "rejected configuration file '$Path': not a *.winget file directly under $ConfigDir"
          }
          $Out.Add('-f'); $Out.Add($Path)
          $HasFile = $true
        }
        elseif ($Arg -in $AllowedConfigureFlags) {
          $Out.Add($Arg)
        }
        else {
          throw "rejected configure argument '$Arg'"
        }
      }
      if (-not $HasFile) { throw "configure request has no -f argument" }
      return $Out.ToArray()
    }
    default {
      throw "unknown request kind '$($Request.Kind)'"
    }
  }
}

# Drops winget's progress-spinner and progress-bar redraws, which only make sense on a live
# console, and keeps the text after the last carriage return of each line.
function Format-WingetLine {
  param([string] $Line)
  $Line = ($Line -split "`r")[-1].TrimEnd()
  if ($Line -match '^\s*[-\\|/]?\s*$') { return $null }
  if ($Line -match '[\u2588\u2592]') { return $null }  # progress-bar block characters
  return $Line
}

# Written by rename so the caller never reads a half-written file.
function Write-QueueFile {
  param([string] $Path, [string] $Content)
  Set-Content -Path "$Path.tmp" -Value $Content
  Move-Item -Path "$Path.tmp" -Destination $Path -Force
}

Write-QueueFile -Path (Join-Path $QueueDir 'ready') -Content $PID

while (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue) {
  $RequestFile = Get-ChildItem -Path $QueueDir -Filter 'request-*.json' -File | Sort-Object Name | Select-Object -First 1
  if (-not $RequestFile) {
    Start-Sleep -Milliseconds 250
    continue
  }
  $Id = $RequestFile.BaseName -replace '^request-', ''
  $LogFile = Join-Path $QueueDir "worker-$Id.log"
  $ExitCode = 1
  try {
    $RequestJson = Get-Content -Path $RequestFile.FullName -Raw
    Remove-Item -Path $RequestFile.FullName -Force
    $Request = $RequestJson | ConvertFrom-Json
    if ($Request.Kind -eq 'stop') { break }
    $WingetArgs = Get-WingetArgumentList -Request $Request
    & winget @WingetArgs 2>&1 | ForEach-Object {
      $Line = Format-WingetLine -Line "$_"
      if ($null -ne $Line) { Add-Content -Path $LogFile -Value $Line }
    }
    $ExitCode = $LASTEXITCODE
  }
  catch {
    Add-Content -Path $LogFile -Value "worker: $($_.Exception.Message)"
  }
  Write-QueueFile -Path (Join-Path $QueueDir "result-$Id.json") -Content (@{ ExitCode = $ExitCode } | ConvertTo-Json -Compress)
}
