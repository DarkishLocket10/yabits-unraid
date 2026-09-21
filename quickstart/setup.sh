#!/bin/sh
# Creates a new installation only. It never rewrites an existing key or volume.
set -eu
umask 077

fail() { printf '%s\n' "$*" >&2; exit 1; }
mode=start
if [ "${1:-}" = '--no-start' ]; then mode=prepare; shift; fi
[ "$#" -le 2 ] || fail 'Usage: sh setup.sh [--no-start] [https://habits.example.com] [new-folder]'
address=${1:-}
if [ -z "$address" ]; then
  printf 'Your Yabits address (for example https://habits.example.com): '
  IFS= read -r address
fi
address=$(printf '%s' "$address" | tr '[:upper:]' '[:lower:]')
address=${address%/}
local_port=
domain=
case "$address" in
  http://localhost:*)
    local_port=${address#http://localhost:}
    case "$local_port" in ''|*[!0-9]*) fail 'Use a localhost port such as http://localhost:8080.';; esac
    [ "${#local_port}" -le 5 ] && [ "$local_port" -ge 1024 ] && [ "$local_port" -le 65535 ] || fail 'Use a port from 1024 to 65535.'
    [ "${local_port#0}" = "$local_port" ] || fail 'Use a port without leading zeros.'
    ;;
  https://*)
    domain=${address#https://}
    printf '%s\n' "$domain" | awk '
      length($0)>253 || $0 !~ /^[a-z0-9.-]+$/ {exit 1}
      {n=split($0,labels,"."); if(n<2) exit 1;
       for(i=1;i<=n;i++) if(length(labels[i])<1 || length(labels[i])>63 || labels[i] ~ /^-/ || labels[i] ~ /-$/) exit 1;
       if(labels[n] !~ /^[a-z][a-z]+$/) exit 1;
       if(labels[n] ~ /^(localhost|local|internal|test|invalid)$/) exit 1;}' || fail 'Use a public HTTPS domain without a port or path, such as https://habits.example.com.'
    ;;
  *) fail 'Use https:// followed by your domain. For a browser-only trial, use http://localhost:8080.';;
esac
folder=${2:-yabits-home}
case "$folder" in -*) fail 'Choose a folder name that does not start with a dash.';; esac
command -v openssl >/dev/null 2>&1 || fail 'Install OpenSSL, then run setup again.'
if [ "$mode" = start ]; then
  command -v docker >/dev/null 2>&1 || fail 'Install Docker with Docker Compose first: https://docs.docker.com/get-started/get-docker/'
  docker compose version >/dev/null 2>&1 || fail 'Docker Compose is missing. Update Docker, then try again.'
  docker info >/dev/null 2>&1 || fail 'Start Docker and check your account can use it, then try again.'
fi
[ ! -e "$folder" ] || fail "The folder $folder already exists. To restart it, open that folder and run: docker compose up -d. Setup will not replace your data or secret key."
secret=$(openssl rand -hex 32)
mkdir "$folder"
printf 'YABITS_EXTERNAL_URL=%s\nYABITS_SECRET_KEY=%s\n' "$address" "$secret" > "$folder/.env"
unset secret
printf '.env\n*.sqlite*\nbackups/\n' > "$folder/.gitignore"
cat > "$folder/compose.yaml" <<'YAML'
services:
  yabits:
    image: ghcr.io/darkishlocket10/yabits-server:1.0.5
    restart: unless-stopped
    environment:
      YABITS_EXTERNAL_URL: ${YABITS_EXTERNAL_URL:?Keep the .env file beside compose.yaml}
      YABITS_SECRET_KEY: ${YABITS_SECRET_KEY:?Keep the original secret key in .env}
      YABITS_SETUP_TOKEN_FILE: "1"
      YABITS_DATA_DIR: /data
    volumes:
      - habits:/data
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=16m
    cap_drop: [ALL]
    security_opt: [no-new-privileges:true]
YAML
if [ -n "$local_port" ]; then
  printf '    ports:\n      - "127.0.0.1:%s:8080"\nvolumes:\n  habits:\n' "$local_port" >> "$folder/compose.yaml"
else
  # A dedicated network trusts only Caddy's stable address, never the subnet.
  cat >> "$folder/compose.yaml" <<'YAML'
    networks:
      proxy:
        ipv4_address: 172.30.58.3
  caddy:
    image: caddy:2.11.4-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - certificates:/data
      - caddy-config:/config
    networks:
      proxy:
        ipv4_address: 172.30.58.2
    depends_on:
      yabits:
        condition: service_healthy
networks:
  proxy:
    ipam:
      config:
        - subnet: 172.30.58.0/29
volumes:
  habits:
  certificates:
  caddy-config:
YAML
  # Keep a single environment mapping; add the exact proxy via an env file.
  printf 'YABITS_TRUSTED_PROXY_CIDRS=172.30.58.2/32\n' >> "$folder/.env"
  # Compose's .env supplies substitutions, not container env automatically.
  # shellcheck disable=SC2016 # Compose, not the shell, expands this variable.
  sed '/YABITS_DATA_DIR: \/data/a\
      YABITS_TRUSTED_PROXY_CIDRS: ${YABITS_TRUSTED_PROXY_CIDRS}
' "$folder/compose.yaml" > "$folder/compose.tmp"
  mv "$folder/compose.tmp" "$folder/compose.yaml"
  printf '%s {\n    reverse_proxy yabits:8080\n}\n' "$domain" > "$folder/Caddyfile"
  chmod 644 "$folder/Caddyfile"
fi
chmod 600 "$folder/.env"
printf '\nCreated %s. Keep its .env file safe; it contains your permanent server key.\n' "$folder"
if [ "$mode" = start ]; then
  (cd "$folder" && docker compose up -d --wait --wait-timeout 180) || fail "Setup files are safe in $folder. Fix the error above, then run docker compose up -d from that folder. Do not delete the volume or regenerate .env."
else
  printf '\nFiles are ready. In %s, run: docker compose up -d --wait\n' "$folder"
fi
printf '\nOnce started, open %s and create your account.\n' "$address"
printf 'In %s, run: docker compose logs yabits\n' "$folder"
printf 'Copy the setup token from those logs into the setup page. It expires after one hour.\n'
if [ -n "$local_port" ]; then
  printf '\nThis localhost trial works only in the browser on this computer. Phone sync needs an HTTPS address.\n'
else
  printf '\nDNS must point to this computer, with TCP ports 80 and 443 forwarded to it.\n'
fi
