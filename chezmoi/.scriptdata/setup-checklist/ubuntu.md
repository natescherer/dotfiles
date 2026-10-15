# Ubuntu Setup Checklist

Manual steps that the Ansible playbook can't handle by itself. Check items off as you go; this
file is only written once.

## Finish Applying

- [ ] Reboot, so the lid-close setting takes effect and the `docker` group applies to your login

## Manual Installs

- [ ] [Yubico Authenticator](https://www.yubico.com/products/yubico-authenticator/)
- [ ] [Home Printer Drivers](https://epson.com/Support/Printers/All-In-Ones/ET-Series/Epson-ET-8500/s/SPT_C11CJ20201)
- No Linux build: Claude, AnyList, Paprika (use their web apps)

## Settings

- **Privacy & Security > Location**
  - [ ] Turn on Location Services, so the time zone can be set automatically
- **Bluetooth**
  - [ ] Pair devices
- **System > Users**
  - [ ] Enroll a fingerprint

## Login and Setup

- [ ] Proton Pass
  - [ ] Open on Startup
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
- [ ] Proton VPN
  - [ ] Set to run on startup
- [ ] Obsidian
  - [ ] Sync Main vault to ~/obsidian

## Simple Logins

- [ ] Disney+
- [ ] Microsoft 365
- [ ] Netflix
- [ ] Paramount+
- [ ] Prime Video
- [ ] Proton VPN
- [ ] VSCode
