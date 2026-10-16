{{- $os := .chezmoi.os -}}
{{- $sep := "/" }}{{ if eq $os "windows" }}{{ $sep = "\\" }}{{ end -}}
# {{ get (dict "darwin" "macOS" "linux" "Ubuntu" "windows" "Windows") $os }} Setup Checklist

Manual steps that {{ if eq $os "windows" }}WinGet Configuration{{ else }}the Ansible playbook{{ end }} can't handle by itself. Check items off as you go; this
file is only written once.

## Finish Applying

- [ ] Reboot to ensure all settings have taken effect

## Manual Installs
{{ if ne $os "linux" }}
- [ ] [VMware](https://archive.org/download/vmwareworkstationarchive/)
{{- end }}
- [ ] [Home Printer Drivers](https://epson.com/Support/Printers/All-In-Ones/ET-Series/Epson-ET-8500/s/SPT_C11CJ20201)
{{- if eq $os "linux" }}
- No Linux build: Claude, AnyList, Paprika (use their web apps)
{{- end }}

## Settings
{{ if eq $os "darwin" }}
### Settings.app

- **Wi-FI**
  - [ ] Turn off Private Wi-Fi address for home network
- **Bluetooth**
  - [ ] Pair devices
- **Menu Bar**:
  - [ ] Enable `Show menu bar background`
- **Touch ID & Password**
  - [ ] Enroll a fingerprint.

### Finder

- **Sidebar**
  - [ ] Uncheck `Shared`,
  - [ ] Uncheck `iCloud Drive`
  - [ ] Uncheck `AirDrop`
  - [ ] Uncheck `Bonjour computers`
  - [ ] Uncheck `Connected servers`
{{- else if eq $os "windows" }}
- [ ] Activate Windows

### Settings App

- System
  - Display
    - [ ] Night Light
    - [ ] Use HDR
  - Sound
    - [ ] Disable devices you don't plan on using
  - Power
    - [ ] Power Mode
    - [ ] Power & sleep button controls
- Network & internet
  - [ ] Change network connection to private for home network
- Personalization
  - [ ] Background
  - Colors
    - [ ] Accent color
  - [ ] Dynamic Lighting
  - [ ] Lock screen
  - [ ] Start

### Control Panel

- ncpa.cpl
  - [ ] Disable unneeded connections
{{- else }}
- **Privacy & Security > Location**
  - [ ] Turn on Location Services, so the time zone can be set automatically
- **Bluetooth**
  - [ ] Pair devices
- **System > Users**
  - [ ] Enroll a fingerprint
{{- end }}

## Login and Setup

- [ ] Docker Desktop
  - [ ] Ensure socket is enabled
- [ ] Proton Pass Desktop
  - [ ] Open on Startup
  - [ ] Set unlock mode
  - [ ] Enable SSH Agent
- [ ] Firefox
  - [ ] Install Proton Pass & Login
  - Proton Pass Extension Settings
    - [ ] Auto-copy 2FA Code
    - [ ] Basic auth autofill
    - [ ] Use Proton Pass as your browser's default password manager
    - [ ] Unlock with PIN Code
  - [ ] Set up Sync
  - [ ] Set search engine
  - [ ] Remove VPN from toolbar and pin extensions
  - [ ] Dark Reader extension settings
  - [ ] Disable `Save and autofill payment info`
  - [ ] Disable `Save and autofill addresses`
  - [ ] Disable all under `Firefox data collection and use`
- [ ] Brave
  - [ ] Set up sync
  - [ ] Set search engine
  - Appearance
    - Customize your toolbar
      - [ ] Disable VPN
      - [ ] Disable Leo AI
      - [ ] Disable Wallet
      - [ ] Disable Rewards
{{- if eq $os "darwin" }}
- [ ] Ghostty
  - [ ] Enable self update
{{- end }}
- [ ] Proton VPN
  - [ ] Set to run on startup
{{- if eq $os "windows" }}
- [ ] NVIDIA App
  - [ ] Install drivers
{{- end }}
- [ ] Obsidian
  - [ ] Sync Main vault to ~{{ $sep }}obsidian
{{- if eq $os "windows" }}
  - [ ] Set up backup in Proton Drive
- [ ] PrusaSlicer
  - [ ] Do initial run, then copy over old config
- [ ] WinRAR
  - [ ] Do file associations
{{- else if eq $os "darwin" }}
- [ ] Rectangle
  - [ ] Grant permissions
  - [ ] Set to open at login
{{- end }}

## Simple Logins
{{ if eq $os "windows" }}
- [ ] Apple Music
- [ ] Apple TV
{{- end }}
- [ ] Disney+
{{- if eq $os "windows" }}
- [ ] Dolby Access
{{- end }}
- [ ] Microsoft 365
- [ ] Netflix
{{- if ne $os "linux" }}
- [ ] Paprika
{{- end }}
- [ ] Paramount+
- [ ] Prime Video
- [ ] Proton VPN
- [ ] VSCode
{{- if eq $os "windows" }}

## Manual Config

- VLC
  - [ ] Interface > Use Dark Palette
{{- end }}
