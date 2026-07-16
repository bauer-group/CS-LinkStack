# CS-LinkStack — BAUER GROUP Edition

Self-hosted **„Link in Bio"**-Plattform auf Basis von
[LinkStack](https://github.com/LinkStackOrg/LinkStack) (PHP/Laravel, AGPL-3.0) —
als reproduzierbare **Container-Solution** mit CI/CD, Infrastructure-as-Code und
**eigenem, ins Image gebackenem Theme-Provisioning** (Corporate-Theme + kuratierte
Themes) verpackt.

> Öffentliche Seite + Admin: `https://links.bauer-group.com` (Admin unter `/admin`)

---

## Funktionen

- **Ein einziges Image** — `FROM linkstackorg/linkstack` (Alpine + Apache2 + PHP 8.3),
  erweitert um Theme-Provisioning und einen Wrapper-Entrypoint.
- **Themes ohne manuelle Uploads** — das Corporate-Theme und alle kuratierten
  Stock-Themes werden ins Image gebacken und beim Boot idempotent in das
  `/htdocs`-Volume gespiegelt („bake-and-sync"). Kein Klicken im Admin-UI mehr.
- **BAUER GROUP Corporate-Theme** — vollständig gescaffoldetes Theme V2 mit
  zentralen CSS-Variablen; Marken-Farben/Fonts/Footer sind ein Ein-Datei-Swap.
- **SQLite** — keine separate Datenbank, das gesamte `/htdocs`-Volume ist die
  Backup-Einheit.
- **Reverse-Proxy-ready** — Traefik v3 (HTTP→HTTPS, Security-Header, Let's Encrypt)
  oder Coolify; `FORCE_HTTPS` wird optional automatisch in `/htdocs/.env` gesetzt.
- **IaaC & CI/CD** — Compose-Triplet, semantic-release, GHCR + Docker Hub,
  Base-Image-Digest-Monitor, Dependabot — delegiert an
  `bauer-group/automation-templates`.

---

## Architektur

```text
                        ┌──────────────────────────────────────────┐
   Internet ──HTTPS──►  │  Reverse Proxy (Traefik v3 / Coolify)     │
                        │  TLS-Terminierung, Security-Header         │
                        └───────────────────┬──────────────────────┘
                                            │ HTTP :80
                        ┌───────────────────▼──────────────────────┐
                        │  linkstack  (Apache + PHP 8.3)            │
                        │  ┌────────────────────────────────────┐   │
   Image-intern         │  │ Entrypoint: bauergroup-provision.sh     │   │
   /opt/linkstack/      │  │  1. Theme-Sync  ─► /htdocs/themes  │   │
   themes/  ───sync───► │  │  2. .env-Bridge (FORCE_HTTPS)      │   │
   (bake-and-sync)      │  │  3. exec docker-entrypoint.sh      │   │
                        │  └────────────────────────────────────┘   │
                        │            Volume: /htdocs                 │
                        │  (SQLite-DB, Uploads, Themes, .env)       │
                        └──────────────────────────────────────────┘
```

**Warum bake-and-sync?** `/htdocs` ist ein gemountetes Named-Volume. Themes, die
direkt nach `/htdocs/themes/` ins Image kopiert werden, würden ab dem zweiten Boot
vom Volume **verdeckt** (Docker befüllt nur ein *leeres* Volume aus dem Image).
Deshalb werden die Themes image-intern unter `/opt/linkstack/themes/` abgelegt und
vom Entrypoint bei jedem Boot in das Volume gespiegelt — idempotent, überschreibt
nur die gebündelten Themes, **löscht niemals selbst hochgeladene Themes**.

---

## Schnellstart (lokal)

```bash
cp .env.example .env
# LINKSTACK_DOMAIN in .env setzen (für dev optional)

docker compose -f docker-compose.development.yml up -d --build
# → http://localhost:8080  → Setup-Wizard: SQLite (Default) wählen, Admin anlegen
```

---

## Deployment

| Variante | Datei | Edge / TLS |
| -------- | ----- | ---------- |
| **Traefik** (Production) | `docker-compose.traefik.yml` | Selbstverwaltetes Traefik v3, Let's Encrypt |
| **Coolify** (Production) | `docker-compose.coolify.yml` | Coolify verwaltet Routing/TLS (keine `traefik.*`-Labels) |
| **Development** | `docker-compose.development.yml` | Direkter Port, **kein** HTTPS — nicht ins Internet stellen |

```bash
# Traefik
docker compose -f docker-compose.traefik.yml up -d

# Coolify: Compose-Datei im Coolify-UI hinterlegen, Domain im Dashboard setzen
```

---

## Konfiguration

Alle Werte sind in [`.env.example`](.env.example) dokumentiert. Es gibt **keine
Pflicht-Secrets** (SQLite; der Admin-Account entsteht im Wizard).

| Variable | Zweck | Default |
| -------- | ----- | ------- |
| `STACK_NAME` | Prefix für Container/Volume/Netzwerk | `linkstack` |
| `LINKSTACK_DOMAIN` | Öffentliche Domain (muss zur DNS passen) | `links.bauer-group.com` |
| `LINKSTACK_IMAGE_TAG` | GHCR-Image-Tag (stable/latest/SemVer) | `stable` |
| `LINKSTACK_VERSION` | Upstream-Base-Image (Build-Arg, dev) | `latest` |
| `PHP_MEMORY_LIMIT` / `UPLOAD_MAX_FILESIZE` | PHP-Tuning | `512M` / `8M` |
| `LINKSTACK_MANAGE_ENV` | Entrypoint darf `/htdocs/.env` anpassen | `true` (prod) |
| `LINKSTACK_FORCE_HTTPS` | Setzt `FORCE_HTTPS` hinter Proxy | `true` (prod) |
| `PROXY_NETWORK` | Externes Traefik-Netz | `EDGEPROXY` |
| `IP_WHITELIST` | Traefik IP-Allow-List (Default: alle) | `0.0.0.0/0,::/0` |

---

## Themes

### Mechanik

- Gebündelte Themes liegen im Repo unter [`app/linkstack/themes/`](app/linkstack/themes/):
  - `bauer-group/` — das Corporate-Theme (Theme V2).
  - `vendor/<name>-<version>/` — kuratierte Stock-Themes, unzip-vendored.
  - [`themes.lock.json`](app/linkstack/themes/themes.lock.json) — Provenienz
    (SHA-256 der Quell-Zips) für reproduzierbare Builds.
- **Warum ein Sync?** Die Themes sind ins Image gebacken — aber unter
  `/opt/linkstack/themes/`, **nicht** unter `/htdocs/themes/`, wo LinkStack sie
  liest. `/htdocs` ist ein persistentes Volume; Docker befüllt es nur beim
  *ersten* Anlegen aus dem Image, spätere Image-Updates würden verdeckt. Der
  Entrypoint kopiert die gebündelten Themes daher bei **jedem Boot** ins Volume:
  Image-verwaltete Themes werden aktualisiert, selbst hochgeladene Themes bleiben
  unangetastet. Kein Marker, kein Schalter — deterministisch.

### Corporate-Theme (Look)

Das Theme definiert nur das **Aussehen** (Palette + Font-Stack), in
`app/linkstack/themes/bauer-group/`. Die BAUER GROUP Palette (Orange `#FF8500` +
Warm-Gray, hell/dunkel, WCAG-AA Link-Text) ist in `extra/custom-head.blade.php`
und `skeleton-auto.css` gesetzt; Font = `system-ui`-Stack (keine Webfonts). Bei
Marken-Änderungen die Werte dort anpassen, `version` in `themes.lock.json` +
`readme.md` erhöhen und Image neu bauen.

### Branding-Inhalte (im Admin-Backend, nicht im Theme)

Bewusst **nicht** im Theme hartkodiert, damit sie editierbar bleiben und im Daten-
Volume liegen:

- **Avatar / Profil-Logo:** BAUER GROUP Logo als Profilbild hochladen
  (Studio → Appearance). Pro Benutzer, im Volume gespeichert.
- **Footer-Links** (Impressum / Datenschutz): Admin → Settings → Footer
  (`DISPLAY_FOOTER_*`); Labels/Ziele im EnvEditor editierbar.
- **„Powered by LinkStack"-Credit:** über `DISPLAY_CREDIT` /
  `DISPLAY_CREDIT_FOOTER` im Admin abschalten.

### Weitere Themes hinzufügen

Theme-Ordner unter `app/linkstack/themes/vendor/<name-version>/` ablegen, Eintrag
(inkl. SHA-256 des Quell-Zips) in `themes.lock.json` ergänzen, Image neu bauen.
Nutzer können zusätzlich jederzeit eigene Themes über das Admin-UI hochladen —
diese bleiben beim Resync erhalten.

---

## Backup & Upgrade

Da SQLite genutzt wird, liegt der komplette Zustand (DB, Uploads, Themes, `.env`)
im Volume `${STACK_NAME}-data` (`/htdocs`).

```bash
# Snapshot des Volumes erstellen
python scripts/linkstack-backup.py backup

# Wiederherstellen
python scripts/linkstack-backup.py restore linkstack-backup-YYYYmmdd-HHMMSS.tar.gz
```

**Upgrade** (Container-Weg, empfohlen statt In-App-Updater): vorher Backup ziehen,
`LINKSTACK_VERSION`/`LINKSTACK_IMAGE_TAG` anheben, neu bauen/pullen, neu starten.
Der Entrypoint spiegelt die gebündelten Themes beim Boot neu ein; von Nutzern
hochgeladene Themes bleiben erhalten.

---

## Sicherheit

- **HTTPS** ist Pflicht: hinter dem Proxy `LINKSTACK_FORCE_HTTPS=true` (Default in
  prod) — der Entrypoint schreibt `FORCE_HTTPS` nach `/htdocs/.env`.
- Container läuft **non-root** (`apache:apache`, aus dem Upstream-Image).
- Traefik-Variante liefert HSTS, `X-Frame-Options: SAMEORIGIN`, `nosniff`,
  Referrer-Policy sowie eine optionale IP-Allow-List.
- **Nach dem Setup: Default-Passwort ändern.** Der Wizard legt den Admin an;
  Upstream-Demos nennen teils `root`/`password` — nicht produktiv verwenden.
- Keine Secrets im Repo (SQLite, `.env` ist gitignored).

---

## Projektstruktur

```text
CS-LinkStack/
├── app/linkstack/
│   ├── Dockerfile                 # FROM linkstackorg/linkstack + Themes + Entrypoint
│   ├── .dockerignore
│   ├── rootfs/usr/local/bin/bauergroup-provision.sh   # Wrapper-Entrypoint (bake-and-sync)
│   └── themes/
│       ├── themes.lock.json       # Provenienz (SHA-256) — reproduzierbare Builds
│       ├── bauer-group/           # Corporate-Theme (Theme V2)
│       └── vendor/                # kuratierte Stock-Themes (unzipped)
├── scripts/linkstack-backup.py    # Volume-Snapshot/-Restore
├── docker-compose.traefik.yml     # Production (Traefik v3)
├── docker-compose.coolify.yml     # Production (Coolify)
├── docker-compose.development.yml # Dev (lokaler Build, direkter Port)
├── .env.example                   # Konfigurations-Contract (keine Secrets)
├── .github/                       # CI/CD (automation-templates), Dependabot, CODEOWNERS
├── LICENSE                        # MIT (Wrapper)
└── NOTICE                         # Drittanbieter-Lizenzen (AGPL/GPLv3/MIT)
```

---

## Lizenz

Der **Wrapper** (dieses Repository) steht unter der [MIT-Lizenz](LICENSE).
Das erzeugte Image **bündelt LinkStack (AGPL-3.0)** sowie Themes unter MIT/GPLv3 —
Details und Hinweise (inkl. zweier Themes mit *Non-Commercial*-Einschränkung) in
[NOTICE](NOTICE).

## Weiterführende Dokumentation

- [LinkStack Docs](https://docs.linkstack.org/)
- [Docker Setup](https://docs.linkstack.org/docker/setup/)
- [Reverse Proxies](https://docs.linkstack.org/docker/reverse-proxies/)
- [Theme V2 Template](https://github.com/LinkStackOrg/linkstack-default-theme)
