.PHONY: install ansible ansible-setup ansible-harden ansible-k3s

ANSIBLE_DIR := ansible

install:
	brew install ansible kubectl
	ansible-galaxy collection install community.general

ansible: ansible-setup ansible-harden ansible-k3s

ansible-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/01-initial-setup.yml --ask-become-pass

ansible-harden:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/02-security-hardening.yml

ansible-k3s:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/03-k3s-setup.yml
