# Func Linux

**Function First Linux** -- en Debian-baserad distro byggd for utvecklare, AI-arbete och natverksanalys.

```
    ______                 __    _
   / ____/_  ______  _____/ /   (_)___  __  ___  __
  / /_  / / / / __ \/ ___/ /   / / __ \/ / / / |/_/
 / __/ / /_/ / / / / /__/ /___/ / / / / /_/ />  <
/_/    \__,_/_/ /_/\___/_____/_/_/ /_/\__,_/_/|_|
```

CLI-forst. Debian-stabil. Kali-inspirerad.

---

## Oversikt

Func Linux ar en minimalistisk Linux-distribution som bootar till ren CLI och erbjuder XFCE-skrivbord vid behov. Tatt integrerad med Googles ekosystem och forinstallerad med verktyg for programmering, AI och natverkssakerhet.

| Egenskap | Val |
|----------|-----|
| Bas | Debian Bookworm (stable) |
| Init | systemd |
| Shell | bash |
| Boot | CLI (TTY) |
| GUI | XFCE 4 (manuellt via `guistart`) |
| Display server | X11 |
| Installer | Calamares |
| Byggsystem | live-build |

---

## Snabbstart

### Bygg ISO

```bash
sudo ./scripts/build-iso.sh
```

Producerar `func-linux-YYYYMMDD.iso` i projektroten.

### Kör ISO

**Virtuell maskin (QEMU):**

```bash
qemu-system-x86_64 -cdrom func-linux-YYYYMMDD.iso -m 4G -smp 2 -boot d -enable-kvm
```

> Flaggan `-enable-kvm` kräver KVM-stöd (`kvm-ok`). Utan den körs VM:en i emulering (långsammare).

**VirtualBox:**

1. Skapa en ny VM (Debian 64-bit, minst 2 GB RAM, 20 GB disk)
2. Under *Storage*, lägg till ISO:n som optisk skiva
3. Starta VM:en — systemet bootar till live-miljö

**USB-sticka:**

```bash
sudo dd if=func-linux-YYYYMMDD.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

> **Varning:** `dd` skriver över allt på enheten. Kontrollera rätt enhet med `lsblk` före körning.

ISO:n är hybrid (BIOS + UEFI) och bootar direkt från USB. Använd **Calamares** i live-miljön för permanent installation.

---

### Installera direkt pa system

```bash
sudo ./scripts/install.sh
```

Installerar alla paket, konfigurerar systemet och satter CLI-boot som standard.

### Konfigurera Google Drive

```bash
func-setup-google
```

---

## Projektstruktur

```
Func_Linux/
├── packages/
│   ├── core.list          # System, natverk, GPU, XFCE, Calamares
│   ├── dev.list           # Git, Python, Node, gcc, Docker
│   ├── ai.list            # ML-bibliotek (numpy, scipy, pandas, sklearn)
│   ├── network.list       # Sakerhetsverktyg (nmap, wireshark, sqlmap, ...)
│   └── google.list        # rclone, Chromium
├── config/
│   ├── bash/bashrc        # Prompt, alias, sokvagar
│   ├── xfce/              # Skrivbordskonfiguration
│   ├── systemd/           # Google Drive auto-mount service
│   └── calamares/         # Installer-konfiguration
├── scripts/
│   ├── build-iso.sh       # Bygger ISO med live-build
│   ├── install.sh         # Direkt installation pa system
│   └── setup-google.sh    # Google Drive-konfiguration
├── branding/
│   ├── motd               # ASCII-logo vid inloggning
│   └── issue              # Login-prompt
├── BUILD-LOG.md           # Detaljerad bygglogg
└── PROJEKT.md             # Intern designspecifikation
```

---

## Forinstallerade verktyg

### Programmering

Git, GitHub CLI (`gh`), Python 3, Node.js (LTS), gcc/g++/cmake, Docker, vim, nano, tmux, screen, shellcheck, jq, yq.

### AI / ML

- **Gemini CLI** -- AI direkt i terminalen
- **Ollama** -- lokal LLM-korning
- Python: numpy, scipy, pandas, sklearn, pytorch, transformers, langchain

### Natverk & Sakerhet (Kali-inspirerat)

| Kategori | Verktyg |
|----------|---------|
| Scanning | nmap, masscan, netdiscover |
| Paketanalys | wireshark, tshark, tcpdump, ettercap |
| Web | nikto, gobuster, ffuf, dirb, sqlmap, whatweb |
| Losenord | john, hashcat, hydra, medusa, crunch |
| Wireless | aircrack-ng, reaver, bully, wifite |
| Natverk | netcat, socat, ncat, proxychains4, sshuttle, openvpn, wireguard |
| HTTP | curl, wget, httpie |
| DNS | dnsenum, dnsrecon, fierce |
| MITM | arpwatch, dsniff, mitmproxy, bettercap, netsniff-ng |
| Forensik | autopsy, sleuthkit, dc3dd, testdisk, scalpel, exiftool |
| Fuzzing | afl++ |
| Anonymitet | tor, torsocks, i2pd |
| Reverse eng. | binwalk, foremost |
| Post-exploit | python3-impacket |
| Container | docker, awscli |

### Manuell installation kravs

Foljande verktyg finns inte i Debian Bookworm-repos och installeras separat (via pip, gem, extern repo eller binar):

| Verktyg | Anledning |
|---------|-----------|
| enum4linux | Kali-specifikt |
| wpscan | Ruby gem, Kali-specifikt |
| exploitdb | Kali-specifikt |
| wordlists | Kali meta-paket |
| responder | Kali-specifikt |
| kismet | Borttaget ur Bookworm |
| radare2 | Borttaget ur Bookworm |
| neo4j | Kraver extern repo |
| openvas (GVM) | Kraver extern repo |
| metasploit | Installeras av `install.sh` via eget skript |
| ghidra | Manuell nedladdning |
| chisel | Manuell nedladdning |

---

## Shell-alias

```bash
guistart        # Starta XFCE
guistop         # Stoppa XFCE, atervand till CLI
update          # apt update && apt upgrade
search          # apt search
ai              # Gemini CLI
drive           # cd ~/Drive
gs/ga/gc/gp/gl  # Git-genvägar
ports           # Visa oeppna portar
myip            # Visa publik IP
dps             # docker ps
```

---

## Google-integration

- **Google Drive** mountas automatiskt vid inloggning via systemd user service (`rclone`)
- **Gemini CLI** for AI-interaktion direkt i terminalen
- **Chromium** for Google-appar (Docs, Calendar, Gmail)
- Konfigurera med `func-setup-google`

---

## GPU-kompatibilitet

Breda drivrutiner inkluderas for att XFCE ska fungera oavsett grafikort:

- Intel (`xserver-xorg-video-intel`)
- AMD (`xserver-xorg-video-amdgpu`)
- NVIDIA (nouveau; proprietar drivrutin installeras separat)
- Fallback: vesa, fbdev
- Mesa for OpenGL

---

## Byggkrav

- Ubuntu eller Debian som vardsystem
- `live-build` (installeras automatiskt av `build-iso.sh`)
- `debian-archive-keyring`
- Root-rattigheter (`sudo`)

---

## Kanda begransningar

- `--force-yes is deprecated` -- varning fran live-build 3.x:s interna apt-anrop. Ofarlig.
- `--security false` anvands i `lb config` eftersom live-build 3.x genererar fel suite-namn for security-repot. Korrekt security-repo laggs till manuellt via `config/archives/security.list.chroot`.
- Kernel installeras via paketlistan (`linux-image-amd64`) istallet for live-builds `--linux-packages`-mekanism, eftersom den kraver `Contents-amd64.gz` som returnerar 404.

Se `BUILD-LOG.md` for fullstandig historik over byggproblem och losningar.

---

## Licens

Func Linux ar ett hobbyprojekt. Alla inkluderade verktyg distribueras under sina respektive licenser.
