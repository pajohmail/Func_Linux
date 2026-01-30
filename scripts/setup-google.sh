#!/bin/bash
# Func Linux -- Google Drive konfiguration
# Kors som vanlig anvandare (INTE root)
set -euo pipefail

GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
RESET='\e[0m'

log()  { echo -e "${GREEN}[FUNC]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }

if [ "$EUID" -eq 0 ]; then
    err "Kor INTE som root. Kor som din vanliga anvandare."
    exit 1
fi

# Kontrollera att rclone ar installerat
if ! command -v rclone &>/dev/null; then
    err "rclone ar inte installerat. Kor install.sh forst."
    exit 1
fi

log "=== Func Linux -- Google Drive Setup ==="
log ""

# Kontrollera om gdrive redan ar konfigurerat
if rclone config show gdrive &>/dev/null 2>&1 && rclone config show gdrive | grep -q "type"; then
    warn "Google Drive remote 'gdrive' ar redan konfigurerat."
    log "For att omkonfigurera, kor: rclone config delete gdrive"
    log "Och kor sedan detta skript igen."
else
    log "Startar rclone-konfiguration for Google Drive..."
    log ""
    log "En webblasare oppnas for Google-autentisering."
    log "Om du ar pa en server utan grafik, kor istallet:"
    log "  rclone config create gdrive drive --rc-web-gui=false"
    log ""
    rclone config create gdrive drive
fi

# Verifiera att konfigurationen lyckades
if ! rclone lsd gdrive: &>/dev/null 2>&1; then
    err "Kunde inte verifiera Google Drive-anslutningen."
    err "Kontrollera din konfiguration med: rclone config show gdrive"
    exit 1
fi

log "Google Drive-anslutning verifierad."

# Skapa mount-punkt
mkdir -p "$HOME/Drive"

# Aktivera systemd user service
log "Aktiverar automatisk mount vid inloggning..."
systemctl --user daemon-reload
systemctl --user enable google-drive-mount.service
systemctl --user start google-drive-mount.service

# Verifiera mount
sleep 2
if mountpoint -q "$HOME/Drive" 2>/dev/null; then
    log "Google Drive ar monterad pa: ~/Drive"
else
    warn "Mount verkar inte ha startat an. Kontrollera med:"
    warn "  systemctl --user status google-drive-mount.service"
fi

log ""
log "=== Google Drive Setup klar ==="
log "Din Google Drive monteras automatiskt vid inloggning."
