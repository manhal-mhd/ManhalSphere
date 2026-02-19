# Mailu DNS Records — octalearn.sd

Use these DNS records for the current Mailu deployment.

## Required Records

- `A` record
  - Host: `mail.octalearn.sd`
  - Value: `102.130.255.187`
  - TTL: `600`

- `MX` record
  - Host: `octalearn.sd`
  - Value: `10 mail.octalearn.sd.`
  - TTL: `600`

- `TXT` SPF record
  - Host: `octalearn.sd`
  - Value: `v=spf1 mx a:mail.octalearn.sd ~all`
  - TTL: `600`

- `TXT` DKIM record
  - Host: `dkim._domainkey.octalearn.sd`
  - Value:
    - `v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoNHqzq7diuRA4iSu0bkdVuJzwvbknXP+LxpPvZbWOoBS3h3LDMH+pVm6O3Cdjpx35rK2CRrhRLitnYGNBOBkTKaTkkUf0Wh3JXx17+hI2AyqiunxXFBJ7lYqejAai9rBaiTcZc+g8PDuN6ovhsdYaigEFFRQcKTmlv/4gK9FwO9O2l/XbO08aPQe2DNhy0g3f0cKbBNveTURnYA8hUV3AOSHioIFhMbSDaRphvDEdlvMmSrvY/E+wJBBplSBrix08ovfCfedMpMDrDvt3/xQQaXwXTbXKvo6f0hPfqeuWizLPxt5QRzQmmxqTBAAKewZi9NzIWUQR9XjN+CapSiktwIDAQAB`
  - TTL: `600`

- `TXT` DMARC record
  - Host: `_dmarc.octalearn.sd`
  - Value: `v=DMARC1; p=reject; adkim=s; aspf=s`
  - TTL: `600`

## Recommended Additional Records

- `A` record for webmail convenience (optional)
  - Host: `webmail.octalearn.sd`
  - Value: `102.130.255.187`

- `CAA` records (optional hardening)
  - `0 issue "letsencrypt.org"`
  - `0 iodef "mailto:postmaster@octalearn.sd"`

- `PTR` (reverse DNS) via your server/VPS provider (important for deliverability)
  - IP `102.130.255.187` should resolve to `mail.octalearn.sd`

## Service Endpoints (Current)

- Webmail: `https://mail.octalearn.sd/webmail`
- Mail admin SSO: `https://mail.octalearn.sd/sso/login`
- IMAPS: `mail.octalearn.sd:993`
- SMTP submission (STARTTLS): `mail.octalearn.sd:587`

## Post-DNS Validation

After saving DNS records, validate:

- `dig +short MX octalearn.sd`
- `dig +short TXT octalearn.sd`
- `dig +short TXT dkim._domainkey.octalearn.sd`
- `dig +short TXT _dmarc.octalearn.sd`
- Send a message to a Gmail/Outlook mailbox and verify SPF/DKIM/DMARC pass in headers.
