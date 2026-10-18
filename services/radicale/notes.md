# Deploy
- podman quadlet for automatic updates

# Configuration
- all configs live /etc/radicale/config
- data in /srv/radicale (read only for my user)
- users in /etc/radicale/users
- listens localhost:5232

## Authentication
- use htpasswd with hash to manage users
- htpasswd -5 -c /etc/radicale/users tima

## Reverse Proxy
- Caddy via caddyfile
- Subdomain dav.tapocek.duckdns.org

## Backup
- rustic backup of /etc/radicale and /srv/radicale

## Firewall
- open 5232 for anyone on tailscale for now
