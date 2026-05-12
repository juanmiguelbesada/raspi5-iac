# ArgoCD

Website: [argoproj.github.io/cd](https://argoproj.github.io/cd) — Docs: [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io)

## Overview

**Argo CD** is a GitOps tool for Kubernetes. You tell it which Git repository
to watch, and it makes sure the cluster looks exactly like what's in that repo.
Push to Git, ArgoCD applies the changes.

Open http://argocd.192.168.1.155.sslip.io and log in with admin
(`make argocd-password`). Each app appears as a card in the dashboard with sync
status and health.

## Core concepts

### ApplicationSet

Instead of creating one ArgoCD `Application` per app, we create a single
**ApplicationSet** with a **generator** and a **template**. The generator
produces a list of parameter sets, and the template is a parameterized
`Application`. ArgoCD combines them and creates one `Application` per
parameter set automatically.

The ApplicationSet below is deployed via Terraform (see
[`docs/terraform.md`](terraform.md) for the HCL config), but the ArgoCD
resource it creates looks like this:

```yaml
# One ApplicationSet that generates one Application per directory under apps/
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet            # template-based Application generator
metadata:
  name: apps
spec:
  generators:
    - git:                      # git directory generator
        repoURL: https://github.com/juanmiguelbesada/raspi5.git
        revision: HEAD
        directories:
          - path: apps/*        # match every subdirectory under apps/
  template:
    metadata:
      name: "{{path.basename}}" # app name = directory name (e.g. hello-world)
    spec:
      project: default
      source:                   # where manifests live
        repoURL: https://github.com/juanmiguelbesada/raspi5.git
        targetRevision: HEAD
        path: "{{path}}"        # e.g. apps/hello-world
      destination:              # where to deploy
        server: https://kubernetes.default.svc
        namespace: "{{path.basename}}" # namespace = directory name
      syncPolicy:
        automated:
          prune: true           # delete resources removed from Git
          selfHeal: true        # revert manual changes to match Git
        syncOptions:
          - CreateNamespace=true
```

### Generators

Generators produce parameter sets. Each set becomes one `Application`. In this case we are using **git** generator. It Scans a Git repo for directories or files matching a pattern.
They expose some variables that we can inject into the template at runtime (like `{{path}}` or `{{path.basename}}`). See the [full list](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/#git-generator-parameters).

## How it works

Our ApplicationSet is configured with a git directory generator that watches
`apps/*`. Each subdirectory is an app and should contain a `kustomization.yaml`
— that's how ArgoCD knows which manifests to deploy. When you push a change
to any of those directories, ArgoCD detects it and tries to match the cluster
state with what's in Git. This process is called **Sync**.

You can tweak how ArgoCD behaves during syncs with policies and options.
- **Policies** control the automated behaviour [sync docs](https://argo-cd.readthedocs.io/en/stable/user-guide/automated-sync/)
- **Options** control how manifests are applied [sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)

