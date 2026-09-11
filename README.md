# Cloud-1: Automated Deployment of Inception

[![42 School Project](https://img.shields.io/badge/42-Cloud--1-blue)](https://42.fr)
[![Ansible](https://img.shields.io/badge/Ansible-2.15+-EE0000.svg?logo=ansible&logoColor=white)](https://ansible.com)
[![Docker](https://img.shields.io/badge/Docker-24+-2496ED.svg?logo=docker&logoColor=white)](https://docker.com)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20LTS-E95420.svg?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Fully automated provisioning and multi-container deployment of **Inception** (WordPress, MariaDB, phpMyAdmin, and Nginx reverse proxy with TLS) on remote cloud instances using **Ansible** and **Docker Compose**.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Key Features & Subject Compliance](#key-features--subject-compliance)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start Guide](#quick-start-guide)
- [Configuration & Secret Management](#configuration--secret-management)
- [Multi-Server Parallel Deployment](#multi-server-parallel-deployment)
- [Automated Verification & Peer Defense](#automated-verification--peer-defense)
- [Design Decisions & FAQ](#design-decisions--faq)

---

## Overview

**Cloud-1** is a 42 School DevOps/System Administration curriculum project. The objective is to automate the deployment of an Inception web stack onto a remote cloud server (e.g. AWS, Scaleway, GCP, Azure, or any Ubuntu 22.04 LTS instance) assuming only an SSH daemon and Python are installed.

---

## Architecture

```
                                  Internet
                                     │
                 ┌───────────────────┴───────────────────┐
                 │                                       │
           Port 22 (SSH)                       Port 80 / 443 (HTTP/HTTPS)
                 │                                       │
                 ▼                                       ▼
     ┌───────────────────────┐               ┌───────────────────────┐
     │   SSH Management      │               │   UFW Firewall        │
     │   (Ansible Target)    │               │   (22, 80, 443 only)  │
     └───────────────────────┘               └───────────┬───────────┘
                                                         │
                                                         ▼
                                             ┌───────────────────────┐
                                             │  Nginx Reverse Proxy  │
                                             │  - TLSv1.2 & TLSv1.3  │
                                             │  - HTTP -> HTTPS 301  │
                                             └─────┬───────────┬─────┘
                                                   │           │
                    Path: / ───────────────────────┘           │ Path: /phpmyadmin/
                    │                                          │
                    ▼                                          ▼
     ┌─────────────────────────────┐            ┌─────────────────────────────┐
     │   WordPress Application     │            │   phpMyAdmin Service        │
     │   (wordpress:6.4-apache)    │            │   (phpmyadmin:5.2-apache)   │
     └──────────────┬──────────────┘            └──────────────┬──────────────┘
                    │                                          │
                    └───────────────────┬──────────────────────┘
                                        │ (Internal cloud1_net)
                                        ▼
                         ┌─────────────────────────────┐
                         │   MariaDB Database Server   │
                         │   (mariadb:10.11)           │
                         │   * NO host port exposed!   │
                         │   * Port 3306 blocked       │
                         └──────────────┬──────────────┘
                                        │
                         ┌──────────────┴──────────────┐
                         │  Persistent Named Volumes   │
                         │  - mariadb_data             │
                         │  - wordpress_data           │
                         └─────────────────────────────┘
```

### Process Isolation (1 Process = 1 Container)
1. **`nginx`**: Front-facing reverse proxy handling TLS encryption, HTTP (80) to HTTPS (443) 301 redirection, security headers, and reverse proxying.
2. **`wordpress`**: Official WordPress application container.
3. **`db`**: Official MariaDB 10.11 database engine. Not reachable from the internet; reachable only within the internal Docker bridge network `cloud1_net`.
4. **`phpmyadmin`**: Official phpMyAdmin administration interface.

---

## Key Features & Subject Compliance

| Subject Requirement | Implementation Detail | Status |
|---|---|---|
| **Automation Tool** | Modular Ansible roles (`common`, `security`, `docker`, `tls`, `app`) | Active |
| **Fresh Ubuntu 22.04 LTS** | Requires only Python 3 and OpenSSH; provisions everything else | Verified |
| **Multi-Server Deployment** | Configured via `inventory/hosts.ini` with parallel task execution | Supported |
| **1 Process = 1 Container** | Separate containers for Nginx, WordPress, phpMyAdmin, MariaDB | Verified |
| **Strict Firewall Access** | UFW configured to allow **only** 22, 80, 443; 3306 explicitly denied | Enforced |
| **Database Isolation** | DB container exposes no host ports and runs inside internal Docker network | Enforced |
| **TLS / HTTPS Enabled** | OpenSSL self-signed certificate with SAN or external certs | Enforced |
| **URL Redirection** | HTTP (80) redirects to HTTPS (443); `/` -> WP, `/phpmyadmin` -> phpMyAdmin | Verified |
| **Data Persistence** | Docker named volumes `mariadb_data` and `wordpress_data` | Enforced |
| **Automatic Boot Recovery** | All containers configured with `restart: unless-stopped` + Docker systemd | Enforced |
| **Idempotency** | Playbook can run repeatedly with zero side-effects (`changed=0`) | Verified |
| **No Hard-coded Secrets** | Credentials stored in `vault.yml` (gitignored) / generated dynamically | Verified |

---

## Project Structure

```
cloud-1/
├── ansible.cfg                          # Ansible runtime settings (roles_path, callbacks, SSH args)
├── playbook.yml                         # Master deployment playbook
├── inventory/
│   ├── hosts.ini                        # Server inventory for single or multi-server deployment
│   └── group_vars/
│       └── all/
│           ├── vars.yml                 # Non-sensitive configuration (ports, domain, images)
│           ├── vault.yml                # Secrets file (gitignored)
│           └── vault.yml.example        # Secrets template
├── roles/
│   ├── common/                          # Package updates, system utilities, timezone
│   ├── security/                        # UFW firewall policy (22, 80, 443 only)
│   ├── docker/                          # Official Docker CE & Compose plugin installation
│   ├── tls/                             # OpenSSL TLS certificate generation with SAN
│   └── app/                             # Docker Compose deployment & Nginx routing
├── scripts/
│   └── verify_deployment.sh             # Automated peer evaluation test suite
├── deploy.sh                            # One-line execution wrapper script
├── Makefile                             # Convenient make targets
├── .gitignore                           # Excludes secrets, temporary files, and keys
└── README.md                            # Complete documentation
```

---

## Prerequisites

### 1. Control Machine (Your local computer)
- Any operating system (Linux, macOS, Windows with WSL/PowerShell)
- **`uv`** (recommended):
  ```bash
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```
  *(Or standard Python 3.10+ with `pip`)*

### 2. Target Machine (Remote Cloud Instance)
- Fresh **Ubuntu 22.04 LTS** (or 20.04 LTS)
- OpenSSH server running (`systemctl status ssh`)
- Python 3 installed (`python3 --version`)
- Public IPv4 or domain name (e.g. DuckDNS)
- SSH key added to the server's `~/.ssh/authorized_keys`

---

## Quick Start Guide

### Step 1: Clone the Repository
```bash
git clone <repository_url> cloud-1
cd cloud-1
```

### Step 2: Configure Inventory & Target Server
Edit `inventory/hosts.ini` with your remote instance details:
```ini
[webservers]
server1 ansible_host=203.0.113.42 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa ansible_port=22
```

Edit `inventory/group_vars/all/vars.yml` to specify your domain or public IP:
```yaml
server_domain: "203.0.113.42"  # Or your DuckDNS / custom domain: "example.duckdns.org"
```

### Step 3: Configure Secure Secrets
```bash
# Initialize vault.yml from the template
make setup-vault

# Edit inventory/group_vars/all/vault.yml with your passwords
```

*(Optional)* Encrypt secrets using Ansible Vault:
```bash
ansible-vault encrypt inventory/group_vars/all/vault.yml
```

### Step 4: Test Connectivity
```bash
make ping
```

### Step 5: Deploy Everything!
```bash
make deploy
# Or: ./deploy.sh
```

---

## Configuration & Secret Management

Secrets (MariaDB root password, WordPress database password, WordPress admin password) are never hardcoded.

1. **`inventory/group_vars/all/vault.yml.example`**:
   Serves as the template.
2. **`inventory/group_vars/all/vault.yml`**:
   The actual active secrets file. It is registered in `.gitignore` so secrets can never be pushed to a public git repository accidentally.
3. **Password Generation**:
   You can easily generate high-entropy passwords with OpenSSL:
   ```bash
   openssl rand -base64 24
   ```

---

## Multi-Server Parallel Deployment

To deploy to multiple cloud servers simultaneously (e.g. across multiple cloud regions or providers):

Add additional servers under `[webservers]` in `inventory/hosts.ini`:
```ini
[webservers]
node1 ansible_host=198.51.100.10 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
node2 ansible_host=198.51.100.11 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
node3 ansible_host=198.51.100.12 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
```

When running `make deploy`, Ansible's parallel fork engine will execute all roles across all instances concurrently.

---

## Automated Verification & Peer Defense

To verify all requirements automatically during a peer evaluation:

```bash
# Syntax: bash scripts/verify_deployment.sh <DOMAIN_OR_HOST> <TARGET_IP>
bash scripts/verify_deployment.sh example.duckdns.org 203.0.113.42
```

The verification script validates:
1. **Firewall check**: Ports 80, 443, and 22 are open.
2. **Database isolation check**: Port 3306 is **strictly blocked** from the outside.
3. **HTTP to HTTPS 301 redirect**: `http://host/` returns HTTP 301 pointing to `https://host/`.
4. **WordPress HTTPS check**: `https://host/` returns HTTP 200/302.
5. **phpMyAdmin check**: `https://host/phpmyadmin/` renders the phpMyAdmin login interface.

---

## Design Decisions & FAQ

### Q1: Why use Ansible roles instead of a single monolithic playbook?
Ansible roles provide strict separation of concerns, idempotency testing per module, reusability across environments, and adhere directly to the subject directive: *"Your Ansible code should be organized into relevant roles for maintainability."*

### Q2: Why is the database port 3306 not exposed?
Exposing database ports directly to the internet is a severe security vulnerability. Containers communicate via Docker's internal DNS over the private bridge network `cloud1_network`. UFW explicitly drops external packets targeting 3306.

### Q3: How is data persistence handled?
Data is stored in Docker named volumes:
- `mariadb_data` mounted at `/var/lib/mysql`
- `wordpress_data` mounted at `/var/www/html`

When a server reboots or containers are recreated, Docker automatically mounts the existing volumes without data loss.

### Q4: How does reboot resilience work?
Containers specify `restart: unless-stopped`. Additionally, the Docker daemon is enabled via `systemd` (`systemctl enable docker`). On operating system reboot, systemd starts Docker, and Docker automatically restarts all containers in the proper dependency order.
