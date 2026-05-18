# ─── Dependencies ────────────────────────────────────────────

.PHONY: install build

install:
	brew install ansible kubectl terraform docker
	ansible-galaxy collection install community.general
	git config core.hooksPath .githooks
	$(MAKE) build

build:
	docker build -t $(DOCKER_IMAGE) .

DOCKER_IMAGE := raspi5-dev
DOCKER_RUN  := docker run --rm -v $(PWD):/workspace -w /workspace $(DOCKER_IMAGE)

# ─── Ansible ─────────────────────────────────────────────────

ANSIBLE_DIR := ansible

.PHONY: ansible ansible-setup ansible-harden ansible-k3s ansible-lint
ansible: ansible-setup ansible-harden ansible-k3s

ansible-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/01-initial-setup.yml --ask-become-pass

ansible-harden:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/02-security-hardening.yml

ansible-k3s:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/03-k3s-setup.yml

ansible-lint:
	$(DOCKER_RUN) ansible-lint ansible/playbooks/

# ─── Terraform ───────────────────────────────────────────────

TERRAFORM_DIR := terraform

.PHONY: terraform terraform-init terraform-plan terraform-apply terraform-destroy terraform-format
.PHONY: terraform-validate terraform-lint

terraform: terraform-init terraform-plan terraform-apply

terraform-init:
	terraform -chdir=$(TERRAFORM_DIR) init -migrate-state

terraform-plan:
	terraform -chdir=$(TERRAFORM_DIR) plan

terraform-apply:
	terraform -chdir=$(TERRAFORM_DIR) apply -auto-approve

terraform-destroy:
	terraform -chdir=$(TERRAFORM_DIR) destroy -auto-approve

terraform-format:
	terraform -chdir=$(TERRAFORM_DIR) fmt

terraform-validate:
	$(DOCKER_RUN) sh -c "cd terraform && terraform init -backend=false && terraform validate"

terraform-lint:
	$(DOCKER_RUN) sh -c "cd terraform && tflint --init && tflint --format compact"

# ─── Code Quality ────────────────────────────────────────────

.PHONY: format format-fix lint security-check

format:
	$(DOCKER_RUN) prettier --check .
	$(DOCKER_RUN) terraform fmt -check -recursive

format-fix: terraform-format
	$(DOCKER_RUN) prettier --write .

security-check:
	$(DOCKER_RUN) trivy config terraform/ apps/

lint: format terraform-validate ansible-lint terraform-lint security-check

# ─── ArgoCD ──────────────────────────────────────────────────

.PHONY: argocd-password

argocd-password:
	kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d; echo
