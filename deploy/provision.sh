#!/usr/bin/env bash
#
# provision.sh — base system for the Chess Master backend host.
#
# Scope on purpose: this brings a fresh Ubuntu droplet to the point where the
# backend *could* run. It deliberately stops before the application itself —
# no checkout, no .env, no systemd unit, no nginx, no TLS — because those need
# decisions that are not made yet (domain name, where uploads live, whether
# nginx terminates TLS). Provisioning the base is version-agnostic and safe to
# repeat; the application half would be guesswork today.
#
# Run as root on a fresh droplet:
#   scp deploy/provision.sh root@HOST:/tmp/ && ssh root@HOST 'bash /tmp/provision.sh'
#
# Idempotent: re-running changes nothing that is already in place.

set -euo pipefail

DEPLOY_USER="chess"
SWAP_SIZE="2G"
NODE_MAJOR_MIN=22
NODE_MINOR_MIN=15   # zlib.zstd* lands in 22.15.0 — the puzzle import needs it

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

log "System packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y full-upgrade
# ffmpeg is not optional: audioTrimmer.js and videoRenderer.js spawn it by name.
# build-essential/python3 are there for any npm dependency without a prebuilt
# binary; fonts-dejavu-core so canvas text renders as text, not tofu.
apt-get -y install \
  ca-certificates curl gnupg git ufw ffmpeg \
  build-essential python3 python3-pip python3-venv fonts-dejavu-core \
  unattended-upgrades

log "Piper (tutorial narration)"
# The voice that reads a tutorial's sentences over its video. Self-hosted on
# purpose: Google Cloud does not accept an individual payments profile in
# Serbia, and this needs no account, no card and no per-character bill - and it
# is the only engine with a Serbian voice, which is what the trainers write in.
#
# A virtualenv rather than --break-system-packages: Ubuntu marks its Python
# externally managed, and a pip install into the system interpreter is the kind
# of thing that works today and breaks an unrelated apt upgrade in six months.
#
# Idempotent like everything else here: an existing venv is left alone, and a
# model already on disk is not downloaded again.
PIPER_HOME="/opt/piper"
PIPER_VOICES="${PIPER_HOME}/voices"
# One English voice and one Serbian, about 140 MB together. More can be added
# with the same command later; the backend offers whatever is in the directory.
PIPER_VOICE_NAMES=(en_US-lessac-medium sr_RS-serbski_institut-medium)

if [[ ! -x "${PIPER_HOME}/bin/piper" ]]; then
  python3 -m venv "${PIPER_HOME}"
  "${PIPER_HOME}/bin/pip" install --quiet --upgrade pip
  "${PIPER_HOME}/bin/pip" install --quiet piper-tts
else
  echo "piper already installed in ${PIPER_HOME}"
fi

mkdir -p "${PIPER_VOICES}"
for voice in "${PIPER_VOICE_NAMES[@]}"; do
  if [[ -f "${PIPER_VOICES}/${voice}.onnx" && -f "${PIPER_VOICES}/${voice}.onnx.json" ]]; then
    echo "voice ${voice} already present"
    continue
  fi
  "${PIPER_HOME}/bin/python" -m piper.download_voices --download-dir "${PIPER_VOICES}" "${voice}"
done
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${PIPER_HOME}" 2>/dev/null || true

# What the backend needs in its .env to use it:
#   TTS_PROVIDER=piper
#   PIPER_PYTHON=/opt/piper/bin/python
#   PIPER_VOICES_DIR=/opt/piper/voices

log "Node.js"
# Prefer the distribution's own Node when it is new enough — fewer third-party
# sources to trust and to keep patched. The major-version test below is
# deliberately strict rather than off by one: a distro shipping 22.x may well be
# 22.11, which is older than the 22.15 that first had zstd, and apt candidate
# strings are not worth parsing to the minor. Anything below 23 goes to
# NodeSource, which pins a current 22.x.
install_node_from_nodesource() {
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR_MIN}.x" | bash -
  apt-get -y install nodejs
}

node_version_ok() {
  command -v node >/dev/null 2>&1 || return 1
  local major minor
  major=$(node -p 'process.versions.node.split(".")[0]')
  minor=$(node -p 'process.versions.node.split(".")[1]')
  (( major > NODE_MAJOR_MIN )) && return 0
  (( major == NODE_MAJOR_MIN && minor >= NODE_MINOR_MIN )) && return 0
  return 1
}

if node_version_ok; then
  echo "Node $(node --version) already present and new enough."
else
  candidate=$(apt-cache policy nodejs 2>/dev/null | awk '/Candidate:/ {print $2}')
  candidate_major=${candidate%%.*}
  candidate_major=${candidate_major##*:}   # strip an epoch such as 2:22.11
  if [[ -n "${candidate_major//[!0-9]/}" ]] && (( candidate_major > NODE_MAJOR_MIN )); then
    echo "Ubuntu ships nodejs $candidate — using it."
    apt-get -y install nodejs npm
  else
    echo "Ubuntu candidate is '${candidate:-none}' — installing from NodeSource."
    install_node_from_nodesource
  fi
fi

node_version_ok || { echo "Node is still older than ${NODE_MAJOR_MIN}.${NODE_MINOR_MIN}." >&2; exit 1; }

log "Swap (${SWAP_SIZE})"
# The box is small and the MP4 export spikes; swap is the safety net, not a
# working surface — hence swappiness 10.
if ! swapon --show | grep -q '^/swapfile'; then
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "swap created"
else
  echo "swap already active"
fi
grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf
sysctl -q -w vm.swappiness=10

log "Journal size cap"
# Left uncapped, journald grows to 10% of the disk. On the previous host that
# was 2.3 GB of logs for a machine that was running nothing at all.
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-size.conf <<'EOF'
[Journal]
SystemMaxUse=200M
EOF
systemctl restart systemd-journald

log "Firewall"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status verbose

log "Deploy user (${DEPLOY_USER})"
# The backend has no business running as root; nginx will be the only thing
# facing the network anyway.
if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
if [[ -f /root/.ssh/authorized_keys ]]; then
  install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" \
    /root/.ssh/authorized_keys "/home/$DEPLOY_USER/.ssh/authorized_keys"
fi

log "Unattended security upgrades"
# The previous host sat a year without patches. This is the cheapest guard.
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now unattended-upgrades

log "Summary"
printf 'OS       : %s\n' "$(. /etc/os-release && echo "$PRETTY_NAME")"
printf 'Node     : %s\n' "$(node --version)"
printf 'npm      : %s\n' "$(npm --version)"
printf 'ffmpeg   : %s\n' "$(ffmpeg -version | head -1 | cut -d' ' -f1-3)"
printf 'swap     : %s\n' "$(swapon --show=NAME,SIZE --noheadings | tr '\n' ' ')"
printf 'user     : %s\n' "$DEPLOY_USER"
node -e 'if (typeof require("zlib").zstdDecompressSync !== "function") { console.error("zstd MISSING"); process.exit(1); } console.log("zstd     : ok")'

cat <<'EOF'

Base system ready. Still to be decided before the application half:
  - hostname / domain for the backend (needed for TLS and for backendUrl)
  - nginx as the TLS terminator, then a systemd unit for the Node process
  - where uploads/ lives, and how it is backed up — it is the only copy of
    the recorded lessons
  - the managed database's Trusted Sources must list this droplet
EOF
