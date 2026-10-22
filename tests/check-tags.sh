#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
cd "$ROOT_DIR"

list_tasks() {
  ansible-playbook site.yml --list-tasks --tags "$1"
}

require_task() {
  local output="$1"
  local task="$2"
  grep -Fq -- "$task" <<<"$output" || {
    printf 'Expected tagged task was missing: %s\n' "$task" >&2
    exit 1
  }
}

reject_task() {
  local output="$1"
  local task="$2"
  if grep -Fq -- "$task" <<<"$output"; then
    printf 'Unrelated task leaked into tag selection: %s\n' "$task" >&2
    exit 1
  fi
}

gdm_tasks="$(list_tasks gdm)"
require_task "$gdm_tasks" 'gnome : Configure GDM dconf profile'
reject_task "$gdm_tasks" 'gnome : Download compatible GNOME extension archives'

dconf_tasks="$(list_tasks dconf)"
require_task "$dconf_tasks" 'gnome : Dump current dconf state'
reject_task "$dconf_tasks" 'gnome : Download compatible GNOME extension archives'

dotfiles_tasks="$(list_tasks dotfiles)"
require_task "$dotfiles_tasks" 'dotfiles : Deploy Ghostty config'
require_task "$dotfiles_tasks" 'dotfiles : Deploy Topgrade config'
reject_task "$dotfiles_tasks" 'ai_agents : Install Claude Code'

ai_agents_tasks="$(list_tasks ai_agents)"
require_task "$ai_agents_tasks" 'ai_agents : Install agent tool dependencies'
require_task "$ai_agents_tasks" 'ai_agents : Configure rustup default toolchain'
require_task "$ai_agents_tasks" 'ai_agents : Install Codex CLI'
require_task "$ai_agents_tasks" 'ai_agents : Install Claude Code'
require_task "$ai_agents_tasks" 'ai_agents : Install Antigravity CLI'
reject_task "$ai_agents_tasks" 'packages : Install pacman packages'

claude_tasks="$(list_tasks claude)"
require_task "$claude_tasks" 'ai_agents : Install agent tool dependencies'
require_task "$claude_tasks" 'ai_agents : Configure rustup default toolchain'
require_task "$claude_tasks" 'ai_agents : Add rust-analyzer component'
require_task "$claude_tasks" 'ai_agents : Install agent skills'
require_task "$claude_tasks" 'ai_agents : Install Serena via uv tool'
require_task "$claude_tasks" 'ai_agents : Install Claude Code'
require_task "$claude_tasks" 'ai_agents : Deploy Claude Code global instructions'
require_task "$claude_tasks" 'ai_agents : Deploy Claude Code MCP config preserving user state'
require_task "$claude_tasks" 'ai_agents : Install i-have-adhd plugin for Claude Code'
reject_task "$claude_tasks" 'ai_agents : Install Codex CLI'
reject_task "$claude_tasks" 'ai_agents : Install Antigravity CLI'

codex_tasks="$(list_tasks codex)"
require_task "$codex_tasks" 'ai_agents : Deploy Codex system config'
reject_task "$codex_tasks" 'ai_agents : Deploy Claude Code settings'

flatpak_tasks="$(list_tasks flatpak)"
require_task "$flatpak_tasks" 'packages : Install Flatpak'
require_task "$flatpak_tasks" 'packages : Install Flatpak packages'

packages_tasks="$(list_tasks packages)"
require_task "$packages_tasks" 'packages : Install pacman packages'
require_task "$packages_tasks" 'Install AUR packages'
require_task "$packages_tasks" 'laptop : Install supergfxctl'
reject_task "$packages_tasks" 'desktop : Enable Wake-on-LAN globally in NetworkManager'
reject_task "$packages_tasks" 'laptop : Enable supergfxd service'

dns_tasks="$(list_tasks dns)"
require_task "$dns_tasks" 'dns : Deploy the NextDNS systemd-resolved drop-in'
reject_task "$dns_tasks" 'mdns : Install Avahi and ufw'

mdns_tasks="$(list_tasks mdns)"
require_task "$mdns_tasks" 'mdns : Install Avahi and ufw'
require_task "$mdns_tasks" 'mdns : Allow mDNS from approved networks'
reject_task "$mdns_tasks" 'dns : Deploy the NextDNS systemd-resolved drop-in'

boot_tasks="$(list_tasks boot)"
require_task "$boot_tasks" 'boot : Remove Plymouth packages'
require_task "$boot_tasks" 'boot : Apply Limine Adwaita Dark global theme keys'

plymouth_tasks="$(list_tasks plymouth)"
require_task "$plymouth_tasks" 'boot : Remove Plymouth packages'
reject_task "$plymouth_tasks" 'boot : Apply Limine Adwaita Dark global theme keys'

gimp_tasks="$(list_tasks gimp)"
require_task "$gimp_tasks" 'Stop when CachyOS was not installed with GNOME and Limine'
require_task "$gimp_tasks" 'gimp : Install GIMP'
require_task "$gimp_tasks" 'gimp : Install the arrow Script-Fu plugin for the user'

ankama_tasks="$(list_tasks ankama)"
require_task "$ankama_tasks" 'Install Ankama Launcher from the AUR'
require_task "$ankama_tasks" 'ankama : Link the saved Dofus display presets to the repository'
reject_task "$ankama_tasks" 'packages : Install pacman packages'

printf 'Tag-selection invariants passed.\n'
