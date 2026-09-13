#Requires -Version 7.0

# run_once_, not run_after_ or run_onchange_after_: unlike taskbar-pins/tray-pins/desktop-icons,
# nothing external fights the desktop wallpaper once it's set, so this doesn't need to self-heal on
# every apply -- chezmoi's own content hash tracking (in its state file) is enough to run this
# exactly once and never again, even across future `chezmoi apply` runs. Still lives under
# 41-windows/ (a run_after_ semantically, since the "once" and "after" prefixes compose) so
# %USERPROFILE%\Pictures\wallpaper-chezmoi\ -- a regular chezmoi-managed directory -- is guaranteed
# already on disk by the time this runs; see
# https://www.chezmoi.io/reference/application-order/ and run_after_desktop-icons.ps1's comment
# for the same reasoning.

$WallpaperPath = Join-Path $env:USERPROFILE 'Pictures\wallpaper-chezmoi\windows-default.jpg'

if (-not (Test-Path $WallpaperPath)) {
  # run_once_ only records success on a zero exit -- exiting 0 here would permanently mark the
  # wallpaper as "set" even though it never was. Exiting non-zero makes chezmoi retry this script
  # on every future apply until the file actually exists.
  Write-Host "Warning: '$WallpaperPath' does not exist; skipping wallpaper setup. Exiting non-zero so chezmoi retries on the next apply." -ForegroundColor Yellow
  exit 1
}

Write-Host "`nSetting wallpaper to '$WallpaperPath'..." -ForegroundColor Green

# WallpaperStyle 10 = "Fill" (crop to fill the screen, preserving aspect ratio) -- a reasonable
# default regardless of each image's own resolution/aspect ratio. TileWallpaper must be explicitly
# 0 or Windows tiles instead of applying the WallpaperStyle at all. Both are read by
# SystemParametersInfo below at the moment it applies the wallpaper, so they must be set first.
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'

# SystemParametersInfo(SPI_SETDESKWALLPAPER) is the only way to change the wallpaper that takes
# effect immediately for the current session -- writing the registry value alone (as above) only
# takes effect at next login. No built-in PowerShell cmdlet wraps this; P/Invoke is required.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WindowsWorkstationDSCWallpaper {
  [DllImport("user32.dll", CharSet = CharSet.Auto)]
  public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@

$SPI_SETDESKWALLPAPER = 0x0014
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDCHANGE = 0x02

$Result = [WindowsWorkstationDSCWallpaper]::SystemParametersInfo(
  $SPI_SETDESKWALLPAPER, 0, $WallpaperPath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE)

if ($Result -eq 0) {
  Write-Host "Warning: SystemParametersInfo failed to set the wallpaper." -ForegroundColor Yellow
  exit 1
}

Write-Host "Wallpaper set to '$WallpaperPath'." -ForegroundColor Green
