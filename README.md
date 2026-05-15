# JuanMi's Raspi5 IaC

Single source of truth for my Raspberry Pi 5 — k3s cluster with GitOps.

## Provisioning flow

```
Ansible ──► Pi OS setup → k3s single-node cluster
Terraform ──► ArgoCD (infra-only, no app logic)
ArgoCD ──► syncs apps/ → creates deployments, services, ingresses
```

## Local setup

```bash
make install                  # brew + ansible-galaxy deps + Docker lint image
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars → add your GitHub PAT (repo:contents=read)
```

## Commands

| Step               | Command                                     | What it does                                 |
| ------------------ | ------------------------------------------- | -------------------------------------------- |
| Provision Pi       | `make ansible`                              | OS bootstrap → security → k3s                |
| Deploy ArgoCD      | `make terraform`                            | Init → plan → apply (installs ArgoCD on k3s) |
| Get admin password | `make argocd-password`                      | Prints ArgoCD admin password                 |
| Open UI            | `open http://argocd.192.168.1.155.sslip.io` | ArgoCD dashboard                             |
| Lint all           | `make lint`                                 | Runs format, validate, lint, security checks |
| Format check       | `make format`                               | Prettier + terraform fmt (read-only)         |
| Format fix         | `make format-fix`                           | Writes fixed formatting                      |

> **Note:** Lint / format commands run inside a Docker image (`raspi5-dev`). Build it with `make build` or `make install-dev`.

## Add a new app

1. Create a directory under `apps/` with your manifests and a `kustomization.yaml`
2. Commit and push to `main`

See [`docs/argocd.md`](docs/argocd.md) for details on how Application discovery works.

## Access

- **ArgoCD**: `http://argocd.192.168.1.155.sslip.io` (admin / `make argocd-password`)
- **hello-world**: `http://hello-world.192.168.1.155.sslip.io`
