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
