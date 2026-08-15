#!/usr/bin/env bash
#
# app-setup.sh — the application half: nginx, a TLS certificate, and the
# backend as a systemd service. Run after provision.sh, as root.
#
#   HOST=209-38-55-151.sslip.io LE_EMAIL=you@example.com bash /tmp/app-setup.sh
#
# HOST is the name the certificate is issued for and the name the app will call.
# It is a parameter rather than a constant because it is expected to change once
# a real domain replaces the interim sslip.io name.
#
# The script stops short of starting the service when chess_backend/.env has not
# been filled in — it writes a template and says so. Secrets are not in the
# repository and are not invented here.
#
# Idempotent: safe to re-run after changing HOST or pulling new code.

set -euo pipefail

APP_USER="chess"
APP_DIR="/home/${APP_USER}/ChessMaster"
REPO="https://github.com/pvladan75/ChessMaster.git"
# Named explicitly: the repository's default branch on GitHub is `main`, which
# holds nothing but the initial README. A plain clone lands there and the first
# sign of it is `npm ci` complaining about a missing lockfile.
BRANCH="${BRANCH:-master}"
BACKEND_DIR="${APP_DIR}/chess_backend"
SERVICE="chess-backend"
PORT=3000

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# Sets KEY=VALUE in an env file, appending the line when it is not there yet.
# A bare `sed -i s/^KEY=.*/` is a silent no-op when the key is absent, so a
# variable added to .env.example later would simply never reach the server.
set_env() {
  local key="$1" value="$2" file="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
[[ -n "${HOST:-}" ]] || { echo "Set HOST, e.g. HOST=209-38-55-151.sslip.io" >&2; exit 1; }
[[ -n "${LE_EMAIL:-}" ]] || { echo "Set LE_EMAIL — Let's Encrypt sends expiry warnings there." >&2; exit 1; }

log "nginx and certbot"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get -y install nginx certbot python3-certbot-nginx

log "Application code"
if [[ -d "${APP_DIR}/.git" ]]; then
  # fetch + checkout -B rather than pull: this also repairs a clone sitting on
  # the wrong branch, and works on the shallow clone made below.
  # The explicit refspec matters: a --depth 1 clone is single-branch, so a plain
  # `fetch origin master` only writes FETCH_HEAD and origin/master never appears.
  sudo -u "$APP_USER" git -C "$APP_DIR" fetch --depth 1 origin \
    "+refs/heads/${BRANCH}:refs/remotes/origin/${BRANCH}"
  sudo -u "$APP_USER" git -C "$APP_DIR" checkout -B "$BRANCH" "origin/${BRANCH}"
else
  sudo -u "$APP_USER" git clone --depth 1 --branch "$BRANCH" "$REPO" "$APP_DIR"
fi
sudo -u "$APP_USER" git -C "$APP_DIR" log --oneline -1

log "Dependencies"
# --omit=dev leaves out nodemon; nothing in production needs it.
# Run from inside the directory: `npm --prefix ... ci` resolves the lockfile
# inconsistently across npm versions.
sudo -u "$APP_USER" bash -c "cd '$BACKEND_DIR' && npm ci --omit=dev"

log "Environment file"
ENV_FILE="${BACKEND_DIR}/.env"
EXAMPLE_FILE="${BACKEND_DIR}/.env.example"
if [[ ! -f "$ENV_FILE" ]]; then
  # Seeded from the repository's own .env.example rather than a copy kept here.
  # Two lists of the same variables drift, and the one in the repository is the
  # one that gets updated when a variable is added.
  sudo -u "$APP_USER" cp "$EXAMPLE_FILE" "$ENV_FILE"
  chmod 600 "$ENV_FILE"

  # Only the values that follow from *this host* are filled in; secrets are not
  # invented here.
  set_env NODE_ENV production "$ENV_FILE"
  set_env DB_CA_PATH "/home/${APP_USER}/do-postgres-ca.crt" "$ENV_FILE"
  set_env ALLOWED_ORIGINS "https://${HOST}" "$ENV_FILE"
  set_env PORT "${PORT}" "$ENV_FILE"
  chown "$APP_USER:$APP_USER" "$ENV_FILE"
  echo "Seeded ${ENV_FILE} from .env.example — secrets still need filling in."
else
  echo "${ENV_FILE} exists — left untouched."
fi


log "systemd service"
cat > "/etc/systemd/system/${SERVICE}.service" <<EOF
[Unit]
Description=Chess Master backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${BACKEND_DIR}
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
# The process reads .env itself through dotenv, so no EnvironmentFile here —
# one source of truth beats two that can disagree.
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=false

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$SERVICE"

log "nginx site for ${HOST}"
cat > "/etc/nginx/sites-available/${SERVICE}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${HOST};

    # The backend accepts lesson recordings up to 100 MB (server.js). nginx
    # defaults to 1 MB, which would reject every saved lesson with a 413 that
    # looks, from inside the app, like recording itself is broken.
    client_max_body_size 120m;

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;

        # Socket.IO: without the upgrade pair the handshake falls back to
        # polling and live sessions get slower and lossier for no visible reason.
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # A lesson can sit idle between moves; the default 60s would cut it.
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF
ln -sf "/etc/nginx/sites-available/${SERVICE}" "/etc/nginx/sites-enabled/${SERVICE}"
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

log "TLS certificate"
# Let's Encrypt rate-limits issuance per name, so an existing certificate is
# never re-requested — but it must still be *re-installed*, because the site
# file above was just rewritten from a template that has no 443 block. Skipping
# this step entirely (the obvious reading of "already present") leaves the host
# answering on port 80 only, and the failure appears one run later than the
# change that caused it.
if certbot certificates 2>/dev/null | grep -q "Domains: ${HOST}\$"; then
  echo "Certificate for ${HOST} exists — reinstalling it into the nginx config."
  certbot install --nginx --cert-name "$HOST" --redirect -n
else
  certbot --nginx -d "$HOST" -m "$LE_EMAIL" --agree-tos --no-eff-email -n --redirect
fi
systemctl reload nginx

log "Service"
# Only the three that must be real are checked. The Play and metering entries
# ship with example values on purpose — absent, they disable their feature
# rather than breaking startup.
if grep -qE '^(DB_HOST|DB_PASSWORD|JWT_SECRET)=.*(your_|_here)' "$ENV_FILE"; then
  cat <<EOF
${ENV_FILE} still holds example values, so ${SERVICE} was NOT started.

Fill in DB_HOST (the private VPC name), DB_PASSWORD and JWT_SECRET, put the
cluster CA at /home/${APP_USER}/do-postgres-ca.crt, then:

  systemctl start ${SERVICE} && systemctl status ${SERVICE}

JWT_SECRET must match the one already in use — a new one signs out every
existing user at once. Copying the working .env across is the safer route.
EOF
else
  systemctl restart "$SERVICE"
  sleep 3
  systemctl is-active --quiet "$SERVICE" && echo "${SERVICE} is running." || {
    echo "${SERVICE} failed to start:"; journalctl -u "$SERVICE" -n 30 --no-pager; exit 1;
  }
fi

log "Summary"
printf 'URL      : https://%s\n' "$HOST"
printf 'code     : %s\n' "$APP_DIR"
printf 'uploads  : %s/uploads  (only copy of the recorded lessons)\n' "$BACKEND_DIR"
printf 'service  : systemctl status %s\n' "$SERVICE"
printf 'logs     : journalctl -u %s -f\n' "$SERVICE"
