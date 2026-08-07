# Cloud-1

Automated deployment of an Inception-style WordPress stack to a fresh Ubuntu 22.04 cloud VM, using Ansible + Docker Compose.

## Stack

- **Reverse proxy:** nginx (TLS termination, URL routing)
- **App:** WordPress (`wordpress:php8.2-fpm`)
- **DB:** MariaDB 10.11 (internal network only, never exposed)
- **Admin:** phpMyAdmin
- **TLS:** Let's Encrypt via certbot (HTTP-01) when domain set, self-signed otherwise

Each service runs in its own container. All managed by a single `docker-compose.yml`.

## Requirements (target host)

- Ubuntu 22.04 LTS
- SSH daemon running
- Python 3 installed
- Root SSH access (for evaluation defense)

## Quick start

```bash
# 1. Edit inventory with your host(s)
vim inventory/hosts.yml

# 2. Set secrets in the vault
ansible-vault edit group_vars/all/vault.yml

# 3. Deploy
ansible-playbook site.yml --ask-vault-pass
```

## Project structure

```
.
├── ansible.cfg
├── site.yml
├── inventory/hosts.yml
├── group_vars/all/{vars.yml, vault.yml}
├── roles/
│   ├── common/     base packages, swap, timezone
│   ├── firewall/   ufw + DOCKER-USER chain (ports 22/80/443 only)
│   ├── docker/     docker-ce + compose plugin
│   ├── tls/        certbot + cert renewal
│   └── app/        docker-compose deploy
├── files/
└── templates/
```

## Verification

- Idempotent: re-running `site.yml` reports `0 changed`.
- Reboot-safe: data persists in named volumes, containers restart automatically.
- Multi-host: add hosts to inventory, run with `-f <N>` for parallel deploy.
- Locked down: external `nmap` sees only ports 22, 80, 443.

## Defense

Root SSH is enabled. Evaluator connects as:

```bash
ssh root@<host>
```

Credentials are shared securely during the defense.

## AI usage transparency

Per project instructions: this repo was built with AI assistance for boilerplate generation. All design decisions (provider, stack choices, security model) are owned and defensible by the author.
