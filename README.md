<h1 align="center">CachyOS Setup</h1>

<p align="center">
  <strong>
    My personal CachyOS setup with GNOME, automated with Ansible.
  </strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/CachyOS-Linux-00a3e0?style=flat-square&logo=archlinux&logoColor=white" alt="CachyOS">
  <img src="https://img.shields.io/badge/GNOME-Desktop-4a86cf?style=flat-square&logo=gnome&logoColor=white" alt="GNOME">
  <img src="https://img.shields.io/badge/Ansible-Automation-ee0000?style=flat-square&logo=ansible&logoColor=white" alt="Ansible">
</p>

<p align="center">
  <img src="./desktop.png" alt="CachyOS desktop with GNOME and Dash to Panel" width="1280">
</p>

## Software

| Purpose                | Choice                                                                                                                                                                                                     |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Terminal               | [**Ghostty**](https://github.com/ghostty-org/ghostty)                                                                                                                                                      |
| System monitoring      | [**Mission Center**](https://gitlab.com/mission-center-devs/mission-center)                                                                                                                                |
| DNS provider           | [**NextDNS**](https://nextdns.io/) via [**systemd-resolved**](https://github.com/systemd/systemd) — routes all system DNS queries over DNS-over-TLS with DNSSEC validation                                 |
| Audio player           | [**Gapless**](https://gitlab.gnome.org/neithern/g4music)                                                                                                                                                   |
| Video player           | [**mpv**](https://github.com/mpv-player/mpv) — custom [**MVUtensils**](https://github.com/myrsloik/mvutensils) motion interpolation for TV-style motion smoothing, toggled with `Shift+I`                  |
| Web browser            | [**Firefox**](https://github.com/mozilla-firefox/firefox)                                                                                                                                                  |
| Code editor            | [**Visual Studio Code**](https://github.com/microsoft/vscode)                                                                                                                                              |
| AI coding agents       | [**Codex CLI**](https://github.com/openai/codex), [**Claude Code**](https://code.claude.com/docs/en/overview), and [**Antigravity CLI**](https://antigravity.google) |
| Claude desktop app     | [**claude-desktop**](https://aur.archlinux.org/packages/claude-desktop) (AUR) |
| Netflix browser        | **Opera** — the only browser that gives me 1080p Netflix playback on Linux                                                                                                                                 |
| Proton version manager | [**ProtonPlus**](https://github.com/Vysp3r/ProtonPlus) — manages [Proton-GE](https://github.com/GloriousEggroll/proton-ge-custom) and [Proton-CachyOS](https://github.com/CachyOS/proton-cachyos) versions |
| System upgrades        | [**Topgrade**](https://github.com/topgrade-rs/topgrade) — centralizes upgrades across packages, tools, and runtimes; replaces the preinstalled `cachy-update` and Shelly, which are removed |

Ankama Launcher is installed from the AUR with my saved Dofus display presets:
“Affichage Fournux” and “Combat Fournux”, which hides the minimap during fights.
Dofus's preset file is a symlink to `roles/ankama/files/dofus-preset.json`, so
preset changes made in game show up in `git status`. Applying the presets and
setting “Combat Fournux” as the fight preset is done in game, once per account.
Run `./bootstrap.sh run --tags ankama` to apply this role on its own.

## Fresh install

1. Install CachyOS with the **GNOME** desktop and the **Limine** bootloader, and set the hostname to the machine's inventory name (`cachyos-desktop` or `cachyos-laptop`). The playbook stops early when one of these is missing.
2. Log in to GNOME and open a terminal there: GNOME settings and extensions are only applied from inside a GNOME session.
3. Clone this repository and run `./bootstrap.sh upgrade`. It upgrades the system, then installs Ansible, the linters, yay, and the pinned Galaxy collections.
4. Restore the vault password into `.vault-password`, then run `chmod 600 .vault-password`.
5. Run `./bootstrap.sh run`, then reboot so the login shell, `environment.d`, kernel module, and initramfs changes apply.
6. Run `./bootstrap.sh run` again. The recap should report `changed=0`; any other count points to a task that is not idempotent.

GWToolbox settings are deployed only once Guild Wars is installed in Steam. Run
`./bootstrap.sh run --tags gwtoolbox` after installing it.

## AI coding agents

Codex, Claude Code, and Antigravity share the skills in `~/.agents/skills`, the
global instructions in `roles/ai_agents/files/agents/AGENTS.md`, Serena, Context7,
and the `i-have-adhd` plugin. Claude Code uses the native installer with automatic
updates and signs in with your Claude subscription. Run `claude` after setup to
sign in. Its `~/.claude/skills` directory contains individual links to the configured
shared skills. Ansible preserves existing user state when configuring MCP servers
in `~/.claude.json`. Codex reads the managed settings from `/etc/codex/config.toml`, a
system layer under `~/.codex/config.toml`, so Codex keeps its own state there
(project trust, notices, plugins). The `ai_agents` role installs its own Bun, uv, and rustup
dependencies, so `./bootstrap.sh run --tags claude` works on its own.

## Machine profiles

The shared playbook configures both machines. Each machine is an inventory host
named after its hostname, in the `desktop` or `laptop` group, and
`./bootstrap.sh` limits the play to the host matching `uname -n`. Values that
identify one machine, such as its NextDNS device name, live in
`host_vars/<hostname>/`. Packages and settings for a machine type live in
`group_vars/desktop/` and `group_vars/laptop/`, and the `desktop` and `laptop`
roles only hold hardware-specific tasks, so they do not leak between machines.

| Group     | Hostname          | Additional configuration                                          |
| --------- | ----------------- | ----------------------------------------------------------------- |
| `desktop` | `cachyos-desktop` | [**Wootility**](https://github.com/WootingKb/wootility-linux), Wake-on-LAN, and no automatic suspend |
| `laptop`  | `cachyos-laptop`  | `asusctl`, `supergfxctl`, `rog-control-center`, and `solaar`; `supergfxd` is enabled and started                                        |

## GNOME extensions

- [**Dash to Panel**](https://github.com/home-sweet-gnome/dash-to-panel) — provides a horizontal taskbar similar to Windows.
- [**Vitals**](https://github.com/corecoding/Vitals) — displays and monitors system temperatures.

## Manual assets

- `show-elgato-output.sh` is a validated standalone helper. Run `./show-elgato-output.sh --help`; its default capture device is machine-specific and can be overridden with `--video-device` and `--sound-device`.

## Appearance

- **Icon theme:** [**Papirus**](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
- **Default system font:** [**FreeSans**](https://www.gnu.org/software/freefont/) 12
- **Terminal font:** [**Inconsolata Medium**](https://github.com/googlefonts/Inconsolata) 14

## Ansible Vault password

> `vault_password_file` is intentionally omitted from `ansible.cfg`; `bootstrap.sh` supplies it only for `run` and `check`, so lint and CI do not depend on a local secret.
