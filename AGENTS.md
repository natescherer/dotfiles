# Notes for AI Agents

## Git workflow

- Because this is a dotfiles repo, commitng directly to main is allowed

## Chezmoi workflow

- Always pass `--use-builtin-diff` when running `chezmoi diff`. The user might
  use an interactive, GUI diff tool like Visual Studio Code.

## Choosing a package manager

Use mise only for development environments that might need different versions
installed, such as language runtimes and their toolchains.

Install everything else through the per-platform package lists, keeping them
in sync:

- Windows: the winget configuration
- macOS and Ubuntu: their separate Ansible Homebrew lists
- NixOS: the Nix package lists
- Servers, WSL, and devcontainers: the mise config for the dotfiles' own tools,
  since mise is the one package manager all of them can rely on. NixOS servers
  are the exception: their flake provides these tools, since mise's generic
  Linux binaries don't run on NixOS.

## Renovate `schedule` cron syntax is not standard cron

Renovate's `schedule` option (see `renovate.json` / `template/renovate.json.jinja`)
looks like 5-field cron but isn't interpreted the same way:

- The minutes field **must** be `*`: Renovate doesn't support minute-level
  granularity, and a schedule that restricts it is invalid.
- A cron schedule defines an allowed **time window**, not an exact trigger
  instant: Renovate itself runs on its own polling cadence (external to
  this repo) and only acts during the window the schedule describes.

So `"* 0 1 * *"` is the *correct* idiomatic form for "once a month, on the
1st, during hour 0"; it is not a bug, even though it looks like a broken
"every minute" cron at a glance. Do not change it to `"0 0 1 * *"` (a
standard-cron-style fix): that's invalid for Renovate specifically, since it
constrains the minutes field.

Reference: <https://docs.renovatebot.com/key-concepts/scheduling/>
