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
