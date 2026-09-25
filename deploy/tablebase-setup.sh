#!/usr/bin/env bash
#
# tablebase-setup.sh — our own Syzygy tables (the 3-4-5 set) and lila-tablebase,
# Lichess's own tablebase server, as a systemd service on 127.0.0.1:9000. Run
# as root, after provision.sh.
#
#   scp deploy/tablebase-setup.sh tools/lila-tablebase/3-4-5.sha256 root@HOST:/tmp/
#   ssh root@HOST 'SUMS=/tmp/3-4-5.sha256 bash /tmp/tablebase-setup.sh'
#
# docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1t: the backend asks these tables
# for positions with five men or fewer (LOCAL_TABLEBASE_URL) and Lichess for
# six and seven. Only the 3-4-5 set, the one the droplet can hold (940 MB), and
# the very same files as the owner's machine: every file is checked against
# `tools/lila-tablebase/3-4-5.sha256`, which was written from that set, so the
# two machines judge a game alike. A file that does not match is refused and
# the script stops — a table that is almost right is the one outcome worse than
# no table.
#
# The build is upstream's at a pinned commit; Linux needs no patch (the
# Windows one is in tools/lila-tablebase/). It builds as its own user, with
# its own rustup, and the service runs as that user with the tables read-only.
#
# Idempotent: tables already verified are not fetched again, and the build is
# skipped when the binary at the pinned commit is already there.

set -euo pipefail

TB_USER="tablebase"
TB_HOME="/opt/lila-tablebase"
SRC_DIR="${TB_HOME}/src"
TABLES="/var/lib/syzygy/3-4-5"
MIRROR="${MIRROR:-http://tablebase.sesse.net/syzygy/3-4-5}"
LILA_REPO="https://github.com/lichess-org/lila-tablebase.git"
# The commit measured on the owner's machine on 25.9.2026 (tools/lila-tablebase/README.md).
LILA_COMMIT="5eaf827193e69485c981fc10dcb7747198451964"
BIND="127.0.0.1:9000"
SERVICE="lila-tablebase"
BACKEND_ENV="/home/chess/ChessMaster/chess_backend/.env"
SUMS="${SUMS:-$(dirname "$0")/../tools/lila-tablebase/3-4-5.sha256}"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# As in app-setup.sh: sets KEY=VALUE, appending the line when the key is absent
# — a bare sed would silently do nothing then.
set_env() {
  local key="$1" value="$2" file="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

[[ $EUID -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
[[ -f "$SUMS" ]] || { echo "No checksum list at $SUMS — pass SUMS=/path/to/3-4-5.sha256." >&2; exit 1; }
SUMS="$(readlink -f "$SUMS")"
[[ $(wc -l < "$SUMS") -eq 290 ]] || { echo "$SUMS should list 290 files (145 tables, WDL and DTZ)." >&2; exit 1; }

log "Build dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# clang/libclang: bindgen, for the antichess and Prophet probers the build
# still compiles even though we never ask them anything.
apt-get -y install build-essential clang libclang-dev pkg-config git curl ca-certificates

log "User ${TB_USER}"
if ! id "$TB_USER" >/dev/null 2>&1; then
  useradd --system --home-dir "$TB_HOME" --create-home --shell /usr/sbin/nologin "$TB_USER"
fi

log "Tables: ${TABLES}"
install -d -m 755 "$TABLES"
fetched=0
while read -r sum name; do
  [[ -n "$name" ]] || continue
  target="${TABLES}/${name}"
  if [[ -f "$target" ]] && echo "${sum}  ${target}" | sha256sum --quiet -c - 2>/dev/null; then
    continue
  fi
  curl -fsS --retry 3 -o "${target}.part" "${MIRROR}/${name}"
  if ! echo "${sum}  ${target}.part" | sha256sum --quiet -c -; then
    rm -f "${target}.part"
    echo "${name}: the download does not match the owner's set. Stopping." >&2
    exit 1
  fi
  mv "${target}.part" "$target"
  fetched=$((fetched + 1))
done < "$SUMS"
(cd "$TABLES" && sha256sum --quiet -c "$SUMS")
chmod 444 "$TABLES"/*.rtb?
echo "Fetched ${fetched}; all $(wc -l < "$SUMS") files verified."

log "Rust for ${TB_USER}"
if ! sudo -u "$TB_USER" -H bash -c 'test -x "$HOME/.cargo/bin/cargo"'; then
  sudo -u "$TB_USER" -H bash -c \
    'curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable'
fi

log "lila-tablebase at ${LILA_COMMIT:0:7}"
if [[ ! -d "${SRC_DIR}/.git" ]]; then
  sudo -u "$TB_USER" -H git clone -q "$LILA_REPO" "$SRC_DIR"
fi
sudo -u "$TB_USER" -H git -C "$SRC_DIR" fetch -q origin
sudo -u "$TB_USER" -H git -C "$SRC_DIR" checkout -q --detach "$LILA_COMMIT"
BINARY="${SRC_DIR}/target/release/lila-tablebase"
STAMP="${SRC_DIR}/target/release/.built-at"
if [[ ! -x "$BINARY" ]] || [[ "$(cat "$STAMP" 2>/dev/null)" != "$LILA_COMMIT" ]]; then
  # One job: one CPU, and an LTO link that wants the memory to itself.
  sudo -u "$TB_USER" -H bash -c \
    "cd '$SRC_DIR' && CARGO_BUILD_JOBS=1 \$HOME/.cargo/bin/cargo build --release --locked"
  echo "$LILA_COMMIT" | sudo -u "$TB_USER" tee "$STAMP" >/dev/null
  rebuilt=1
else
  echo "Already built at ${LILA_COMMIT:0:7}."
  rebuilt=0
fi

log "systemd: ${SERVICE}"
cat > "/etc/systemd/system/${SERVICE}.service" <<EOF
[Unit]
Description=lila-tablebase — our own Syzygy 3-4-5 (PLAN-ZAGONETKE-IZ-PARTIJE.md, 1t)
After=network.target

[Service]
User=${TB_USER}
Group=${TB_USER}
Environment=RUST_LOG=info
ExecStart=${BINARY} --standard ${TABLES} --bind ${BIND}
LimitNOFILE=4096
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=${TABLES}
CapabilityBoundingSet=
NoNewPrivileges=true
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null
if [[ $rebuilt -eq 1 ]]; then systemctl restart "$SERVICE"; else systemctl start "$SERVICE"; fi

log "It answers"
# A king and pawn against king and pawn that White wins by promoting — the
# example in lila-tablebase's own README. Asked a few times: the service may
# still be opening the tables.
answer=""
for _ in 1 2 3 4 5; do
  answer="$(curl -fsS "http://${BIND}/standard?fen=4k3/6KP/8/8/8/8/7p/8_w_-_-_0_1" || true)"
  [[ -n "$answer" ]] && break
  sleep 2
done
echo "$answer" | grep -q '"category":"win"' || {
  echo "The tablebase did not answer as it should: ${answer:-nothing}" >&2
  systemctl status "$SERVICE" --no-pager | tail -20 >&2
  exit 1
}
echo "Answered: win."

log "Backend configuration"
if [[ -f "$BACKEND_ENV" ]]; then
  owner="$(stat -c '%U:%G' "$BACKEND_ENV")"
  set_env LOCAL_TABLEBASE_URL "http://${BIND}/standard" "$BACKEND_ENV"
  chown "$owner" "$BACKEND_ENV"
  echo "LOCAL_TABLEBASE_URL set in ${BACKEND_ENV}."
else
  echo "No ${BACKEND_ENV} yet — app-setup.sh seeds it; then set LOCAL_TABLEBASE_URL=http://${BIND}/standard."
fi
