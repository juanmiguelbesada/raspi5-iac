.PHONY: ansible-ping ansible-setup ansible-list

ANSIBLE_DIR := ansible

ansible-ping:
	cd $(ANSIBLE_DIR) && ansible all -m ping

ansible-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/01-initial-setup.yml --ask-become-pass

ansible-list:
	cd $(ANSIBLE_DIR) && ansible-inventory --list
