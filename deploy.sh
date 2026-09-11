#!/usr/bin/env bash
# ==============================================================================
# Cloud-1: Automated Deployment Script
# Provisions and deploys the complete Inception stack via Ansible
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

INVENTORY_FILE="${INVENTORY_FILE:-inventory/hosts.ini}"
VAULT_FILE="inventory/group_vars/all/vault.yml"

echo "========================================================================"
echo " Cloud-1: Automated Deployment of Inception"
echo " Target Inventory: ${INVENTORY_FILE}"
echo "========================================================================"

# Step 1: Verify inventory file
if [ ! -f "${INVENTORY_FILE}" ]; then
    echo "[-] Error: Inventory file '${INVENTORY_FILE}' not found!"
    exit 1
fi

# Step 2: Ensure secrets file exists
if [ ! -f "${VAULT_FILE}" ]; then
    echo "[!] Notice: ${VAULT_FILE} not found."
    echo "[!] Creating ${VAULT_FILE} from template..."
    cp inventory/group_vars/all/vault.yml.example "${VAULT_FILE}"
    echo "[!] Please configure your secure credentials in ${VAULT_FILE} before running."
    exit 1
fi

# Step 3: Determine Ansible executor
if command -v ansible-playbook >/dev/null 2>&1; then
    ANSIBLE_BIN="ansible-playbook"
elif command -v uvx >/dev/null 2>&1; then
    echo "[+] Using uvx to run ansible-playbook on-the-fly..."
    ANSIBLE_BIN="uvx --from ansible ansible-playbook"
else
    echo "[-] Error: 'ansible-playbook' command not found."
    echo "    Please install Ansible or install uv (curl -LsSf https://astral.sh/uv/install.sh | sh)"
    exit 1
fi

# Step 4: Run the deployment
echo "[*] Executing Ansible playbook..."
${ANSIBLE_BIN} -i "${INVENTORY_FILE}" playbook.yml "$@"

echo "========================================================================"
echo "[+] Cloud-1 deployment finished successfully!"
echo "========================================================================"
