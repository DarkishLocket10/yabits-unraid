# Set up your own Yabits server

Yabits works without a server. Self-hosting adds sync between your devices and a
web app you can use in your browser. Your habits still work when you're offline.

If you only use Apple devices and don't want to maintain a server, choose iCloud
in **Settings → Data & backup → Sync** instead.

## Pick your setup

| What you have | Start here |
| --- | --- |
| A computer or server with Docker and a domain | [Docker setup](#docker-setup) |
| Unraid, especially with SWAG already installed | [Unraid setup](#unraid-setup) |
| Just want to try the web app on this computer | [Local trial](#local-trial) |
| A server that already works | [Connect your phone](#connect-your-phone) |

The public downloads and this guide live in
[yabits-unraid](https://github.com/DarkishLocket10/yabits-unraid). Despite its name,
that repository also includes the regular Docker setup. You don't need access to
the private server source. The server image is public.

## Docker setup

### 1. Have these ready

- A computer you can leave on, with [Docker and Compose](https://docs.docker.com/get-started/get-docker/).
  On a Mac or Windows PC, Docker Desktop includes both. On Linux, install the
  Docker Engine and Compose plugin.
- A domain such as `habits.yourdomain.com`. In your DNS provider, create an **A**
  record pointing to this server's public IPv4 address. Only add an **AAAA** record
  if IPv6 actually reaches this server. For this Caddy setup, use **DNS only** if
  your DNS provider is Cloudflare.
- TCP ports **80 and 443** available on that computer. If it is at home, forward
  those two ports in your router to this computer and allow them in its firewall.
  Keep its local IP stable using a router DHCP reservation.

The helper adds Caddy, which gets and renews your HTTPS certificate automatically.
It follows [Caddy's HTTPS setup](https://caddyserver.com/docs/quick-starts/https).
If you already have a reverse proxy on ports 80/443, use your existing proxy
instead; don't start a second one on those ports. Unraid/SWAG instructions are below.

If your internet provider uses CGNAT or blocks incoming ports, this direct setup
won't work from home. Use a server with a reachable public address, or have your
existing HTTPS/VPN setup route to Yabits. An HTTP LAN address alone won't work for
phone sync. You can still try the browser version locally first.

### 2. Download and run the helper

Open a terminal on the computer that will run Yabits. Copy these commands:

```sh
curl -fL https://raw.githubusercontent.com/DarkishLocket10/yabits-unraid/main/quickstart/setup.sh -o yabits-setup.sh
sh yabits-setup.sh
```

Enter your full address when asked, for example `https://habits.yourdomain.com`.
The helper creates a new `yabits-home` folder and starts the containers. It:

- generates a random server key and saves it in a private `.env` file;
- uses persistent Docker volumes for habits and HTTPS certificates;
- starts the released server image, without building source code;
- gives only the HTTPS proxy access to the server port;
- refuses to replace an existing installation.

**Keep the `yabits-home` folder and its `.env` file.** Save the secret key from
`.env` in your password manager too. It is a permanent server key, separate from
your account password. Don't regenerate it during an update. Never post `.env`
or unredacted logs in an issue.

To prepare the files without starting anything:

```sh
sh yabits-setup.sh --no-start https://habits.yourdomain.com yabits-home
```

Then, from `yabits-home`, run `docker compose up -d --wait`. Use the same folder
for future commands so Docker keeps using the same named volumes.

### 3. Create your account

```sh
cd yabits-home
docker compose logs yabits
```

Find the **setup token** in the startup log. Open your HTTPS address, paste that
token into the setup page, and choose your account name and password. Use a
unique password and save it in your password manager.

The token expires after one hour and works only until the account is created.
If it expired, run `docker compose restart yabits`, then read the newest token
in the logs. **Don't delete the volume.** A claimed server shows sign-in on
future visits; the setup page isn't meant to come back.

The server may take a little longer on its first start while it prepares the
database and password settings. If HTTPS isn't ready yet, check
`docker compose logs caddy`; DNS and port forwarding must be correct before
Caddy can obtain a certificate.

### 4. Connect a phone and check sync

Follow [Connect your phone](#connect-your-phone), then the two-way check below.
A healthy container alone doesn't prove your phone can sync.

## Unraid setup

If SWAG already works, you only need the Yabits container, its data folder and a
proxy configuration. Use the
[Unraid and SWAG guide](https://github.com/DarkishLocket10/yabits-unraid#deploying-yabits-server-on-unraid-behind-swag-and-cloudflare)
for the complete sequence, including Cloudflare, DNS, folder ownership and backups.

The main things to fill in are:

1. **External URL:** the HTTPS address you'll use in the browser and app.
2. **Secret key:** generate once with `openssl rand -base64 32`, then save it.
3. **Data folder:** keep `/mnt/user/appdata/yabits-server` mapped to `/data`.
4. **Network:** the same dedicated Docker network as SWAG.
5. **Trusted proxy:** only SWAG's fixed IP, with `/32` after it.

Open the container log to get its setup token. Create your account at the HTTPS
address, then follow the phone instructions below. Container updates keep your
habits as long as the same data folder stays mapped.

## Local trial

This starts only on this computer. It does not expose a server to your network:

```sh
sh yabits-setup.sh http://localhost:8080 yabits-trial
```

Open `http://localhost:8080` on that computer, get the setup token with
`docker compose logs yabits` from the `yabits-trial` folder, and create an account.

A phone's `localhost` means the phone itself. **This trial cannot sync a physical
phone.** For phone sync, use the HTTPS setup. Pick a different unused port such
as `http://localhost:8081` if 8080 is taken. Treat this as a separate trial;
changing the address of a browser's saved data is not a migration shortcut.

## Connect your phone

Do this once for each phone, using the **same account** on the **same server**.
Give each phone a separate app token; don't reuse a token on another device.

1. Open your server's HTTPS address in a browser and sign in.
2. Open **Settings → Security**.
3. Under **Password and account security**, enter your password and select
   **Verify for sensitive changes**. If you enabled an authenticator, enter its
   code too.
4. Under **Enroll another app**, enter a name such as `My iPhone` and choose
   **Create one-time app token**.
5. Connect using one of these:
   - **Browser on the phone:** tap **Open secure app enrollment**. Yabits opens
     and connects automatically.
   - **Browser on another screen:** in Yabits, open **Settings → Data & backup**,
     choose **Self-hosted**, then **Scan enrollment QR code**.
   - **Manual:** copy the enrollment link into **Paste enrollment link** and tap
     **Connect to server**. If you only have the raw token, open **Enter server
     and token separately**, enter your exact HTTPS address and token, then connect.
6. Back in Data & backup, tap **Sync now**. Wait for **Up to date** and no waiting
   uploads. If a conflict needs a choice, use **Review conflicts**.

In older iOS builds, Sync is directly on the main Settings page. Android's
self-hosted controls are also in Settings. The enrollment link is the easiest
way to connect either app without finding a setting.

The app token is shown once. Keep the page open until the phone connects. If you
lose the token, revoke that unused token in Security and create another. Your
account password, initial setup token and app token are three different things.
Only the app token or its enrollment link belongs in the phone's sync settings.

### Check sync in both directions

1. On the phone, add a habit called `Sync test`. Tap **Sync now** and wait until
   it is up to date.
2. Open the same server account in your browser. Confirm `Sync test` appears.
3. Check it off in the browser. Bring the phone to the foreground and sync it.
   The check-in should appear there too.
4. Put the phone offline, change another day's check-in, then reconnect and sync.
   Confirm the browser catches up.
5. Delete the test habit when you're done and confirm it disappears on both.

Keep the app open during the first sync, especially with years of history.
Later changes sync while the app is active and when it returns to the foreground;
**Sync now** is useful for checking immediately. Background execution is up to iOS.

Health values stay on the device that read them. Theme, app icon, sound settings
and imported sound files are also local preferences. Different sounds on two
phones do not mean sync failed. Only one sync provider is active at a time;
choosing Self-hosted switches away from iCloud without deleting local habits.

## If something isn't working

| What you see | What to do |
| --- | --- |
| Docker isn't running | Start Docker Desktop or the Docker service, then rerun the helper. |
| Folder already exists | Use that folder and run `docker compose up -d`. The helper won't replace its key. |
| Port already allocated | Another program owns the port. Use your existing HTTPS proxy, or choose another port for a local trial. |
| Docker network pool overlaps | The quickstart uses `172.30.58.0/29`. Before starting, change its subnet and both fixed IPs in `compose.yaml`, and the trusted proxy address in `.env`, to an unused private range. |
| Site won't open | Check DNS, router forwarding and firewall. A wrong AAAA record can break access even when the A record is right. |
| Certificate error | Check `docker compose logs caddy`. Verify ports 80/443 reach this computer and that DNS isn't pointing elsewhere. Don't bypass the warning or change the app to HTTP. |
| Setup token expired | Restart only the Yabits container, then copy its newest token. No data deletion needed. |
| Sign-in immediately fails or loops | Use the exact HTTPS address in `YABITS_EXTERNAL_URL`. The scheme, hostname and port must match. |
| Could not connect on the phone | First open that same HTTPS address in the phone's browser. Then check that you used an app enrollment token, not your password or setup token. |
| Connect this device again | The token may have been revoked by a password change or server restore. Create a fresh app token for this phone. |
| Up to date but missing habits | Check the server address, signed-in account, habit filters and archived habits. Health-only values don't sync. |
| Waiting to upload | Keep the app open, check the connection, then tap Sync now. Review any conflicts or error message before changing settings. |
| Unable to open database file on Unraid | Check that the mapped data directory belongs to `99:100`, as shown in the Unraid guide. The Docker helper's named volume handles this automatically. |

## Updates and backups

The helper starts a known server release (`1.0.5`) and Caddy (`2.11.4-alpine`). It
doesn't silently change versions. Read the new release notes, take a backup, then
edit the corresponding image tag in `compose.yaml` and run:

```sh
docker compose pull
docker compose up -d --wait
```

Keep the same folder, `.env` and volumes. **Do not run `docker compose down -v`:**
`-v` removes the volumes containing your habits and certificates. A normal
container restart or replacement doesn't delete them.

Sync is not a backup: deletions can sync too. In the iOS app, use **Data & backup →
Backups & restore** for local restore points, or **Export database** for a portable
copy of manual data. Health values are excluded from portable exports.

For a whole-server backup, follow the offline procedure in the
[operations guide](https://github.com/DarkishLocket10/yabits-unraid#backup-and-restore).
Stop the server before taking its database snapshot; don't copy just a live
SQLite file. Save the permanent secret key separately. Restoring a server
invalidates sessions and app tokens, so reconnect each device afterwards.

### Back up the Docker quickstart

Run these from your existing `yabits-home` folder. This stops sync briefly and
uses the server's own backup command. The name includes the date and time, so a
new backup never replaces an old one.

```sh
mkdir -p backups
YABITS_BACKUP_NAME="yabits-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
docker compose stop yabits &&
  docker compose run --rm --no-deps yabits backup --output "/data/$YABITS_BACKUP_NAME" &&
  docker compose cp "yabits:/data/$YABITS_BACKUP_NAME" "backups/$YABITS_BACKUP_NAME" &&
  docker compose up -d --wait
```

Check that the command succeeded and copy the file in `backups` to another disk.
Keep the printed SHA-256 with it. If backup or copying fails, the server stays
stopped so you can inspect the error; the original database and `.env` are still
there. After fixing the problem, run the backup again with a new name, then
`docker compose up -d --wait`. The backup also remains inside the server volume;
remove old backup copies only after verifying your separate copy.

### Restoring a server

Use server **1.0.5 or newer**. Version 1.0.4 cannot start a restored database.
Update before recovering, and keep the backup, original volume and permanent
secret key. Follow the [step-by-step restore guide](QUICKSTART-RESTORE.md); it
covers preparation, account checks, activation and reconnecting your devices.
