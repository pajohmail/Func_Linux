# Func Linux -- ISO Build Log

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
