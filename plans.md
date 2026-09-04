# Planned services:
## Strongly planned:
1. Jellyfin
2. Seafile (or better suited cloud storage alternative)
3. Radicale

## Maybe planned:
- Soulseek for sharing with community

# Service improvement plans:
## Maybe planned:
- Authelia in front of Caddy-proxied services

# Infrastructure plans:
- Migrate from Ubuntu to Debian (debian is truly free, no corporate ties)
- 3-2-1 backups: rustic already targets encrypted Google Drive (live disk + one offsite copy); add a second local or offline copy
- Internet exposure: widen UFW for Caddy 443; keep DNS closed
