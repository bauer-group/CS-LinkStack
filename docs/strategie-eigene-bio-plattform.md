# Strategie: Eigene „Link in Bio"-Plattform (LinkStack-Ablösung)

> **Status:** Entwurf zur Entscheidung · **Datum:** 2026-07-16 · **Kontext:** BAUER GROUP · Repo `bauer-group/CS-LinkStack`
>
> Dieses Dokument analysiert, ob und wie BAUER GROUP eine eigene „Link in Bio"-Lösung
> anstelle von LinkStack aufbauen sollte. Auslöser: LinkStack erfüllt zwei zunehmend
> wichtige Anforderungen **nicht** — eine echte Verwaltungs-**API** und **OIDC/Entra-ID-SSO** —
> und der Markt bietet keine fertige Self-Hosted-Alternative, die beides mitbringt.

---

## 1. Management Summary

- **Problem:** LinkStack ist ein session-basierter Blade-Monolith **ohne Management-API** und **ohne OIDC/Entra-ID-SSO** (nur Social-Login via Google/GitHub/Facebook/Twitter). Beides ist für eine professionelle, integrierte Corporate-Nutzung relevant.
- **Markt:** Es existiert **keine** dedizierte Self-Hosted-Bio-Seite, die „besser als LinkStack **und** API **und** OIDC" ist. API-starke Tools (Dub, Bookmark-Manager, Headless-CMS) gehören zu Nachbarkategorien und/oder scheitern an Self-Host/IaaC (siehe Kap. 3).
- **Kernfrage vor dem Bauen:** *Braucht ihr wirklich eine Plattform, oder ist der eigentliche Bedarf „Inhalte reproduzierbar (IaaC) ausrollen + Zugang absichern"?* Diese Frage entscheidet zwischen einer schlanken und einer großen Lösung.
- **Empfehlung (gestuft):**
  - **Sofort/lean:** Wenn Inhalte selten und durch Devs gepflegt werden → **Option C (deklarativ-statisch)** deckt IaaC-Provisioning **ohne API und ohne OIDC** ab (Git-Review = Autorisierung). Günstigste, robusteste Lösung.
  - **Wenn API/OIDC echte Anforderungen sind (wie genannt):** **Option D (Headless, Payload/TypeScript)** als API-first-Plattform mit **Entra-ID-OIDC**, plus **Delegation der Klick-Analytik an das bereits betriebene Shlink**. Verpackung nach CS-URLShortener-Konventionen.
  - **Greenfield (Option E)** nur, wenn dies ein strategisches Produkt mit Mandantenfähigkeit/tiefer Integration werden soll.
- **Aufwand (grob):** MVP ~3–5 Personenwochen, v1 ~2–3 Personenmonate. **Hauptrisiko:** Eigenbetrieb und -wartung (ihr besitzt danach den Code).

---

## 2. Ausgangslage & Problem

Aktuell betreibt BAUER GROUP **CS-LinkStack** — einen professionellen Docker/IaaC-Wrapper
um Upstream-LinkStack (dieses Repo). Der Wrapper ist sauber (Themes, Bootstrap, `mod_remoteip`,
Backups, CI/CD), aber die **funktionalen Grenzen liegen im Upstream selbst**.

### 2.1 LinkStack — verifizierte Gap-Analyse (aus dem Code des Images)

| Bereich | Befund | Beleg |
| --- | --- | --- |
| **Management-API** | ❌ Keine. Nur der Laravel-Standard-Stub `GET /api/user` hinter `auth:api`. Kein CRUD für Links/Profile/Seiten. | `routes/api.php` |
| **SSO / OIDC** | ❌ Kein OIDC/Entra/Keycloak/SAML. Nur `laravel/socialite` mit den Core-Providern Google/GitHub/Facebook/Twitter, global geschaltet über `ENABLE_SOCIAL_LOGIN`. Keine `socialiteproviders/*`-Pakete installiert. | `composer.json`, `config/services.php`, `routes/web.php`, `SocialLoginController` |
| **Architektur** | Session-basierter Blade-Monolith (server-rendered), AGPL-3.0. | LinkStackOrg/LinkStack |
| **Provisionierung** | Config/Content liegen im `/htdocs`-Volume; Automatisierung nur via DB-Zugriff oder `.env`-Merge (kein API-Weg). | (unsere Umsetzung: Theme via SQLite-`UPDATE`, Config via `.env`-Bootstrap) |
| **Datenhaltung** | SQLite (Default) oder MySQL/MariaDB. | docs.linkstack.org |

### 2.2 Business-Treiber

- **API-first:** Programmatisches Ausrollen/Pflegen von Links, Profilen, Seiten aus anderen Systemen (Kampagnen-Tooling, CMDB, CI). Aktuell nur über DB-Hacks möglich — nicht wartbar.
- **OIDC/Entra ID:** Zentraler, richtlinienkonformer Admin-Zugang über den bestehenden Identity Provider (M365/Entra ID). Aktuell nur lokaler Login oder Google-Social-Login.
- **Governance:** Ein selbst betriebener, integrierter Baustein passt besser in die BAUER-GROUP-Standards (IaaC, Security, Wiederverwendung vorhandener Infrastruktur).

---

## 3. Marktanalyse — Kurzfazit

Ausführliche Recherche (2025/2026) hat ergeben: **Keine dedizierte Self-Hosted-Bio-Seite
kombiniert „gepflegt + Docker/IaaC + echte API + OIDC".**

| Kandidat | Kategorie | Echte API | Self-Host/IaaC | OIDC | Als Bio-Seite |
| --- | --- | --- | --- | --- | --- |
| LinkStack | Bio-Seite | ❌ | ✅ | ❌ | ✅ |
| Dub | Link-Mgmt + Analytics | ✅ (top) | ❌ Vercel-only, kein Docker | teils | ❌ |
| Slash | Link-Sharing | ⚠️ dünn | ✅ | ❌ | ⚠️ stagniert |
| LinkAce / Linkwarden / Karakeep | Bookmark-Manager | ✅ | ✅ | teils | ❌ falsche Form |
| PocketBase / Payload / Strapi | Headless-CMS/BaaS | ✅ | ✅ | ✅ (konfigurierbar) | ⚠️ Backend, Frontend selbst |
| Skarf / LittleLink | Bio-Seite | ❌ | ✅ (deklarativ) | ❌ | ⚠️ einfach |

**Schlussfolgerung:** Die API-/OIDC-Anforderungen zwingen entweder zu einem **Headless-Backend
+ eigenem Frontend** oder zu einem **Greenfield-Bau**. Ein reiner „besserer LinkStack von der Stange"
existiert nicht. → Der Eigenbau ist eine legitime Option.

---

## 4. Anforderungen

### Must (MVP)
- **API-first:** REST + OpenAPI-Spezifikation; Auth über **API-Key (M2M)** und **OIDC (User)**.
- **OIDC/Entra-ID-SSO** für den Admin-Zugang.
- **Self-Host, Docker, IaaC:** Compose-Triplet (traefik/coolify/development), Traefik, GHCR+Docker-Hub, semantic-release — **nach CS-URLShortener-Konventionen**.
- **Öffentliche Bio-Seite(n):** schnell, SEO-fähig, **BAUER GROUP Corporate-Branding** (Design-Tokens bereits vorhanden), **WCAG 2.1 AA**.
- **Betrieb:** Backup/Restore, echte Client-IP hinter Proxy, OWASP-konform, keine Secrets im Repo.

### Should
- Multi-Profil / Multi-Page (mehrere Kampagnen-/Abteilungsseiten).
- Klick-Analytik, QR-Codes, vCard-Export, i18n (DE/EN), mehrere Themes.

### Won't (bewusst nicht im MVP)
- Öffentliche Mandanten-SaaS, Plugin-Marktplatz, In-App-Theme-Editor.

---

## 5. Optionen

| # | Option | Kurzbeschreibung | API | OIDC | Aufwand | Kontrolle |
| --- | --- | --- | --- | --- | --- | --- |
| **A** | LinkStack behalten + Workarounds | DB-/`.env`-Provisionierung, kein SSO | ❌ | ❌ | – | niedrig |
| **B** | LinkStack **forken** (PHP/Laravel) | Sanctum-API + OIDC-Socialite ergänzen | teils | teils | mittel | mittel |
| **C** | **Deklarativ-statisch** (YAML→Static via CI) | Bio-Seite aus Git generiert, kein DB/Admin | ❌ (Git) | ❌ (Git-Review) | **niedrig** | **hoch** |
| **D** | **Headless (Payload/PocketBase) + Frontend** | API+Admin+Auth „geschenkt", eigenes Bio-Frontend | ✅ | ✅ | mittel | hoch |
| **E** | **Greenfield-Plattform** | Alles selbst, exakt passend | ✅ | ✅ | **hoch** | **max** |

### Bewertung der Kern-Optionen

**B — LinkStack forken:** Wiederverwendung von Themes/Features, aber **AGPL-Pflichten**
(Modifikationen offenlegen), Erben eines Legacy-Codebestands, **dauerhafte Merge-Last**
gegen Upstream, und der In-App-Updater kollidiert mit eigenen Änderungen. → Nur bei minimalem
Delta sinnvoll; für „API + OIDC" ist das Delta groß. **Nicht empfohlen.**

**C — Deklarativ-statisch (die ehrliche Lean-Option):** Inhalte (Profil, Links, Theme) liegen
als `bio.yaml` **in Git**; die CI generiert eine gebrandete statische Seite und deployt sie.
- **Deckt die eigentlichen Bedürfnisse ohne die genannten Features ab:** „Provisioning" = Git-Commit (kein API nötig); „Admin-Zugang absichern" = Git-Repo-Rechte + Review (kein OIDC nötig).
- Maximal reproduzierbar, kein DB/Server-State, kaum Angriffsfläche, günstigster Betrieb.
- **Grenze:** Nicht-Devs können nicht ohne Git-Kenntnis pflegen; keine Laufzeit-API für Fremdsysteme.

**D — Headless (Payload) + Frontend (empfohlener Build-Pfad):** Payload (TypeScript, **MIT**,
Next-native) liefert **REST + GraphQL-API**, ein **Admin-UI**, Auth (OIDC via Custom-Strategy),
Postgres und Docker out of the box. Man modelliert `Profiles`/`Links`/`Themes` und baut **eine**
öffentliche Bio-Seite. → ~80 % weniger Backend-Code als Greenfield, trotzdem API + OIDC + Kontrolle.

**E — Greenfield:** Volle Passung und eigenes IP, aber höchster Bau- und Wartungsaufwand
(Auth, Admin-UI, öffentliche Seite, Themes, Analytics, Migration). Nur bei strategischem Produktziel.

---

## 6. Empfehlung

**Zuerst die Nutzungsfrage klären** (offene Entscheidung, Kap. 12):
*Wer pflegt Inhalte, wie oft, eine oder viele Seiten?*

1. **Selten + durch Devs + wenige Seiten →** mit **Option C (deklarativ-statisch)** starten.
   Erfüllt IaaC-Provisioning sofort, braucht **weder API noch OIDC**, minimaler Betrieb.
   Das ist die BAUER-GROUP-„lean"-Antwort und sollte bewusst geprüft werden, bevor eine
   Plattform gebaut wird.
2. **Nicht-Devs pflegen Inhalte ODER echte API-Integration/Multi-Page nötig (die genannten
   Anforderungen) →** **Option D (Payload, API-first, Entra-OIDC)** bauen, mit **Shlink** für
   Analytik. Das ist der empfohlene Plattform-Weg.
3. **Strategisches Produkt (Mandantenfähigkeit, Marktplatz, eigenes IP) →** **Option E**.

**Empfohlener Pfad:** **Evolutionär** — mit **C** eine günstige, sofort nutzbare Basis schaffen und
auf **D** eskalieren, sobald API/Non-Dev-Pflege real gebraucht wird. Falls API + OIDC bereits
gesetzte, harte Anforderungen sind, direkt **D** starten (das Datenmodell aus C wird 1:1 zur
API-Ressource in D).

---

## 7. Referenzarchitektur (Build-Pfad D, greenfield-fähig)

```text
                 ┌───────────────────────────────────────────────┐
  Besucher ────► │  Traefik (Edge, TLS, Security-Header)          │
                 │   └─ forward-auth (optional): OIDC-Gate /admin │
                 └───────────┬───────────────────┬───────────────┘
                             │ öffentlich         │ /admin, /api
                 ┌───────────▼─────────┐ ┌────────▼─────────────────┐
                 │  Public Bio-Frontend │ │  API + Admin (Payload)   │
                 │  (Astro/Next SSR/SSG)│ │  REST+GraphQL, OpenAPI    │
                 │  Corporate-Branding  │ │  Auth: API-Key + OIDC     │
                 └───────────┬─────────┘ └───────┬──────────────────┘
                             │ liest                   │
                       ┌─────▼───────────────────────▼─────┐
                       │  PostgreSQL  (Profiles/Links/…)    │
                       └────────────────────────────────────┘
       Link-Klicks  ─────────────────►  Shlink (bestehend): Short-URLs + Analytics
       Admin-Login  ─────────────────►  Entra ID (OIDC)
```

### 7.1 Komponenten & Stack

| Baustein | Empfehlung (primär) | Alternative | Begründung |
| --- | --- | --- | --- |
| Backend/API + Admin | **Payload CMS** (TS, MIT) | NestJS/Hono (mehr Kontrolle) · **ASP.NET Core** (MS-nativ) | API+Admin+Auth „geschenkt"; TS = eine Sprache mit Frontend |
| Öffentliche Seite | **Astro** (oder Next.js) | – | SEO/Performance, statisch/SSR, gebrandet |
| DB | **PostgreSQL** | – | konsistent mit Shlink-Stack im URLShortener |
| Auth (Admin/User) | **OIDC → Entra ID** | Keycloak/Authentik | zentraler IdP (M365) |
| Auth (M2M/API) | **API-Keys** | OIDC Client-Credentials | Provisioning aus CI/Fremdsystem |
| Link-Redirect + Analytik | **Shlink (bestehend)** | eigenes Tracking | Wiederverwendung, spart Neubau |
| Theming | **BAUER GROUP Design-Tokens** | – | bereits extrahiert (CorporateIdentity) |
| Deployment/CI | Docker + Compose-Triplet, GHCR+DockerHub, semantic-release | – | **wie CS-URLShortener** |

### 7.2 Datenmodell (MVP)

- **Profile** (Handle, Name, Bio, Avatar, `themeId`, Reihenfolge, Sichtbarkeit)
- **Link** (`profileId`, Label, Ziel-URL **oder** Shlink-Shortcode, Icon, Position, aktiv, Zeitfenster)
- **Theme** (Tokens: Farben/Font/Radius — Default = BAUER GROUP)
- **Page** (statische Seiten: Impressum/Datenschutz, i18n)

### 7.3 API-Oberfläche (OpenAPI)

- `GET/POST/PATCH/DELETE /api/profiles`, `/links`, `/themes`, `/pages`
- Auth: `Authorization: Bearer <api-key>` (M2M) oder OIDC-Access-Token (User)
- **Provisioning-Use-Case:** `bio.yaml` in Git → CI ruft die API → deklaratives Ausrollen (IaaC).

### 7.4 Shlink-Synergie (strategischer Hebel)

Bio-Links werden als **Shlink-Short-URLs** angelegt (ihr betreibt Shlink bereits mit voller
REST-API und MCP-Tooling). Damit bekommt die Bio-Plattform **Klick-Analytik gratis** und muss
kein eigenes Tracking bauen; sie hält nur Reihenfolge/Label/Icon. → Weniger Code, mehr Insight.

---

## 8. OIDC / Entra-ID-Konzept

- **Admin-/API-User:** OIDC gegen Entra ID (Authorization-Code + PKCE). Rollen/Gruppen aus dem
  Token → Autorisierung (Admin/Editor/Viewer).
- **Öffentliche Bio-Seite:** unauthentifiziert.
- **Zusätzliches Härtungs-Gate (optional, sofort einsetzbar auch für LinkStack):** Traefik
  **forward-auth** (oauth2-proxy/Authelia/Authentik) vor `/admin` — OIDC am Edge, update-sicher.
- **M2M (CI/Provisioning):** API-Key oder OIDC Client-Credentials.

---

## 9. Roadmap & Aufwand (grob, iterativ)

| Phase | Inhalt | Aufwand |
| --- | --- | --- |
| **0 — Fundament** | Spec, ADRs, Design-Tokens übernehmen, OpenAPI-Entwurf, Repo `CS-Bio` nach URLShortener-Muster | ~1 Wo |
| **1 — MVP** | 1 Profil, Links-CRUD (API+Admin), öffentliche Marken-Seite, Entra-OIDC-Admin, Docker/CI, LinkStack-Import | ~2–3 Wo |
| **2 — Ausbau** | Multi-Profil/Pages, Shlink-Analytik, Themes, QR/vCard, i18n | ~3–5 Wo |
| **3 — Reife** | WCAG-Audit, Security-Härtung/Pentest, Doku, Last-/Backup-Tests | ~2 Wo |

> Aufwände sind Richtwerte für 1 fokussierte Entwickler:in; **Unsicherheit ± 50 %** je nach
> Stack-Vertrautheit und Scope. Bei Option **C** reduziert sich Phase 1 auf wenige Tage.

---

## 10. Risiken & Gegenmaßnahmen

| Risiko | Wirkung | Gegenmaßnahme |
| --- | --- | --- |
| **Eigenbetrieb/Wartung** (ihr besitzt den Code) | dauerhafte Kosten | MVP schlank halten; Standard-Libs; Option C als Fallback |
| **Security-Fläche** (Auth, XSS, Uploads) | hoch | OIDC-Library statt Eigenbau; CSP; OWASP-Review; Pentest in Phase 3 |
| **Scope-Creep** (Feature-Parität zu LinkStack) | Verzögerung | „Won't"-Liste, Shlink für Analytik, klare MVP-Grenze |
| **Reinvention** gelöster Probleme | Aufwand | Payload/Astro/Shlink wiederverwenden statt selbst bauen |
| **Falsche Grundannahme** (Plattform gar nicht nötig) | Fehlinvest | Nutzungsfrage (Kap. 6) VOR Baubeginn beantworten |

---

## 11. Migration von LinkStack

- **Inhalte:** LinkStack `Export links/all` (bzw. DB-Read) → Import-Skript in das neue Datenmodell.
- **Branding:** BAUER GROUP Design-Tokens sind bereits extrahiert (aus CorporateIdentity) und
  1:1 wiederverwendbar.
- **Cutover:** Parallelbetrieb, DNS erst nach Abnahme umstellen; CS-LinkStack bleibt bis dahin
  produktiv und ist per `linkstack-backup.py` gesichert.

---

## 12. Offene Entscheidungen

1. **Nutzungsmuster** (entscheidet C vs. D): Wer pflegt Inhalte, wie oft, eine oder viele Seiten?
2. **Stack** für Build-Pfad: **TypeScript/Payload** (empfohlen) vs. **.NET** (MS-nativ, beste
   Entra-Integration) vs. **NestJS/Hono** (max. Kontrolle).
3. **Analytik:** Klicks über **Shlink** (empfohlen) oder eigenes Tracking?
4. **Multi-Page** von Anfang an oder erst Phase 2?
5. **Ownership/Betrieb:** Wer wartet die Plattform langfristig?

---

## 13. Anhang — verifizierte LinkStack-Fakten (Quelle: Image-Code)

- `routes/api.php`: nur `Route::middleware('auth:api')->get('/user', …)` (Standard-Stub).
- `composer.json`: `laravel/socialite` vorhanden; **keine** `socialiteproviders/*` (kein OIDC/Entra/Keycloak/SAML).
- `config/services.php`: Provider `google`, `github`, `facebook`, `twitter`; `.env`: `ENABLE_SOCIAL_LOGIN=false`.
- `routes/web.php`: `/social-auth/{provider}` + `/callback` → `SocialLoginController` (reicht Provider an Socialite durch).
- Rate-Limits IP-basiert (`LoginRequest`, `RouteServiceProvider`) → daher `mod_remoteip` im Wrapper nötig.
- Datenhaltung SQLite/MySQL; Config/Content im `/htdocs`-Volume; keine API-Provisionierung.
- Lizenz: **AGPL-3.0** (relevant für Option B/Fork).

---

*Dieses Dokument ist ein Entscheidungs-Entwurf. Nächster Schritt: Nutzungsfrage (Kap. 12.1) und
Stack (12.2) klären; danach entweder Option C sofort umsetzen oder Repo `CS-Bio` (Option D) nach
CS-URLShortener-Muster aufsetzen.*

> **Update:** Die Anforderung ist geklärt — **saubere Unternehmensanwendung mit OIDC-SSO und
> API-first** zur automatisierten Datenpflege aus den Unternehmenssystemen (⇒ Option D). Das
> konkrete Stack- und Architektur-Design dazu steht im
> [ADR-0001: CS-Bio-Architektur](adr-0001-cs-bio-architektur.md) (empfohlener Stack: **Payload CMS**).
