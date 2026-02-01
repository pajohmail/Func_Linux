# Func Linux -- ISO Build Log

## 2026-02-01: Lägg till installationsalternativ i bootmenyn (Calamares)

**Problem:** Bootmenyn visar bara "Live" — inget sätt att installera
Func Linux till disk. `install.cfg` i bootloader-templaten innehöll
bara `# FIXME`.

**Orsak:** live-build 3.x skapar ingen `install.cfg` för Calamares-baserade
installationer. Calamares är en grafisk installer som körs inifrån en
live-session, inte ett separat boot-alternativ som `debian-installer`.

**Åtgärd:**

1. Skapade en riktig `install.cfg` i bootloader-templaten med ett
   "Install Func Linux"-menyalternativ. Bootar samma live-kernel med
   extra kernel-parameter `func-install`.

2. Skapade `/usr/local/bin/func-install-check` — ett skript som vid boot
   kollar `/proc/cmdline` efter `func-install`. Om den hittas startas
   LightDM/XFCE och sedan Calamares automatiskt.

3. Skapade en systemd-service (`func-install.service`) som körs vid
   `multi-user.target` och anropar install-check-skriptet.

```diff
 # config/bootloaders/isolinux/install.cfg (ny fil, ersätter "# FIXME")
+ label install
+ 	menu label ^Install Func Linux
+ 	kernel /live/vmlinuz
+ 	append initrd=/live/initrd.img boot=live components hostname=func username=func func-install
```

```diff
 # Nya filer i config/includes.chroot/:
+ /usr/local/bin/func-install-check        -- startar LightDM + Calamares
+ /etc/systemd/system/func-install.service  -- systemd oneshot vid boot
```

## 2026-02-01: Fix tangentbord fungerar inte i live-session (Dell + USB)

**Problem:** Vid boot till live-session (CLI) fungerar varken det interna
Dell-tangentbordet eller externt USB-tangentbord. Musen fungerar inte heller.
Skärmen visar terminal men ingen input registreras.

**Orsak:** Kernelmodulerna `i8042` (PS/2-kontroller) och `atkbd`
(AT-tangentbordsdrivrutin) saknades i initrd. Dessa krävs för PS/2-baserade
tangentbord som Dells interna tangentbord använder. Modulerna fanns i
squashfs men laddades aldrig vid boot eftersom de inte inkluderades i
initramfs. Utan `i8042` initieras inte heller USB HID korrekt på vissa
system eftersom kernel inte probar input-subsystemet fullständigt.

**Åtgärd:**

Lade till `i8042` och `atkbd` i `/etc/initramfs-tools/modules` i chroot
innan `update-initramfs -u` körs (steg 2/4 i `build-iso.sh`).

```diff
 # scripts/build-iso.sh (steg 2/4)
  chroot chroot apt-get install -y --no-install-recommends live-config live-config-systemd
+ echo "i8042" >> chroot/etc/initramfs-tools/modules
+ echo "atkbd" >> chroot/etc/initramfs-tools/modules
  chroot chroot update-initramfs -u
```

## 2026-01-31: Fix `Failed to load ldlinux.c32` — symlänkar resolvas mot värden

**Problem:** ISO bootar inte, syslinux visar `Failed to load ldlinux.c32`.
Trots att symlänkar för `ldlinux.c32`, `libcom32.c32` och `libutil.c32`
lades till i bootloader-templaten (se 2026-01-31-posten nedan) saknas
filerna fortfarande på den färdiga ISO:n.

**Orsak:** Symlänkarna i `config/bootloaders/isolinux/` pekar på
`/usr/lib/syslinux/modules/bios/*.c32` — sökvägar som resolvas mot
**värd-systemet**, inte chroot. `syslinux-common` var inte installerat
på värden, så `cp -aL` (som live-build kör internt) misslyckades tyst
och filerna kopierades aldrig till ISO:n.

**Åtgärd:**

1. Tog bort symlänkarna för `.c32`-modulerna från template-sektionen.
2. Kopierar istället de riktiga filerna direkt från chroot efter
   `lb chroot`-steget (steg 3/4), precis som kernel och initrd.

```diff
 # scripts/build-iso.sh (template-sektion, efter lb config)
- ln -sf /usr/lib/syslinux/modules/bios/vesamenu.c32 config/bootloaders/isolinux/vesamenu.c32
- ln -sf /usr/lib/syslinux/modules/bios/ldlinux.c32 config/bootloaders/isolinux/ldlinux.c32
- ln -sf /usr/lib/syslinux/modules/bios/libcom32.c32 config/bootloaders/isolinux/libcom32.c32
- ln -sf /usr/lib/syslinux/modules/bios/libutil.c32 config/bootloaders/isolinux/libutil.c32
+ # Symlänkar ersätts med riktiga filer från chroot i steg 3/4
+ ln -sf /usr/lib/syslinux/modules/bios/vesamenu.c32 config/bootloaders/isolinux/vesamenu.c32
```

```diff
 # scripts/build-iso.sh (steg 3/4, efter lb chroot)
+ # Kopiera syslinux-moduler direkt från chroot (inte symlänkar)
+ for mod in ldlinux.c32 libcom32.c32 libutil.c32 vesamenu.c32; do
+     cp "chroot/usr/lib/syslinux/modules/bios/$mod" "config/bootloaders/isolinux/$mod"
+ done
+ cp chroot/usr/lib/ISOLINUX/isolinux.bin config/bootloaders/isolinux/isolinux.bin
```

## 2026-01-31: Fix DNS i chroot — `Temporary failure resolving 'deb.debian.org'`

**Problem:** Steg 2/4 (reinstallation av Calamares och live-config-systemd
i chroot) misslyckas med `Temporary failure resolving 'deb.debian.org'`.

**Orsak:** `lb chroot` monterar `/etc/resolv.conf` i chroot under sitt
steg men avmonterar den när steget avslutas. De manuella `chroot chroot
apt-get`-anropen i steg 2/4 körs efter det, utan DNS-konfiguration.

**Åtgärd:**

Kopierar värdens `/etc/resolv.conf` till chroot före apt-anropen och
tar bort den efteråt (ska inte finnas i den färdiga live-sessionen).

```diff
 # scripts/build-iso.sh (steg 2/4)
+ cp /etc/resolv.conf chroot/etc/resolv.conf
  chroot chroot apt-get update
  chroot chroot apt-get install -y --no-install-recommends calamares ...
+ rm -f chroot/etc/resolv.conf
```

## 2026-01-31: Fix kernel panic vid live-boot + Calamares saknas i live-session

**Problem:** Vid boot av ISO laddas vmlinuz och initrd, sedan kernel panic
(PC-högtalaren tjuter och systemet hänger). Dessutom saknas Calamares
(grafisk installer) i den färdiga live-sessionen.

**Orsak:**

1. **Kernel panic:** `live-config-systemd` saknades i squashfs. Utan det
   skapas ingen `live-config.service`, live-config-scriptsen körs aldrig
   vid boot, ingen användare skapas, och systemet stannar. Paketet drogs
   in som beroende av `live-config` men togs bort av live-build 3.x:s
   paket-rensning under `lb_chroot`.

2. **Calamares borttaget:** live-build 3.x tar bort Calamares (och
   beroenden) under `lb_chroot`-stegets paket-rensning, innan squashfs
   skapas. Binären hamnar aldrig i den färdiga live-sessionen.

**Åtgärd:**

1. Lade till `live-config` och `live-config-systemd` i `packages/core.list`.
2. I `build-iso.sh`, efter `lb chroot` (steg 2/4), reinstalleras
   Calamares, live-config och live-config-systemd i chroot.
   Därefter körs `update-initramfs -u` så att initrd innehåller
   live-boot/live-config-hooks.

```diff
 # packages/core.list
  live-boot
+ live-config
+ live-config-systemd
  systemd
```

```diff
 # scripts/build-iso.sh (steg 2/4, efter lb chroot)
  chroot chroot apt-get update
  chroot chroot apt-get install -y --no-install-recommends calamares calamares-settings-debian
+ chroot chroot apt-get install -y --no-install-recommends live-config live-config-systemd
+ chroot chroot update-initramfs -u
```

## 2026-01-30: Fix gzip "unexpected end of file" vid kernel-steg

**Problem:** `lb_chroot_linux-image` försöker hämta
`http://deb.debian.org/debian/dists/bookworm/Contents-amd64.gz` för att hitta
rätt kernel-paket. Filen returnerar HTTP 404, wget sparar HTML-felsidan, och
gzip kraschar med `stdin: unexpected end of file`.

**Orsak:** Debian-spegeln serverar inte längre `Contents-amd64.gz` på den
URL:en som live-build förväntar sig. Eftersom kernel redan är explicit angiven
via `--linux-packages` och `--linux-flavours` behövs inte Contents-indexet.

**Åtgärd:** Lade till `--contents false` i `lb config`-anropet i
`scripts/build-iso.sh` (rad 65).

```diff
     --memtest none \
-    --win32-loader false
+    --win32-loader false \
+    --contents false
```

## 2026-01-30: Fix `--contents` okänd flagga i live-build 3.0

**Problem:** `lb config` avbryter med `okänd flagga "--contents"`.

**Orsak:** Installerad live-build är version `3.0~a57-1ubuntu49.1` som inte
stöder `--contents`-flaggan. Den flaggan finns bara i nyare versioner.

**Åtgärd:** Ersatte `--contents false` med `--apt-indices false` i
`scripts/build-iso.sh` (rad 65). Effekten är densamma — inga Contents-index
laddas ned — och flaggan stöds av live-build 3.0.

```diff
     --memtest none \
-    --win32-loader false \
-    --contents false
+    --win32-loader false \
+    --apt-indices false
```

## 2026-01-30: Fix Contents-404 — skippa live-builds kernel-steg helt

**Problem:** Trots `--apt-indices false` försöker `lb_chroot_linux-image`
fortfarande hämta `Contents-amd64.gz` (HTTP 404) för att hitta kernel-paketet.
Bygget avbryts med `gzip: stdin: unexpected end of file`. Dessutom skriver
live-build 3.x varningen `--force-yes is deprecated`.

**Orsak:** `--apt-indices false` styr bara om apt-index inkluderas i den
färdiga binär-imagen. Det hindrar *inte* `lb_chroot_linux-image` från att
ladda ner Contents under chroot-steget. Live-build 3.x kräver Contents för
att resolva kernel-paketnamnet via `--linux-packages`/`--linux-flavours`.

**Åtgärd:**
1. Ändrade `--linux-packages "linux-image linux-headers"` och
   `--linux-flavours amd64` till `--linux-packages none` i
   `scripts/build-iso.sh`. Detta hoppar över `lb_chroot_linux-image` helt.
2. La till `linux-headers-amd64` i `packages/core.list` (bredvid redan
   befintliga `linux-image-amd64`). Kernel installeras nu som vanligt paket
   via paketlistan istället.

```diff
 # build-iso.sh
-    --linux-packages "linux-image linux-headers" \
-    --linux-flavours amd64 \
+    --linux-packages none \
```

```diff
 # packages/core.list
  linux-image-amd64
+ linux-headers-amd64
  systemd
```

**Notering:** Varningen `--force-yes is deprecated` kommer från live-build
3.x:s interna apt-anrop och är ofarlig — den påverkar inte bygget.

## 2026-01-30: Fix paket som inte finns i Debian Bookworm

**Problem:** Bygget avbryts vid `lb_chroot_install-packages` med 10 felmeddelanden:

```
E: Unable to locate package networkmanager
E: Unable to locate package enum4linux
E: Unable to locate package wpscan
E: Unable to locate package exploitdb
E: Unable to locate package wordlists
E: Unable to locate package kismet
E: Unable to locate package responder
E: Package 'radare2' has no installation candidate
E: Unable to locate package neo4j
E: Unable to locate package openvas
```

**Orsak:** Två kategorier av fel:

1. **Fel paketnamn:** `networkmanager` i `core.list` — rätt namn i Debian är
   `network-manager` (med bindestreck).
2. **Ej tillgängliga i Debian Bookworm:** Nio paket i `network.list` finns
   bara i Kali Linux-repos eller kräver externa tredjepartsrepon:
   - `enum4linux`, `wpscan`, `exploitdb`, `wordlists`, `responder` — Kali-specifika
   - `kismet`, `radare2` — borttagna ur Debian Bookworm
   - `neo4j`, `openvas` (GVM) — kräver externa repos

**Åtgärd:**

1. Rättade `networkmanager` → `network-manager` i `packages/core.list`.
2. Kommenterade ut alla 9 otillgängliga paket i `packages/network.list` med
   förklarande kommentarer. Dessa verktyg behöver installeras manuellt
   (via pip, gem, extern repo eller binär) i ett separat installationsskript.

```diff
 # packages/core.list
- networkmanager
+ network-manager
```

```diff
 # packages/network.list
- enum4linux
+ # enum4linux -- ej i Debian repos, installeras manuellt
- wpscan
+ # wpscan -- ej i Debian repos, installeras via gem
- exploitdb
+ # exploitdb -- ej i Debian repos, installeras manuellt
- wordlists
+ # wordlists -- ej i Debian repos (Kali meta-paket), installeras manuellt
- kismet
+ # kismet -- ej i Debian bookworm, installeras manuellt
- responder
+ # responder -- ej i Debian repos, installeras manuellt
- radare2
+ # radare2 -- ej i Debian bookworm, installeras manuellt
- neo4j
+ # neo4j -- kraver extern repo, installeras manuellt
- openvas
+ # openvas (GVM) -- kraver extern repo, installeras manuellt
```

## 2026-01-30: Fix isolinux.bin och vesamenu.c32 saknas vid ISO-bygge

**Problem:** Byggets binär-steg (`lb_binary_syslinux`) misslyckas med:

```
cp: cannot stat '/root/isolinux/isolinux.bin': No such file or directory
cp: cannot stat '/root/isolinux/vesamenu.c32': No such file or directory
```

Ingen bootbar ISO skapas.

**Orsak:** live-build 3.x:s inbyggda bootloader-template
(`/usr/share/live/build/bootloaders/isolinux/`) innehåller symlänkar till
gamla sökvägar som inte stämmer i Debian Bookworm:

- `isolinux.bin -> /usr/lib/syslinux/isolinux.bin` — filen finns inte;
  i Bookworm levereras den av paketet `isolinux` på
  `/usr/lib/ISOLINUX/isolinux.bin`.
- `vesamenu.c32 -> /usr/lib/syslinux/vesamenu.c32` — filen har flyttat till
  `/usr/lib/syslinux/modules/bios/vesamenu.c32` i `syslinux-common`.

live-build kopierar template-katalogen in i chroot och kör `cp -aL` för att
resolva symlänkarna. Eftersom målfilerna inte finns misslyckas kopieringen.

**Åtgärd:**

1. Skapar en lokal bootloader-template i `config/bootloaders/isolinux/`
   (via `build-iso.sh`) med korrekta symlänkar som pekar på Bookworm-sökvägar.
   live-build prioriterar lokala templates före systemets.
2. La till paketet `isolinux` i `packages/core.list` så att
   `/usr/lib/ISOLINUX/isolinux.bin` finns tillgänglig i chroot.

```diff
 # scripts/build-iso.sh (efter lb config)
+# ─── Fix isolinux bootloader (Debian Bookworm-kompatibla sökvägar) ────
+log "Skapar lokal isolinux bootloader-template..."
+mkdir -p config/bootloaders/isolinux
+cp /usr/share/live/build/bootloaders/isolinux/*.cfg \
+   /usr/share/live/build/bootloaders/isolinux/*.in \
+   config/bootloaders/isolinux/ 2>/dev/null || true
+ln -sf /usr/lib/ISOLINUX/isolinux.bin config/bootloaders/isolinux/isolinux.bin
+ln -sf /usr/lib/syslinux/modules/bios/vesamenu.c32 config/bootloaders/isolinux/vesamenu.c32
```

```diff
 # packages/core.list
  linux-image-amd64
  linux-headers-amd64
  systemd
+ isolinux
```

## 2026-01-30: Fix vmlinuz saknas i binary/live/ — kernel kopieras inte vid `--linux-packages none`

**Problem:** Byggets binär-steg misslyckas med:

```
mv: kan inte ta status på 'binary/live/vmlinuz-*': Filen eller katalogen finns inte
```

Ingen bootbar ISO skapas. Felet uppstår under `lb_binary_syslinux`.

**Orsak:** Med `--linux-packages none` hoppar live-build över hela
`lb_binary_linux-image`-steget, som normalt kopierar kernel (`vmlinuz-*`) och
initrd (`initrd.img-*`) från `chroot/boot/` till `binary/live/`. Kernel
installeras korrekt i chroot via `linux-image-amd64` i paketlistan, men
syslinux-steget hittar inga filer i `binary/live/` eftersom kopieringssteget
aldrig körs.

**Åtgärd:**

1. La till en binary-hook (`config/hooks/normal/0050-copy-kernel.hook.binary`)
   i `scripts/build-iso.sh` som manuellt kopierar `vmlinuz-*` och
   `initrd.img-*` från `chroot/boot/` till `binary/live/`. Hooken körs före
   syslinux-steget och ersätter den logik som `lb_binary_linux-image` normalt
   utför.
2. La till paketet `live-boot` i `packages/core.list`. Det paketet krävs för
   att initrd ska innehålla live-boot-skripten som `boot=live`-parametern i
   bootloadern refererar till.

```diff
 # scripts/build-iso.sh (ny hook efter chroot-hook)
+cat > config/hooks/normal/0050-copy-kernel.hook.binary << 'HOOKEOF'
+#!/bin/bash
+set -e
+mkdir -p binary/live
+cp chroot/boot/vmlinuz-* binary/live/vmlinuz
+cp chroot/boot/initrd.img-* binary/live/initrd.img
+HOOKEOF
+chmod +x config/hooks/normal/0050-copy-kernel.hook.binary
```

```diff
 # packages/core.list
  linux-image-amd64
  linux-headers-amd64
+ live-boot
  systemd
```

## 2026-01-30: Fix vmlinuz-felet — binary hook körs för sent, byt till stegvis bygge

**Problem:** Trots binary-hooken `0050-copy-kernel.hook.binary` misslyckas bygget
fortfarande med:

```
mv: kan inte ta status på 'binary/live/vmlinuz-*': Filen eller katalogen finns inte
```

**Orsak:** I live-build 3.x körs binary-hooks (`lb_binary_hooks`) **efter**
syslinux-steget (`lb_binary_syslinux`). Syslinux-steget försöker flytta
`binary/live/vmlinuz-*` men filerna finns inte ännu — hooken som skulle
kopiera dem har inte körts.

Exekveringsordning i `lb binary`:
1. `lb_binary_rootfs` (squashfs)
2. `lb_binary_linux-image` — **hoppas över** pga `--linux-packages none`
3. `lb_binary_syslinux` — **misslyckas** (vmlinuz saknas)
4. `lb_binary_hooks` — hooken körs, men det är för sent

**Åtgärd:**

1. Tog bort binary-hooken `0050-copy-kernel.hook.binary` (den hinner aldrig
   köra före syslinux).
2. Ersatte `lb build` med stegvis exekvering:
   - `lb bootstrap` + `lb chroot` — bygger chroot med alla paket inkl. kernel
   - Manuell kopiering av `vmlinuz-*` och `initrd.img-*` från `chroot/boot/`
     till `binary/live/` — filerna behåller originalnamnet med versionssuffix
     så att live-builds `mv`-glob matchar
   - `lb binary` — skapar bootloader och ISO, hittar nu kernelfilerna

```diff
 # scripts/build-iso.sh
-cat > config/hooks/normal/0050-copy-kernel.hook.binary << 'HOOKEOF'
-#!/bin/bash
-set -e
-mkdir -p binary/live
-cp chroot/boot/vmlinuz-* binary/live/vmlinuz
-cp chroot/boot/initrd.img-* binary/live/initrd.img
-HOOKEOF
-chmod +x config/hooks/normal/0050-copy-kernel.hook.binary
-
-lb build 2>&1 | tee "$BUILD_DIR/build.log"
+lb bootstrap 2>&1 | tee "$BUILD_DIR/build.log"
+lb chroot 2>&1 | tee -a "$BUILD_DIR/build.log"
+
+mkdir -p binary/live
+cp chroot/boot/vmlinuz-* binary/live/
+cp chroot/boot/initrd.img-* binary/live/
+
+lb binary 2>&1 | tee -a "$BUILD_DIR/build.log"
```

## 2026-01-30: Fix `rsvg` saknas — splash-generering misslyckas i syslinux-steget

**Problem:** `lb_binary_syslinux` misslyckas med:

```
/usr/bin/env: 'rsvg': No such file or directory
```

Ingen ISO skapas. Felet uppstår när live-build försöker generera syslinux
splash-bilden genom att köra `rsvg --format png --height 480 --width 640
splash.svg splash.png` inuti chroot.

**Orsak:** I Debian Bookworm har paketet `librsvg2-bin` ersatt det gamla
`rsvg`-kommandot med `rsvg-convert`. Dessutom skiljer sig syntaxen:

- **Gammal:** `rsvg [options] input.svg output.png` (positionsargument)
- **Ny:** `rsvg-convert [options] -o output.png input.svg` (kräver `-o`)

live-build 3.x:s `lb_binary_syslinux` (rad 337) anropar det gamla `rsvg`
som inte längre finns.

**Åtgärd:**

Skapar ett wrapper-skript `chroot/usr/bin/rsvg` i det stegvisa bygget
(mellan `lb chroot` och `lb binary`) som översätter det gamla `rsvg`-syntaxen
till `rsvg-convert`-anrop.

```diff
 # scripts/build-iso.sh (efter kernel-kopiering, före lb binary)
+log "Skapar rsvg-wrapper i chroot (rsvg -> rsvg-convert)..."
+cat > chroot/usr/bin/rsvg << 'RSVGEOF'
+#!/bin/bash
+# Wrapper: rsvg -> rsvg-convert (Debian Bookworm-kompatibilitet)
+args=()
+positional=()
+while [ $# -gt 0 ]; do
+    case "$1" in
+        --format|--height|--width)
+            args+=("$1" "$2"); shift 2 ;;
+        -*)
+            args+=("$1"); shift ;;
+        *)
+            positional+=("$1"); shift ;;
+    esac
+done
+exec rsvg-convert "${args[@]}" -o "${positional[1]}" "${positional[0]}"
+RSVGEOF
+chmod +x chroot/usr/bin/rsvg
```

## 2026-01-30: Fix `bootlogo: No such file` — live-build 3.x kräver gfxboot-arkiv även i Debian-mode

**Problem:** `lb_binary_syslinux` avbryter med:

```
/usr/lib/live/build/lb_binary_syslinux: 365: cannot open binary/isolinux/bootlogo: No such file
```

Ingen ISO skapas.

**Orsak:** I `/usr/lib/live/build/lb_binary_syslinux` rad 365 körs:

```bash
(cd "$tmpdir" && cpio -i) < ${_TARGET}/bootlogo
```

Detta försöker ovillkorligt extrahera ett gfxboot `bootlogo`-cpio-arkiv från
`binary/isolinux/bootlogo`. Filen skapas bara i Ubuntu-mode (via
`gfxboot-theme-ubuntu`), men i Debian-mode (`--mode debian`) extraheras den
aldrig. Scriptet kontrollerar inte om filen finns innan det försöker läsa den
— en bugg i live-build 3.x.

**Åtgärd:**

Skapar ett tomt cpio-arkiv som `bootlogo` i den lokala isolinux-templaten
(`config/bootloaders/isolinux/`). Detta gör att rad 365 lyckas (extraherar
noll filer), och rad 376 packar om ett nytt arkiv med de `.cfg`-filer som
finns — precis som live-build förväntar sig.

```diff
 # scripts/build-iso.sh (i isolinux bootloader-template-sektionen)
  ln -sf /usr/lib/ISOLINUX/isolinux.bin config/bootloaders/isolinux/isolinux.bin
  ln -sf /usr/lib/syslinux/modules/bios/vesamenu.c32 config/bootloaders/isolinux/vesamenu.c32
+ # Skapa tom bootlogo (cpio-arkiv) — live-build 3.x:s lb_binary_syslinux rad 365
+ # försöker ovillkorligt läsa binary/isolinux/bootlogo för gfxboot-repacking.
+ (cd config/bootloaders/isolinux && echo -n | cpio --quiet -o > bootlogo)
```

## 2026-01-30: Fix `isohybrid: not found` — ISO skapas men är ej USB-bootbar

**Problem:** ISO-bygget slutförs (3171 MB), men under `lb_binary_syslinux`
loggas:

```
binary.sh: 5: isohybrid: not found
```

ISO:n startar bara från CD/DVD, inte USB.

**Orsak:** `isohybrid` levereras av paketet `syslinux-utils` som körs på
**värd-systemet** (inte i chroot). Paketet var inte installerat. live-build 3.x
anropar `isohybrid` i `lb_binary_iso` för att göra ISO:n hybrid-bootbar
(MBR + El Torito).

**Åtgärd:**

Lade till `syslinux-utils` i prerequisite-installationen i `scripts/build-iso.sh`
(bredvid `live-build`). Skriptet kontrollerar nu att båda paketen finns och
installerar dem vid behov.

```diff
 # scripts/build-iso.sh
-# Krav: live-build + Debian keyring
-if ! command -v lb &>/dev/null; then
-    log "Installerar live-build..."
-    apt-get update
-    apt-get install -y live-build
-fi
+# Krav: live-build + syslinux-utils + Debian keyring
+for pkg in live-build syslinux-utils; do
+    if ! dpkg -s "$pkg" &>/dev/null; then
+        log "Installerar $pkg..."
+        apt-get update
+        apt-get install -y "$pkg"
+    fi
+done
```

## 2026-01-31: Fix `Failed to load ldlinux.c32` vid ISO-boot

**Problem:** ISO:n bootar inte — syslinux visar:

```
Failed to load ldlinux.c32
```

**Orsak:** Sedan syslinux 5+ kräver alla `.c32`-moduler att `ldlinux.c32`
finns i samma katalog som `isolinux.bin`. Dessutom kräver `vesamenu.c32`
biblioteksmodulerna `libcom32.c32` och `libutil.c32`. Den lokala
bootloader-templaten symlänkade bara `vesamenu.c32` men inte dessa tre
obligatoriska beroenden.

**Åtgärd:**

Lade till symlänkar för `ldlinux.c32`, `libcom32.c32` och `libutil.c32`
i bootloader-template-sektionen i `scripts/build-iso.sh`.

```diff
 # scripts/build-iso.sh
  ln -sf /usr/lib/syslinux/modules/bios/vesamenu.c32 config/bootloaders/isolinux/vesamenu.c32
+ ln -sf /usr/lib/syslinux/modules/bios/ldlinux.c32 config/bootloaders/isolinux/ldlinux.c32
+ ln -sf /usr/lib/syslinux/modules/bios/libcom32.c32 config/bootloaders/isolinux/libcom32.c32
+ ln -sf /usr/lib/syslinux/modules/bios/libutil.c32 config/bootloaders/isolinux/libutil.c32
```

## 2026-01-31: Fix `Couldn't download package libtirpc3` — cachad paketlista inaktuell

**Problem:** Bygget avbryts under bootstrap med:

```
W: Couldn't download package libtirpc3 (ver 1.3.3+ds-1 arch amd64)
E: Couldn't download packages: libtirpc3
```

**Orsak:** Debian Bookworm har fått en point release och den cachade
paketversionen (`1.3.3+ds-1`) har ersatts med en nyare version på
mirror-servern. `debootstrap`/`lb` försöker ladda ner den gamla versionen
som inte längre finns.

**Åtgärd:**

Rensa cachade paketlistor och bygg om:

```bash
sudo lb clean
sudo lb clean --purge
sudo ./scripts/build-iso.sh
```

`--purge` rensar cachade index så att aktuella paketversioner hämtas.

## 2026-01-30: Fix `isohybrid` i chroot + ISO-sökväg fel vid stegvis bygge

**Problem:** Trots att `syslinux-utils` installeras på värd-systemet loggas
fortfarande `binary.sh: 5: isohybrid: not found` under bygget. Dessutom hamnar
ISO-filen i `build/chroot/binary.hybrid.iso` istället för direkt i `build/`,
och skriptets `find -maxdepth 1` hittar den inte.

**Orsak:**
1. **isohybrid i chroot:** live-build 3.x:s `lb_binary_iso` kör `isohybrid`
   inuti chroot-miljön via `binary.sh`. Paketet `syslinux-utils` fanns bara på
   värden, inte i chroot.
2. **ISO-sökväg:** Vid stegvis bygge (`lb bootstrap` + `lb chroot` + `lb binary`)
   skapar live-build ISO:n i `chroot/` istället för i `$BUILD_DIR` direkt.
   Skriptets `find -maxdepth 1` missade filen.

**Åtgärd:**
1. Lade till `syslinux-utils` i `packages/core.list` så att `isohybrid` finns
   tillgänglig inuti chroot under `lb binary`.
2. Ändrade ISO-sökningen i `build-iso.sh` till rekursiv `find` (utan maxdepth)
   som söker efter `*.hybrid.iso` och `*.iso`.
3. La till en fallback-isohybrid på värd-sidan: om ISO:n saknar MBR-boot körs
   `isohybrid` manuellt efter att filen hittats.

```diff
 # packages/core.list
  isolinux
+ syslinux-utils
```

```diff
 # scripts/build-iso.sh
-ISO_FILE=$(find "$BUILD_DIR" -maxdepth 1 -name "*.iso" -type f | head -1)
+ISO_FILE=$(find "$BUILD_DIR" -name "*.hybrid.iso" -o -name "*.iso" | head -1)
 if [ -n "$ISO_FILE" ]; then
+    if command -v isohybrid &>/dev/null; then
+        if ! file "$ISO_FILE" | grep -q "MBR boot"; then
+            isohybrid "$ISO_FILE" 2>/dev/null || true
+        fi
+    fi
     FINAL_NAME="func-linux-$(date +%Y%m%d).iso"
```
