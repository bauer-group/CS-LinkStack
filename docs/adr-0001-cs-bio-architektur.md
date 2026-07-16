# ADR-0001: CS-Bio — API-first, OIDC-gesicherte Unternehmens-Bio-Plattform

> **Status:** Vorschlag (Entscheidung ausstehend) · **Datum:** 2026-07-16 · **Kontext:** BAUER GROUP
>
> **Bezug:** Konkretisiert Option D aus der [Strategie](strategie-eigene-bio-plattform.md).
> **Scope-Hinweis:** CS-Bio wird ein **eigenes neues Repo** (`bauer-group/CS-Bio`) nach dem
> CS-URLShortener-Muster. Dieses ADR ist der Entscheidungs-Record und liegt vorerst hier im
> CS-LinkStack-Repo, bis das neue Repo angelegt ist.
> **Methodik:** erarbeitet über eine Multi-Agent-Analyse — 3 unabhängige Stack-Bewertungen →
> Synthese → 4 parallele Detailentwürfe → adversariale Prüfung → Konsolidierung. Die P0/P1-
> Sicherheitsbefunde der Prüfung sind in den Entscheidungen unten **eingearbeitet**, nicht angehängt.

---

## Kontext & Zielbild

CS-Bio ist eine self-hosted, unternehmenstaugliche "link in bio"-Plattform für die BAUER GROUP und löst das bestehende LinkStack ab. Zwei harte Treiber bestimmen die Architektur:

1. **OIDC-SSO** für Admin/Editor-Zugriff über den Firmen-IdP (Microsoft Entra ID / M365).
2. **API-first**: eine dokumentierte, OpenAPI-beschriebene REST-API, deren **Hauptzweck** die maschinelle, idempotente und unbeaufsichtigte Pflege der Bio-Daten durch andere Unternehmenssysteme ist (M2M). Die API ist das Produkt; die Admin-UI ist der Ausnahmepfad.

Nicht-funktional gelten die CS-URLShortener-Konventionen: Docker + IaaC (Compose-Triplet traefik/coolify/development), Traefik-Reverse-Proxy, PostgreSQL, GHCR + Docker Hub, semantic-release, Backups, echte Client-IP hinter Proxy, OWASP, keine Secrets im Repo, WCAG 2.1 AA. Bestehende Investitionen werden wiederverwendet: **Shlink** übernimmt Short-URLs und Click-Analytics; ein **LinkStack**-Bestand wird migriert. Öffentliche Profilseiten sind schnell, SEO-fähig und tragen die vorhandenen Marken-Tokens (Primär `#FF8500`, warme Grautöne, `system-ui`, Light/Dark, AA-Linktext `#C2570A`).

## Entscheidung (Stack + Kernprinzipien)

**Gewählt: Payload CMS (TypeScript/Next.js, MIT).** Alle drei unabhängigen Architektur-Evaluationen empfehlen A; aggregiert führt es (Ø 46,8 vs. C 44,8 vs. B 43,8) — nicht auf einer Einzelachse, sondern in der Kombination, die für ein kleines Team zählt, das dies langfristig **ownen** muss.

**Warum A.** Der Haupttreiber ist API-first M2M-Pflege — genau dort liefert Payload ~80 % ohne Eigenbau: `profiles`/`links`/`themes` als Collections erzeugen automatisch eine REST-(+GraphQL-)API mit Validierung und Access Control; native per-User-API-Keys bedienen den unbeaufsichtigten M2M-Zugriff idiomatisch. Übrig bleibt eine dünne Custom-Schicht (idempotenter Upsert + hand-authored OpenAPI-Fragmente). Gratis dazu: vollständige Admin-UI inklusive RBAC — die größte Ersparnis. Alles bleibt im hauseigenen TypeScript/Next-Stack (Public Page = Next-Route, Shlink-Delegation = TS-Hook), Single-Container + Postgres fügt sich in die CS-URLShortener-Konventionen. MIT statt LinkStacks AGPL beseitigt die Offenlegungslast.

**Bewusst akzeptierte Schwäche.** Entra-OIDC ist bei Payload nicht first-party. Mitigation: der reife Auth.js-`microsoft-entra-id`-Provider via `payload-authjs` deckt den Login ab (Entra ist standardkonformes OIDC), optional plus Traefik forward-auth vor `/admin`. Verbleibt nur das Mapping Entra-App-Roles → Payload-Access-Control.

**Runner-up: C (.NET, Microsoft.Identity.Web)** ist die stärkste Entra-Story und wäre richtig, **nur** wenn (a) echte C#/.NET-Kompetenz besteht oder (b) first-party Entra als nicht verhandelbare Audit-Anforderung gilt. Sonst überwiegt der dauerhafte Nachteil: eine zweite Sprache/Runtime im JS/TS-+-PHP-Team = größtes Bus-Factor-Risiko, bei sekundärem SSO-Treiber und weiterhin selbst zu bauender Admin-UI. B (NestJS+Astro) liefert die reinste decorator-generierte OpenAPI, verletzt aber Lean/YAGNI.

**Kernprinzipien:** idempotent, upsert-by-`externalId`, Payload-native, YAGNI. Trennung von **Read-Model** (öffentlich, projiziert) und **Write-Model** (authentifiziert, voll).

## Architektur (Diagramm + Komponenten)

```
                        Entra ID (OIDC, App-Roles)
                               │  Auth-Code + PKCE
                               ▼
  Unternehmens-      ┌──────────────────────────────────────┐
  systeme (M2M)      │            Traefik (TLS, HSTS)        │
  HRIS / Entra ─┐    │  X-Forwarded-*  · optional fwd-auth   │
  Intranet ─────┤    └───────┬───────────────────┬──────────┘
                │            │ /bio/*, /api/*     │ /admin
   API-Key      ▼            ▼                    ▼
  ┌─────────────────────────────────────────────────────────┐
  │                 CS-Bio  (Next.js + Payload)              │
  │  ┌───────────┐  ┌────────────┐  ┌───────────────────┐    │
  │  │ Public    │  │ Payload    │  │ Custom Layer:     │    │
  │  │ /bio/{h}  │  │ REST/GQL   │  │ /api/v1/sync/*    │    │
  │  │ (Read-M.) │  │ +AdminUI   │  │ OpenAPI-Merge     │    │
  │  └───────────┘  └─────┬──────┘  └─────────┬─────────┘    │
  │        Access Control · Hooks (afterChange, async)       │
  └───────┬───────────────────────────────────┬─────────────┘
          │                                    │ afterChange (async, retry)
          ▼                                    ▼
     PostgreSQL 17                        Shlink REST (Short-URLs + Visits)
   (profiles, links, themes,
    syncRuns, idempotencyKeys)
```

**Komponenten:** Public-Route (SSR/SSG, cache-fähig, JSON-LD), Payload-Core (Collections, Auth, RBAC, Admin-UI), dünne Custom-Sync-Endpoints, Postgres, Shlink (extern, wiederverwendet). Kein Queue-, kein Scheduler-Eigenbetrieb.

## Domänenmodell & REST-API (OpenAPI-Auszug)

Bio-Daten sind Payload-**Collections**; wir schreiben Schemas, keine Controller.

| Collection | Zweck | Kernrelationen |
|---|---|---|
| `users` | Admin/Editor + Service-Identitäten | `role`, `allowedScopes[]` |
| `profiles` | Bio-Subjekt (Aggregate Root) | `owners→users`, `theme→themes`, `externalId`, `handle`, `source` |
| `links` | Aktionselement | `profile→profiles`, `externalId`, `shlinkShortCode`, `shlinkStatus` |
| `themes` | Marken-Presets (Tokens, kein freies CSS) | shared |
| `syncRuns` | Audit-Log der Sync-Läufe | immutable |
| `idempotencyKeys` | Dedupe-Store (Key + Response-Hash + TTL) | — |

`organizations`/`pages` bleiben **latent** (YAGNI — nur bei realem Multi-Tenant/Multi-Page-Bedarf).

**Identität & Idempotenz (vereinheitlicht).** `externalId` ist die **unveränderliche** natürliche Identität, auf die M2M-Aufrufer keyen — sie kollidiert nicht mit Umbenennungen. `handle` (Slug, unique, regex-validiert) ist **mutierbar** und rein für die öffentliche URL. Damit ist der frühere Widerspruch (Section 1 keyte auf `handle`, Section 3 auf `externalId`) aufgelöst: **ein** dokumentierter Sync-Kontrakt, immer auf `externalId`.

**Read- vs. Write-Model (Sicherheitskritisch).** Die native Collection-REST (`/api/v1/{collection}`) ist **ausschließlich authentifiziert**. Öffentlich ausgeliefert wird **nur** die dedizierte Projektion `GET /api/v1/bio/{handle}` (bzw. die Next-Route `/bio/{handle}`): profile + sichtbare Links + aufgelöste Theme-Tokens, Short-URLs bereits delegiert — keine internen IDs, keine Drafts, keine Audit-Felder.

**Versionierung (vereinheitlicht).** **Alles** unter `/api/v1`, inklusive der Sync-Endpoints; Payloads native Routen werden per `routes.api = '/api/v1'` tatsächlich unter das Präfix geroutet. Breaking → `/api/v2`, additiv bleibt in `v1`. Pagination `?limit=&page=`, Filter via Payload-Query.

**OpenAPI.** `payload-oapi` emittiert die auto-generierten Collection-Routen. Die **hand-gerollten `/sync/*`-Endpoints — das eigentliche Produkt — würden dort fehlen**, deshalb hand-authored OpenAPI-3.1-Fragmente, die in das Dokument unter `/api/openapi.json` gemerged und per Contract-Test (Doc vs. echte Response-Schemas) abgesichert werden. Swagger UI unter `/api/docs`.

```yaml
# GET /api/v1/bio/{handle} — public read model (projiziert)
PublicProfile:
  type: object
  required: [handle, displayName, links, theme]
  properties:
    handle:      { type: string, example: "max-bauer" }
    displayName: { type: string, example: "Max Bauer" }
    headline:    { type: string, nullable: true }
    avatarUrl:   { type: string, format: uri, nullable: true }
    theme:
      properties:
        primary:  { type: string, example: "#FF8500" }
        linkText: { type: string, example: "#C2570A" }  # WCAG-AA
        mode:     { type: string, enum: [light, dark, system] }
    links:
      type: array
      items:
        required: [label, url]
        properties:
          label: { type: string, example: "Company Website" }
          url:   { type: string, format: uri }   # Shlink-Short-URL falls delegiert
          icon:  { type: string, nullable: true }
```

Validierung lebt in den Feld-Definitionen (`required`, `unique`, `handle`-Regex, `format: uri`) und gilt uniform für Admin-UI, REST und Sync — eine Quelle der Wahrheit.

## AuthN/AuthZ (OIDC/Entra + M2M/RBAC)

Zwei bewusst getrennte Trust-Planes; Public-Reads sind unauthentifiziert.

| Plane | Wer | Mechanismus | Zugriffsmodell |
|---|---|---|---|
| Users | Admin/Editor/Viewer | OIDC Auth-Code + PKCE (Entra) → Payload-Session-Cookie | RBAC aus Entra-App-Roles |
| Systeme (M2M) | HRIS, Entra-Feeder, Intranet | Payload-API-Key (Service-User) | Rolle + `allowedScopes` + Collection-Access |
| Public | Alle | keiner | nur `_status: published`, projiziert |

**User-Auth.** `payload-authjs` mit `MicrosoftEntraID`, Auth-Code **mit PKCE**, kein Implicit. Eine **confidential** App-Registration (Web), Redirect `…/api/auth/callback/microsoft-entra-id`. Entra **App-Roles** (`CSBio.Admin/Editor/Viewer`) kommen als `roles`-Claim im ID-Token — robuster als Gruppen-GUIDs.

**Rollen-Staleness-Fix.** Das Mapping `roles`-Claim → Payload-`user.role` läuft **bei jedem `signIn`/`jwt`-Callback neu**, nicht nur bei Erstprovisionierung — so veralten entzogene Rollen nicht zwischen Logins. Benutzer ohne CS-Bio-App-Role werden am `signIn` abgewiesen (kein stiller Viewer-Fallback). Keine lokalen Passwörter für Staff.

**Break-glass (First-Admin).** Da rollen-gated `signIn` Selbst-Provisionierung des allerersten Admins blockiert, gibt es einen dokumentierten Bootstrap: ein `PAYLOAD_BOOTSTRAP_ADMIN_EMAIL`-Env, das beim ersten Start genau diese Adresse als `admin` seedet (per Migration/Seed-Script), danach deaktiviert. Alternativ ein einmaliger CLI-`payload`-Seed.

```ts
// collections/Profiles.ts — access (Fix: Constraint statt true)
const isStaff = ({ req }) => ['admin','editor'].includes(req.user?.role);
export const access = {
  // native REST nur authentifiziert; anon erhält Constraint, nie "alles"
  read: ({ req }) => req.user
    ? true
    : { _status: { equals: 'published' } },
  create: isStaff,
  update: ({ req }) => req.user?.role === 'admin'
    ? true
    : { owners: { contains: req.user?.id } },
  delete: ({ req }) => req.user?.role === 'admin',
};
```

Interne Felder (`owners`, `source`, Audit) erhalten **feld-level** `access.read` (nur Staff). Der öffentliche Pfad nutzt ausschließlich die Projektion — die native Collection-REST ist nie anonym erreichbar.

**M2M — API-Keys, nicht client-credentials.** Feeder sind intern und wenige; client-credentials hieße Entra-App-Registrations + eigene JWT/Scope-Validierung (YAGNI). Payloads `enableAPIKey` gibt jedem Feeder einen eigenen **Service-User**, sodass dieselben Access-Funktionen greifen.

**Rotation (korrigiert).** Payloads `enableAPIKey` ist **ein Key pro User** — ein "zweiter Overlap-Key am selben User" ist technisch nicht möglich. Overlap wird daher über **zwei Service-User** modelliert (`svc-hr-a`/`svc-hr-b`, gleiche `allowedScopes`): neuen aktivieren, in den Secret-Store des Aufrufers rollen, alten deaktivieren → Zero-Downtime. (Alternative bei vielen Feedern: eine eigene `apiKeys`-Collection mit **gehashten** Keys und n-Keys-pro-Service.) Keys AES-verschlüsselt at rest via `PAYLOAD_SECRET`, Plaintext einmalig bei Erstellung, Rotation quartalsweise, nie im Repo.

## Daten-Synchronisation aus Unternehmenssystemen (Kernanforderung)

Design-Bias: idempotent, upsert-by-`externalId`, Payload-native, YAGNI.

**Ownership pro Record (kein Field-Merge).** Jede Collection trägt `externalId` (unique, indiziert), `source` (`hris|entra|manual`) und `locked` (bool). `source != manual` = voll vom Sync besessen, bei jedem Upsert überschrieben; `source == manual` = Editor-besessen, Sync **skippt** (außer `?force=true`); `locked` = nie angefasst. Human-Takeover = `source` auf `manual` flippen. Kein CRDT.

**Endpoints (unter `/api/v1`, vereinheitlicht):**

```
PUT   /api/v1/sync/profiles/{externalId}      # einzelner idempotenter Upsert
POST  /api/v1/sync/bulk                        # Bulk-Upsert + Reconcile, transaktional je Profil
POST  /api/v1/sync/bulk?dryRun=true            # nur validieren, keine Writes
```

Auth: Service-User-API-Key, dessen Access auf `source != manual` beschränkt.

**Scope-Autorisierung (Cross-Tenant-Fix).** `scope` wird **nicht** dem Body vertraut. Jeder Service-User trägt eine `allowedScopes`-Allowlist; die Access-Schicht **weist jeden Payload-Scope außerhalb der Allowlist ab** (403). So kann `svc-hr` (`hris:department:sales`) keine Records fremder Scopes soft-deleten.

**Full vs. Delta + Reconciliation (Soft-Delete).** `mode: delta` (default, unbeaufsichtigt): nur gelieferte Records upserten, nichts löschen. `mode: full`: der Aufrufer behauptet den vollständigen Satz für seinen (autorisierten) `scope`; jeder gemanagte Record, dessen `externalId` **fehlt**, wird **soft-deleted** (`status: archived`, `deletedAt`) — nie hard-deleted, damit ein fehlerhafter Export keine Live-Seiten löscht.

**Idempotenz (Mechanismus-Fix).** `Idempotency-Key`-Header auf **jedem mutierenden Endpoint**. Persistenz in Postgres-Tabelle `idempotencyKeys` (Key + Request-Hash + Response-Hash + `expiresAt`, TTL 24 h): identischer Key → gespeicherte Response zurückspielen; gleicher Key mit abweichendem Body → `409`.

```json
POST /api/v1/sync/bulk?dryRun=false
{ "mode":"full", "scope":"hris:department:sales",
  "profiles":[{ "externalId":"emp-4711", "handle":"jane.doe",
    "displayName":"Jane Doe", "title":"Head of Sales", "status":"published",
    "links":[
      {"externalId":"emp-4711-li","label":"LinkedIn","url":"https://linkedin.com/in/janedoe","order":1,"shorten":false},
      {"externalId":"emp-4711-book","label":"Book a meeting","url":"https://outlook.office.com/bookwithme/janedoe","order":2,"shorten":true}
    ]}]}
```

```json
HTTP 200
{ "syncId":"01J8...ULID", "dryRun":false,
  "results":[{ "externalId":"emp-4711","op":"updated","links":[
     {"externalId":"emp-4711-li","op":"unchanged"},
     {"externalId":"emp-4711-book","op":"created","shortUrl":"https://l.bauer.to/x7Qz"}]}],
  "reconciled":{ "archived":["emp-3092"], "skipped_manual":["emp-5001"] },
  "summary":{ "created":0,"updated":1,"unchanged":0,"archived":1,"skipped":1,"errors":0 } }
```

`unchanged` wird aus einem Content-Hash berechnet — häufiges Pollen erzeugt kein Rauschen.

**Fehler/Partial-Failure.** `dryRun=true` läuft denselben Validierungspfad, gibt `op`-Prognosen ohne Writes. Fehler sind **strukturiert, pro-Item, RFC 9457 (Problem Details)**; ein schlechter Record kippt nicht den Batch (`207`-Semantik über `errors`).

**Audit/Rate-Limits.** `syncRuns` (immutable) speichert `syncId`, Actor, mode, scope, counts, per-Item-Diff — Admin-UI-abfragbar. Rate-Limit per Key (z. B. 60 req/min, Bulk ≤ 500 Profile/Call), `429` mit `Retry-After`.

**Push vs. Pull.** Beide, push-first: Quellsysteme POSTen `delta` bei Änderung (near-real-time). Ein nächtlicher `full`-Reconcile je Scope (Cron des Quellsystems ruft `/sync/bulk`) ist das Sicherheitsnetz für verpasste Events und Soft-Deletes. CS-Bio bleibt reiner Empfänger — kein eigener Scheduler, keine Queue.

## Deployment/IaaC + Shlink-Integration + LinkStack-Migration

**Image.** Multi-Stage-Dockerfile (`node:22-alpine`, pnpm, Next standalone), non-root, `HEALTHCHECK` auf `/api/health`, ein Image nach GHCR **und** Docker Hub, semantic-release-getaggt. `TRUST_PROXY=1` hinter Traefik — echte Client-IP aus `X-Forwarded-For` für Rate-Limit/Audit.

**Compose-Triplet** (CS-URLShortener-Layout): `compose.yaml` (Base: `cs-bio` + `postgres:17-alpine`, Volume `pgdata`, Healthchecks) · `compose.traefik.yaml` (Router, TLS `certresolver: le`, Security-Header-Middleware: HSTS, nosniff, referrer-policy, Permissions-Policy) · `compose.coolify.yaml` (`SERVICE_FQDN_*`) · `compose.development.yaml` (exponierte Ports, mailpit, kein TLS). CSP in `next.config`: strikt `default-src 'self'` für Public, `'unsafe-inline'` nur für das Admin-Bundle.

**Config (12-factor, Env-only):** `DATABASE_URI`, `PAYLOAD_SECRET`, `PUBLIC_SERVER_URL`, `ENTRA_CLIENT_ID/SECRET/TENANT_ID`, `SHLINK_BASE_URL/API_KEY`, `TRUST_PROXY`, `PAYLOAD_BOOTSTRAP_ADMIN_EMAIL`. `.env.example` committed, echte Werte in Coolify/GitHub-Secrets.

**CI/CD.** Reusable Workflow aus `bauer-group/automation-templates@main`, `secrets: inherit`, explizite `permissions: {contents: write, packages: write, id-token: write}`, `timeout-minutes` je Job, buildx multi-arch (`amd64,arm64`). Migrationen via `payload migrate` als Init-Step — **committen, nie Auto-Migrate in Prod**.

**Backups.** Nächtlicher `pg_dump -Fc` nach Object-Storage, 30 Tage Retention; `uploads`-Volume im selben Job; Restore in `docs/runbook.md`.

**Shlink (Stabilitäts-Fix).** Kürzen läuft **asynchron im `afterChange`-Hook mit Retry + `shlinkStatus`-Feld** (`pending|active|failed`) — ein Shlink-Ausfall blockiert/kippt **keinen** Write mehr (früher synchrones `beforeChange` = Hazard). `findIfExists: true` für Idempotenz. **Tag-Schema vereinheitlicht** auf `["cs-bio", "profile:{handle}", "link:{externalId}"]` (früher divergierten `bio:…` / `profile:…` / `cs-bio`). **Delete-Fix:** `afterDelete` löscht einen Slug **nur, wenn er ausschließlich diesem Link gehört** (Ownership-Check gegen `link:{externalId}`-Tag) — ein via `findIfExists` geteilter Slug wird nicht mitgerissen. Analytics werden **gepullt** (`GET …/visits`), nichts nachgebaut.

**LinkStack-Migration (Realismus-Fix).** LinkStack ist Laravel/MySQL (littlelink) — es gibt **kein** Standard-`linkstack-export.json`. Das Migrationsskript liest daher die **MySQL-Schema direkt** (`users`, `links`, `buttons`, `pages`) und mappt explizit: `users`→`profiles`, `links(url,title,order,up)`→`links`, Button-Icons→`links.icon`, Theme/Custom-CSS→`themes` (Marken-Tokens). **Theme-Fidelity-Verlust wird ausgewiesen:** freies Custom-CSS aus LinkStack wird **nicht** 1:1 übernommen, sondern auf die BAUER-GROUP-Tokens gemappt (Primär `#FF8500`, warme Grautöne, `system-ui`, AA-Linktext `#C2570A`, Light+Dark) — migrierte Profile landen on-brand statt LinkStack-gestylt; abweichende Individualstile gehen bewusst verloren. Geschrieben über Payloads Local API (Validierung + Access greifen), upsert-by-`externalId`, re-runnbar.

## Sicherheit (OWASP, Secrets, Isolation)

- **Zugriffskontrolle:** anon `read` gibt **Constraint** (`_status: published`), nie `true`; interne Felder feld-level geschützt; native Collection-REST authentifiziert; Public nur über Projektion. M2M-`scope` per `allowedScopes`-Allowlist autorisiert (kein Body-Trust).
- **Secrets** nur in Deploy-Env/Secret-Store, nie im Image/Repo; `.env.example` mit Platzhaltern. API-Keys AES-at-rest.
- **Transport:** TLS + HSTS an Traefik; Session-Cookies `httpOnly`, `secure`, `sameSite=lax`; Auth.js verifiziert Entra-Signatur (JWKS), Issuer/Audience.
- **Input:** uniforme Feld-Validierung; RFC-9457-Fehler; Rate-Limits + `Idempotency-Key` gegen Replay/Flood; keine Secrets/PII in Logs.
- **Isolation:** non-root Container, Least-Privilege-Service-User, optional Traefik forward-auth vor `/admin` als Defence-in-Depth.

## Roadmap/Phasen mit groben Aufwänden

| Phase | Inhalt | Aufwand |
|---|---|---|
| P0 Bootstrap | Repo, Compose-Triplet, CI, Payload-Grundgerüst, Postgres, Health | ~3–4 PT |
| P1 Domäne + Public | Collections, `/bio/{handle}`-Projektion, Read-Model-Access, Branding/WCAG | ~4–5 PT |
| P2 Auth | Entra OIDC via `payload-authjs`, App-Role-Mapping (per-login), RBAC, Break-glass | ~3–4 PT |
| P3 M2M-Sync (Kern) | `/api/v1/sync/*`, Idempotenz-Store, Scope-Allowlist, Reconcile/Soft-Delete, Audit, hand-authored OpenAPI + Contract-Test | ~6–8 PT |
| P4 Shlink | async Hook + Status/Retry, Tag-Schema, Visits-Pull, Ownership-safe Delete | ~2–3 PT |
| P5 Migration | MySQL-Reader, Mapping, Theme-Token-Mapping, Dry-Run | ~2–3 PT |
| P6 Härtung | Rate-Limits, forward-auth, Backups, Runbook, Pen-Check | ~2–3 PT |

Summe grob **22–30 PT**. P3 ist der wertkritische Pfad.

## Risiken & Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| Entra nicht first-party | `payload-authjs` (Standard-OIDC) + optional forward-auth; Mapping-Layer isoliert |
| Sync-Endpoints fehlen in OpenAPI | hand-authored Fragmente + Contract-Test im CI |
| Fehlerhafter `full`-Export löscht Seiten | nur Soft-Delete, scope-begrenzt, `dryRun`, Audit-Restore |
| Cross-Tenant-Archive | `allowedScopes`-Allowlist server-seitig erzwungen |
| Shlink-Ausfall blockiert Writes | async Hook, Retry, `shlinkStatus` |
| Public-Leak (Drafts/interne Felder) | Constraint-`read` + feld-level Access + reine Projektion |
| Rollen-Staleness | Re-Map bei jedem `signIn`/`jwt` |
| Key-Rotation-Fehlannahme | zwei Service-User bzw. gehashte Key-Collection |

## Offene Entscheidungen

1. **Key-Modell:** zwei Service-User (einfach) vs. eigene gehashte `apiKeys`-Collection (n-Keys, mehr Code) — abhängig von der Feeder-Zahl.
2. **forward-auth vor `/admin`:** aktivieren (Defence-in-Depth, doppelter Login) oder App-seitige Entra-Prüfung genügt?
3. **Multi-Tenant (`organizations`/`pages`):** latent lassen oder ist Kampagnen-Gruppierung ein realer Nahbedarf?
4. **Visits-Caching-Intervall** für Shlink-Analytics (scheduled vs. on-demand).
5. **Migrations-Cutover:** Big-Bang vs. Parallelbetrieb LinkStack↔CS-Bio mit read-only-Freeze.