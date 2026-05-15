# ─── Dependencies ────────────────────────────────────────────

.PHONY: install install-dev

install:
	brew install ansible kubectl terraform
	ansible-galaxy collection install community.general

install-dev: install
	brew install tflint trivy prettier ansible-lint
	tflint --init

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
	ansible-lint ansible/playbooks/

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
	terraform -chdir=$(TERRAFORM_DIR) validate

terraform-lint:
	tflint --chdir=$(TERRAFORM_DIR) --format compact

# ─── Code Quality ────────────────────────────────────────────

.PHONY: format format-fix lint security-check

format:
	prettier --check .
	terraform -chdir=$(TERRAFORM_DIR) fmt -check

format-fix: terraform-format
	prettier --write .

security-check:
	trivy config .

lint: terraform-validate ansible-lint terraform-lint security-check

# ─── ArgoCD ──────────────────────────────────────────────────

.PHONY: argocd-password

argocd-password:
	kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d; echo
