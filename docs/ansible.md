# Ansible

Website: [ansible.com](https://www.ansible.com) — Docs: [docs.ansible.com](https://docs.ansible.com)

## Overview

An **Infrastructure as Code** tool. You describe your desired server state (packages, files, services) in YAML files called **playbooks**. Ansible connects via SSH and makes the server match that description.

Three traits define it:

- **Agentless** — nothing installed on targets, only needs Python
- **Push-based** — your machine pushes config to servers
- **Idempotent** — running the same playbook repeatedly produces the same result

## Getting started

First, install Ansible on your machine: `brew install ansible`.

- **`ansible`** — run ad-hoc tasks directly.
```shell
ansible all -i inventory.yml -m ping
```

- **`ansible-playbook`** — run a playbook file. The standard way to use Ansible.
```shell
ansible-playbook playbooks/01-initial-setup.yml
```

## Inventory

The inventory lists which servers Ansible can connect to. You point Ansible to it in `ansible.cfg` with the `inventory` setting, with the [`ANSIBLE_INVENTORY`](https://docs.ansible.com/projects/ansible/latest/reference_appendices/config.html#envvar-ANSIBLE_INVENTORY) env var, or with `-i` on the CLI. If none is set, the default is `/etc/ansible/hosts` (defined by [`DEFAULT_HOST_LIST`](https://docs.ansible.com/projects/ansible/latest/reference_appendices/config.html#default-host-list)).

```yaml
all:                      # built-in group — every host belongs to it automatically
  hosts:
    raspi5:               # Ansible's internal name for this machine
      ansible_host: 192.168.1.155  # optional — only if the name doesn't resolve via DNS
      ansible_user: juanmi         # optional — defaults to your local user
```

## Playbook

A playbook is a YAML file that describes what to do on the servers listed in the inventory. It contains one or more **plays** — each play targets a set of hosts and runs a list of **tasks** on them.

```yaml
- name: Initial Raspberry Pi 5 setup  # human-readable label (optional)
  hosts: raspi5                       # target host from the inventory
  become: yes                         # run tasks with sudo
  gather_facts: no                    # skip system info collection (saves time)

  tasks:
    - name: Disable SSH password authentication
      ansible.builtin.lineinfile:    # module — reusable, idempotent unit of work
        path: /etc/ssh/sshd_config
        regexp: '^#?PasswordAuthentication'
        line: 'PasswordAuthentication no'
      notify: restart sshd           # flags the handler if this task changed something

  handlers:
    - name: restart sshd             # only runs at end of play, only if notified
      ansible.builtin.service:
        name: sshd
        state: restarted
```

Each task calls a **module** — a reusable, idempotent unit of work. The `ansible.builtin` prefix means it ships with Ansible. See the [full list of built-in modules](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html).

**Handlers** are the same as tasks — they call the same modules — but only run when notified, and only once at the end of the play. Use them for service restarts, config reloads — anything that should only happen when a change actually occurred.

### Playbook keywords

Keywords modify how a play or a task behaves. See the [full playbook keywords reference](https://docs.ansible.com/projects/ansible/latest/reference_appendices/playbooks_keywords.html).

```yaml
  tasks:
    - name: Check if memory cgroup is active
      ansible.builtin.shell: |
        ...
      register: cgroup_active     # saves task output into the variable cgroup_active
      changed_when: false          # never mark this task as "changed" (it's read-only)
      ignore_errors: yes           # continue even if this task fails

    - name: Enable cgroup memory
      ansible.builtin.lineinfile:
        ...
      when: cgroup_active is failed  # only runs if the previous task failed

    - name: Reboot to apply changes
      ansible.builtin.reboot:
      when: cgroup_active is failed   # same condition, independent task
```

## Configuration

INI format (`[section]`, `key = value`). Ansible looks for it in the current directory, then `~/.ansible.cfg`, then `/etc/ansible/ansible.cfg`. It defines project-wide defaults so you don't need to pass them on every command. See the [full list of configuration options](https://docs.ansible.com/ansible/latest/reference_appendices/config.html). Adding it to the project root overrides what you need and makes the setup portable — anyone who clones the repo can run playbooks without any prior config.

```ini
[defaults]                         # general Ansible settings (most common section)
host_key_checking = False          # skip SSH host key prompt (trusted LAN only)
inventory = inventory.yml          # path to the inventory file
retry_files_enabled = False        # don't create .retry files
interpreter_python = auto_silent   # auto-detect Python on remote, no warnings
```

> [!NOTE]
> Retry files are designed for multi-host runs — they let you re-run only on failed hosts. We disable them because we only manage one host.

