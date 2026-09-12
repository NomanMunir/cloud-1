.PHONY: help deps lint syntax deploy idempotency clean vm-up vm-ip vm-down vm-destroy vault-create vault-edit

VENV ?= .venv
BIN  ?= $(VENV)/bin

VM_NAME ?= cloud1
REMOTE_HOST ?= cloud1-mkhan.indiasouthcentral.cloudapp.azure.com
SSH_KEY     ?= ~/.ssh/cloud1_azure
ANSIBLE_PLAYBOOK ?= $(BIN)/ansible-playbook
ANSIBLE_GALAXY   ?= $(BIN)/ansible-galaxy
ANSIBLE_LINT     ?= $(BIN)/ansible-lint
ANSIBLE_VAULT    ?= $(BIN)/ansible-vault
VAULT_FILE       := group_vars/all/vault.yml

help:
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

deps: ## Install uv, create .venv, install ansible, ansible-lint, and galaxy collections
	@if ! command -v uv >/dev/null 2>&1; then \
		echo "[*] Installing uv to ~/.local/bin..."; \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
	fi
	@if [ ! -d "$(VENV)" ]; then \
		echo "[*] Creating virtual environment with uv..."; \
		uv venv $(VENV); \
	fi
	@echo "[*] Installing Python dependencies with uv..."
	@uv pip install --python $(BIN)/python -r requirements.txt
	@echo "[*] Installing Ansible Galaxy collections..."
	@$(ANSIBLE_GALAXY) collection install -r requirements.yml
	@echo "[+] Dependencies installed successfully!"

lint: ## Lint playbooks
	$(ANSIBLE_LINT) site.yml

syntax: ## Check playbook syntax
	$(ANSIBLE_PLAYBOOK) site.yml --syntax-check

deploy: ## Run full deploy
	$(ANSIBLE_PLAYBOOK) site.yml --ask-vault-pass

idempotency: ## Run twice, expect 0 changed on 2nd
	$(ANSIBLE_PLAYBOOK) site.yml --ask-vault-pass
	$(ANSIBLE_PLAYBOOK) site.yml --ask-vault-pass | tee /tmp/cloud1.run2.log
	@grep -E 'changed=0 .*failed=0' /tmp/cloud1.run2.log && echo "IDEMPOTENT ✓"

clean: ## Tear down remote containers and persistent data on Azure host
	@echo "[*] Tearing down remote stack on $(REMOTE_HOST)..."
	ssh -i $(SSH_KEY) root@$(REMOTE_HOST) \
	  "docker compose -f /opt/inception/docker-compose.yml down -v --remove-orphans 2>/dev/null || true; \
	   rm -rf /opt/inception /srv/inception/db /srv/inception/wp"
	@rm -rf .ansible_facts_cache/*
	@echo "[+] Remote stack cleaned. Ready for 'make deploy'."

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
