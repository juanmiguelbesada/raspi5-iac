# JuanMi's Raspi5 IaC

Single source of truth for my Raspberry Pi 5 infrastructure, built as a hands-on DevOps training project.

## Local setup

```bash
make install # Install local dependencies (ansible, kubectl, terraform)
```

## Useful commands

### Ansible — server provisioning

```bash
make ansible        # full setup (initial + hardening + k3s)
```

### Terraform — k3s workloads

```bash
make terraform-init    # download providers
make terraform-plan    # preview changes
make terraform-apply   # deploy apps to k3s
make terraform-destroy # tear down all apps
```
