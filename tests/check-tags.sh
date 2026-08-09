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
reject_task "$gdm_tasks" 'gnome : Fetch compatible extension metadata'

dconf_tasks="$(list_tasks dconf)"
require_task "$dconf_tasks" 'gnome : Dump current dconf state'
reject_task "$dconf_tasks" 'gnome : Fetch compatible extension metadata'

dotfiles_tasks="$(list_tasks dotfiles)"
require_task "$dotfiles_tasks" 'environment : Install Bun from the Arch repositories'
require_task "$dotfiles_tasks" 'dotfiles : Install the pinned OMP version with Bun'

flatpak_tasks="$(list_tasks flatpak)"
require_task "$flatpak_tasks" 'packages : Install Flatpak'
require_task "$flatpak_tasks" 'packages : Install Flatpak packages'

gimp_tasks="$(list_tasks gimp)"
require_task "$gimp_tasks" 'gimp : Install GIMP'
require_task "$gimp_tasks" 'gimp : Install the arrow Script-Fu plugin for the user'

printf 'Tag-selection invariants passed.\n'
