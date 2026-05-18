# Terraform

Website: [terraform.io](https://www.terraform.io) — Docs: [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform/docs)

## Overview

**Infrastructure as Code** tool. Declare cloud resources (servers, DNS, K8s releases) in `.tf` files, it provisions them.

Three traits:

- **Declarative** — write desired state, not steps
- **Provider-based** — one provider per platform (AWS, Kubernetes, Helm...)
- **State-driven** — `terraform.tfstate` tracks what exists

## Usage

Create a `main.tf`:

```hcl
terraform {                                          # required block — sets Terraform-wide settings
  required_version = ">= 1.5"                        # minimum CLI version
  required_providers {                               # providers to download
    null = {
      source  = "hashicorp/null"                     # registry namespace / provider name
    }
  }
}

resource "null_resource" "example" {}                # "make sure this thing exists"
```

> [!NOTE]
> `main.tf` is a convention — Terraform picks up **any** `.tf` file in the directory and merges them into one config (loaded in alphabetical order). Splitting across multiple files is fine, but you can only have one `terraform {}` block across all of them.

Then run **once** to set up the directory:

```shell
terraform init     # download providers + modules (required once)
```

> [!NOTE]
> `terraform init` generates `.terraform.lock.hcl` — commit this file to pin provider versions for your team.
>
> Run `init` again when: cloning the repo for the first time, changing `required_providers`, changing backend config, or running `terraform init -upgrade` to fetch newer provider versions.
>
> Switching backends requires `terraform init -migrate-state` to copy existing state to the new backend.

After that, the main loop is just plan + apply. `plan` is optional — `terraform apply` shows a plan and asks for confirmation before executing:

```shell
terraform plan     # diff: current state → desired state (optional preview)
terraform apply    # show plan → confirm → execute (no plan needed first)
```

> [!NOTE]
> `terraform apply` creates state — a mapping of your config to real-world resources. On every run, Terraform reads the state, diffs against your `.tf` files, and decides what to create, update, or destroy. Without it, every `apply` would try to recreate everything from scratch.
>
> State storage is configured via a `backend` block in `terraform {}`. The default is local (`terraform.tfstate`), but this project uses the **Kubernetes backend**:
>
> ```hcl
> terraform {
>   backend "kubernetes" {
>     config_path    = "~/.kube/config"                 # uses the same kubeconfig as providers
>     secret_suffix  = "raspi5"                         # creates Secret "tfstate-raspi5"
>   }
> }
> ```
>
> This stores state as a Secret (`default/tfstate-raspi5`) on the cluster — decoupled from any single machine. The trade-off: if the cluster is unrecoverable, the state is lost too.
>
> State often contains sensitive data — keep it out of git.

## Core concepts

### Providers

Providers are plugins that translate Terraform's generic resource syntax into API calls for a specific platform. Every resource belongs to a provider — the resource type `helm_release` comes from `hashicorp/helm`, `kubernetes_secret_v1` from `hashicorp/kubernetes`, and so on. Terraform can't talk to Kubernetes or Helm on its own — it needs a provider to handle authentication, API formatting, and CRUD operations for each platform.

Declare providers inside `required_providers` whenever your config uses a resource type from a given platform:

```hcl
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"               # registry namespace / provider name
      version = "~> 2.31"                             # version constraint (not required, but recommended)
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }
}
```

Terraform downloads the provider binary on `init`. Some providers also need a configuration block with connection settings:

```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"                      # path to kubeconfig file
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"                    # Helm talks to K8s through the same config
  }
}
```

If a provider picks up defaults from the environment (env vars, default credentials), you can skip the `provider` block entirely.

#### In this project

Two providers are declared:

- **`hashicorp/kubernetes`** — manages raw Kubernetes resources (secrets, namespaces...). Configured with a kubeconfig path pointing to the cluster.
- **`hashicorp/helm`** — manages Helm chart releases (install/upgrade/uninstall). Note the nested `kubernetes {}` block: Helm deploys to a cluster, so it reuses the same kubeconfig.

Both talk to the same k3s cluster running on the Pi. No additional credentials are needed — `~/.kube/config` is created by k3s during the Ansible provisioning step.

### Resources

Resources are the core of Terraform — they represent infrastructure objects you want to create, update, or delete: a Helm chart release, a Kubernetes secret, a DNS record. Each resource tells Terraform "make sure this thing exists". Without resources, there's nothing to provision. Each resource describes the desired state, and Terraform figures out the API calls to reach it.

```hcl
resource "helm_release" "argocd" {                    # resource type + local name
  name             = "argocd"                         # Helm release name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true                             # create ns if it doesn't exist
}
```

> [!TIP]
> **Helm** is a Kubernetes package manager ([helm.sh](https://helm.sh)). Charts are pre-packaged app definitions (deployments, services, ingress) that you install with a single command — like `apt` for Kubernetes ([artifacthub.io](https://artifacthub.io) is the public registry). The `helm_release` resource lets Terraform manage those chart installs.

Declare a resource whenever you need a piece of infrastructure to exist. The resource type determines which provider it belongs to — `helm_release` requires `hashicorp/helm`, `kubernetes_secret_v1` requires `hashicorp/kubernetes`.

The first string after `resource` is the **type** (provider-specific). The second is the **local name** — used only within your config to reference this resource from other resources:

```hcl
resource "kubernetes_secret_v1" "repo_raspi5" {
  depends_on = [helm_release.argocd]                  # wait for ArgoCD to be deployed first

  metadata {
    name      = "repo-raspi5"
    namespace = "argocd"
  }
  data = {
    url      = "https://github.com/juanmiguelbesada/raspi5-iac.git"
    password = var.github_token
  }
}
```

### Variables

Variables make configs reusable across environments without hardcoding values. Without them, every value would be hardcoded in resources. Variables let you change behaviour (region, token, instance count) by swapping value files or flags — no config changes needed.

```hcl
variable "github_token" {                              # input variable declaration
  description = "GitHub classic PAT with repo scope"   # what it's for
  type        = string                                 # type constraint
  sensitive   = true                                   # mask in logs / plan output
}
```

Declare a variable whenever a value might differ between environments, contains a secret, or is used more than once. Set values via:

```shell
terraform apply -var="github_token=ghp_..."            # CLI flag
export TF_VAR_github_token="ghp_..." && terraform apply # env var
```

Or in a `terraform.tfvars` file (auto-loaded, gitignore for secrets):

```hcl
github_token = "ghp_..."
```

### Locals

Use locals to avoid repeating an expression across resources — they're computed once and can reference resources, data sources, or other locals. Unlike variables, they're never set by the caller.

```hcl
locals {
  domain   = "192.168.1.155.sslip.io"                  # computed once, used many times
  repo_url = "https://github.com/juanmiguelbesada/raspi5-iac.git"  # used by ArgoCD repo secret + ApplicationSet
}

resource "helm_release" "argocd" {
  ...
  values = [yamlencode({
    global = {
      domain = "argocd.${local.domain}"                # → "argocd.192.168.1.155.sslip.io"
    }
  })]
}
```

## Project structure

```
terraform/
├── main.tf                   # terraform block, providers, locals
├── argocd.tf                 # ArgoCD Helm release + repo secret
├── apps.tf                   # ApplicationSet (generates Applications from apps/*)
├── variables.tf              # input variable declarations
└── terraform.tfvars          # variable values (gitignored)
```

### ArgoCD (`argocd.tf`)

ArgoCD is the GitOps engine. Terraform installs it once; from then on ArgoCD watches the `apps/` directory and keeps the cluster in sync.

```hcl
resource "helm_release" "argocd" {
  name             = "argocd"                          # Helm release name (used in K8s labels)
  repository       = "https://argoproj.github.io/argo-helm" # chart repo URL
  chart            = "argo-cd"                         # chart name in that repo
  namespace        = "argocd"                          # K8s namespace to install into
  create_namespace = true                              # auto-create if it doesn't exist

  values = [yamlencode({
    global = {
      domain = "argocd.${local.domain}"                # UI domain (for ingress + redirect URLs)
    }
    configs = {
      params = {
        "server.insecure" = true                        # default false; allows HTTP (no TLS certs)
      }
    }
    server = {
      ingress = {
        enabled          = true                         # default false; creates a K8s Ingress for UI
        ingressClassName = "traefik"                    # k3s default ingress controller
        hosts = ["argocd.${local.domain}"]             # hostname the ingress accepts
      }
    }
  })]
}
```

The same file also declares the **repository secret** — ArgoCD needs the GitHub PAT to clone the repo. There's no reference to this Secret in the ArgoCD Helm values: ArgoCD [automatically scans its namespace](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#repositories) for Secrets with the label `argocd.argoproj.io/secret-type: repository` and uses them as repo credentials. No explicit config needed:

```hcl
resource "kubernetes_secret_v1" "repo_raspi5" {
  depends_on = [helm_release.argocd]                   # namespace must exist first

  metadata {
    name      = "repo-raspi5"                          # Secret name in Kubernetes
    namespace = "argocd"                               # must match ArgoCD's namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"  # tells ArgoCD "this is a repo"
    }
  }

  data = {
    type     = "git"
    url      = local.repo_url                           # from locals in main.tf
    username = "juanmiguelbesada"
    password = var.github_token                         # PAT from terraform.tfvars
  }
}
```

### Apps (`apps.tf`)

This resource tells ArgoCD to deploy everything in `apps/`. A
[`kubernetes_manifest`](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest)
resource creates an **ApplicationSet** with a **git directory generator** —
one `Application` per subdirectory.

Using `kubernetes_manifest` (instead of a Helm release wrapping the
`argocd-apps` chart) means the ApplicationSet is a **first-class Terraform
resource** — if it's deleted from the cluster, `terraform apply` detects the
drift and recreates it immediately. See [`docs/argocd.md`](argocd.md) for more
details.

```hcl
resource "kubernetes_manifest" "apps" {
  depends_on = [helm_release.argocd, kubernetes_secret_v1.repo_raspi5]  # CRD + repo secret must exist first

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"

    metadata = {
      name      = "apps"
      namespace = "argocd"
    }

    spec = {
      generators = [{                                # list of generators (produce parameter sets)
        git = {                                      # git directory generator: scans repo dirs
          repoURL     = local.repo_url                # from locals in main.tf
          revision    = "HEAD"
          directories = [{ path = "apps/*" }]        # every subdirectory under apps/
        }
      }]

      template = {                                   # parameterized Application template
        metadata = {
          name = "{{path.basename}}"                 # e.g. "my-app" from apps/my-app
        }

        spec = {
          project = "default"

          source = {
            repoURL        = local.repo_url           # from locals in main.tf
            targetRevision = "HEAD"
            path           = "{{path}}"              # e.g. "apps/my-app"
          }

          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{path.basename}}"          # one namespace per app, matching dir name
          }

          syncPolicy = {
            automated = {
              prune    = true                        # delete K8s resources removed from Git
              selfHeal = true                        # revert manual changes to match Git
            }
            syncOptions = ["CreateNamespace=true"]   # auto-create namespace if missing
          }
        }
      }
    }
  }
}
```

Net result: **every subdirectory in `apps/` automatically becomes an ArgoCD Application**. No per-app Terraform config needed.
