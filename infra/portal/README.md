# ManhalSphere — Micro Datacenter

ManhalSphere is a production-oriented self-hosted platform that unifies core business and infrastructure services behind a single, domain-driven gateway. Built with Docker Compose, it provides a practical foundation for running ERP, file services, mail, password management, monitoring, backups, and DNS in one coherent operating sphere.

Purpose
- Make life easier by providing a single, maintainable micro-datacenter stack.
- Emphasise reliability, security and operational simplicity.

Included services (example)
- ERPNext + HRMS
- Mail (Mailu)
- Nextcloud (files)
- Vaultwarden (passwords)
- Uptime Kuma (monitoring)
- Backup manager (restic)
- DNS manager

Quickstart (mockup)
1. Preview the portal mockup:

```bash
cd infra/portal/mockup
python3 -m http.server 8000
# open http://localhost:8000
```

2. To integrate into your deployment, copy the template `infra/portal/config.yml.template` into your config directory and update base domain and tile URLs.

Customization
- Icons: use SVG files in `infra/portal/mockup/icons/` or point tile `logo` values in `config.yml` to external SVGs.
- Colors: adjust `styles.css` tokens (`--accent`, `--text`, etc.) to match branding.

Contact
- Created by Manhal Mohammed — https://www.linkedin.com/in/manhalmohammed/

License
- MIT (same as the surrounding project unless otherwise noted)
