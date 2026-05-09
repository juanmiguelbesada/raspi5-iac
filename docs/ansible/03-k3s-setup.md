# Ansible: k3s Installation

Installs a single-node k3s cluster on the Raspberry Pi 5.

## What this playbook does

1. Checks if memory cgroups are active — if not, enables them in `/boot/firmware/cmdline.txt` and reboots (the `reboot` module waits for the Pi to come back)
2. Opens UFW port 6443 for the Kubernetes API
3. Installs k3s via `get.k3s.io` (skips if `/usr/local/bin/k3s` already exists)
4. Fetches the kubeconfig to `~/.kube/config` on your laptop, patching the server address from `127.0.0.1` to `192.168.1.155`

## Usage

Single command — if a reboot is needed, the playbook handles it and continues:

```bash
make ansible-k3s
```

## Verification

```bash
# From your laptop — kubectl should connect to the Pi
kubectl get nodes
# NAME           STATUS   ROLES                  AGE   VERSION
# raspberry-pi   Ready    control-plane,master   1m    v1.35.4+k3s1
```

## Notes

- **Channel/version:** Uses the stable channel (default). To pin a version, add e.g. `INSTALL_K3S_CHANNEL=v1.30` to the `k3s_install` command in the playbook.
- **Components:** All k3s defaults are kept (CoreDNS, Traefik, Metrics Server, ServiceLB, Local Path Provisioner). These can be disabled later with `--disable=<name>` in `/etc/rancher/k3s/config.yaml`.
- **Cgroups:** On modern Raspberry Pi OS Bookworm (64-bit), cgroups may already be enabled. The playbook checks and only modifies `cmdline.txt` if needed.
