#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR
cd "$ROOT_DIR"

export SHELL=/bin/bash

PLAYBOOK_FILE="$ROOT_DIR/site.yml"
REQUIREMENTS_FILE="$ROOT_DIR/requirements.yml"
VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-$ROOT_DIR/.vault-password}"
LOCAL_HOST="$(uname -n)"
readonly PLAYBOOK_FILE REQUIREMENTS_FILE VAULT_PASSWORD_FILE LOCAL_HOST
readonly -a SYSTEM_PACKAGES=(ansible ansible-lint yamllint shellcheck yay)

usage() {
  cat <<'USAGE'
Usage: ./bootstrap.sh <command> [options]

Calling the script without a command only displays this help; it never runs the
playbook implicitly.

Commands:
  help            display this help
  deps            install the pinned Ansible Galaxy dependencies only
  upgrade         explicitly upgrade CachyOS/Arch and install project tooling
  run [options]   run the setup (requires a readable vault password file)
  check [options] run Ansible check mode; --diff is opt-in because it may expose secrets
  lint            run Bash, YAML, and Ansible linters offline
  syntax          run the Ansible syntax check

run and check pass extra options to ansible-playbook, for example
'./bootstrap.sh run --tags ankama'. Both limit the play to the inventory host
named after this machine.

Environment:
  VAULT_PASSWORD_FILE  vault password file used by run/check only
                       (default: <repository>/.vault-password)

The lint, syntax, and check commands never install or update dependencies.
Run './bootstrap.sh deps' when Galaxy dependencies are missing. The upgrade
command performs a full system upgrade and therefore requires explicit use.
USAGE
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 ||
    fail "required command '$command_name' was not found; install the tooling explicitly with './bootstrap.sh upgrade'."
}

require_file() {
  local path="$1"
  local description="$2"
  [[ -f "$path" ]] || fail "$description is missing: $path"
}

require_no_arguments() {
  local command_name="$1"
  shift
  (( $# == 0 )) || fail "'$command_name' does not accept arguments."
}

preflight_playbook() {
  require_command ansible-playbook
  require_file "$PLAYBOOK_FILE" "playbook"
  require_file "$ROOT_DIR/ansible.cfg" "Ansible configuration"
  require_file "$ROOT_DIR/inventory/hosts.yml" "inventory"
}

preflight_vault() {
  local vault_mode

  [[ -f "$VAULT_PASSWORD_FILE" && -r "$VAULT_PASSWORD_FILE" && -s "$VAULT_PASSWORD_FILE" ]] ||
    fail "run/check requires a non-empty, readable vault password file at '$VAULT_PASSWORD_FILE' (or set VAULT_PASSWORD_FILE)."

  vault_mode=$(stat -Lc '%a' "$VAULT_PASSWORD_FILE")
  (( (8#$vault_mode & 077) == 0 )) ||
    fail "vault password file permissions are too broad ($vault_mode); use chmod 0600 '$VAULT_PASSWORD_FILE'."
}

install_galaxy_dependencies() {
  require_command ansible-galaxy
  require_file "$REQUIREMENTS_FILE" "Galaxy requirements file"
  echo '==> Installing pinned Ansible Galaxy dependencies...'
  ansible-galaxy collection install --requirements-file "$REQUIREMENTS_FILE"
}

command_name="${1:-help}"
if (( $# > 0 )); then
  shift
fi

case "$command_name" in
  help|-h|--help)
    require_no_arguments "$command_name" "$@"
    usage
    ;;
  deps)
    require_no_arguments "$command_name" "$@"
    install_galaxy_dependencies
    ;;
  upgrade)
    require_no_arguments "$command_name" "$@"
    require_command pkexec
    require_command pacman
    echo '==> Explicit full system upgrade and project-tool installation...'
    pkexec pacman -Syu --needed "${SYSTEM_PACKAGES[@]}"
    install_galaxy_dependencies
    ;;
  run)
    preflight_playbook
    preflight_vault
    echo "==> Running setup playbook for $LOCAL_HOST..."
    ansible-playbook "$PLAYBOOK_FILE" \
      --limit "$LOCAL_HOST" \
      --vault-password-file "$VAULT_PASSWORD_FILE" \
      --ask-become-pass \
      "$@"
    ;;
  check)
    preflight_playbook
    preflight_vault
    for option in "$@"; do
      if [[ "$option" == '--diff' ]]; then
        echo 'Warning: --diff may print sensitive values; use its output carefully.' >&2
      fi
    done
    echo "==> Running setup playbook in check mode for $LOCAL_HOST..."
    ansible-playbook "$PLAYBOOK_FILE" \
      --check \
      --limit "$LOCAL_HOST" \
      --vault-password-file "$VAULT_PASSWORD_FILE" \
      --ask-become-pass \
      "$@"
    ;;
  lint)
    require_no_arguments "$command_name" "$@"
    preflight_playbook
    require_command yamllint
    require_command ansible-lint
    require_command shellcheck
    require_file "$ROOT_DIR/.yamllint" "yamllint configuration"
    require_file "$ROOT_DIR/.ansible-lint" "ansible-lint configuration"
    require_file "$ROOT_DIR/tests/static.yml" "static test playbook"
    require_file "$ROOT_DIR/tests/check-tags.sh" "tag-selection test"
    echo '==> Checking Bash scripts...'
    shellcheck bootstrap.sh show-elgato-output.sh tests/check-tags.sh \
      roles/ai_agents/files/agents/statusline.sh roles/boot/files/90-no-plymouth.conf
    echo '==> Running yamllint...'
    yamllint .
    echo '==> Running Ansible syntax-check...'
    ansible-playbook "$PLAYBOOK_FILE" --syntax-check
    echo '==> Running non-destructive repository invariants...'
    ansible-playbook "$ROOT_DIR/tests/static.yml"
    "$ROOT_DIR/tests/check-tags.sh"
    echo '==> Running ansible-lint offline...'
    ansible-lint --offline
    ;;
  syntax)
    require_no_arguments "$command_name" "$@"
    preflight_playbook
    echo '==> Running syntax-check...'
    ansible-playbook "$PLAYBOOK_FILE" --syntax-check
    ;;
  *)
    usage >&2
    fail "unknown command '$command_name'."
    ;;
esac
