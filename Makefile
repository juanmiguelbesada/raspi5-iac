# ─── Dependencies ────────────────────────────────────────────

.PHONY: install
install:
	brew install ansible kubectl terraform
	ansible-galaxy collection install community.general

# ─── Ansible ─────────────────────────────────────────────────

ANSIBLE_DIR := ansible

.PHONY: ansible ansible-setup ansible-harden ansible-k3s
ansible: ansible-setup ansible-harden ansible-k3s

ansible-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/01-initial-setup.yml --ask-become-pass

ansible-harden:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/02-security-hardening.yml

ansible-k3s:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/03-k3s-setup.yml

# ─── Terraform ───────────────────────────────────────────────

TERRAFORM_DIR := terraform

.PHONY: terraform-init terraform-plan terraform-apply terraform-destroy

terraform-init:
	terraform -chdir=$(TERRAFORM_DIR) init

terraform-plan:
	terraform -chdir=$(TERRAFORM_DIR) plan

terraform-apply:
	terraform -chdir=$(TERRAFORM_DIR) apply -auto-approve

terraform-destroy:
	terraform -chdir=$(TERRAFORM_DIR) destroy -auto-approve
