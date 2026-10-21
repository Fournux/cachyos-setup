# AI Agent Directives

## Core Principles

1. **Fresh Install Baseline (Clean Slate Only)**
   - The Ansible repository is designed to run exclusively on a **fresh, clean CachyOS / Arch Linux installation**.
   - Playbooks and roles must define the **desired target state** from a pristine base system.

2. **No Migration or Legacy Cleanup Tasks**
   - **Never add cleanup / migration / transition tasks** to delete files, configurations, or packages that belonged to older versions of the repository (e.g., deleting leftover config files like `70-rbenv.conf` for dropped tools).
   - When a package or configuration is dropped from the target stack, simply remove it from the role/playbook. Do not add `state: absent` cleanup tasks to accommodate previous local runs.

3. **Clean Idempotence**
   - Tasks must be idempotent and declare the necessary target state without accumulating backward-compatibility debt or historical migration logic.

## Repository Conventions

4. **Role Boundaries**
   - A package without managed configuration is a list entry in `roles/packages/defaults/main.yml` (pacman, AUR, or Flatpak).
   - A package with managed configuration is installed by the role that configures it.
   - A role owns its files, including its own `~/.config/environment.d/70-<name>.conf` drop-in.

5. **Machine Differences**
   - Values that identify one machine go in `host_vars/<hostname>/main.yml`.
   - Values shared by a machine type go in `group_vars/<group>/main.yml`, including `packages_extra_pacman_packages` and `packages_extra_aur_packages`.
   - The `desktop` and `laptop` roles only hold tasks for hardware specific to that machine type.

6. **Configuration Files**
   - Prefer drop-in directories (`*.conf.d`, `environment.d`, `modprobe.d`) over rewriting files owned by packages.
   - Overwrite a user config file only when the application never writes to it. Otherwise use the application's lower-priority config layer (as with `/etc/codex/config.toml`), merge into the file (as with `~/.claude.json`), or deploy it once with `force: false`.
