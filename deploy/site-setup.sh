#!/usr/bin/env bash
#
# site-setup.sh — the public site: the documents Play will not publish an app
# without, served as static files by the nginx that is already running.
# Run as root, after app-setup.sh.
#
#   LE_EMAIL=you@example.com bash /tmp/site-setup.sh
#
# Idempotent, and meant to be re-run: that is how two of this project's bugs
# were found.
#
# Two rules this script exists to keep, both learned the expensive way:
#
#   1. **`@` and `www` get their own certificate, never `--expand` onto the
#      API's.** If the site ever moves off this machine and the names stay on
#      the API certificate, certbot keeps renewing names this host no longer
#      serves; HTTP-01 fails for them, the renewal of the *whole* certificate
#      fails, and `api` — which nobody touched — goes down three months later
#      without a single message. Same shape as closing port 80.
#
#   2. **A page with `{{PLACEHOLDER}}` still in it is never published.** This is
#      a privacy policy naming a data controller. Publishing it with the
#      controller's name unset is worse than not publishing it at all, so the
#      substitution happens in a temporary directory, is verified there, and
#      only then replaces what is live.

set -euo pipefail

SITE_HOST="${SITE_HOST:-chesstrainers.app}"
REDIRECT_HOST="${REDIRECT_HOST:-chesstrainers.net}"
APP_USER="chess"
APP_DIR="/home/${APP_USER}/ChessMaster"
SITE_SRC="${SITE_SRC:-${APP_DIR}/site}"
ENV_FILE="${ENV_FILE:-${APP_DIR}/chess_backend/.env}"
WEB_ROOT="/var/www/${SITE_HOST}"
NGINX_SITE="chesstrainers-site"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
[[ -n "${LE_EMAIL:-}" ]] || { echo "Set LE_EMAIL — Let's Encrypt sends expiry warnings there." >&2; exit 1; }
[[ -d "$SITE_SRC" ]] || { echo "No site sources at ${SITE_SRC}. Pull the repository first." >&2; exit 1; }
[[ -f "$ENV_FILE" ]] || { echo "No env file at ${ENV_FILE}." >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Build the pages into a staging directory
# ---------------------------------------------------------------------------

log "Filling in the site's values from ${ENV_FILE}"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -r "${SITE_SRC}/." "$STAGE/"

# python3 rather than sed: these values land inside HTML and come from a file a
# human edits, so both HTML-escaping and the substitution itself have to be done
# without the shell's quoting rules in the middle. certbot already pulls python3
# in, so this costs nothing.
python3 - "$STAGE" "$ENV_FILE" <<'PY'
import html, os, re, sys

stage, env_file = sys.argv[1], sys.argv[2]

# The values the pages ask for. Everything here is either public-by-nature (the
# controller's details, which the law requires on the policy) or an address —
# and none of it is in the repository, which is public.
KEYS = [
    'OPERATOR_NAME', 'OPERATOR_ADDRESS', 'PRIVACY_EMAIL', 'SUPPORT_EMAIL',
    'HOSTING_PROVIDER', 'HOSTING_REGION', 'SMTP_PROVIDER',
    'EXPORT_RETENTION_DAYS', 'SITE_LAST_UPDATED',
]

values = {}
with open(env_file, encoding='utf-8') as fh:
    for line in fh:
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, _, value = line.partition('=')
        key = key.strip()
        if key in KEYS:
            values[key] = value.strip().strip('"').strip("'")

# The policy's date is its own field rather than "today": a legal document's
# last-modified date is a decision, and a date that moves on every deploy is a
# date nobody can rely on.
mapping = {
    'LAST_UPDATED': values.get('SITE_LAST_UPDATED', ''),
    **{k: values.get(k, '') for k in KEYS if k != 'SITE_LAST_UPDATED'},
}

missing = sorted(k for k, v in mapping.items() if not v)
if missing:
    print('Ove vrednosti nedostaju u ' + env_file + ':', file=sys.stderr)
    for key in missing:
        name = 'SITE_LAST_UPDATED' if key == 'LAST_UPDATED' else key
        print('  ' + name, file=sys.stderr)
    sys.exit(1)

for root, _, files in os.walk(stage):
    for name in files:
        if not name.endswith('.html'):
            continue
        path = os.path.join(root, name)
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
        for key, value in mapping.items():
            text = text.replace('{{' + key + '}}', html.escape(value, quote=True))
        left = re.findall(r'\{\{([A-Z_]+)\}\}', text)
        if left:
            print(f'{name} still has: {", ".join(sorted(set(left)))}', file=sys.stderr)
            sys.exit(1)
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(text)

print('Pages built.')
PY

# ---------------------------------------------------------------------------
# 2. Publish
# ---------------------------------------------------------------------------

log "Publishing to ${WEB_ROOT}"
mkdir -p "$WEB_ROOT"
# --delete so a page removed from the repository stops being served; the ACME
# challenge directory is excluded because certbot owns it and a renewal may be
# in flight.
rsync -a --delete --exclude '.well-known' "$STAGE/" "$WEB_ROOT/"
chown -R www-data:www-data "$WEB_ROOT"

# ---------------------------------------------------------------------------
# 3. nginx
# ---------------------------------------------------------------------------

log "nginx site for ${SITE_HOST}"
cat > "/etc/nginx/sites-available/${NGINX_SITE}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${SITE_HOST} www.${SITE_HOST};

    root ${WEB_ROOT};
    index index.html;

    # Kept reachable over plain HTTP on purpose: this is where certbot proves
    # the host owns the name, and the whole certificate depends on it. Do not
    # redirect this location to HTTPS.
    location ^~ /.well-known/acme-challenge/ {
        root ${WEB_ROOT};
        default_type "text/plain";
    }

    # Extensionless URLs, because Play remembers the privacy policy's address
    # and it must not change if the file layout does.
    location / {
        try_files \$uri \$uri.html \$uri/ =404;
    }
}
EOF
ln -sf "/etc/nginx/sites-available/${NGINX_SITE}" "/etc/nginx/sites-enabled/${NGINX_SITE}"
nginx -t
systemctl reload nginx

# ---------------------------------------------------------------------------
# 4. Its own certificate — see rule 1 at the top
# ---------------------------------------------------------------------------

log "TLS certificate for ${SITE_HOST} (separate from the API's)"
if certbot certificates 2>/dev/null | grep -q "Certificate Name: ${SITE_HOST}\$"; then
  echo "Certificate ${SITE_HOST} exists — reinstalling it into the nginx config."
  # Reinstalled rather than skipped: the site file above was just rewritten from
  # a template that has no 443 block, and "it already exists" is exactly the
  # reading that once left this host answering on port 80 only.
  certbot install --nginx --cert-name "$SITE_HOST" --redirect -n
else
  certbot --nginx --cert-name "$SITE_HOST" \
    -d "$SITE_HOST" -d "www.${SITE_HOST}" \
    -m "$LE_EMAIL" --agree-tos --no-eff-email -n --redirect
fi
systemctl reload nginx

# ---------------------------------------------------------------------------
# 5. The .net redirect, only if it actually points here
# ---------------------------------------------------------------------------

log "Redirect from ${REDIRECT_HOST}"
site_ip="$(getent ahostsv4 "$SITE_HOST" | awk 'NR==1{print $1}')"
redirect_ip="$(getent ahostsv4 "$REDIRECT_HOST" 2>/dev/null | awk 'NR==1{print $1}' || true)"
# `www` is checked as well as the apex, because certbot is asked for both names
# two lines below. Checking only the apex let a half-repointed domain through
# the guard and into certbot, which then failed the HTTP-01 challenge for the
# name nobody had checked — a guard that verifies less than what follows it.
redirect_www_ip="$(getent ahostsv4 "www.${REDIRECT_HOST}" 2>/dev/null | awk 'NR==1{print $1}' || true)"

if [[ -z "$redirect_ip" ]]; then
  echo "SKIPPED: ${REDIRECT_HOST} does not resolve."
elif [[ -z "$redirect_www_ip" ]]; then
  echo "SKIPPED: www.${REDIRECT_HOST} does not resolve, and the certificate covers it too."
  echo "Add its A record alongside the apex, then re-run this script."
elif [[ "$redirect_www_ip" != "$site_ip" ]]; then
  echo "SKIPPED: www.${REDIRECT_HOST} points somewhere else than ${SITE_HOST}."
  echo "Repoint it at this host, then re-run this script."
elif [[ "$redirect_ip" != "$site_ip" ]]; then
  # Said out loud, with the reason. A silent skip here would leave the operator
  # believing the redirect works, and asking certbot for a name that resolves
  # elsewhere fails the HTTP-01 challenge — which is why this is checked before
  # certbot is asked rather than after it refuses.
  echo "SKIPPED: ${REDIRECT_HOST} points somewhere else than ${SITE_HOST}."
  echo "Repoint its A record (and www) at this host, then re-run this script."
else
  cat > "/etc/nginx/sites-available/${NGINX_SITE}-redirect" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${REDIRECT_HOST} www.${REDIRECT_HOST};

    location ^~ /.well-known/acme-challenge/ {
        root ${WEB_ROOT};
        default_type "text/plain";
    }

    location / {
        return 301 https://${SITE_HOST}\$request_uri;
    }
}
EOF
  ln -sf "/etc/nginx/sites-available/${NGINX_SITE}-redirect" \
         "/etc/nginx/sites-enabled/${NGINX_SITE}-redirect"
  nginx -t
  systemctl reload nginx

  if certbot certificates 2>/dev/null | grep -q "Certificate Name: ${REDIRECT_HOST}\$"; then
    certbot install --nginx --cert-name "$REDIRECT_HOST" --redirect -n
  else
    certbot --nginx --cert-name "$REDIRECT_HOST" \
      -d "$REDIRECT_HOST" -d "www.${REDIRECT_HOST}" \
      -m "$LE_EMAIL" --agree-tos --no-eff-email -n --redirect
  fi
  systemctl reload nginx
fi

# ---------------------------------------------------------------------------
# 6. Say what is live
# ---------------------------------------------------------------------------

log "Summary"
cat <<EOF
Site:     https://${SITE_HOST}/            (all three apps)

One policy per app, because they handle different data. These are the URLs each
Play listing gets, and Play keeps whatever it is first given:

Mislisha           https://${SITE_HOST}/mislisha/privacy-policy
Chess Brain Trainer  https://${SITE_HOST}/brain-trainer/privacy-policy
Blindfold Trainer    https://${SITE_HOST}/blindfold-trainer/privacy-policy

Mislisha also has a parent consent page, and its Serbian versions are the
legally binding ones:

Consent (en)  https://${SITE_HOST}/mislisha/parent-consent
Policy (sr)   https://${SITE_HOST}/mislisha/politika-privatnosti
Consent (sr)  https://${SITE_HOST}/mislisha/saglasnost-roditelja

Contact:  https://${SITE_HOST}/contact  ·  https://${SITE_HOST}/kontakt

Certificates are separate: '${SITE_HOST}' for the site, and whatever the API
already had. Never join them with --expand; see the header of this file.

Re-run this script after editing anything in ${SITE_SRC}.
EOF
