# rustic — encrypted Google Drive backups

Host binary + rootful systemd timer. Not a Podman service. Google sees ciphertext only.

Official docs: [rustic user documentation](https://rustic.cli.rs/docs), [configuration file](https://rustic.cli.rs/docs/commands/init/configuration_file.html), [OpenDAL services](https://rustic.cli.rs/docs/commands/init/services.html), [OpenDAL Gdrive](https://opendal.apache.org/docs/rust/opendal/services/struct.Gdrive.html), [scheduling](https://rustic.cli.rs/docs/commands/backup/scheduling.html).

## Host paths

| Path | Role |
|------|------|
| `/usr/local/bin/rustic` | musl binary |
| `/etc/rustic/rustic.toml` | profile (no secrets) |
| `/etc/rustic/password` | repo encryption password, mode `600` |
| `/etc/rustic/gdrive.env` | OpenDAL OAuth env, mode `600` |
| `/etc/systemd/system/rustic-backup.service` | oneshot |
| `/etc/systemd/system/rustic-backup.timer` | daily 03:30 |

Repo password: store in Vaultwarden **and** offline (paper/USB). Vaultwarden-only is a chicken-egg on disaster restore.

OpenDAL cannot do the first OAuth hop. Credentials stay in `gdrive.env`, not in TOML. OpenDAL options use snake_case, so rustic reads `OPENDAL_*` (not `RUSTIC_REPO_OPT_*`). See [config/README.md](https://github.com/rustic-rs/rustic/blob/main/config/README.md).

Manual rustic commands need the same env as the timer:

```bash
sudo bash -c 'set -a; source /etc/rustic/gdrive.env; set +a; rustic "$@"' _ snapshots
```

Replace `snapshots` with `backup`, `check`, `init`, etc.

## 1. Install rustic

Pin to the version this layout was written for, or pick a newer [release](https://github.com/rustic-rs/rustic/releases):

```bash
VER=0.11.4
ARCH=x86_64-unknown-linux-musl
curl -fL "https://github.com/rustic-rs/rustic/releases/download/v${VER}/rustic-v${VER}-${ARCH}.tar.gz" -o /tmp/rustic.tar.gz
sudo tar -C /usr/local/bin -xzf /tmp/rustic.tar.gz rustic
sudo chmod 755 /usr/local/bin/rustic
rustic --version
sudo apt-get install -y sqlite3
```

Later updates: `sudo rustic self-update` (needs write access to the binary).

## 2. Config and secrets

From this directory in a clone of the homelab repo (`services/rustic/`):

```bash
sudo mkdir -p /etc/rustic
sudo chmod 700 /etc/rustic
sudo cp rustic.toml /etc/rustic/rustic.toml
```

Generate the password and store it offline as well:

```bash
openssl rand -base64 32 | sudo tee /etc/rustic/password >/dev/null
sudo chmod 600 /etc/rustic/password
```

Create `/etc/rustic/gdrive.env` (mode `600`) after OAuth:

```
OPENDAL_CLIENT_ID=....apps.googleusercontent.com
OPENDAL_CLIENT_SECRET=...
OPENDAL_REFRESH_TOKEN=1//...
```

No quotes unless the value contains spaces. No `export`.

## 3. Google OAuth

1. [Google Cloud Console](https://console.cloud.google.com/): new project (or existing).
2. Enable **Google Drive API**.
3. OAuth consent screen: External. **Publish the app.** Tokens from a consent screen left in Testing expire after 7 days. Personal use with the unverified-app warning is fine.
4. Credentials → Create OAuth client ID → application type **Desktop app**. Copy client ID and secret.
5. Mint a refresh token with [OAuth 2.0 Playground](https://developers.google.com/oauthplayground/):
    - Gear: **Use your own OAuth credentials**; paste client ID and secret.
    - Scope: `https://www.googleapis.com/auth/drive`
    - Authorize, then Exchange authorization code for tokens.
6. Put `OPENDAL_CLIENT_ID`, `OPENDAL_CLIENT_SECRET`, `OPENDAL_REFRESH_TOKEN` in `/etc/rustic/gdrive.env`.

```bash
sudo chmod 600 /etc/rustic/gdrive.env
```

## 4. Init repository

```bash
sudo bash -c 'set -a; source /etc/rustic/gdrive.env; set +a; rustic init'
```

Drive folder is `/ideapad110-homelab` (`[repository.options] root` in `rustic.toml`).

## 5. First backup, check, restore test

```bash
sudo bash -c 'set -a; source /etc/rustic/gdrive.env; set +a; rustic backup'
sudo bash -c 'set -a; source /etc/rustic/gdrive.env; set +a; rustic check'
sudo bash -c 'set -a; source /etc/rustic/gdrive.env; set +a; rustic snapshots'
sudo mkdir -p /tmp/rustic-restore-test
sudo bash -c 'set -a; source /etc/rustic/gdrive.env; set +a; rustic restore --filter-label caddy latest:/etc/caddy /tmp/rustic-restore-test'
ls /tmp/rustic-restore-test
sudo rm -rf /tmp/rustic-restore-test
```

If `rustic check` reports pack size `0` or Drive API errors, use the rclone fallback below. Do not dual-run backends.

## 6. Enable the timer

From `services/rustic/` in the repo clone:

```bash
sudo cp rustic-backup.service rustic-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rustic-backup.timer
systemctl list-timers rustic-backup.timer
journalctl -u rustic-backup.service -e
```

On-demand run: `sudo systemctl start rustic-backup.service`.

## Restore

List snapshots, then restore from that service's snapshot (`--filter-label`). Example: Vaultwarden data:

```bash
sudo bash -c 'set -a; source /etc/rustic/gdrive.env; set +a; rustic snapshots'
sudo bash -c 'set -a; source /etc/rustic/gdrive.env; set +a; rustic restore --filter-label vaultwarden latest:/srv/vaultwarden /srv/vaultwarden'
```

Prefer `db.backup.sqlite3` over a live `db.sqlite3` copy if the snapshot was taken while Vaultwarden was running. Stop the container before replacing data.

One service only: `rustic backup --name vaultwarden`.

## rclone fallback

Use only if OpenDAL GDrive fails the check above. rustic still encrypts; rclone is the pipe. Docs: [Other Services via rclone](https://rustic.cli.rs/docs/commands/init/rclone.html).

```bash
sudo apt-get install -y rclone
sudo rclone config
```

Create a Drive remote named `gdrive`. Use a **new** Drive folder (do not point at the OpenDAL repo). In `/etc/rustic/rustic.toml` replace:

```toml
repository = "opendal:gdrive"
```

with:

```toml
repository = "rclone:gdrive:ideapad110-homelab"
```

Remove `throttle` from `[repository.options]` (that key is OpenDAL-only). Optional bandwidth limit:

```toml
[global.env]
RCLONE_BWLIMIT = "1M"
```

Then `sudo rustic init` (rclone uses `/root/.config/rclone/rclone.conf`; systemd as root will see it). Re-run backup, check, restore test. You can drop `EnvironmentFile=` from the service if OAuth lives only in rclone.conf — keep it if you still use `gdrive.env` for nothing else.

## What is backed up

One snapshot per service (that service's `/etc` and `/srv` together). Forget retention applies per label.

- **caddy:** `/etc/caddy`, `/srv/caddy`
- **vaultwarden:** `/etc/vaultwarden`, `/srv/vaultwarden` (plus `db.backup.sqlite3` from that snapshot's pre-backup hook)
- **adguardhome:** `/etc/adguardhome`, `/srv/adguardhome`
- **ufw:** `/etc/ufw`
- **quadlets:** `/home/tima/.config/containers/systemd` (covers tg-ws-proxy)

Not 3-2-1: live disk + one encrypted offsite copy. Media (Jellyfin later) does not belong on Drive.
