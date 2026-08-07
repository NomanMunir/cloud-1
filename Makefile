.PHONY: help deps lint syntax deploy idempotency vm-up vm-ip vm-down vm-destroy vault-create vault-edit

VM_NAME ?= cloud1
ANSIBLE_PLAYBOOK ?= ansible-playbook
VAULT_FILE := group_vars/all/vault.yml

help:
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

deps: ## Install Ansible collection dependencies
	ansible-galaxy collection install -r requirements.yml

lint: ## Lint playbooks
	ansible-lint || true

syntax: ## Check playbook syntax
	$(ANSIBLE_PLAYBOOK) site.yml --syntax-check

deploy: ## Run full deploy
	$(ANSIBLE_PLAYBOOK) site.yml --ask-vault-pass

idempotency: ## Run twice, expect 0 changed on 2nd
	$(ANSIBLE_PLAYBOOK) site.yml --ask-vault-pass
	$(ANSIBLE_PLAYBOOK) site.yml --ask-vault-pass | tee /tmp/cloud1.run2.log
	@grep -E 'changed=0 .*failed=0' /tmp/cloud1.run2.log && echo "IDEMPOTENT ✓"

vm-up: ## Launch local Multipass Ubuntu 22.04 VM
	multipass launch 22.04 --name $(VM_NAME) --cpus 2 --memory 2G --disk 10G \
	  --cloud-init cloud-init.yaml
	@echo "VM IP: $$(multipass info $(VM_NAME) | grep IPv4 | awk '{print $$2}')"

vm-ip: ## Print VM IP
	@multipass info $(VM_NAME) | grep IPv4 | awk '{print $$2}'

vm-down: ## Stop VM
	multipass stop $(VM_NAME)

vm-destroy: ## Delete VM
	multipass delete $(VM_NAME) && multipass purge

vault-create: ## Create encrypted vault from example
	cp group_vars/all/vault.yml.example $(VAULT_FILE)
	ansible-vault encrypt $(VAULT_FILE)

vault-edit: ## Edit encrypted vault
	ansible-vault edit $(VAULT_FILE)
