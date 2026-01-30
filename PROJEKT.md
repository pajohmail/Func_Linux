# Func Linux

**Function First Linux** -- en Debian-baserad distro byggd for utvecklare, AI-arbete och natverksanalys.

---

## Vision

Func Linux ar en minimalistisk, CLI-forst Linux-distribution som prioriterar stabilitet och funktionalitet over estetik. Distron bootar till ett rent CLI-lage och erbjuder ett XFCE-skrivbord som startas manuellt vid behov. Tatt integrerad med Googles ekosystem och forinstallerad med verktyg for programmering, AI och natverkssakerhet -- inspirerad av Kali Linux filosofi.

Malgrupp: erfarna utvecklare som foredrar terminalen.

---

## Grundregler

### 1. Funktion fore utseende
Alla designbeslut prioriterar stabilitet, prestanda och anvandbarhet. Inga onodiga visuella effekter eller teman. Varje installerat paket ska ha ett tydligt syfte.

### 2. CLI forst -- GUI manuellt
Systemet bootar till TTY/CLI. Grafiskt granssnitt (XFCE) startas manuellt via alias:

```
guistart    # Startar XFCE-session
```

GUI:t ska stodja alla vanliga grafikort (Intel, AMD, NVIDIA) utan manuell konfiguration. Nar GUI inte behovs ska noll grafiska resurser forbrukas.

### 3. Google-ekosystem integration
- **Google Drive** mountas automatiskt vid inloggning (via `google-drive-ocamlfuse` eller `rclone`)
- **Gemini CLI** forinstallerad for AI-interaktion direkt i terminalen
- **Google-appar** tillgangliga: Docs, Calendar, Gmail (via webapp-genvagar eller CLI-verktyg)

### 4. Utveckling, AI och natverksverktyg
Distron levereras med forinstallerade verktyg inom tre karnomraden:

**Programmering:**
- git, gh (GitHub CLI)
- Python 3 + pip + venv
- Node.js + npm
- gcc, make, cmake
- Docker
- vim, nano
- tmux

**AI/ML:**
- Gemini CLI
- Python AI-bibliotek (pytorch, transformers, langchain)
- Ollama (lokal LLM-korning)

**Natverk & Sakerhet (Kali-inspirerat):**
- Scanning: nmap, masscan, netdiscover
- Paketanalys: Wireshark/tshark, tcpdump, ettercap
- Web: nikto, gobuster, ffuf, dirb, sqlmap, wpscan, nuclei
- Exploitation: Metasploit Framework, exploitdb
- Losenord: John the Ripper, Hashcat, Hydra, Medusa
- Wireless: aircrack-ng, wifite, kismet, reaver
- OSINT: maltego, spiderfoot, theharvester, recon-ng, sherlock
- Forensik: autopsy, sleuthkit, volatility3, binwalk, testdisk
- Reverse Engineering: radare2, ghidra
- Pivoting: chisel, sshuttle, proxychains4
- Post-Exploitation: crackmapexec, bloodhound, impacket
- Fuzzing: afl++, boofuzz
- Anonymitet: tor, torsocks, i2pd
- Natverk: netcat, socat, curl, wget, httpie, bettercap, responder

### 5. Kali Linux som inspiration
Verktygsurvalet for natverk och sakerhet ar direkt inspirerat av Kali Linux. Skillnaden ar att Func Linux ar en generell utvecklardistro med sakerhetsverktyg -- inte en ren pentesting-distro.

---

## Teknisk arkitektur

| Lager | Val |
|-------|-----|
| Bas | Debian (stable/testing) |
| Init | systemd |
| Shell | bash (zsh tillganglig) |
| Pakethanterare | apt |
| Boot | CLI (TTY) |
| GUI | XFCE 4 (manuellt via `guistart`) |
| Display server | X11 (Wayland som option) |
| Filsystem | ext4 (btrfs som option) |

## Google Drive auto-mount

Vid inloggning mountas Google Drive till `~/Drive/` automatiskt via systemd user service eller `.bashrc`-hook. Konfiguration sker vid forsta inloggning.

## Alias och genvagar

```bash
guistart        # Starta XFCE
guistop         # Stoppa XFCE och atervand till CLI
update          # apt update && apt upgrade
search          # apt search
ai              # Gemini CLI
drive           # cd ~/Drive
```

---

## Installer

Func Linux anvander **Calamares** som grafiskt installationsprogram pa live-ISO:n. Installern hanterar:
- Partitionering (ext4/btrfs/xfs, EFI/BIOS)
- Anvandarskapande med sudo, docker, wireshark-grupper
- Bootloader (GRUB)
- Post-install: Node.js, Gemini CLI, Ollama, Docker-aktivering
- Satter `multi-user.target` som default (CLI-boot)

Ingen display manager installeras -- GUI startas manuellt.

---

## GPU-kompatibilitet

Breda GPU-drivrutiner inkluderas for att XFCE ska fungera oavsett grafikort:
- Intel (xserver-xorg-video-intel)
- AMD (xserver-xorg-video-amdgpu)
- NVIDIA (nouveau, proprietar drivrutin kan installeras separat)
- Fallback: vesa, fbdev
- Mesa for OpenGL

---

## Projektstruktur (byggsystem)

```
Func_Linux/
├── PROJEKT.md                          # Detta dokument
├── config/
│   ├── bash/bashrc                     # Prompt, alias, Google Drive mount
│   ├── xfce/
│   │   ├── terminal/terminalrc         # Terminalinstallningar
│   │   └── xfconf/xfce-perchannel-xml/
│   │       ├── xsettings.xml           # Tema (Adwaita-dark)
│   │       ├── xfce4-keyboard-shortcuts.xml
│   │       ├── xfce4-panel.xml         # Panel-layout
│   │       ├── xfce4-desktop.xml       # Skrivbord (ren, inga ikoner)
│   │       └── xfwm4.xml              # Fonsterhanterare
│   ├── systemd/
│   │   └── google-drive-mount.service
│   └── calamares/
│       ├── settings.conf               # Installationsflode
│       ├── branding/func/
│       │   ├── branding.desc
│       │   └── show.qml                # Installationsslideshow
│       └── modules/
│           ├── welcome.conf
│           ├── partition.conf
│           ├── users.conf
│           ├── bootloader.conf
│           ├── displaymanager.conf
│           ├── packages.conf
│           └── shellprocess.conf       # Post-install hooks
├── packages/
│   ├── core.list                       # System, GPU, XFCE, Calamares
│   ├── dev.list                        # Git, Python, Node, gcc, Docker
│   ├── ai.list                         # ML-bibliotek, Ollama, Gemini
│   ├── network.list                    # 100+ sakerhetsverktyg
│   └── google.list                     # rclone, Chromium
├── scripts/
│   ├── build-iso.sh                    # Bygger ISO med live-build
│   ├── install.sh                      # Direkt installation pa system
│   └── setup-google.sh                 # Google Drive-konfiguration
└── branding/
    ├── motd                            # ASCII-logo vid inloggning
    └── issue                           # Login-prompt
```
