# ==============================================================================
# Cloud-1: Automated Deployment of Inception - Makefile
# ==============================================================================

.PHONY: all help setup-vault ping check dry-run deploy test clean

ANSIBLE_PLAYBOOK := $(shell which ansible-playbook 2>/dev/null || echo "uvx --from ansible-core ansible-playbook")
ANSIBLE          := $(shell which ansible 2>/dev/null || echo "uvx --from ansible-core ansible")

all: help

help:
	@echo "Cloud-1: Automated deployment of Inception (42 School)"
	@echo ""
	@echo "Available targets:"
	@echo "  make setup-vault  - Create inventory/group_vars/all/vault.yml from template"
	@echo "  make ping         - Test SSH connection and Python on inventory servers"
	@echo "  make check        - Verify Ansible playbook syntax"
	@echo "  make dry-run      - Run Ansible playbook in check mode (dry-run)"
	@echo "  make deploy       - Execute complete automated deployment"
	@echo "  make test         - Run verification test suite on the deployed instance"
	@echo "  make clean        - Remove temporary retry and log files"

setup-vault:
	@if [ ! -f inventory/group_vars/all/vault.yml ]; then \
		cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml; \
		echo "[+] Created inventory/group_vars/all/vault.yml from template."; \
		echo "[!] Please edit it with your passwords before running deploy."; \
	else \
		echo "[!] inventory/group_vars/all/vault.yml already exists."; \
	fi

ping:
	@$(ANSIBLE) -i inventory/hosts.ini webservers -m ping

check:
	@$(ANSIBLE_PLAYBOOK) -i inventory/hosts.ini playbook.yml --syntax-check

dry-run:
	@$(ANSIBLE_PLAYBOOK) -i inventory/hosts.ini playbook.yml --check

deploy:
	@$(ANSIBLE_PLAYBOOK) -i inventory/hosts.ini playbook.yml

test:
	@bash scripts/verify_deployment.sh

clean:
	@rm -f *.retry *.log
