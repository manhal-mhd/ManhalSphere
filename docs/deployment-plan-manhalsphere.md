# Deployment Plan — ManhalSphere (Lightweight Core)

## 1) Scope of This Plan

This deployment plan implements the selected stack:

- Core infrastructure: Portal, reverse proxy, DNS filtering, Portainer, Uptime Kuma, optional WireGuard.
- Business apps: ERPNext + HRMS, Mailu, Nextcloud.
- Supporting foundations: shared Docker networks, TLS, backup, monitoring, and operational runbook.

Primary UX requirement:

- Non-technical users open one URL (`portal.<base-domain>`) and launch all apps from portal tiles.

---

## 2) Target Architecture (Execution Baseline)

- Host: single Linux node (Ubuntu Server LTS preferred).
- Runtime: Docker Engine + Docker Compose plugin.
- Shared networks:
  - `proxy` for web-facing containers.
  - `backend` for internal DB/service traffic.
- DNS and domain:
  - Base domain + subdomains for portal, ERP, mail, nextcloud, status.
- TLS:
  - HTTPS for all web UIs.
  - Certificate automation through reverse proxy.

Suggested hostnames:

- `portal.<base-domain>`
- `erp.<base-domain>`
- `mail.<base-domain>`
- `files.<base-domain>`
- `status.<base-domain>`
- `dns.<base-domain>`

---

## 3) Deployment Phases

## Phase 0 — Pre-Deployment Decisions

### Tasks

1. Confirm `BASE_DOMAIN` and public IP (or LAN-only mode).
2. Confirm hardware profile and storage sizing.
3. Approve service list for day-1:
   - Required: Portal, reverse proxy, DNS, ERP+HRMS, Mailu, Nextcloud, Uptime Kuma.
   - Optional day-1: WireGuard, Vaultwarden.

### Deliverables

- Approved domain plan and service scope.
- Initial `.env` values list.

### Exit Criteria

- Team sign-off on hostnames, service scope, and go-live checklist owner.

---

## Phase 1 — Host and Docker Foundation

### Tasks

1. Prepare host OS, updates, and time sync.
2. Install Docker Engine and Compose plugin.
3. Create persistent storage paths and backup mount point.
4. Harden host baseline:
   - SSH key-only access.
   - Firewall enabled.
   - Automatic security updates (if policy allows).

### Repo Alignment

- Work from `infra/` as deployment root.
- Keep runtime settings in environment files, not hard-coded compose edits.

### Exit Criteria

- `docker --version` and `docker compose version` are healthy.
- Host survives reboot and Docker starts automatically.

---

## Phase 2 — Shared Networks and Core Infrastructure

### Tasks

1. Ensure `proxy` and `backend` Docker networks exist.
2. Deploy `infra/docker-compose.yml` (portal, portainer, uptime-kuma, wireguard if enabled).
3. Deploy DNS filter stack (AdGuard Home stack file to be added/confirmed in infra).
4. Configure reverse proxy routing and HTTPS certificates.
5. Publish initial portal with app placeholders.

### Commands (reference)

- `cd infra`
- `docker compose -f docker-compose.yml up -d`

### Exit Criteria

- Portal is reachable.
- Reverse proxy serves HTTPS.
- DNS service answers LAN queries.

---

## Phase 3 — ERPNext + HRMS Stack

### Tasks

1. Build and deploy `infra/docker-compose.erpnext-hrms.yml`.
2. Run one-time setup job (`erp-hrms-setup` service).
3. Configure ERP site URL and SMTP relay settings.
4. Verify HRMS app installation and module visibility.

### Commands (reference)

- `cd infra`
- `docker compose -f docker-compose.erpnext-hrms.yml up -d --build`
- `docker compose -f docker-compose.erpnext-hrms.yml run --rm erp-hrms-setup`

### Exit Criteria

- `erp.<base-domain>` loads over HTTPS.
- Admin login works.
- HRMS module is available and usable.

---

## Phase 4 — Mailu Implementation (Replace Placeholder Mail Stack)

### Current State

- `infra/docker-compose.mail.yml` is a placeholder and must be replaced for production.

### Tasks

1. Add a dedicated Mailu environment file in `infra/mailu.env` (copied from `infra/mailu.env.example`).
2. Use `infra/docker-compose.mail.yml` for Mailu service definitions.
3. Join Mailu web-facing components to `proxy`, internal services to `backend`.
4. Configure required Mailu env values:
   - Primary domain, hostnames, admin credentials, secret key.
   - TLS mode and reverse proxy integration mode.
5. Create DNS records (MX, SPF, DKIM, DMARC, A/AAAA).
6. Enable webmail/admin access at `mail.<base-domain>`.

### Exit Criteria

- Inbound and outbound mail tests pass.
- SPF, DKIM, DMARC checks pass for test messages.
- Mail web UI is reachable from portal.

### Commands (reference)

- `cd infra`
- `cp mailu.env.example mailu.env`
- `docker compose -f docker-compose.mail.yml up -d`

---

## Phase 5 — Nextcloud Stack

### Tasks

1. Deploy `infra/docker-compose.nextcloud.yml`.
2. Move hard-coded DB credentials into env file.
3. Configure trusted domains and reverse-proxy headers.
4. Route `files.<base-domain>` through HTTPS reverse proxy.
5. Create initial users/groups and storage policy.

### Commands (reference)

- `cd infra`
- `docker compose -f docker-compose.nextcloud.yml up -d`

### Exit Criteria

- Nextcloud login works at `files.<base-domain>`.
- File upload/download works.
- Portal tile opens Nextcloud successfully.

---

## Phase 6 — Portal UX and Access Model

### Tasks

1. Configure portal groups:
   - End-user apps: ERP, Mail, Files.
   - Admin apps: DNS admin, Portainer, Uptime, proxy admin.
2. Set portal as browser homepage for office users (policy-dependent).
3. Hide direct technical URLs from non-technical user documentation.

### Exit Criteria

- Non-technical user can complete daily flow only via portal.
- Admin tools remain restricted to admin roles/LAN/VPN.

---

## Phase 7 — Security, Backup, and Observability

### Tasks

1. Enforce HTTPS and redirect HTTP for all public web apps.
2. Restrict admin interfaces to LAN or WireGuard.
3. Implement backups for:
   - ERP DB + files.
   - Mailu data/config.
   - Nextcloud DB + data.
   - Compose/env configs.
4. Configure Uptime Kuma monitors and alert targets.
5. Run restore drill for one ERP backup and one Nextcloud backup.

### Exit Criteria

- Backup jobs run and produce restorable artifacts.
- Monitoring alerts are tested.
- Security review items closed or risk-accepted.

---

## Phase 8 — UAT and Go-Live

### UAT Checklist

- User can open portal and access ERP, Mail, Files.
- ERP transactions and HRMS flows work.
- Mail send/receive (external + internal) works.
- Nextcloud collaboration and file sync works.
- Helpdesk process for incidents is documented.

### Go-Live Steps

1. Freeze configuration and tag release.
2. Capture full backup snapshot.
3. Execute cutover communication.
4. Hypercare period (first 7–14 days) with daily health checks.

### Exit Criteria

- Stakeholder sign-off.
- Hypercare issues resolved or assigned with SLA.

---

## 4) Implementation Backlog (Immediate Next Tasks)

1. Create production Mailu compose and env templates.
2. Add reverse proxy mapping templates for ERP, Mailu, Nextcloud, portal, status.
3. Add central env template for all subdomains and secrets.
4. Refactor Nextcloud compose to remove hard-coded secrets.
5. Add backup script set and runbook commands for ERP, Mailu, Nextcloud.
6. Update `infra/deploy-all.sh` to follow Mailu-based deployment path.

---

## 5) Definition of Done (Project Level)

Deployment is considered complete when:

- All required stacks are running and reachable via HTTPS.
- Portal is the single documented entry point for non-technical users.
- Mailu, ERPNext+HRMS, and Nextcloud pass functional checks.
- Backup/restore and monitoring checks pass.
- Operations handover documentation is approved.
