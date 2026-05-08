# Ansible: Initial Raspberry Pi 5 Setup

## What is Ansible?

Ansible is an **Infrastructure as Code (IaC)** tool. Instead of SSHing into a server and typing commands manually, you write a **playbook** (a YAML file) that describes the desired state of the system. Ansible connects via SSH and makes the server match that state.

Key characteristics:

- **Agentless** — nothing needs to be installed on the Raspberry Pi except Python (which Raspberry Pi OS has by default). Ansible runs from your laptop and connects via SSH.
- **Push-based** — you push configuration from your machine to the server, unlike pull-based tools like Puppet or Chef.
- **Idempotent** — running the same playbook multiple times produces the same result. If the system already matches the desired state, nothing changes.

---

## Project Structure

```
raspi5/
├── Makefile                        # Shortcuts for common commands
├── ansible/
│   ├── ansible.cfg                 # Ansible configuration
│   ├── inventory/
│   │   └── hosts.yml               # Defines which servers to manage
│   └── playbooks/
│       └── 01-initial-setup.yml    # Our first playbook
└── docs/
    └── ansible/
        └── 01-intro.md             # This file
```

---

## Inventory (`hosts.yml`)

The inventory is Ansible's list of servers. It can be INI, YAML, or even a dynamic script. We use YAML:

```yaml
all:
  hosts:
    raspi5:
      ansible_host: 192.168.1.155
      ansible_user: juanmi
```

| Element | Meaning |
|---------|---------|
| `all` | A group containing everything. Every inventory has this automatically. |
| `hosts` | The list of hosts in this group. |
| `raspi5` | Ansible's name for this machine. You can use any name; it becomes the target in playbooks. |
| `ansible_host` | The actual IP address or hostname to connect to. |
| `ansible_user` | The SSH user Ansible connects as. |

Later, we could add more variables here (grouping servers, setting ports, etc.).

---

## Ansible Config (`ansible.cfg`)

```ini
[defaults]
host_key_checking = False
inventory = inventory/hosts.yml
retry_files_enabled = False
deprecation_warnings = False
interpreter_python = auto_silent
```

| Setting | Default | What it does |
|---------|---------|-------------|
| `host_key_checking = False` | `True` | Skips SSH host key verification on first connection. Avoids the "Are you sure you want to continue connecting?" prompt. Only safe for trusted local networks. |
| `inventory = inventory/hosts.yml` | `/etc/ansible/hosts` | Tells Ansible where to find the inventory file. Relative path is relative to where you run the command. |
| `retry_files_enabled = False` | `True` | Disables the `.retry` files Ansible creates when a playbook fails on some hosts. Keeps the project clean. |
| `deprecation_warnings = False` | `True` | Suppresses deprecation warnings from Ansible collections (e.g., `ansible.posix` uses an old import path). Noise we don't need. |
| `interpreter_python = auto_silent` | `auto` | Ansible auto-discovers the Python interpreter on the remote machine. `auto` prints a warning; `auto_silent` does the same discovery silently. |

---

## Playbook Anatomy (`01-initial-setup.yml`)

A playbook is a YAML file containing one or more **plays**. A play maps a set of **tasks** to a group of hosts.

```yaml
---
- name: Initial Raspberry Pi 5 setup
  hosts: raspi5
  become: yes
  gather_facts: no

  tasks:
    - name: Update apt cache and upgrade all packages
      ansible.builtin.apt:
        update_cache: yes
        upgrade: dist
        autoremove: yes

    - name: Deploy SSH public key for juanmi
      ansible.posix.authorized_key:
        user: juanmi
        state: present
        key: "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"

    - name: Disable SSH password authentication
      ansible.builtin.lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PasswordAuthentication'
        line: 'PasswordAuthentication no'
      notify: restart sshd

  handlers:
    - name: restart sshd
      ansible.builtin.service:
        name: sshd
        state: restarted
```

### Play-level directives

| Directive | Meaning |
|-----------|---------|
| `name` | A description of the play. Shows up in terminal output. |
| `hosts: raspi5` | Target the host named `raspi5` in the inventory. |
| `become: yes` | Run all tasks with privilege escalation (`sudo`). Required because updating packages and editing system config needs root. |
| `gather_facts: no` | Ansible can collect system information (facts) before running tasks. We don't need it for these simple tasks, so we skip it for speed. |

### Tasks

Each task uses a **module** (the building blocks of Ansible).

#### Task 1: `ansible.builtin.apt`

```yaml
ansible.builtin.apt:
  update_cache: yes
  upgrade: dist
  autoremove: yes
```

| Parameter | What it does |
|-----------|-------------|
| `update_cache: yes` | Runs `apt update` before upgrading. |
| `upgrade: dist` | Runs `apt upgrade` with distribution upgrade (handles kernel and dependency changes, unlike `safe`). Equivalent to `apt upgrade` with the dist-upgrade flag. |
| `autoremove: yes` | Removes packages that were automatically installed and are no longer needed (`apt autoremove`). |

**Idempotency:** If all packages are already at the latest version, this task does nothing (reports `ok` instead of `changed`).

#### Task 2: `ansible.posix.authorized_key`

```yaml
ansible.posix.authorized_key:
  user: juanmi
  state: present
  key: "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

| Parameter | What it does |
|-----------|-------------|
| `user: juanmi` | Which user's `~/.ssh/authorized_keys` to manage. |
| `state: present` | Ensures the key is in the file. If already there, nothing changes. |
| `key` | The public key content. `lookup('file', ...)` reads the local file and inserts its content. |

**How it works:** The `lookup` function runs on your **control machine** (your laptop), reads `~/.ssh/id_ed25519.pub`, and passes the content to the Pi. Ansible then ensures that content is in `/home/juanmi/.ssh/authorized_keys`.

If the Pi's `authorized_keys` file didn't exist, Ansible creates it with the correct permissions (`600`). If the key is already there, nothing changes.

#### Task 3: `ansible.builtin.lineinfile`

```yaml
ansible.builtin.lineinfile:
  path: /etc/ssh/sshd_config
  regexp: '^#?PasswordAuthentication'
  line: 'PasswordAuthentication no'
```

| Parameter | What it does |
|-----------|-------------|
| `path` | The file to edit (`/etc/ssh/sshd_config`). |
| `regexp` | A pattern to find the line. `^#?` matches both the commented-out default (`#PasswordAuthentication yes`) and an already-uncommented line. |
| `line` | The replacement text. |

**What this does:** Finds any line matching `PasswordAuthentication` (commented or not) and replaces it with `PasswordAuthentication no`. If the line doesn't exist at all, it appends it.

### The Notify/Handler Pattern

```yaml
notify: restart sshd
```

The `notify` keyword tells Ansible: "if this task actually changed something, flag the handler named `restart sshd` as pending."

Handlers run **at the end of the play**, only if notified, and only once even if multiple tasks notify them.

```yaml
handlers:
  - name: restart sshd
    ansible.builtin.service:
      name: sshd
      state: restarted
```

So if `PasswordAuthentication` was already `no`, nothing changes, the handler doesn't run, and sshd is not restarted — avoiding unnecessary downtime.

---

## How to Run

```bash
make ansible-setup
```

This runs:

```bash
cd ansible && ansible-playbook playbooks/01-initial-setup.yml --ask-become-pass
```

| Part | Meaning |
|------|---------|
| `cd ansible` | Ansible looks for `ansible.cfg` in the current directory. |
| `ansible-playbook` | The command to execute a playbook. |
| `playbooks/01-initial-setup.yml` | Which playbook to run. |
| `--ask-become-pass` | Ansible will prompt for the sudo password of `juanmi` (since we use `become: yes` and `juanmi` requires a password for sudo). |

### Other Make commands

```bash
make ansible-ping      # Test connectivity to the Pi
make ansible-list      # Show parsed inventory
```

---

## What the Playbook Achieves

1. **System is up to date.** All packages upgraded, unused packages removed.
2. **SSH key is deployed.** Your laptop's public key is in `~juanmi/.ssh/authorized_keys`.
3. **Password authentication is disabled.** Only key-based SSH connections are accepted. `PasswordAuthentication no` means anyone trying to connect with a password will be rejected, even if they know the password.

After running, the only way to SSH into the Pi is with a matching private key. This is the single most important security measure for any SSH-exposed server.
