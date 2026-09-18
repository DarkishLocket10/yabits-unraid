# Deploying yabits-server on Unraid, behind SWAG and Cloudflare

**New here?** Start with the [simple setup guide](SETUP.md). It covers regular Docker,
Unraid, connecting your phone and checking sync in both directions.

This is the whole path from nothing to a working instance on your own domain,
in the order that avoids backtracking. Every step depends on the one before it,
so doing them out of order mostly produces certificate errors that look like
configuration errors.

Files here:

| Path | What it is |
|---|---|
| `yabits-server.xml` | Community Applications template |
| `swag/yabits-server.subdomain.conf` | SWAG reverse proxy config |

The template references `yabits-server.png`, which is the dark icon used
by the iOS app.

## What you need first

A domain whose DNS is on Cloudflare, an Unraid server with the Community
Applications plugin, and your router able to forward a port to it. The whole
setup assumes the container is never reachable directly: SWAG terminates TLS,
Cloudflare sits in front of SWAG, and the container listens only on a Docker
network.

## Order of operations

### 1. Cloudflare: get an API token, not a global key

In the Cloudflare dashboard create an API token scoped to `Zone / DNS / Edit`
for your zone only. SWAG uses it to answer the DNS-01 ACME challenge, which is
what lets you keep the DNS record proxied from the very beginning and never open
port 80. A global API key would work and would also let anything that reads it
take over your account, so use the scoped token.

### 2. Cloudflare: create the DNS record, proxied

Add an `A` record for the subdomain you want, for example `habits`, pointing at
your home IP address, and leave the proxy status **Proxied** (orange cloud).

Proxied is the point of this arrangement. Your home IP address never appears in
public DNS, the origin only ever sees Cloudflare, and you can then restrict your
router's port forward to Cloudflare's published address ranges so nothing else
can reach SWAG at all. If you set it to DNS only (grey cloud) everything in this
guide still works, but you have published your home address and lost that
filtering.

### 3. Unraid: a dedicated Docker network

Create a small network used only by SWAG and yabits-server. Choose an unused
private subnet for your installation; this example reserves a `/29`:

```sh
docker network create --subnet 172.30.50.0/29 yabits-proxy
```

Put no other container on this network. Docker's default `bridge` network has no
DNS between containers, so `proxy_pass http://yabits-server:8080` would fail to
resolve on it. The dedicated user-defined network provides that DNS without
granting unrelated containers trusted-proxy authority.

### 4. Router: forward 443 to Unraid

Forward TCP 443 only. Port 80 stays closed, because DNS-01 validation does not
use it and nothing here should ever be served over plain HTTP.

If your router supports it, restrict the forward to Cloudflare's IP ranges
(`https://www.cloudflare.com/ips/`). Combined with a proxied record that makes
Cloudflare the only route to your origin.

### 5. Unraid: install SWAG

From Community Applications, with:

- `VALIDATION` = `dns`
- `DNSPLUGIN` = `cloudflare`
- `URL` = your domain, `SUBDOMAINS` = the exact subdomain label from step 2,
  such as `habits`
- `Network` = `yabits-proxy`
- `Fixed IP address` = `172.30.50.2`, the stable SWAG address from the example
  subnet

Then put the token from step 1 into
`/mnt/user/appdata/swag/dns-conf/cloudflare.ini` and restart SWAG. Watch the log
until it says the certificate was obtained. Do not move on until it has, because
step 8 depends on a real certificate existing.

### 6. Unraid: install yabits-server

Install from the template in `yabits-server.xml`, then change two things
from their defaults:

- **Network Type** to `yabits-proxy`, so SWAG can resolve it by name.
- **Remove the host port mapping** unless you want to test on the LAN first.
  With SWAG on the same network nothing needs to be published, and an
  unpublished port is one fewer way in.

Fill in the required fields:

- **Secret key** (`YABITS_SECRET_KEY`): generate with `openssl rand -base64 32`.
  This encrypts TOTP secrets and keys token verifiers. Save it in a password
  manager, separately from database backups. Changing it later invalidates
  existing second factors and device tokens, so it is effectively permanent once
  the instance has users.
- **External URL** (`YABITS_EXTERNAL_URL`): `https://habits.example.com`, the
  address a browser will actually type. The server cannot infer this, because
  behind a proxy the `Host` header is supplied by the caller and trusting it is
  how absolute redirects get poisoned.
- **Trusted proxy CIDRs** (`YABITS_TRUSTED_PROXY_CIDRS`): SWAG's stable host
  address only, `172.30.50.2/32` for the example above. Use `/128` for one IPv6
  address.

The optional **storage quota** (`YABITS_STORAGE_QUOTA_MIB`) is reconciled for
all accounts before each listener start. Increasing it, keeping it equal, or
lowering it while every account fits is one all-or-none database transaction.
If a requested lower value is below any current usage, startup changes nothing
and exits. Restore the old or a higher value, start the server, delete data,
stop it, and retry the lower value; never edit stored quota rows or delete the
database to force the change.

Version 1 has exactly four configurable protocol limits. The Unraid template
exposes all four under advanced settings:

- **Storage quota per user in MiB** (`YABITS_STORAGE_QUOTA_MIB`): default 256,
  accepted range 64 through 16384.
- **Tombstone retention in days** (`YABITS_TOMBSTONE_RETENTION_DAYS`): default
  180, accepted range 180 through 3650.
- **Recycle retention in days** (`YABITS_RECYCLE_RETENTION_DAYS`): default 180,
  accepted range 30 through 3650, and never greater than effective tombstone
  retention.
- **Event heartbeat in seconds** (`YABITS_SSE_HEARTBEAT_SECONDS`): default 15,
  accepted range 5 through 25.

Each is one base-10 integer. Startup rejects an invalid or inconsistent value
instead of clamping it. Every other advertised version 1 protocol limit is
fixed and intentionally has no environment variable.

The optional **session idle** and **session absolute** settings apply only when
a future non-admin session is issued. Administrator sessions are fixed at 12
hours idle and 7 days absolute. Every existing session retains the idle and
absolute lifetimes stored when it was issued, so changing either setting never
extends or shortens an existing row.

The four Phase 2 authentication inputs are also available under advanced
settings:

- **Setup token file** (`YABITS_SETUP_TOKEN_FILE`) accepts only `0` or `1` and
  defaults to `0`. At `1`, `/data/setup-token` is written mode 0600 with the
  token and its Unix-millisecond expiry on two LF-terminated lines. Every startup
  reconciles that exact path: value `0` and every claimed instance require it
  absent before readiness, while value `1` on an unclaimed instance atomically
  replaces it with only the newly rotated token. Claim and expiry attempt removal
  immediately and retain one bounded retry if the filesystem temporarily refuses
  it. A committed claim still succeeds because a stale token is already unusable.
  At `0`, read the token from the container log.
- **Argon2 memory**, **Argon2 time**, and **Argon2 parallelism**
  (`YABITS_ARGON2_MEMORY`, `YABITS_ARGON2_TIME`, and
  `YABITS_ARGON2_PARALLELISM`) are one all-or-none override. Memory accepts
  19456 through 262144 KiB, time accepts 2 through 10 iterations, and
  parallelism accepts 1 through 4 lanes. Leave all three blank for calibration.
  A partial set fails startup. After first claim, supplied values must exactly
  match the immutable persisted profile and cannot migrate it.

The trusted proxy setting is worth understanding rather than pasting. The server
believes `X-Forwarded-For` only from the exact configured proxy addresses and
uses the socket peer address otherwise. Enter each proxy as its stable `/32`
IPv4 or `/128` IPv6 address. Never trust a Docker network prefix or any whole
subnet: every container in that range could invent client addresses. If you set
`0.0.0.0/0` you have made the auth rate limiter useless, because a single
attacker can send a different fake client address with every request. If you
leave it empty while SWAG is in front, every request looks like it came from
SWAG, so the per-IP limit becomes global and one attacker can lock out every
user.

### 6a. The data folder, before you press Start

Two things about the Data mapping are worth a minute, because both fail in ways
that read as a broken image.

**Keep appdata on a pool.** The portable template default is
`/mnt/user/appdata/yabits-server`, because Unraid pool names are configurable and
many systems have no pool literally named `cache`. Configure the `appdata` share
with your pool as primary storage and no secondary storage. On Unraid 6.12 or
later, enable exclusive shares and confirm that `appdata` reports `Exclusive
access: Yes`; `/mnt/user/appdata` then resolves directly to the pool and bypasses
the user-share layer. An explicit `/mnt/<pool>/appdata/yabits-server` path is an
advanced alternative when you know the actual pool name. Avoid the array for the
live database: WAL mode does many small writes and a spinning disk makes every
check-in feel slow.

**Create it and own it first.** The container runs as uid 99, gid 100
(`nobody:users`), which is what Unraid's appdata is owned by and what the "Docker
Safe New Permissions" tool resets it to. Docker creates a *missing* host folder
owned by root, and a non-root container cannot write that, so on the Unraid
terminal:

```sh
mkdir -p /mnt/user/appdata/yabits-server
chown 99:100 /mnt/user/appdata/yabits-server
```

If you skip this, the container exits immediately and the log says
`unable to open database file`. The fix is that `chown`. It is specifically not
`chmod -R 777` on the share and not flipping the container to root: appdata is
often exported over SMB, and either of those makes everyone's habit history
readable by every device in the house.

The uid is baked into the image rather than read from `PUID`/`PGID`, because there
is no shell and no root inside it to change ownership or drop privileges at
startup. To run as something else, add `--user <uid>:<gid>` to Extra Parameters
and chown the folder to match.

**Run exactly one serving process for this database.** The server keeps an
exclusive lock on persistent `/data/yabits.sqlite.yabits-lock` for the entire
database-open lifetime. It requires that sidecar to be a regular file with one
link, mode `0600`, owned by the container's effective uid, on the same filesystem
as the database. Keep it in the data folder and do not hard-link, replace, or
relax its permissions. Shutdown drains any active write and releases this lock
only after the SQLite readers and writer close.

Do not run `sqlite3`, a second `yabitsd`, or any other direct SQLite writer
against the database while the server is open. Do not create a filesystem
snapshot or reflink of the live database or data folder while serving. Those
operations are outside the gate and can invalidate its free-space or COW bound.

### 7. SWAG: the proxy config

Copy `swag/yabits-server.subdomain.conf` to
`/mnt/user/appdata/swag/nginx/proxy-confs/yabits-server.subdomain.conf`. SWAG
loads files ending in `.conf` and ignores `.conf.sample`, so the name matters.
Before restarting SWAG, open the copied file and make its `server_name` label
exactly match `SUBDOMAINS` from step 5. The checked-in example is
`server_name habits.*;`; if you configured `tracker`, change it to
`server_name tracker.*;`. Nginx does not substitute SWAG's `SUBDOMAINS` value
inside proxy configuration files, so leaving a different label silently sends
the hostname to another server block.

Then create `/mnt/user/appdata/swag/nginx/cf-real-ip.conf` and uncomment the
include for it at the top of the proxy config:

```nginx
# Cloudflare IPv4, from https://www.cloudflare.com/ips-v4
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
# ... the rest of the list ...

# Cloudflare IPv6, from https://www.cloudflare.com/ips-v6
set_real_ip_from 2400:cb00::/32;
# ... the rest of the list ...

real_ip_header CF-Connecting-IP;
```

Without this, nginx sees a Cloudflare edge address as the client and forwards
that, so the address the server rate-limits on is Cloudflare's rather than the
visitor's. Fetch the current ranges from the URLs above rather than trusting a
copy in a guide; Cloudflare adds ranges.

Restart SWAG. `nginx -t` inside the container will tell you about a syntax error
before a restart turns it into downtime.

### 8. Cloudflare: SSL/TLS mode Full (strict)

Under SSL/TLS, set the encryption mode to **Full (strict)**.

The other modes are all worse in ways that are easy to miss. *Flexible* makes
Cloudflare talk to your origin over plain HTTP, so the traffic crosses your ISP
and your LAN unencrypted while the browser shows a padlock, and the server's
`Secure` session cookies will not survive the round trip. *Full* encrypts but
does not verify, so it accepts any certificate, including one from whoever has
managed to get in the path. *Full (strict)* requires the certificate SWAG already
obtained in step 5, which is why that step came first.

While you are here, add a cache rule that bypasses cache for this hostname. The
API responses are per-user and the event stream is not a document; there is
nothing to cache and a cached response served to the wrong user would be a data
leak.

### 9. First run: claim the instance

The container prints a one-time setup token to its log on first start. By default
it stores the plaintext nowhere else. Open the log in the Unraid Docker tab, copy
the token, open `https://habits.example.com`, and create the admin account with
it. The warning is emitted even if the configured log threshold is `error`.

Until that is done the instance serves nothing but the setup page, which is the
point: there is no default password to forget to change. The token expires 60
minutes after it is printed and a new one is generated on every start while the
instance is unclaimed, so if you miss the log line or let it expire, restart the
container and read the new one. Nothing needs deleting.

### 10. Point the iOS app at it

In the app's Settings, choose the self-hosted transport and enter the same URL.
Create a device token in the web client, which shows it once. The token is
scoped to sync alone, so a phone that gets stolen cannot change your password or
read another user's data, and you can revoke it from any other device.

## Server-Sent Events, and why Cloudflare's 100 seconds matters

The web client learns about changes from another device through a Server-Sent
Events stream. It is a single HTTP response that stays open and never ends, and
almost everything in a normal proxy chain is designed to make responses end.

Two limits are in the way.

**nginx** buffers proxied responses by default, and SWAG's `proxy.conf` sets a
240 second read timeout. Buffering is the nastier of the two: the stream opens,
the browser's `EventSource` reports state `OPEN`, and then nothing arrives until
a buffer happens to fill. It looks like a server bug, it only reproduces through
the proxy, and it is genuinely hard to diagnose.
`swag/yabits-server.subdomain.conf` keeps SWAG's normal buffering and compression
for ordinary pages, then adds a narrow location block for
`/api/v1/sync/events`. That block disables buffering, disables gzip, forces
HTTP/1.1 so a response with no `Content-Length` can be chunked, and raises the
read timeout to 24 hours. Each line is commented with what breaks without it.

Three things are worth knowing before you edit that block, or add another one.

It does not `include /config/nginx/proxy.conf`, which looks like an oversight and
is not. `proxy.conf` sets `proxy_http_version` and `proxy_read_timeout`, and
nginx treats a second occurrence of either in the same context as a fatal
duplicate rather than an override, so a block that includes `proxy.conf` cannot
raise the timeout at all. The price is that the forwarding headers are written
out by hand in that block, so a header added to `proxy.conf` later has to be
added there too.

Its path has to match the server's SSE route, which the endpoint table in
`docs/SYNC-PROTOCOL.md` section 1 fixes at `/api/v1/sync/events`. If the route
ever moves and this is not updated, the symptom is not an nginx configuration
error: requests fall through to `location /`, regain normal buffering, and lose
the 24 hour stream timeout. That silence is why the block uses a prefix match
(`^~`) rather than an exact one, so a trailing slash or a suffix on the route
cannot miss it, and why CI greps the protocol doc and this file and fails if the
two paths disagree.

The rest of the API needs no special treatment, which is worth stating so nobody
adds blocks that will rot. Everything else either is a short request or, for the
finite bootstrap stream, works with SWAG's ordinary response buffering and 240
second timeout.

**Cloudflare** closes a proxied connection that has been idle for about 100
seconds and returns a 524. There is no dashboard setting to raise it on the free
plan, and no reverse-proxy configuration on your side can change it, because the
limit is enforced at the edge.

So the fix is not configuration, it is traffic. The server sends a heartbeat every
15 seconds (`docs/SYNC-PROTOCOL.md` section 11.1), as a real event rather than an
SSE comment:

```
event: heartbeat
data: {"t":1786000105000}

```

A real event because `EventSource` never surfaces comment lines to JavaScript, so
a comment cannot drive the client's own watchdog, and a client that cannot tell a
dead connection from a quiet one reconnects either always or never.

Fifteen seconds leaves margin against Cloudflare's roughly 100 second idle limit
and carrier NAT on a mobile network, which can drop an idle mapping quickly. It also
does two other useful things: it resets nginx's read timeout, and a failed write
is how the server notices a client that went away without closing, so
disconnected streams get cleaned up instead of accumulating.

If the browser reconnects every 100 seconds anyway, the heartbeat is not
arriving, and the cause is almost always buffering somewhere in the chain rather
than the timeout itself. Check in this order: the `proxy_buffering off` line is
present and the file is actually loaded, no Cloudflare rule is caching the
hostname, and no second proxy sits between SWAG and the container.

## Verify the release image

Releases are published only by the repository's manual, tag-selected
`Publish release image` workflow. Ordinary pushes cannot publish an image. The
workflow builds one `linux/amd64` + `linux/arm64` manifest, attaches BuildKit's
maximum provenance and SPDX SBOM attestations, and signs the immutable digest
with GitHub's OIDC identity through Cosign. Resolve the tag to a digest before a
first install or upgrade, and retain that digest with the backup record:

```sh
YABITS_VERSION='1.0.0'
YABITS_IMAGE="ghcr.io/darkishlocket10/yabits-server:$YABITS_VERSION"
YABITS_DIGEST="$(docker buildx imagetools inspect "$YABITS_IMAGE" \
  --format '{{json .Manifest.Digest}}' | tr -d '"')"
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/DarkishLocket10/yabits-server/.github/workflows/release.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' \
  "ghcr.io/darkishlocket10/yabits-server@$YABITS_DIGEST"
```

Use the exact digest in automation when you require immutable deployment. The
Unraid template tracks `:latest` for convenient updates, so verify the resolved
digest before applying an update there.

## Backup and restore

**Version 1.0.4 restore limitation:** backup creation works, but starting a restored
server fails because of an authentication-state check. Do not activate a restore
with that release. Keep the original volume, backup and secret key. The fix is
tested locally and awaiting publication; use a fixed release for the restore
steps below.


The current image includes the offline `yabitsd backup` command. The serving
container must be stopped and Docker's `Running=false` and `Status=exited` state
verified before the one-shot command starts. Do not run it with `docker exec` or
start a second `yabitsd` beside a live container: the lifetime database lock
correctly rejects that open.

The command opens the database through the complete serving validation path,
uses SQLite `VACUUM INTO` to a private staging file, independently runs
`quick_check` and verifies the exact application schema, foreign keys,
allocator, logical counters, and immutable instance identity, fsyncs the file,
installs it without overwriting any existing path, fsyncs its directory, and
prints its byte length and SHA-256. A `VACUUM INTO` database snapshot is a SQLite operation;
it is not a filesystem snapshot and does not permit live Unraid, Btrfs, ZFS, or
reflink snapshot creation. Copy only the completed validated output to backup
storage and encrypt it if it leaves the server.

Use that operation instead of copying `yabits.sqlite`, its WAL or
SHM sidecar, or the whole appdata folder. A stopped folder copy is still
unsupported because it bypasses validation and the restore epoch, credential,
and watermark work in `docs/CONTRACT-V1.md` section 9.

The image implements offline restore as separate prepare, remediate, complete,
and activate steps. Stop the normal container and run the same deployed image
with the same `/data` bind mount and the complete deployed environment. The
offline commands need the same secret key, external URL, custom Argon profile,
quota, and every other `YABITS_*` setting; reconstructing only a few values is
unsafe.

The following single preflight block captures the deployed container's exact
image, numeric uid and gid, and data bind mount, then stops the server and
verifies Docker reports both `Running=false` and `Status=exited` before copying
its environment. This automatically honors a supported custom `--user
<uid>:<gid>` setting instead of silently falling back to 99:100.

Do not split the block. `YABITS_RESTORE_READY` starts false and becomes true
only after stop verification, atomic environment capture, mode and owner checks,
and a second stopped-state verification all succeed. The helper rechecks the
sentinel, stopped state, and root-only environment file before every offline
command later in this runbook:

```sh
YABITS_CONTAINER_NAME='yabits-server'
YABITS_RESTORE_ENV='/root/yabits-restore.env'
YABITS_RESTORE_READY='0'
YABITS_RESTORE_PREFLIGHT_VALID='1'

yabits_restore_require_ready() {
  if [ "${YABITS_RESTORE_READY:-0}" != '1' ]; then
    echo 'Restore preflight is not ready; no offline command was run.' >&2
    return 1
  fi
  YABITS_RESTORE_CURRENT_STATE="$(docker inspect \
    --format '{{.State.Running}}:{{.State.Status}}' \
    "$YABITS_CONTAINER_NAME")" || return 1
  if [ "$YABITS_RESTORE_CURRENT_STATE" != 'false:exited' ]; then
    echo "The serving container is $YABITS_RESTORE_CURRENT_STATE, not stopped." >&2
    return 1
  fi
  YABITS_RESTORE_ENV_METADATA="$(stat -c '%a %U:%G' \
    "$YABITS_RESTORE_ENV")" || return 1
  if [ "$YABITS_RESTORE_ENV_METADATA" != '600 root:root' ]; then
    echo 'The recovery environment is not mode 600 and owned by root:root.' >&2
    return 1
  fi
}

if ! YABITS_RESTORE_IMAGE="$(docker inspect \
  --format '{{.Image}}' "$YABITS_CONTAINER_NAME")"; then
  echo 'Could not inspect the deployed image.' >&2
  YABITS_RESTORE_PREFLIGHT_VALID='0'
fi
if ! YABITS_RESTORE_USER="$(docker inspect \
  --format '{{.Config.User}}' "$YABITS_CONTAINER_NAME")"; then
  echo 'Could not inspect the deployed container user.' >&2
  YABITS_RESTORE_PREFLIGHT_VALID='0'
fi
if ! YABITS_DATA_HOST_DIR="$(docker inspect \
  --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}' \
  "$YABITS_CONTAINER_NAME")"; then
  echo 'Could not inspect the deployed data mount.' >&2
  YABITS_RESTORE_PREFLIGHT_VALID='0'
fi

YABITS_CONTAINER_UID=${YABITS_RESTORE_USER%%:*}
YABITS_CONTAINER_GID=${YABITS_RESTORE_USER#*:}
if [ "$YABITS_CONTAINER_UID" = "$YABITS_RESTORE_USER" ]; then
  echo 'The deployed container user must be numeric uid:gid.' >&2
  YABITS_RESTORE_PREFLIGHT_VALID='0'
fi
case "$YABITS_CONTAINER_UID" in
  ''|*[!0-9]*)
    echo 'The deployed container uid is not numeric.' >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
    ;;
esac
case "$YABITS_CONTAINER_GID" in
  ''|*[!0-9]*)
    echo 'The deployed container gid is not numeric.' >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
    ;;
esac
case "$YABITS_DATA_HOST_DIR" in
  /*) ;;
  *)
    echo 'The deployed container has no absolute host bind for /data.' >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
    ;;
esac
if [ "$YABITS_RESTORE_PREFLIGHT_VALID" = '1' ]; then
  if ! docker stop "$YABITS_CONTAINER_NAME"; then
    echo 'Docker could not stop the serving container.' >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
  fi
fi
if [ "$YABITS_RESTORE_PREFLIGHT_VALID" = '1' ]; then
  if ! YABITS_RESTORE_CURRENT_STATE="$(docker inspect \
    --format '{{.State.Running}}:{{.State.Status}}' \
    "$YABITS_CONTAINER_NAME")"; then
    echo 'Could not verify the stopped container state.' >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
  elif [ "$YABITS_RESTORE_CURRENT_STATE" != 'false:exited' ]; then
    echo "Docker reports $YABITS_RESTORE_CURRENT_STATE, not false:exited." >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
  fi
fi
if [ "$YABITS_RESTORE_PREFLIGHT_VALID" = '1' ]; then
  umask 077
  YABITS_RESTORE_ENV_CANDIDATE="${YABITS_RESTORE_ENV}.candidate.$$"
  if ! docker inspect "$YABITS_CONTAINER_NAME" \
    --format '{{range .Config.Env}}{{println .}}{{end}}' \
    > "$YABITS_RESTORE_ENV_CANDIDATE"; then
    echo "Environment capture failed; keep $YABITS_RESTORE_ENV_CANDIDATE." >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
  elif ! chmod 600 "$YABITS_RESTORE_ENV_CANDIDATE"; then
    echo "Environment chmod failed; keep $YABITS_RESTORE_ENV_CANDIDATE." >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
  elif [ "$(stat -c '%a %U:%G' "$YABITS_RESTORE_ENV_CANDIDATE")" \
    != '600 root:root' ]; then
    echo "Environment metadata check failed; keep $YABITS_RESTORE_ENV_CANDIDATE." >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
  elif ! mv -f "$YABITS_RESTORE_ENV_CANDIDATE" "$YABITS_RESTORE_ENV"; then
    echo "Environment install failed; keep $YABITS_RESTORE_ENV_CANDIDATE." >&2
    YABITS_RESTORE_PREFLIGHT_VALID='0'
  fi
fi
if [ "$YABITS_RESTORE_PREFLIGHT_VALID" = '1' ]; then
  YABITS_RESTORE_READY='1'
  if ! yabits_restore_require_ready; then
    YABITS_RESTORE_READY='0'
  fi
fi
if [ "$YABITS_RESTORE_READY" = '1' ]; then
  echo "Restore preflight ready; keep $YABITS_RESTORE_ENV until healthy startup."
else
  echo 'Restore preflight failed. No offline command is permitted.' >&2
  false
fi
```

The image variable is Docker's exact local image ID for the deployed container,
so restore cannot pull a newer tag accidentally. Docker-root access already
permits reading the container environment, so the root-only file adds no new
authority. Do not put a literal secret in a `docker run -e` argument. Keep the
file under `/root`, never appdata, an SMB share, terminal output, or shell
history. Retain it across every failed command in the same boot. `/root` on
Unraid may not survive a host reboot, so after reboot rerun the complete
preflight against the still-stopped container; never move the file into appdata
for persistence.

For a routine backup, create the destination with the deployed numeric identity,
run the exact deployed image with networking disabled, then restart the serving
container. The output name must be new; the command never rotates or overwrites
old backups. Keep the printed SHA-256 with the copied backup:

```sh
YABITS_BACKUP_NAME="yabits-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
YABITS_BACKUP_SUCCEEDED='0'
if yabits_restore_require_ready \
  && install -d -m 700 -o "$YABITS_CONTAINER_UID" -g "$YABITS_CONTAINER_GID" \
    "$YABITS_DATA_HOST_DIR/backups" \
  && docker run --rm --network none --user "$YABITS_RESTORE_USER" \
    --env-file "$YABITS_RESTORE_ENV" \
    -v "$YABITS_DATA_HOST_DIR:/data" \
    "$YABITS_RESTORE_IMAGE" backup \
    --output "/data/backups/$YABITS_BACKUP_NAME"; then
  YABITS_BACKUP_SUCCEEDED='1'
fi
if [ "$YABITS_BACKUP_SUCCEEDED" = '1' ] \
  && docker start "$YABITS_CONTAINER_NAME"; then
  rm -f "$YABITS_RESTORE_ENV"
  YABITS_RESTORE_READY='0'
else
  echo 'Backup or restart failed; keep the root-only environment file for diagnosis.' >&2
  false
fi
```

Do not restart automatically if Docker reports an unexpected stopped state or
the backup command fails: inspect the error and source volume first. A successful
command leaves exactly one owner-only snapshot and no SQLite sidecar.

For restore, remove the root-only environment file only after activation and the
restored server both succeed. The default preparation requires a valid current
live database and preserves its latest authentication state:

```sh
if yabits_restore_require_ready; then
  docker run --rm -it --user "$YABITS_RESTORE_USER" \
    --env-file "$YABITS_RESTORE_ENV" \
    -v "$YABITS_DATA_HOST_DIR:/data" \
    "$YABITS_RESTORE_IMAGE" restore \
    --from /data/backups/yabits-2026-08-06.sqlite \
    --prepare /data/yabits.restore.sqlite
else
  false
fi
```

Preparation validates the current database and requested backup, builds the
same-filesystem temporary database, bumps the instance epoch, reissues sync
record tokens, invalidates restored sessions and device credentials, rebuilds
watermarks and reserves, runs `quick_check`, and fsyncs. It does not alter or
replace the live database.

Preparation prints an exact command for each user whose current verifier or
factor could not be transplanted safely. Run every printed command against the
temporary database. Each one requires a controlling terminal:

```sh
if yabits_restore_require_ready; then
  docker run --rm -it --user "$YABITS_RESTORE_USER" \
    --env-file "$YABITS_RESTORE_ENV" \
    -v "$YABITS_DATA_HOST_DIR:/data" \
    "$YABITS_RESTORE_IMAGE" auth \
    reset-user --database /data/yabits.restore.sqlite --user-id USER_UUID
else
  false
fi
```

Completion is mandatory even if preparation prints no reset commands:

```sh
if yabits_restore_require_ready; then
  docker run --rm -it --user "$YABITS_RESTORE_USER" \
    --env-file "$YABITS_RESTORE_ENV" \
    -v "$YABITS_DATA_HOST_DIR:/data" \
    "$YABITS_RESTORE_IMAGE" auth \
    complete-restore --database /data/yabits.restore.sqlite
else
  false
fi
```

Only after completion succeeds, activate the prepared database. The command
does not try to rename main, WAL, and SHM as a set. It exclusively
TRUNCATE-checkpoints and fsyncs the completed temporary main, closes it, removes
only its disposable temp sidecars, and fsyncs the directory. In default
valid-current mode it revalidates the prepared-source identity and first makes
the old live main self-contained before removing old live sidecars. Disaster
mode instead requires the invalid main and both sidecars already preserved and
all target paths absent. It then performs one same-filesystem atomic rename of
only the self-contained main and fsyncs the directory:

```sh
if yabits_restore_require_ready; then
  if docker run --rm --user "$YABITS_RESTORE_USER" \
    --env-file "$YABITS_RESTORE_ENV" \
    -v "$YABITS_DATA_HOST_DIR:/data" \
    "$YABITS_RESTORE_IMAGE" restore \
    --activate /data/yabits.restore.sqlite --database /data/yabits.sqlite; then
    YABITS_RESTORE_READY='0'
    if docker start "$YABITS_CONTAINER_NAME"; then
      YABITS_RESTORE_START_STATUS='starting'
      for YABITS_RESTORE_START_ATTEMPT in $(seq 1 60); do
        YABITS_RESTORE_START_STATUS="$(docker inspect \
          --format '{{.State.Health.Status}}' "$YABITS_CONTAINER_NAME")"
        case "$YABITS_RESTORE_START_STATUS" in
          healthy|unhealthy) break ;;
        esac
        sleep 2
      done
      if [ "$YABITS_RESTORE_START_STATUS" = 'healthy' ]; then
        if rm -f -- "$YABITS_RESTORE_ENV"; then
          echo 'Restore activated, server healthy, recovery environment removed.'
        else
          echo "Server is healthy, but $YABITS_RESTORE_ENV could not be removed." >&2
        fi
      else
        echo "The restored server is $YABITS_RESTORE_START_STATUS; keep $YABITS_RESTORE_ENV." >&2
      fi
    else
      echo "Activation succeeded but the server did not start; keep $YABITS_RESTORE_ENV." >&2
    fi
  else
    echo "Activation failed; the server remains stopped and $YABITS_RESTORE_ENV is retained." >&2
  fi
else
  echo "Restore preflight is not ready; keep $YABITS_RESTORE_ENV." >&2
fi
```

Do not flatten that block into three independent commands. Activation failure
must not start the serving container, and a start or health failure must retain
the root-only environment file for diagnosis and recovery. If activation
succeeds but startup fails, fix the startup problem and start the existing
container again. Do not activate the already-installed temporary main a second
time.

The first live-path open after rename runs `quick_check` and rebuilds/fsyncs the
live-named 8 MiB WAL before the listener becomes ready. A crash at checkpoint,
close, sidecar removal, rename, directory fsync, or WAL rebuild is therefore
recoverable without ever attaching stale sidecars to the replacement. Do not
manually move any `-wal` or `-shm` file.

If no valid current database exists, first preserve any invalid live database
and its `-wal` and `-shm` sidecars together in a separate recovery directory.
Move rather than copy the set so all three target live paths are absent, verify
that absence without deleting the preserved files, and never mix sidecars from
different copies. Then use the
same preparation command with `--no-valid-current`. This disaster mode refuses
to run if the live database validates and prompts on the controlling terminal
for exactly `NO VALID CURRENT <backup-sha256>` using the printed lower-case
backup SHA-256. It discards every
backup password and factor, leaves every user disabled, and prints reset
commands. After entering the username and password, each reset requires typing
exactly `ADMIN USER_UUID` or `USER USER_UUID`; backup roles are ignored. Reset
at least one restored user with the explicit ADMIN confirmation, leave all
other unreset users disabled, run completion unconditionally, and activate
only after it succeeds. It never silently replaces a recoverable live database.

On any failure before activation, the live file and sidecars remain unchanged
and the serving container must remain stopped until the error is fixed. A
pending temporary database is never activated for remediation in place.

Before relying on backups, exercise this exact runbook end to end with an
enrolled TOTP account, non-default all-or-none Argon settings, and a custom
storage quota. Interrupt and resume after preparation and after a reset; the
durable mode, reset obligations, roles, audits, credentials, and quota must
survive. Confirm every fresh offline container receives the root-only env file,
the server refuses pending state, and the restored server passes login/TOTP and
advertises the same effective configuration before deleting the env file.

Back up `YABITS_SECRET_KEY` separately in a password manager, not beside or
inside the routine database snapshot. Restored TOTP secrets need the same key.
Sessions and device bearer tokens are intentionally invalidated by restore and
must be issued again.
