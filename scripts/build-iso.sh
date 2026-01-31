#!/bin/bash
# Func Linux -- ISO Build Script
# Bygger en installationsbar ISO med live-build (Debian)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
PACKAGES_DIR="$PROJECT_DIR/packages"
CONFIG_DIR="$PROJECT_DIR/config"

GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
RESET='\e[0m'

log()  { echo -e "${GREEN}[BUILD]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERR]${RESET} $*" >&2; }

if [ "$EUID" -ne 0 ]; then
    err "Kors som root: sudo $0"
    exit 1
fi

# Krav: live-build + syslinux-utils + Debian keyring
for pkg in live-build syslinux-utils; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        log "Installerar $pkg..."
        apt-get update
        apt-get install -y "$pkg"
    fi
done

if [ ! -f /usr/share/keyrings/debian-archive-keyring.gpg ]; then
    log "Installerar debian-archive-keyring..."
    apt-get install -y debian-archive-keyring
fi

# Rensa tidigare bygg (spara befintliga ISO:r)
if [ -d "$BUILD_DIR" ]; then
    log "Rensar tidigare bygg..."
    # Flytta undan eventuella ISO:r innan rensning
    for iso in "$BUILD_DIR"/*.iso "$BUILD_DIR"/**/*.iso; do
        [ -f "$iso" ] && mv "$iso" "$PROJECT_DIR/" && log "Sparade befintlig ISO: $PROJECT_DIR/$(basename "$iso")"
    done
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ─── Konfigurera live-build ──────────────────────────
log "Konfigurerar live-build..."
lb config \
    --mode debian \
    --distribution bookworm \
    --mirror-bootstrap http://deb.debian.org/debian \
    --mirror-chroot http://deb.debian.org/debian \
    --mirror-binary http://deb.debian.org/debian \
    --security false \
    --archive-areas "main contrib non-free non-free-firmware" \
    --linux-packages none \
    --bootappend-live "boot=live components hostname=func username=func" \
    --iso-application "Func Linux" \
    --iso-publisher "Func Linux Project" \
    --iso-volume "FUNC_LINUX" \
    --memtest none \
    --win32-loader false \
    --apt-indices false

# ─── Fix isolinux bootloader (Debian Bookworm-kompatibla sökvägar) ────
# live-build 3.x:s inbyggda template har symlänkar till /usr/lib/syslinux/
# som inte stämmer i Bookworm. Skapar lokal template med korrekta sökvägar.
# Paketet "isolinux" krävs i chroot (ger /usr/lib/ISOLINUX/isolinux.bin).
log "Skapar lokal isolinux bootloader-template..."
mkdir -p config/bootloaders/isolinux
cp /usr/share/live/build/bootloaders/isolinux/*.cfg \
   /usr/share/live/build/bootloaders/isolinux/*.in \
   config/bootloaders/isolinux/ 2>/dev/null || true
# Symlänkar med korrekta Bookworm-sökvägar (tolkas i chroot)
ln -sf /usr/lib/ISOLINUX/isolinux.bin config/bootloaders/isolinux/isolinux.bin
ln -sf /usr/lib/syslinux/modules/bios/vesamenu.c32 config/bootloaders/isolinux/vesamenu.c32
ln -sf /usr/lib/syslinux/modules/bios/ldlinux.c32 config/bootloaders/isolinux/ldlinux.c32
ln -sf /usr/lib/syslinux/modules/bios/libcom32.c32 config/bootloaders/isolinux/libcom32.c32
ln -sf /usr/lib/syslinux/modules/bios/libutil.c32 config/bootloaders/isolinux/libutil.c32
# Skapa tom bootlogo (cpio-arkiv) — live-build 3.x:s lb_binary_syslinux rad 365
# försöker ovillkorligt läsa binary/isolinux/bootlogo för gfxboot-repacking.
# I Debian-mode skapas aldrig denna fil (bara i Ubuntu-mode). Utan den kraschar
# scriptet med "cannot open binary/isolinux/bootlogo: No such file".
(cd config/bootloaders/isolinux && echo -n | cpio --quiet -o > bootlogo)

# ─── Manuell security-repo (live-build 3.x använder fel suite-namn) ───
mkdir -p config/archives
echo "deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" \
    > config/archives/security.list.chroot
echo "deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" \
    > config/archives/security.list.binary

# ─── Kopiera paketlistor ─────────────────────────────
log "Kopierar paketlistor..."
mkdir -p config/package-lists

for listfile in "$PACKAGES_DIR"/*.list; do
    local_name=$(basename "$listfile")
    # Filtrera bort kommentarer for live-build
    grep -v '^#' "$listfile" | grep -v '^\s*$' > "config/package-lists/$local_name"
done

# ─── Custom filer (chroot) ──────────────────────────
log "Kopierar konfigurationsfiler..."
mkdir -p config/includes.chroot/etc/skel
cp "$CONFIG_DIR/bash/bashrc" config/includes.chroot/etc/skel/.bashrc

# MOTD
if [ -f "$PROJECT_DIR/branding/motd" ]; then
    mkdir -p config/includes.chroot/etc
    cp "$PROJECT_DIR/branding/motd" config/includes.chroot/etc/motd
fi

# Systemd service
mkdir -p config/includes.chroot/etc/skel/.config/systemd/user
cp "$CONFIG_DIR/systemd/google-drive-mount.service" \
    config/includes.chroot/etc/skel/.config/systemd/user/

# Setup-skript
mkdir -p config/includes.chroot/usr/local/bin
cp "$PROJECT_DIR/scripts/setup-google.sh" config/includes.chroot/usr/local/bin/func-setup-google
chmod +x config/includes.chroot/usr/local/bin/func-setup-google

# XFCE-konfiguration
if [ -d "$CONFIG_DIR/xfce" ]; then
    log "Kopierar XFCE-konfiguration..."
    mkdir -p config/includes.chroot/etc/skel/.config/xfce4
    cp -r "$CONFIG_DIR/xfce/"* config/includes.chroot/etc/skel/.config/xfce4/
fi

# Calamares installer
if [ -d "$CONFIG_DIR/calamares" ]; then
    log "Kopierar Calamares-konfiguration..."
    mkdir -p config/includes.chroot/etc/calamares
    cp "$CONFIG_DIR/calamares/settings.conf" config/includes.chroot/etc/calamares/
    cp -r "$CONFIG_DIR/calamares/modules" config/includes.chroot/etc/calamares/
    mkdir -p config/includes.chroot/etc/calamares/branding
    cp -r "$CONFIG_DIR/calamares/branding/func" config/includes.chroot/etc/calamares/branding/
fi

# Login-prompt (issue)
if [ -f "$PROJECT_DIR/branding/issue" ]; then
    cp "$PROJECT_DIR/branding/issue" config/includes.chroot/etc/issue
fi

# ─── Hooks (post-install skript) ─────────────────────
log "Skapar hooks..."
mkdir -p config/hooks/normal

cat > config/hooks/normal/0100-func-setup.hook.chroot << 'HOOKEOF'
#!/bin/bash
# Installera Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Installera Gemini CLI
npm install -g @google/gemini-cli

# Aktivera Docker
systemctl enable docker
HOOKEOF
chmod +x config/hooks/normal/0100-func-setup.hook.chroot

# ─── Bygg ISO (stegvis — kernel kopieras manuellt) ───────────────────
# Med --linux-packages none hoppar live-build över lb_binary_linux-image,
# som normalt kopierar vmlinuz/initrd till binary/live/. Syslinux-steget
# i lb binary förväntar sig att filerna redan finns och kör
# mv binary/live/vmlinuz-* ... som misslyckas.
#
# Binary-hooks körs EFTER syslinux-steget, så en hook kan inte lösa det.
# Lösning: kör bootstrap+chroot separat, kopiera kernel manuellt, kör binary.
log "Bygger ISO... (detta tar en stund)"

log "Steg 1/3: bootstrap + chroot..."
lb bootstrap 2>&1 | tee "$BUILD_DIR/build.log"
lb chroot 2>&1 | tee -a "$BUILD_DIR/build.log"

log "Steg 2/3: kopierar kernel och initrd till binary/live/..."
mkdir -p binary/live
cp chroot/boot/vmlinuz-* binary/live/
cp chroot/boot/initrd.img-* binary/live/

# ─── Fix rsvg: live-build 3.x anropar "rsvg" som inte finns i Bookworm ───
# librsvg2-bin i Bookworm levererar "rsvg-convert" istället för "rsvg",
# och syntaxen skiljer sig (rsvg-convert kräver -o för output).
# Skapar ett wrapper-skript i chroot som översätter anropet.
log "Skapar rsvg-wrapper i chroot (rsvg -> rsvg-convert)..."
cat > chroot/usr/bin/rsvg << 'RSVGEOF'
#!/bin/bash
# Wrapper: rsvg -> rsvg-convert (Debian Bookworm-kompatibilitet)
# Gammal syntax: rsvg [options] input.svg output.png
# Ny syntax:     rsvg-convert [options] -o output.png input.svg
args=()
positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        --format|--height|--width)
            args+=("$1" "$2"); shift 2 ;;
        -*)
            args+=("$1"); shift ;;
        *)
            positional+=("$1"); shift ;;
    esac
done
exec rsvg-convert "${args[@]}" -o "${positional[1]}" "${positional[0]}"
RSVGEOF
chmod +x chroot/usr/bin/rsvg

log "Steg 3/3: binary (bootloader + ISO)..."
lb binary 2>&1 | tee -a "$BUILD_DIR/build.log"

# Flytta ISO -- live-build 3.x kan skapa filen i chroot/ vid stegvis bygge
ISO_FILE=$(find "$BUILD_DIR" -name "*.hybrid.iso" -o -name "*.iso" | head -1)
if [ -n "$ISO_FILE" ]; then
    # Kör isohybrid om det inte redan körts (gör ISO USB-bootbar)
    if command -v isohybrid &>/dev/null; then
        if ! file "$ISO_FILE" | grep -q "MBR boot"; then
            log "Kör isohybrid för USB-boot-stöd..."
            isohybrid "$ISO_FILE" 2>/dev/null || warn "isohybrid misslyckades (ISO funkar ändå som CD)"
        fi
    fi
    FINAL_NAME="func-linux-$(date +%Y%m%d).iso"
    mv "$ISO_FILE" "$PROJECT_DIR/$FINAL_NAME"
    log "=== ISO klar: $PROJECT_DIR/$FINAL_NAME ==="
    log "Storlek: $(du -h "$PROJECT_DIR/$FINAL_NAME" | cut -f1)"
else
    err "Ingen ISO-fil hittades. Kontrollera $BUILD_DIR/build.log"
    exit 1
fi
