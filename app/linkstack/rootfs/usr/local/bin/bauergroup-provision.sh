#!/bin/sh
# =============================================================================
# bauergroup-provision.sh — LinkStack wrapper entrypoint (BAUER GROUP)
# =============================================================================
# Runs as the upstream non-root user (apache:apache) on every container boot:
#
#   1. Mirror the image's bundled themes into the /htdocs volume.
#   2. Optionally bridge reverse-proxy (HTTPS) settings into /htdocs/.env.
#   3. Hand off to the upstream boot process (docker-entrypoint.sh → Apache).
#
# WHY step 1 exists: the bundled themes are baked into the IMAGE at build time,
# but at /opt/linkstack/themes/ — NOT at /htdocs/themes/, where LinkStack reads
# them. /htdocs is a persistent named volume and Docker only seeds a volume from
# the image when it is FIRST created; on an existing volume, later image updates
# to the bundled themes would be shadowed. So we simply copy the bundled themes
# into the volume on every boot: image-managed themes are refreshed, user-
# uploaded themes are left untouched. No marker, no toggle — deterministic.
#
# The wrapper is resilient: a theme-sync problem must never stop the app from
# booting, so it always reaches the handoff.
# =============================================================================

set -u

STAGE="/opt/linkstack/themes"
DEST="/htdocs/themes"
APP_USER="apache"
APP_GROUP="apache"

log() { printf '[bauergroup-provision] %s\n' "$*"; }

# ── 1. Theme sync (always: refresh bundled themes, preserve user uploads) ─────
sync_themes() {
  if [ ! -d "$STAGE" ] || [ ! -f "${STAGE}/.bundled" ]; then
    log "no staged themes found; skipping theme sync"
    return 0
  fi
  if ! mkdir -p "$DEST" 2>/dev/null; then
    log "WARNING: cannot write ${DEST}; skipping theme sync"
    return 0
  fi

  count=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ -d "${STAGE}/${name}" ] || continue
    rm -rf "${DEST}/${name}" 2>/dev/null || true
    # cp -r (not -a) so copied files are owned by the running user (apache).
    if cp -r "${STAGE}/${name}" "${DEST}/${name}" 2>/dev/null; then
      count=$((count + 1))
      # Best-effort ownership fix (no-op as apache; effective if run as root).
      chown -R "${APP_USER}:${APP_GROUP}" "${DEST}/${name}" 2>/dev/null || true
    else
      log "WARNING: failed to sync theme '${name}'"
    fi
  done < "${STAGE}/.bundled"

  log "refreshed ${count} bundled themes into ${DEST} (user uploads preserved)"
}

# ── 2. Optional Laravel .env bridge (opt-in, idempotent) ─────────────────────
# Only acts if /htdocs/.env already exists (i.e. AFTER LinkStack's setup wizard
# created it) so it never races the first-run installer.
set_env_kv() {  # $1=key $2=value  (edits /htdocs/.env in place)
  f="/htdocs/.env"; key="$1"; val="$2"
  [ -f "$f" ] || return 0
  if grep -qE "^${key}=" "$f" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$f" 2>/dev/null || true
  else
    printf '\n%s=%s\n' "$key" "$val" >> "$f" 2>/dev/null || true
  fi
}

manage_env() {
  [ "${LINKSTACK_MANAGE_ENV:-false}" = "true" ] || return 0
  if [ ! -f /htdocs/.env ]; then
    log "LINKSTACK_MANAGE_ENV=true but /htdocs/.env not present yet (pre-wizard); skipping"
    return 0
  fi
  log "bridging managed keys into /htdocs/.env"
  [ "${LINKSTACK_FORCE_HTTPS:-}" = "true" ] && set_env_kv FORCE_HTTPS true
  # DB bridge — off by default; only relevant when using external MySQL/MariaDB.
  if [ "${LINKSTACK_DB_BRIDGE:-false}" = "true" ]; then
    set_env_kv DB_CONNECTION "${DB_CONNECTION:-mysql}"
    set_env_kv DB_HOST       "${DB_HOST:-}"
    set_env_kv DB_PORT       "${DB_PORT:-3306}"
    set_env_kv DB_DATABASE   "${DB_DATABASE:-}"
    set_env_kv DB_USERNAME   "${DB_USERNAME:-}"
    set_env_kv DB_PASSWORD   "${DB_PASSWORD:-}"
  fi
}

# ── 3. Hand off to the upstream boot process ─────────────────────────────────
handoff() {
  # Priority 1: forward the inherited CMD (upstream ["docker-entrypoint.sh"]).
  if [ "$#" -gt 0 ]; then
    log "exec upstream CMD: $*"
    exec "$@"
  fi
  # Priority 2: known upstream entrypoint path.
  for cand in /usr/local/bin/docker-entrypoint.sh /usr/local/bin/entrypoint.sh /entrypoint.sh /init; do
    if [ -x "$cand" ]; then
      log "exec discovered entrypoint: $cand"
      exec "$cand"
    fi
  done
  # Priority 3: last resort — start Apache in the foreground.
  log "WARNING: no upstream entrypoint found; starting Apache directly"
  exec httpd -D FOREGROUND
}

sync_themes
manage_env
handoff "$@"
