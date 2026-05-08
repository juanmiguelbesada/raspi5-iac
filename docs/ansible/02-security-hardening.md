# Security Hardening: ufw, fail2ban, unattended-upgrades

## Why These Extras?

The initial playbook (`01-initial-setup.yml`) handled system updates and SSH hardening. This playbook adds three security layers:

| Tool | Purpose |
|------|---------|
| **ufw** (Uncomplicated Firewall) | Blocks all incoming traffic except explicitly allowed ports. If a service starts listening on a port, ufw will block it unless you've added a rule. |
| **fail2ban** | Monitors SSH login attempts and temporarily bans IPs with repeated failures. Stops brute-force attacks. |
| **unattended-upgrades** | Automatically installs security updates daily. Ensures critical patches are applied even if you forget to run `apt upgrade`. |

---

## Playbook: `02-security-hardening.yml`

```yaml
---
- name: Security hardening for Raspberry Pi 5
  hosts: raspi5
  become: yes
  gather_facts: no

  tasks:
    - name: Install security packages
      ansible.builtin.apt:
        name:
          - ufw
          - fail2ban
          - unattended-upgrades
        state: present
        update_cache: yes

    - name: Configure ufw — default deny incoming traffic
      community.general.ufw:
        direction: incoming
        policy: deny

    - name: Configure ufw — allow SSH
      community.general.ufw:
        rule: allow
        port: ssh
        proto: tcp

    - name: Enable ufw
      community.general.ufw:
        state: enabled

    - name: Enable unattended-upgrades for security updates
      ansible.builtin.copy:
        dest: /etc/apt/apt.conf.d/20auto-upgrades
        content: |
          APT::Periodic::Update-Package-Lists "1";
          APT::Periodic::Unattended-Upgrade "1";
        mode: "644"

    - name: Ensure fail2ban is running and enabled on boot
      ansible.builtin.service:
        name: fail2ban
        state: started
        enabled: yes
```

---

## Task Breakdown

### 1. Install packages

```yaml
ansible.builtin.apt:
  name:
    - ufw
    - fail2ban
    - unattended-upgrades
  state: present
  update_cache: yes
```

Installs all three tools in one task. `update_cache: yes` runs `apt update` first. The `name` list format passes multiple packages — Ansible handles them in a single apt transaction.

### 2-4. UFW rules

UFW ships with a default policy of allowing outgoing traffic and denying incoming. We make that explicit and then punch a hole for SSH:

**Task 2:** `direction: incoming` + `policy: deny` — all incoming traffic blocked by default.
**Task 3:** `rule: allow` + `port: ssh` + `proto: tcp` — allow SSH (port 22/tcp) through the firewall.
**Task 4:** `state: enabled` — activates the firewall. Without this, the rules exist but aren't applied.

The `community.general.ufw` module manages UFW idempotently — running again won't duplicate rules.

**Note:** Enabling UFW over SSH is safe here because we added the SSH allow rule *before* enabling it. If you accidentally enable UFW without an SSH allow rule, you'd lock yourself out.

### 5. Unattended-upgrades

```yaml
ansible.builtin.copy:
  dest: /etc/apt/apt.conf.d/20auto-upgrades
  content: |
    APT::Periodic::Update-Package-Lists "1";
    APT::Periodic::Unattended-Upgrade "1";
  mode: "644"
```

This writes the configuration file that controls automatic updates:

| Directive | What it does |
|-----------|-------------|
| `Update-Package-Lists "1"` | Runs `apt update` daily (1 = enabled, 0 = disabled) |
| `Unattended-Upgrade "1"` | Installs available security updates daily |

Only security updates are installed by default (configurable in `/etc/apt/apt.conf.d/50unattended-upgrades`). Regular package updates are never auto-installed.

### 6. Fail2ban

```yaml
ansible.builtin.service:
  name: fail2ban
  state: started
  enabled: yes
```

Ensures the fail2ban service is running and will start on boot. The default configuration on Raspberry Pi OS Bookworm includes an SSH jail that:

- Tracks failed login attempts
- Bans IPs after 5 failures within 10 minutes
- Unbans them after 10 minutes

You can check the jail status later with: `sudo fail2ban-client status sshd`

---

## How to Run

```bash
make ansible-harden
```

This runs:

```bash
cd ansible && ansible-playbook playbooks/02-security-hardening.yml
```

No `--ask-become-pass` needed — the `01-initial-setup` playbook already granted `juanmi` passwordless sudo.

---

## Verification

After running, you can verify each component:

```bash
# Check UFW status
sudo ufw status verbose

# Check fail2ban SSH jail
sudo fail2ban-client status sshd

# Check when unattended-upgrades last ran
less /var/log/unattended-upgrades/unattended-upgrades.log
```
