#!/bin/bash
# Func Linux -- Installationsskript
# Installerar alla paket och konfigurerar systemet
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGES_DIR="$PROJECT_DIR/packages"
CONFIG_DIR="$PROJECT_DIR/config"

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
RESET='\e[0m'

log()  { echo -e "${GREEN}[FUNC]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }

# Krav: kors som root
if [ "$EUID" -ne 0 ]; then
    err "Kors som root: sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Validera att vi har en riktig anvandare
if [ -z "$REAL_USER" ] || [ -z "$REAL_HOME" ]; then
    err "Kan inte identifiera anvandare. Kor med: sudo -E $0"
    exit 1
fi

if [ "$REAL_USER" = "root" ]; then
    err "Kor inte som ren root. Kor med: sudo $0 (fran din vanliga anvandare)"
    exit 1
fi

log "Anvandare: $REAL_USER (home: $REAL_HOME)"

# ─── Apt-paket ─────────────────────────────────────────
install_packages() {
    local listfile="$1"
    local name
    name=$(basename "$listfile" .list)

    if [ ! -f "$listfile" ]; then
        warn "Paketlista saknas: $listfile"
        return
    fi

    log "Installerar paket: $name"
    local packages
    packages=$(grep -v '^#' "$listfile" | grep -v '^\s*$' | tr '\n' ' ')

    if [ -n "$packages" ]; then
        # shellcheck disable=SC2086
        apt-get install -y $packages || warn "Vissa paket i $name kunde inte installeras"
    fi
}

# ─── NodeSource repo (Node.js LTS) ───────────────────
install_nodejs() {
    log "Installerar Node.js LTS via NodeSource"
    if ! command -v node &>/dev/null; then
        local tmpfile
        tmpfile=$(mktemp /tmp/func-nodesource-XXXXXX.sh)
        curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$tmpfile"
        bash "$tmpfile"
        rm -f "$tmpfile"
        apt-get install -y nodejs
    else
        log "Node.js redan installerat: $(node --version)"
    fi
}

# ─── Ollama ───────────────────────────────────────────
install_ollama() {
    log "Installerar Ollama"
    if ! command -v ollama &>/dev/null; then
        local tmpfile
        tmpfile=$(mktemp /tmp/func-ollama-XXXXXX.sh)
        curl -fsSL https://ollama.com/install.sh -o "$tmpfile"
        sh "$tmpfile"
        rm -f "$tmpfile"
    else
        log "Ollama redan installerat"
    fi
}

# ─── Gemini CLI ───────────────────────────────────────
install_gemini_cli() {
    log "Installerar Gemini CLI"
    if ! command -v gemini &>/dev/null; then
        npm install -g @google/gemini-cli
    else
        log "Gemini CLI redan installerat"
    fi
}

# ─── Python AI-paket ──────────────────────────────────
install_ai_pip() {
    log "Installerar Python AI-paket via pip"
    sudo -u "$REAL_USER" pip3 install --user --no-cache-dir \
        torch \
        transformers \
        langchain \
        openai \
        anthropic \
        jupyter \
        notebook
}

# ─── Konfiguration ───────────────────────────────────
install_config() {
    log "Installerar konfiguration"

    # Bashrc
    cp "$CONFIG_DIR/bash/bashrc" "$REAL_HOME/.bashrc"
    chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.bashrc"

    # Google Drive systemd service
    local systemd_user_dir="$REAL_HOME/.config/systemd/user"
    mkdir -p "$systemd_user_dir"
    cp "$CONFIG_DIR/systemd/google-drive-mount.service" "$systemd_user_dir/"
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/systemd"

    # MOTD
    cp "$PROJECT_DIR/branding/motd" /etc/motd 2>/dev/null || true

    # Issue (login-prompt)
    cp "$PROJECT_DIR/branding/issue" /etc/issue 2>/dev/null || true

    # Drive-mapp
    sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/Drive"

    # Log-mapp
    sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.local/share/func-linux"

    # Aktivera lingering for systemd user services
    loginctl enable-linger "$REAL_USER"

    # Setup-skript tillgangligt globalt
    cp "$PROJECT_DIR/scripts/setup-google.sh" /usr/local/bin/func-setup-google
    chmod +x /usr/local/bin/func-setup-google
}

# ─── XFCE konfiguration ──────────────────────────────
install_xfce_config() {
    log "Installerar XFCE-konfiguration"
    local xfce_dir="$REAL_HOME/.config/xfce4"
    if [ -d "$CONFIG_DIR/xfce" ] && [ "$(ls -A "$CONFIG_DIR/xfce" 2>/dev/null)" ]; then
        mkdir -p "$xfce_dir"
        cp -r "$CONFIG_DIR/xfce/"* "$xfce_dir/"
        chown -R "$REAL_USER:$REAL_USER" "$xfce_dir"
    fi
}

# ─── Metasploit (separat repo) ────────────────────────
install_metasploit() {
    log "Installerar Metasploit Framework"
    if ! command -v msfconsole &>/dev/null; then
        local tmpfile
        tmpfile=$(mktemp /tmp/func-msf-XXXXXX)
        curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o "$tmpfile"
        chmod 700 "$tmpfile"
        "$tmpfile"
        rm -f "$tmpfile"
    else
        log "Metasploit redan installerat"
    fi
}

# ─── Huvud ────────────────────────────────────────────
main() {
    log "=== Func Linux Installation ==="
    log ""

    # Uppdatera apt
    log "Uppdaterar paketindex"
    apt-get update

    # Installera paketlistor
    for listfile in "$PACKAGES_DIR"/*.list; do
        install_packages "$listfile"
    done

    # Extra installationer
    install_nodejs
    install_ollama
    install_gemini_cli
    install_ai_pip
    install_metasploit

    # Konfiguration
    install_config
    install_xfce_config

    # Aktivera Docker
    systemctl enable docker
    usermod -aG docker "$REAL_USER"

    # Satt CLI-boot som standard
    systemctl set-default multi-user.target

    log ""
    log "=== Installation klar ==="
    log "Starta om for att tillampa alla andringar: sudo reboot"
    log "Konfigurera Google Drive: func-setup-google"
}

main "$@"
