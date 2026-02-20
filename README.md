# ManhalSphere Micro Datacenter

ManhalSphere is a production-oriented self-hosted platform that unifies core business and infrastructure services behind a single, domain-driven gateway. Built with Docker Compose, it provides a practical foundation for running ERP, files, mail, password management, monitoring, backups, and DNS in one coherent operating sphere.

## What this repository contains

- `infra/` → active deployment stack (recommended entrypoint)
- `docs/` → project planning and operational documentation
- `frappe_docker/` → upstream/reference resources used during implementation

---

## Deployed stack (current)

Core services:
- Traefik reverse proxy (`80/443`)
- Homer portal (`portal.<domain>`)
- Technitium DNS Manager (`dns.<domain>` + DNS on `53/tcp` and `53/udp`)
- Backrest Backup Manager (`backup.<domain>`)
- Automated DB dump worker (`backup-db-dumps`)
- Portainer (`docker.<domain>`)
- Uptime Kuma (`status.<domain>`)
- WireGuard (`51820/udp`)

Application services:
- ERPNext + HRMS (`erp.<domain>`)
- Nextcloud (`files.<domain>`)
- Vaultwarden (`pw.<domain>`)
- Mailu (`mail.<domain>` + SMTP/IMAP ports)

---

## Domain and routing model

Routing is domain-driven through Traefik labels in compose files.

Expected hostnames (from `.env`):
- `portal.${BASE_DOMAIN}`
- `erp.${BASE_DOMAIN}`
- `files.${BASE_DOMAIN}`
- `pw.${BASE_DOMAIN}`
- `status.${BASE_DOMAIN}`
- `docker.${BASE_DOMAIN}`
- `mail.${BASE_DOMAIN}`
- `dns.${BASE_DOMAIN}`
- `backup.${BASE_DOMAIN}`

Mail DNS additionally requires:
- `MX` for root domain pointing to mail host
- SPF TXT (`v=spf1 ...`)
- DMARC TXT (`_dmarc`)
- DKIM TXT (`<selector>._domainkey`)

---

## Prerequisites

- Linux host with Docker Engine + Compose plugin
- `sudo` access
- Public DNS control for your domain
- Ports open on host/firewall:
  - Web: `80`, `443`
  - Mail: `25`, `465`, `587`, `143`, `993` (and optional `110`, `995` if used)
  - WireGuard: `51820/udp`

Recommended tools installed on host:
- `curl`, `dig`, `openssl`, `python3`, `timeout`

---

## Initial setup

From `infra/`:

1. Copy env templates:
   - `cp .env.example .env`
   - `cp mailu.env.example mailu.env`

2. Edit values:
   - `.env`
     - `BASE_DOMAIN`
     - `LETSENCRYPT_EMAIL`
     - strong values for `MARIADB_ROOT_PASSWORD`, `ERP_DB_PASSWORD`, optional `ERP_ADMIN_PASSWORD`
   - `mailu.env`
     - `DOMAIN`
     - `HOSTNAMES`
     - strong `SECRET_KEY`
     - `TLS_FLAVOR` (`letsencrypt` recommended)

3. Run pre-check:
   - `cd scripts && ./pre-check.sh`

4. Deploy:
   - `cd .. && bash deploy-all.sh`

  Note: deployment now auto-renders `infra/portal/config.yml` from `infra/portal/config.yml.template` using `BASE_DOMAIN`.

5. Validate:
   - `cd scripts && ./health-check.sh`

6. DNS setup (authoritative mapping):
  - Ensure your registrar/domain DNS uses this server as nameserver for the zone.
  - Open inbound DNS ports `53/tcp` and `53/udp` to this host.
  - Deployment auto-creates/updates A records for: root, `portal`, `erp`, `mail`, `dns`, `files`, `pw`, `status`, `docker`, `backup`.

---

## Scripts reference

### `infra/deploy-all.sh`
Main deployment entrypoint.

What it does:
- Renders portal links from `BASE_DOMAIN` before startup
- Starts core stack
- Bootstraps DNS zone + subdomain A records from `.env`
- Builds/starts ERP core services
- Runs ERP setup/migrations as one-off job
- Starts ERP nginx only after setup step
- Waits for ERP endpoint readiness
- Starts Nextcloud, Vaultwarden, Mailu
- Keeps automated DB dump worker running for ERP/Nextcloud SQL exports

Useful env controls:
- `ERP_WAIT_TIMEOUT` (default `900` seconds)
- `ERP_WAIT_INTERVAL` (default `5` seconds)

DNS env controls:
- `DNS_API_URL` (default `http://localhost:5380`)
- `DNS_ADMIN_USER` (default `admin`)
- `DNS_ADMIN_PASSWORD` (default `admin`, change for production)
- `DNS_RECORD_IP` (optional; if empty deploy tries to auto-detect)

Backup dump env controls:
- `BACKUP_DUMP_INTERVAL_HOURS` (default `24`)
- `BACKUP_DUMPS_RETENTION_DAYS` (default `14`)
- `ERP_DB_CONTAINER` (default `infra-erp-db-1`)
- `NEXTCLOUD_DB_CONTAINER` (default `nextcloud-db`)

Example:
- `ERP_WAIT_TIMEOUT=1200 bash deploy-all.sh`

---

### `infra/scripts/render-portal-config.sh`
Renders Homer portal config from template with current domain.

What it does:
- Reads `BASE_DOMAIN` from `infra/.env`
- Replaces `__BASE_DOMAIN__` in `infra/portal/config.yml.template`
- Writes final `infra/portal/config.yml`

Run manually:
- `cd infra && bash scripts/render-portal-config.sh`

---

### `infra/scripts/bootstrap-dns.sh`
Auto-creates DNS zone and maps application subdomains.

What it does:
- Logs into Technitium DNS API
- Creates primary zone for `BASE_DOMAIN` (if missing)
- Upserts A records for root and app subdomains

Run manually:
- `cd infra && bash scripts/bootstrap-dns.sh`

---

### `infra/scripts/health-check.sh`
Runtime health validation for web routes, mail ports, and key containers.

Checks:
- Web routes (`portal`, `erp`, `files`, `pw`, `status`, `mail`)
- Mail protocol ports (`25`, `465`, `587`, `143`, `993`)
- Container state (`reverse-proxy`, `mailu-front`, `infra-erp-app-1`, `nextcloud-app`, `vaultwarden`)

Useful env controls:
- `HEALTH_URL_RETRIES` (default `30`)
- `HEALTH_URL_RETRY_DELAY` (default `5`)

Example:
- `HEALTH_URL_RETRIES=40 HEALTH_URL_RETRY_DELAY=4 bash scripts/health-check.sh`

---

### `infra/scripts/reset-services.sh`
Interactive reset utility (destructive for selected stack volumes).

Menu targets:
- Mailu
- ERPNext + HRMS
- Nextcloud
- Vaultwarden
- Core stack
- All stacks

Run:
- `cd scripts && ./reset-services.sh`

Then redeploy:
- `cd .. && bash deploy-all.sh`

---

### `infra/scripts/pre-check.sh`
Pre-deployment validation and readiness checks.

Modes:
- Normal check: `./pre-check.sh`
- Dry-run secret generation (no file writes): `./pre-check.sh --generate-secrets-only`
- Auto-generate/update secrets in env files: `./pre-check.sh --auto-generate-secrets`

---

## Credentials and first-login notes

ERPNext:
- URL: `https://erp.<domain>`
- User: `Administrator`
- Password: from `ERP_ADMIN_PASSWORD` (or setup default if not set)

Mailu:
- Admin URL: `https://mail.<domain>/sso/login`
- Mailbox login URL: `https://mail.<domain>/webmail/`

Nextcloud:
- URL: `https://files.<domain>`
- Complete initial admin setup in UI if fresh volume

Vaultwarden:
- URL: `https://pw.<domain>`

Portainer:
- URL: `https://docker.<domain>`
- If you see `timeout.html`, restart container once:
  - `sudo docker restart portainer`

Technitium DNS Manager:
- URL: `https://dns.<domain>`
- API/web bootstrap credentials come from `.env`: `DNS_ADMIN_USER` / `DNS_ADMIN_PASSWORD`

Backrest Backup Manager:
- URL: `https://backup.<domain>`
- First open: create Backrest admin user/password in the web UI
- Recommended backup sources mounted read-only in container:
  - `/userdata/workspace` (repository and infra files)
  - `/userdata/docker-volumes` (named Docker volumes)
- Local restic repositories path in container: `/repos`
- Automated SQL dumps are written to: `infra/backups/db-dumps`

---

## Backup quick start

1. Open `https://backup.<domain>` and complete first-time account setup.
2. Create a repository (recommended local path: `/repos/manhalsphere`).
3. Create a plan and include paths:
   - `/userdata/workspace/infra`
   - `/userdata/docker-volumes`
  - Ensure `infra/backups/db-dumps` is included (it is under `infra` path)
4. Configure schedule (example): daily snapshots + weekly prune/forget.
5. Add retention policy (example): keep 7 daily, 4 weekly, 6 monthly.

Restore basics:
- In Backrest UI, open snapshot browser and restore files/folders to a target path.
- For service data restore, stop affected container first, restore volume data, then start service.
- For DB restore from dumps: extract `*.sql.gz` and import into target MariaDB container.

---

## Automated DB dump hooks

Service:
- `backup-db-dumps` runs continuously and creates compressed SQL dumps on schedule.

Scripts:
- `infra/scripts/backup-db-dumps.sh` (single dump cycle)
- `infra/scripts/backup-db-dumps-runner.sh` (loop/scheduler)

Manual trigger:
- `cd infra && /bin/sh scripts/backup-db-dumps.sh`

Output:
- `infra/backups/db-dumps/erp-*.sql.gz`
- `infra/backups/db-dumps/nextcloud-*.sql.gz`

---

## Common operations

### Restart a single service
- `sudo docker restart <container-name>`

### Check logs
- `sudo docker logs --tail 200 <container-name>`

### Check running containers
- `sudo docker ps`

### Re-run ERP setup manually (if needed)
- `cd infra && sudo docker compose -f docker-compose.erpnext-hrms.yml run --rm erp-hrms-setup`

---

## Troubleshooting

### ERP returns HTTP 500
Typical causes:
- ERP setup/migrations still running
- DB credentials not yet synchronized

What to do:
1. `sudo docker logs --tail 200 infra-erp-app-1`
2. Re-run ERP setup job:
   - `sudo docker compose -f docker-compose.erpnext-hrms.yml run --rm erp-hrms-setup`
3. Re-test:
   - `bash scripts/health-check.sh`

### Mail works but webmail/admin loops or fails
- Verify `mailu.env` (`DOMAIN`, `HOSTNAMES`, `TLS_FLAVOR`, `SECRET_KEY`, `SUBNET`)
- Recreate mail stack:
  - `sudo docker compose -f docker-compose.mail.yml up -d`

### Portainer shows timeout page
- Restart Portainer:
  - `sudo docker restart portainer`

---

## Security notes (important)

- Rotate all placeholder/default secrets before production.
- Keep backups before destructive resets.
- Current Traefik dashboard is enabled on `:8090` with insecure API mode; restrict access before internet-wide exposure.
- Never commit real production secrets to GitHub.

---

## Recommended GitHub push checklist

Before pushing:
- Ensure `.env` and `mailu.env` are **not** committed with real secrets.
- Keep only `.env.example` and `mailu.env.example` in repo.
- Run:
  - `bash scripts/pre-check.sh`
  - `bash scripts/health-check.sh`

Suggested include in `.gitignore` (if not already):
- `infra/.env`
- `infra/mailu.env`
- `infra/archives/`

---

## License and upstreams

This repository includes components and references from upstream projects (Frappe/ERPNext, Mailu, Nextcloud, Vaultwarden, Portainer, Traefik). Follow each upstream license and security guidance for production deployments.
