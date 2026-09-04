# Purpose of the server:
I use AdGuard home only as a local plain DNS server for sinkholing ads and trackers and override of my server's domain to local address in local network. I'll also use the admin panel.

# DNS settings:
## Upstream DNS:
https://dns9.quad9.net/dns-query
tls://dns9.quad9.net

## Bootstrap DNS:
9.9.9.9
9.9.9.10
9.9.9.11
149.112.112.112
149.112.112.10
149.112.112.11

# Other:
Redirect ports 53 -> 5353 via ufw (iptables) before.rules. Adguard is a rootless container.
Change DNS server for this machine to 127.0.0.1:5353
Disabled dns stub listener of systemd-resolved in /etc/systemd/resolved.service.d/adguardhome.conf.

# Admin UI (behind Caddy):
- URL: `https://adguard.duckdns.org`
- Container admin port `3000` is not host-published; Caddy proxies on `homelab` Podman network.
