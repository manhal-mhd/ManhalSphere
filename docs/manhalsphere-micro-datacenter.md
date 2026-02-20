# ManhalSphere Micro Datacenter

## 1. Project Charter – "ManhalSphere Micro Datacenter"

### 1.1 Project Name

ManhalSphere Micro Datacenter

### 1.2 Purpose and Background

This project aims to deliver a compact, energy-efficient micro datacenter that consolidates essential office IT services into a single, plug-and-play device (for example, Mac mini–class hardware). The system will use Docker-based services to provide DNS filtering, email, ERP, and optional collaboration tools, with a lightweight-first software stack and one unified portal that non-technical users can open to access all applications.

### 1.3 Objectives

- Provide a self-contained platform for:
  - Secure DNS filtering with a lightweight web interface.
  - Lightweight email system with webmail and standard client support.
  - ERPNext for core business management.
  - One unified portal as the primary user entry point to all enabled apps.
  - Optional modules (file sync, password manager, helpdesk, asset management).
- Deliver a plug-and-play experience:
  - Connect power and network.
  - Access a setup URL.
  - Complete initial configuration within 1–2 hours.
- Prioritize low resource usage by default:
  - Enable only essential services at first boot.
  - Select lightweight software options unless advanced needs require heavier stacks.
- Ensure reliability and maintainability through:
  - Containerized services.
  - Automated backups.
  - Clear operational procedures.

### 1.4 Success Criteria

- System supports 10–50 users with acceptable performance.
- Initial deployment can be completed by a sysadmin-level user in under half a day.
- Non-technical users can open one portal URL and access required applications without manually entering service URLs.
- Core profile runs within typical limits of 4–6 CPU cores and 16 GB RAM for small offices.
- All core services (DNS, email, ERPNext) operate reliably for 90+ days with no critical incidents.
- Backup and restore process tested successfully at least once before production go-live.

### 1.5 Stakeholders

- Project Owner: [Name / Role]
- Technical Lead: [Name / Role]
- System Administrator(s): [Name / Role]
- End Users: Office staff using email, ERP, and other tools.
- Management: Receives reports and approves changes.

### 1.6 Scope Overview

**In scope**

- Design, build, and test a Docker-based micro datacenter image.
- Integration of:
  - Mandatory unified user portal (single homepage for all apps).
  - DNS filtering service (Pi-hole or AdGuard Home) using OpenDNS.
  - Dockerized email stack (Mailu).
  - ERPNext stack.
  - Optional (disabled by default): Nextcloud, Vaultwarden (or similar), helpdesk/asset tools.
- Deployment guide, operations runbook, security and backup policies.

**Out of scope (Phase 1)**

- High-availability clustering or failover to secondary hardware.
- Multi-site replication and complex SSO with external IdPs.
- Custom ERPNext modules beyond configuration and basic apps.

### 1.7 Constraints

- Runs on a single small form-factor device (for example, 4–8 core CPU, 16–32 GB RAM, SSD).
- Must use Docker and Docker Compose (or equivalent) as container runtime.
- Must support LAN deployment; internet access required only for updates, email, DNS resolution, and optional cloud backups.

---

## 2. Requirements & Design Plan (RDP)

### 2.1 Functional Requirements

#### 2.1.0 Unified Portal Experience (Primary UX)

- Provide one primary URL (for example, `portal.${BASE_DOMAIN}`) as the default homepage for users.
- The portal must be understandable for non-technical office staff:
  - Clear app tiles (ERP, Mail, Files, Passwords, Helpdesk).
  - Human-friendly names and short descriptions.
  - No infrastructure jargon on the main screen.
- Users should not need to remember or type individual service URLs.
- Role-based portal views:
  - End-user view: only business applications.
  - Admin view: adds technical tools (DNS admin, monitoring, container UI).
  - Optional owner view: setup, backup, and update controls.

#### 2.1.1 DNS Filtering (OpenDNS-based)

- Provide DNS resolution for all LAN clients.
- Integrate with OpenDNS or similar upstream resolvers.
- Offer a web UI to:
  - View query logs, top clients, and blocked domains.
  - Configure allow/deny lists and content categories.
- Allow configuration of DHCP-assigned DNS or static DNS usage on clients.

#### 2.1.2 Email System

- Provide company email accounts under one or more domains.
- Support:
  - Webmail interface.
  - IMAP/SMTP access for desktop and mobile clients.
- Include basic spam filtering and optional antivirus scanning.
- Implement and assist with:
  - MX, SPF, DKIM, and DMARC records.
- Provide administrative features:
  - Create/disable mailboxes.
  - Set aliases and groups.
  - Quota management.

#### 2.1.3 ERPNext

- Deploy ERPNext with:
  - CRM, sales, purchasing, accounting, inventory, HR modules.
- Support role-based access control and permissions.
- Integrate email notifications (for example, order confirmations, reminders).
- Ensure data persistence (database and files) across container restarts and updates.

#### 2.1.4 Optional Services (Phase 1 "Nice-to-Have")

- File sync and sharing (for example, Nextcloud).
- Password manager (for example, Vaultwarden).
- Helpdesk/ticketing (for example, Frappe Helpdesk, Zammad).
- Asset management (for example, Snipe-IT).

#### 2.1.5 Admin Portal

- Provide a single landing page listing:
  - ERPNext.
  - Webmail.
  - DNS admin.
  - Monitoring dashboard.
  - Other deployed services.
- Display basic health status (up/down) for each service.
- Provide links to documentation and support contacts.
- Keep UX minimal and clear for non-technical users:
  - Large tiles and concise labels.
  - Hide advanced controls unless admin role is detected.

#### 2.1.6 Backup & Restore

- Automatic scheduled backups for:
  - All databases (ERPNext, email, others).
  - Configuration files and volume-based data.
- Backup destinations:
  - Local disk.
  - External USB drive.
  - Optional remote/cloud storage (for example, via rclone).
- Include documented one-click or semi-automated restore procedure.

### 2.2 Non-Functional Requirements

- **Performance**
  - Support 10–50 concurrent users for ERP and email with acceptable response times (less than 2–3 seconds typical page load on LAN).
- **Efficiency**
  - Lightweight profile must avoid unnecessary always-on services.
  - Optional modules are disabled by default and enabled only when needed.
- **Security**
  - Force HTTPS for all web interfaces.
  - No default passwords; enforce strong admin credentials.
  - Minimize exposed ports to only what is essential.
- **Reliability**
  - Automatic restart of containers on failure.
  - Minimal downtime during updates (prefer rolling or blue/green where possible).
- **Maintainability**
  - All service configurations captured in Docker Compose files and environment files.
  - Version-controlled infrastructure configurations.
  - Clear documented update steps.
- **Usability**
  - Non-technical users can access daily tools from one portal in 1 click.
  - Admin actions are presented as guided tasks where possible.

### 2.3 High-Level Technical Choices

- Host OS: Ubuntu Server LTS or Debian (preferred), with Docker and Docker Compose.
- Reverse Proxy: Nginx Proxy Manager (default for simple UI) or Traefik.
- DNS Filtering: AdGuard Home (default lightweight) or Pi-hole; upstream: OpenDNS or equivalent.
- Mail Stack: Mailu (selected default and implementation target).
- ERP: Official ERPNext / Frappe Docker stack.
- Monitoring: Uptime Kuma (default lightweight); Netdata optional; Prometheus and Grafana only for advanced environments.
- Portal: Homer or Heimdall as mandatory user entry point.
- Authentication: Local accounts initially; potential for central SSO later.

### 2.3.1 Lightweight Software Selection Policy

- **Default principle**: choose the lowest-complexity tool that meets office requirements.
- **Core profile (recommended)**:
  - Nginx Proxy Manager + Homer/Heimdall portal.
  - AdGuard Home.
  - ERPNext.
  - Mailu (or Poste.io).
  - Uptime Kuma.
- **Extended profile (optional)**:
  - Nextcloud, Vaultwarden, Helpdesk, Asset management.
  - Advanced monitoring (Prometheus/Grafana).

### 2.4 Domain and URL Strategy

- Define a single **base domain** at provisioning time, for example:
  - `BASE_DOMAIN = manhal.mn`
- All service URLs are derived from this base domain using subdomains, for example:
  - `erp.${BASE_DOMAIN}` → ERPNext (for example, `erp.manhal.mn`).
  - `mail.${BASE_DOMAIN}` → Webmail and/or mail admin (for example, `mail.manhal.mn`).
  - `smtp.${BASE_DOMAIN}` / `imap.${BASE_DOMAIN}` → Mail protocols if exposed externally.
  - `dns.${BASE_DOMAIN}` → DNS filter admin (for example, `dns.manhal.mn`).
  - `files.${BASE_DOMAIN}` → File sync (for example, `files.manhal.mn` for Nextcloud).
  - `pw.${BASE_DOMAIN}` → Password manager (for example, `pw.manhal.mn` for Vaultwarden).
  - `portal.${BASE_DOMAIN}` → Main admin/user portal (for example, `portal.manhal.mn`).
  - `status.${BASE_DOMAIN}` → Monitoring dashboard (for example, `status.manhal.mn`).
- The base domain and all subdomain mappings are stored in a central configuration file (for example, `.env` or `config/domain.env`) and consumed by:
  - The reverse proxy (Nginx Proxy Manager) to create virtual hosts and SSL certificates.
  - Individual application stacks (ERPNext, Mailu, Nextcloud, etc.) via environment variables.
- Provisioning flow (first-time setup):
  - Admin provides `BASE_DOMAIN` (for example, `manhal.mn`) and external IP.
  - System generates recommended subdomain records and displays them as a checklist.
  - Admin configures DNS provider (or uses a wildcard `*.BASE_DOMAIN` record) pointing to the micro datacenter’s IP.
  - Reverse proxy requests and installs Let’s Encrypt certificates for each subdomain automatically.
- For LAN-only deployments without public DNS:
  - Use internal DNS (for example, AdGuard Home) to define hostnames such as `erp.office.local` instead of public domains.

### 2.5 Milestones

- **M1** – Design finalized and stacks chosen.
- **M2** – Base OS and Docker environment prepared on hardware.
- **M3** – Core lightweight services (portal, DNS, ERPNext, mail) deployed and accessible.
- **M4** – Admin portal, monitoring, backup jobs implemented.
- **M5** – Security review and basic penetration test.
- **M6** – User acceptance testing and go-live.

### 2.6 Design Enhancements and Assumptions

- **Tenant model**
  - Single-tenant: one office/customer per device, with full isolation per box.
  - Multi-tenant scenarios (one box for many customers) are out of scope for the initial version.
- **Appliance approach**
  - Treat the solution as an appliance image: standard OS and Docker base, configured through a wizard instead of manual edits.
  - Replacing a failed device is done by reinstalling the image and restoring from backups.
- **First-run wizard**
  - Web-based wizard accessible on first boot (or after reset) to:
    - Set `BASE_DOMAIN` and main admin account.
    - Configure network settings (static IP, DNS gateway if needed).
    - Enable or disable services, with lightweight core enabled by default (Portal, ERPNext, Mail, DNS).
    - Generate the list of DNS records/subdomains to configure externally.
- **Default operating mode**
  - Start in a lightweight mode that runs only core services.
  - Additional services are enabled later through the portal when business need is confirmed.
- **Admin roles in the portal**
  - Define roles such as:
    - Owner / Super Admin: full access to infrastructure and apps.
    - IT Admin: operational control (restart services, view logs, manage users).
    - Office Manager: manage business users in ERPNext, email, and collaboration tools only.
- **Remote support via VPN**
  - Optional WireGuard (or similar) VPN container for secure remote access by trusted support staff.
  - Administrative interfaces (Portainer, DNS admin, reverse proxy admin) should be reachable only over LAN or VPN, not directly from the public internet.
- **TLS and certificates**
  - Prefer wildcard certificates (for example, `*.BASE_DOMAIN`) obtained via DNS challenge when possible, to simplify managing many subdomains.
  - Fallback to individual Let’s Encrypt HTTP-01 certificates when wildcard DNS automation is not available.
- **Update strategy**
  - Provide a stable update channel with:
    - Clear indication of current and target versions.
    - A pre-update backup step.
    - Option to roll back to the previous version if issues occur.
- **Offline and degraded mode**
  - Core LAN functionality (ERP, DNS, internal mail delivery, file access) should continue to work during internet outages.
  - Document which features degrade (for example, external email, certificate renewal, cloud backups) when internet is unavailable.
- **Backups and portability**
  - Backups are designed to be portable between devices: restoring on new hardware should be straightforward via a guided restore wizard.
  - Backup format and location (for example, `/backups`) are standardized.
- **Observability defaults**
  - Uptime and health checks configured by default for all key services.
  - Optional email or messaging alerts for service downtime, backup failures, and high disk usage.

---

## 3. High-Level Architecture Specification

### 3.1 Logical Architecture

- Users (LAN) → Switch/Router → Micro Datacenter Device (Docker host).
- Front-end access:
  - HTTP/HTTPS via reverse proxy to:
    - ERPNext web UI.
    - Webmail interface.
    - DNS admin.
    - Admin portal.
    - Monitoring dashboards.
- Backend services:
  - Databases (MariaDB/PostgreSQL).
  - Redis or similar cache for ERPNext.
  - Mail transfer and storage (MTA, IMAP/POP).
- External services:
  - OpenDNS / upstream DNS resolvers.
  - Public DNS hosting for domains and MX records.
  - Optional off-site backup target.

### 3.2 Physical Architecture

- Single hardware node:
  - CPU: 4–8 cores.
  - RAM: 16–32 GB.
  - Storage: SSD (≥ 512 GB recommended).
  - NIC: 1 Gbps Ethernet.
- Network:
  - Static IP for the device.
  - Direct connection to office LAN/switch.
  - Optional VLAN separation for management interfaces.

### 3.3 Container Topology

- Reverse Proxy container (Nginx Proxy Manager default, Traefik optional).
- Portal container (Homer/Heimdall) as single user entry point.
- DNS container (AdGuard Home default, Pi-hole optional).
- ERPNext containers:
  - App container(s).
  - Database container.
  - Redis container.
- Mail stack containers:
  - SMTP, IMAP/POP, webmail, anti-spam, etc. (lightweight suite preferred by default).
- Optional services:
  - Nextcloud, Vaultwarden, helpdesk, asset management (disabled by default).
- Monitoring:
  - Uptime Kuma (default); optional Netdata; Prometheus/Grafana only when required.

### 3.4 Networking and Security

- Internal Docker networks:
  - Frontend network for reverse proxy and web apps.
  - Backend network for databases and internal services.
- Firewall:
  - Allow HTTP/HTTPS, SMTP, IMAPS, DNS as needed.
  - Restrict admin ports to specific IP ranges or VPN.
- Certificates:
  - Let’s Encrypt for public-facing domains.
  - Self-signed or internal CA for LAN-only endpoints if needed.

### 3.5 Application Stack Integration

- All application stacks (ERPNext, mail, files, password manager, etc.) are configured to:
  - Join the common `proxy` network so they can be published behind the reverse proxy.
  - Optionally join a `backend` network for database and internal traffic.
- Hostnames and URLs are derived from environment variables defined in the `.env` file (for example, `ERP_HOST`, `MAIL_HOST`, `FILES_HOST`), which themselves are built from `BASE_DOMAIN`.
- Example integration patterns:
  - ERPNext stack:
    - Containers join `proxy` and `backend` networks.
    - Public URL set to `https://erp.${BASE_DOMAIN}` (for example, `https://erp.manhal.mn`).
  - Mail stack (Mailu):
    - Joins `proxy` and `backend` networks.
    - Public URLs set via `MAIL_HOST`, `smtp.${BASE_DOMAIN}`, `imap.${BASE_DOMAIN}` as required.
  - Nextcloud, Vaultwarden, and other optional apps:
    - Join `proxy` network with hostnames `FILES_HOST`, `PASSWORDS_HOST`, etc.
- Each application stack can be defined in its own `docker-compose` file but shares the same `.env` file and Docker networks, allowing consistent domain mapping and centralized reverse proxy configuration.

---

## 4. Deployment & Installation Guide

### 4.1 Prerequisites

- **Hardware**
  - Mac mini–class or similar x86_64 device with 16–32 GB RAM and SSD.
- **Network**
  - Static IP reserved.
  - Ability to configure DNS and DHCP on the office router.
- **DNS**
  - Domain name accessible via public DNS (for email and HTTPS).
- **Admin**
  - Technical user with SSH access to the device.

### 4.2 Base OS Setup

1. Install Ubuntu Server (or chosen OS) with:
   - OpenSSH enabled.
   - Basic partitioning (root plus optional data partition).
2. Update system packages.
3. Create an administrative user and disable password-based SSH login.

### 4.3 Docker Environment Setup

1. Install Docker Engine and Docker Compose (or compose plugin).
2. Add admin user to the `docker` group if desired.
3. Configure Docker to:
   - Use log rotation.
   - Use data directory on larger storage partition if needed.

### 4.4 Application Stack Deployment

1. Clone or copy the infrastructure repository containing:
   - Docker Compose files.
   - Environment variable templates (`.env`).
2. Configure `.env` files:
   - Hostname and domain settings.
   - Admin credentials.
   - Email and DNS parameters.
3. Deploy core services in order:
   - Reverse proxy.
  - Portal.
  - DNS filtering container.
   - ERPNext stack.
   - Mail stack.
   - Optional services (Nextcloud, etc.).
4. Verify:
   - DNS resolution for clients (point a test machine at the device).
   - ERPNext accessible via HTTPS.
   - Webmail accessible via HTTPS.
   - Mail send/receive from/to external addresses.

### 4.5 Initial Configuration

- Run ERPNext setup wizard (company name, currency, etc.).
- Create initial mailboxes and test accounts.
- Configure office router:
  - Set DNS for LAN clients to the device’s IP.
- Configure public DNS:
  - A/AAAA records for services (mail, ERP, portal).
  - MX, SPF, DKIM, DMARC for the mail domain.

### 4.6 First-Run Setup Wizard Flow

The first-run wizard guides a non-technical admin through initial provisioning via a browser (for example, `http://portal.local` or `https://portal.BASE_DOMAIN`).

**Step 1 – Welcome and System Check**

- Display basic device information (hostname, IP, hardware profile, free disk space).
- Verify required services are running (reverse proxy, DNS, database engine).
- Confirm that the wizard has not been completed before (or offer a “factory reset” option).

**Step 2 – Administrator Account**

- Create the primary “Owner / Super Admin” account for the portal:
  - Full name.
  - Email address (for alerts and password recovery).
  - Strong password (with strength indicator).
- Optionally enable 2FA (if supported at this stage) or provide guidance to enable it later.

**Step 3 – Network and Domain Settings**

- Show current IP configuration (static or DHCP) with an option to switch to static IP.
- Ask for the base domain name to use, for example `manhal.mn`:
  - `BASE_DOMAIN = ____________`
- Confirm whether public DNS will be configured (internet-integrated mode) or LAN-only hostnames will be used.

**Step 4 – Service Selection**

- Let the admin choose which services to enable initially (lightweight defaults pre-selected):
  - [x] Portal (single homepage)
  - [x] ERPNext (ERP)
  - [x] Mail (Mailu/Poste.io or selected mail stack)
  - [x] DNS filtering (AdGuard Home)
  - [ ] File sync (Nextcloud)
  - [ ] Password manager (Vaultwarden)
  - [ ] Helpdesk / ticketing
  - [ ] Asset management
- Explain that additional services can be enabled later from the portal.

**Step 5 – Domain and DNS Checklist**

- Based on `BASE_DOMAIN` and selected services, generate a list of recommended DNS records, for example:
  - `erp.BASE_DOMAIN` → ERPNext.
  - `mail.BASE_DOMAIN` → Webmail/mail admin.
  - `portal.BASE_DOMAIN` → Portal.
  - `status.BASE_DOMAIN` → Monitoring.
  - `files.BASE_DOMAIN`, `pw.BASE_DOMAIN`, etc., as needed.
- Offer two options:
  - Use a wildcard record: `*.BASE_DOMAIN` pointing to the device IP (recommended where possible).
  - Create individual A/AAAA records for each hostname.
- Show a copy/paste-friendly table that the admin can use to configure their DNS provider.

**Step 6 – TLS and Certificates**

- Ask how certificates should be obtained:
  - [x] Automatic Let’s Encrypt (HTTP-01 or DNS-01 challenge).
  - [ ] Use existing certificate (upload files).
  - [ ] Use internal/self-signed certificates (LAN only).
- If wildcard via DNS-01 is chosen, guide the admin through adding the necessary DNS records or API credentials (if supported).

**Step 7 – Mail and ERP Basics**

- Mail setup (if enabled):
  - Primary mail domain (usually the same as `BASE_DOMAIN`).
  - Default quota settings for new mailboxes.
  - Optionally create first mailbox (for the Owner admin).
- ERPNext setup (if enabled):
  - Company name, country, default currency, and fiscal year.
  - Industry/type selection (to pre-load sample settings where appropriate).

**Step 8 – Summary and Apply Configuration**

- Present a summary page showing:
  - Chosen base domain.
  - IP configuration.
  - Enabled services and their URLs.
  - DNS records required or already detected as working.
- Ask for confirmation before applying settings and bringing all stacks online.
- Show progress while containers are started and initial migrations run.

**Step 9 – Post-Setup Dashboard**

- Redirect to the main portal with tiles for each enabled service.
- Display quick “next steps”, for example:
  - “Add users to ERPNext and mail.”
  - “Configure backup destination and schedule.”
  - “Enable 2FA for admin accounts.”

---

## 5. Operations Runbook

### 5.1 Daily/Weekly Tasks

- Check admin portal for:
  - Service health.
  - Resource usage (CPU, RAM, disk).
- Review DNS and mail logs for anomalies.
- Spot-check backups (ensure latest backups exist and appear complete).

### 5.2 Monthly Tasks

- Apply OS and Docker updates during planned maintenance window.
- Update containers (pull new images and redeploy).
- Test restore procedure on a non-production environment or with test data.
- Review user accounts and access levels (disable unused accounts).

### 5.3 Incident Response

- **Service down**
  - Check container status.
  - Restart affected container(s).
  - Inspect logs for root cause.
- **Performance degradation**
  - Check resource usage.
  - Identify misbehaving containers.
  - Consider scaling container resources or refactoring usage.
- **Security incident**
  - Immediately revoke compromised credentials.
  - Review logs and isolate affected services.
  - Restore from known-good backup if required.

### 5.4 Change Management

- All configuration changes documented in a simple change log.
- Significant updates scheduled during low-usage periods.
- Ability to roll back to previous container image version or configuration snapshot.

---

## 6. Security & Access Policy

### 6.1 Access Control

- **Admin access**
  - Restricted to named admins with strong individual accounts.
  - SSH access via key-based authentication only.
- **Application access**
  - ERPNext and webmail accounts tied to real staff identities.
  - Role-based permissions applied in ERPNext.

### 6.2 Authentication and Passwords

- Enforce strong passwords for all admin accounts.
- Encourage or enforce 2FA where supported (ERPNext, webmail, admin portal).
- Rotate critical credentials (database, mail, root/admin) at least annually.

### 6.3 Network Security

- **Firewall configuration**
  - Allow only:
    - HTTPS.
    - SMTP and IMAPS (if needed externally).
    - DNS (for LAN clients).
  - Block unnecessary ports from external networks.
- Optionally require VPN for administrative functions.

### 6.4 Data Protection

- All web interfaces over HTTPS.
- Data at rest protected via filesystem permissions; consider disk encryption where feasible.
- Backups encrypted when stored off-device.

### 6.5 Logging and Auditing

- Central logging for:
  - Authentication attempts.
  - Service failures.
  - Administrative actions where supported.
- Log retention policy (for example, 90–180 days) with secure storage.

---

## 7. Backup & Disaster Recovery Plan

### 7.1 Backup Strategy

- **Scope**
  - ERPNext database and files.
  - Mail server data (mailboxes, configs).
  - DNS configuration and logs (if required).
  - Configuration files and compose definitions.
- **Frequency**
  - Daily full backups of databases and critical configs.
  - More frequent incremental or snapshot-based backups if available.
- **Storage**
  - Local backup directory on device.
  - External USB drive (rotated regularly).
  - Optional remote/cloud backup via rclone or equivalent.

### 7.2 Backup Implementation

- Use scheduled jobs (cron or scheduler containers) to:
  - Dump databases to compressed files.
  - Archive key configuration directories.
- Verify backups:
  - Check logs for successful runs.
  - Periodic manual restoration test on non-production environment.

### 7.3 Recovery Objectives

- **Recovery Time Objective (RTO)**
  - 4–8 hours for full-system recovery after hardware or software failure.
- **Recovery Point Objective (RPO)**
  - 24 hours (data loss limited to changes since last daily backup).

### 7.4 Restore Procedures

- **Hardware failure**
  - Replace or repair device.
  - Install base OS and Docker.
  - Restore configuration repository and backup archives.
  - Redeploy containers and apply restored data.
- **Service-level restore**
  - Restore specific database or mailboxes from backup.
  - Validate service behavior and integrity.

### 7.5 Testing and Review

- Backup and restore process tested at least twice per year.
- Update procedures and documentation after each major test or incident.

---

## 8. Application Stack Specifications

This section describes each major application stack, focusing on how it plugs into the shared infrastructure (networks, domains, data) and what a non-technical admin needs to know.

### 8.1 Reverse Proxy and Portal Layer

**8.1.1 Nginx Proxy Manager (NPM)**

- **Purpose**: Central entry point for all HTTPS traffic; manages virtual hosts and TLS certificates via a web UI.
- **Images**: `jc21/nginx-proxy-manager:latest`.
- **Networks**: `proxy` (frontend).
- **Ports**:
  - 80/tcp (HTTP, used for redirects and ACME HTTP-01 challenges).
  - 81/tcp (NPM admin UI; should be restricted to LAN/VPN).
  - 443/tcp (HTTPS termination for all public services).
- **Data persistence**: `npm_data` and `npm_letsencrypt` volumes for configuration and certificates.
- **Integration**:
  - Uses `BASE_DOMAIN` and `*_HOST` values to define proxy hosts.
  - Obtains and renews Let’s Encrypt certificates (single or wildcard).

**8.1.2 Portal (Homer/Heimdall)**

- **Purpose**: Single landing page with tiles for all services; required main entry point for admins and users.
- **Images**: `b4bz/homer:latest` (or equivalent Heimdall image if preferred).
- **Networks**: `proxy`.
- **URL**: `PORTAL_HOST` (for example, `portal.manhal.mn`).
- **Data persistence**: `portal_data` volume storing configuration (links, groups, icons).
- **Integration**:
  - First-run wizard publishes this portal at the `PORTAL_HOST` URL.
  - Tiles link to ERPNext, webmail, DNS admin, monitoring, Docker UI, etc.
  - End-user view shows business apps first; admin tools are role-restricted.

**8.1.3 Portainer (Docker UI)**

- **Purpose**: Simple web UI to view, start/stop, and inspect containers and volumes.
- **Images**: `portainer/portainer-ce:latest`.
- **Networks**: `proxy`.
- **URL**: `DOCKER_UI_HOST` (for example, `docker.manhal.mn`), typically restricted to LAN/VPN.
- **Data persistence**: `portainer_data` volume.
- **Integration**:
  - Connects to the Docker socket on the host.
  - Only exposed via the reverse proxy to trusted networks.

### 8.2 DNS Filtering Stack (AdGuard Home)

- **Purpose**: DNS resolution and content filtering for LAN clients; optional upstream to OpenDNS.
- **Images**: `adguard/adguardhome:latest`.
- **Networks**: `proxy`.
- **Ports**:
  - 53/tcp and 53/udp (DNS service for the network).
  - 3000/tcp (initial setup and admin UI; later proxied behind `DNS_HOST`).
- **URL**: `DNS_HOST` (for example, `dns.manhal.mn`) when proxied via NPM.
- **Data persistence**: `adguard_conf` and `adguard_work` volumes.
- **Integration**:
  - Office router/DHCP points clients to this device as primary DNS resolver.
  - AdGuard Home configured to use OpenDNS (or similar) as upstream servers.
  - Internal DNS entries can be created for local-only hostnames when needed (for example, `erp.office.local`).

### 8.3 Email Stack (Mail Suite)

- **Preferred option**: Use Mailu as the selected integrated mail suite for this project.
- **Purpose**: Provide SMTP/IMAP, webmail, spam filtering, and administrative control in one web UI.
- **Images**: As provided by chosen suite (not reproduced here to avoid divergence from upstream).
- **Networks**: `proxy` and `backend`.
- **URLs**:
  - `MAIL_HOST` (for example, `mail.manhal.mn`) for webmail and mail admin UI.
  - `smtp.${BASE_DOMAIN}` and `imap.${BASE_DOMAIN}` for mail clients, if exposed externally.
- **Ports** (typically via host mapping or reverse proxy, depending on suite):
  - SMTP (25, 587/tcp), IMAP (143, 993/tcp), and associated ports as required.
- **Data persistence**:
  - Volumes for mail storage, configuration, and spam/antivirus data defined by the mail suite.
- **Integration**:
  - Uses `BASE_DOMAIN` as main mail domain unless overridden.
  - Reverse proxy publishes webmail/admin UI at `MAIL_HOST` over HTTPS.
  - DNS records configured (MX, SPF, DKIM, DMARC) as per suite documentation.

### 8.4 ERP Stack (ERPNext)

- **Purpose**: Provide ERPNext for CRM, sales, purchasing, accounting, inventory, HR, and related modules.
- **Images**: Official ERPNext/Frappe Docker images (for example, `frappe/erpnext` plus supporting services such as MariaDB and Redis).
- **Networks**: `proxy` and `backend`.
- **URL**: `ERP_HOST` (for example, `erp.manhal.mn`).
- **Data persistence**:
  - Database volume (MariaDB/PostgreSQL data).
  - File storage volume for user uploads and ERPNext files.
  - Redis data (optional, depending on configuration).
- **Integration**:
  - Exposed behind the reverse proxy with HTTPS.
  - Configured to send email via the mail stack (SMTP settings).
  - First-run ERPNext wizard completed during Step 7 of the first-run setup.

### 8.5 File Sync Stack (Nextcloud – Optional)

- **Purpose**: Web-based file sharing, sync, calendars, and contacts.
- **Images**: Official Nextcloud Docker image plus a database (MariaDB/PostgreSQL) and optional Redis.
- **Networks**: `proxy` and `backend`.
- **URL**: `FILES_HOST` (for example, `files.manhal.mn`).
- **Data persistence**:
  - Application data volume.
  - Database volume.
- **Integration**:
  - Reverse proxy publishes Nextcloud at `FILES_HOST` over HTTPS.
  - User accounts may be managed locally or integrated with other identity solutions if added later.

### 8.6 Password Manager Stack (Vaultwarden – Optional)

- **Purpose**: Provide secure password management compatible with Bitwarden clients.
- **Images**: `vaultwarden/server:latest` (or maintained equivalent).
- **Networks**: `proxy`.
- **URL**: `PASSWORDS_HOST` (for example, `pw.manhal.mn`).
- **Data persistence**: Dedicated volume for Vaultwarden data.
- **Integration**:
  - Reverse proxy publishes Vaultwarden at `PASSWORDS_HOST` with HTTPS.
  - Admin can create organizations and share vaults with staff.

### 8.7 Monitoring and Status Stack

**8.7.1 Uptime Kuma**

- **Purpose**: Monitor availability of internal and external services with a simple dashboard and notifications.
- **Images**: `louislam/uptime-kuma:latest`.
- **Networks**: `proxy`.
- **URL**: `STATUS_HOST` (for example, `status.manhal.mn`).
- **Data persistence**: `uptime_kuma_data` volume.
- **Integration**:
  - Checks endpoints such as ERPNext (`ERP_HOST`), mail/webmail (`MAIL_HOST`), DNS UI (`DNS_HOST`), Nextcloud, Vaultwarden, and portal.
  - Can send alerts to email or messaging platforms based on admin configuration.

**8.7.2 System Metrics (Optional – Netdata/Prometheus + Grafana)**

- **Purpose**: Deeper performance and resource monitoring if needed.
- **Images**: Netdata (`netdata/netdata`) or Prometheus and Grafana images.
- **Networks**: `proxy` and/or `backend` as required.
- **Integration**:
  - Links from the portal for admins only.
  - Used primarily by technical staff for troubleshooting.
  - Disabled by default in lightweight profile.

### 8.8 VPN / Remote Access Stack (WireGuard – Optional)

- **Purpose**: Provide secure remote access for trusted support or admins without exposing admin UIs directly to the internet.
- **Images**: `lscr.io/linuxserver/wireguard:latest`.
- **Networks**: `backend`.
- **Ports**: 51820/udp (default WireGuard port; configurable).
- **Data persistence**: `wireguard_config` volume.
- **Integration**:
  - VPN clients connect to the micro datacenter and gain access to admin interfaces (NPM, Portainer, mail admin, DNS admin) over the internal networks.
  - Portal may display a “Remote Support” tile visible only to Owner/IT Admin roles with connection instructions.
