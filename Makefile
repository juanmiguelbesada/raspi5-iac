.PHONY: ansible ansible-setup ansible-harden

ANSIBLE_DIR := ansible

ansible: ansible-setup ansible-harden

ansible-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/01-initial-setup.yml --ask-become-pass

ansible-harden:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/02-security-hardening.yml
