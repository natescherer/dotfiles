# NixOS Setup

The repo's flake installs NixOS with a KDE Plasma desktop. Two hosts exist:

| Host | Product | Architecture |
| --- | --- | --- |
| `nixos-vmw-wk` | VMware Workstation | x86_64 |
| `nixos-vmw-fus` | VMware Fusion on Apple Silicon | aarch64 |

## Preflight

1. Log in to the Proton Pass CLI on your workstation with `pass-cli login`. The
   devcontainer reads the host key from it.
1. Open this repo in its devcontainer.
1. Create a VM with UEFI firmware, an NVMe disk, and 3D acceleration on.
1. Boot the VM from the [NixOS minimal installer](https://nixos.org/download/)
   for its architecture.
1. On the VM, run `passwd` to set a temporary password for the `nixos` user, and
   run `ip a` to find its address.

## Installation

From the devcontainer, run the task below, giving the temporary password when
prompted. It erases the VM's disk.

```shell
mise run nixos-install nixos-vmw-wk <address>
```

After the VM reboots, log in to Plasma as `nate` and run the below in a terminal:

```shell
mise use -g python@latest
eval "$(mise env -s zsh)"
chezmoi init --apply natescherer
```

Answer yes when asked whether your account has sudo rights.

## Updates

- **System:** run
  `sudo nixos-rebuild switch --flake github:natescherer/dotfiles --refresh`.
  Renovate updates the flake's `nixos-unstable` pin monthly.
- **Dotfiles:** run `chezmoi update`.

## Secrets

`nixos/secrets.yaml` holds each host's password hash, encrypted to one SSH key
that every host shares as its host key. Edit it from the devcontainer with
`sops nixos/secrets.yaml`. A new host needs its own `nate@<host>_passwordhash`
entry, created with `mkpasswd -m yescrypt`.

## Known Gaps

- nixpkgs has no Claude Desktop package.
- `nixos-vmw-fus` lacks Discord, Proton Mail, Proton Pass Desktop, and Slack, which
  have no aarch64 build.
- Flat mouse acceleration and tap-to-click aren't set, since KWin stores them per
  input device.
- Copying from the guest to the host covers text only, through a bridge service.
  Native Wayland apps can't copy images or files out.
