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
if [[ ! -f "$ENV_FILE" ]]; then
  install -m 600 -o "$APP_USER" -g "$APP_USER" /dev/null "$ENV_FILE"
  cat > "$ENV_FILE" <<EOF
# Never in the repository. The full set the backend reads — anything left empty
# disables its feature rather than crashing, except the ones marked CHANGE_ME.
#
# Fastest correct route: copy the working .env from the development machine and
# change only DB_HOST, DB_CA_PATH and ALLOWED_ORIGINS. That keeps JWT_SECRET
# identical, and a different JWT_SECRET signs out every existing user at once.

PORT=${PORT}
NODE_ENV=production
LOG_LEVEL=info

# Database — private VPC host from Overview -> Connection details -> VPC network.
# DB_CA_PATH is what turns encryption into verified encryption.
DB_HOST=CHANGE_ME
DB_PORT=25060
DB_USER=doadmin
DB_DATABASE=defaultdb
DB_PASSWORD=CHANGE_ME
DB_CA_PATH=/home/${APP_USER}/do-postgres-ca.crt

# Sessions. Must match the value already in use, or everyone is logged out.
JWT_SECRET=CHANGE_ME
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_IDS=

# Browser clients only; the Flutter app does not go through CORS.
ALLOWED_ORIGINS=https://${HOST}

# Live lessons — without these, voice in a room does not work.
AGORA_APP_ID=
AGORA_APP_CERTIFICATE=
AGORA_TOKEN_TTL_SECONDS=

# Verification and notification mail.
SMTP_HOST=
SMTP_PORT=
SMTP_USER=
SMTP_PASSWORD=
MAIL_FROM=

# Position commentary.
GEMINI_API_KEY=

# Play billing. PLAY_RTDN_SECRET also appears in the Pub/Sub push URL.
GOOGLE_PLAY_PACKAGE_NAME=
GOOGLE_PLAY_SA_EMAIL=
GOOGLE_PLAY_SA_PRIVATE_KEY=
PLAY_RTDN_SECRET=
PLAY_PRODUCT_TIERS=
ENABLE_LIMITS=
USAGE_UNIT_COSTS=

# Exported MP4s are regenerable, so they age out; uploads/ audio never does.
EXPORT_RETENTION_DAYS=
EOF
  chown "$APP_USER:$APP_USER" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "Template written to ${ENV_FILE}"
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
# Let's Encrypt rate-limits certificates per name, so ask only when there is
# not already a live one for this host.
if certbot certificates 2>/dev/null | grep -q "Domains: ${HOST}\$"; then
  echo "Certificate for ${HOST} already present — not requesting another."
else
  certbot --nginx -d "$HOST" -m "$LE_EMAIL" --agree-tos --no-eff-email -n --redirect
fi
systemctl reload nginx

log "Service"
if grep -q 'CHANGE_ME' "$ENV_FILE"; then
  cat <<EOF
${ENV_FILE} still contains CHANGE_ME, so ${SERVICE} was NOT started.

Fill in DB_HOST, DB_PASSWORD and JWT_SECRET, put the cluster CA at
/home/${APP_USER}/do-postgres-ca.crt, then:

  systemctl start ${SERVICE} && systemctl status ${SERVICE}
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
