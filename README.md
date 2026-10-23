# My Dotfiles

Small, focused collection of personal configuration files and scripts managed with chezmoi.

- The scripts here are primarily intended for Arch Linux systems, but may work on other distributions with some modifications.
- You're free to use them however you'd like; just make sure to review them before applying them on a new machine.
- For help on how to use chezmoi, you can check <https://www.chezmoi.io>

## Initial setup

For convenience (mostly mine), this repository includes a setup script for new Arch Linux installations. To set up a new machine, download and run the [first-run setup script](setup/setup_1st_run.sh).

You might be able to run the script directly using `curl`. For example, assumming the script is hosted on GitHub by user `NeoAdonis` in repository `dotfiles`:

```bash
curl -fsSL https://raw.githubusercontent.com/NeoAdonis/dotfiles/refs/heads/main/setup/setup_1st_run.sh | sudo bash -s -- [new_username] [shell=zsh|bash|fish]
```

## Setup scripts

Besides the dotfiles themselves, the [setup](setup/) directory holds scripts to get a fresh machine from a bare install to a usable system. They aren't applied by chezmoi; run them by hand, picking the ones that fit the machine. In general, they:

- Bootstrap the system: set the locale, tweak `pacman` and `makepkg`, create a sudo user and, under WSL, write its configuration.
- Install the AUR helper (`yay`) and packages from grouped lists (base, desktop, development, gaming, theming, etc.), so a machine only gets what it needs.
- Configure system services, such as hardening `sshd`, enabling OTP for remote SSH logins and setting up `ufw` firewall rules.

Most scripts check their requirements first, and some describe what they're about to do and wait for confirmation, but others might apply their changes right away.

> [!WARNING]
> These scripts change important parts of the system, such as `sudoers`, PAM, the SSH server and the firewall, and a mistake there can lock you out of the machine. Read them before running them, and verify the results afterwards.
