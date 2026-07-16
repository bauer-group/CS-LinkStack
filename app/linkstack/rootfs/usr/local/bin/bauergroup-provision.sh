#!/bin/sh
# =============================================================================
# bauergroup-provision.sh — LinkStack wrapper entrypoint (BAUER GROUP)
# =============================================================================
# Runs as the upstream non-root user (apache:apache) on every container boot:
#
#   1. Mirror the image's bundled themes into the /htdocs volume.
#   2. Optionally MERGE managed config (reverse-proxy HTTPS, "no LinkStack
#      credit" brand policy, SMTP) into /htdocs/.env — preserving all other keys.
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

# ── 2. Config bootstrap — MERGE managed keys into /htdocs/.env ───────────────
# Applies a curated set of deployment/brand defaults to LinkStack's Laravel .env
# by editing ONLY the keys listed below, in place. Every other key (APP_KEY, the
# admin's settings, DB config, …) is preserved byte-for-byte — this is a merge,
# not a rewrite. Only runs when LINKSTACK_MANAGE_ENV=true and after the setup
# wizard has created /htdocs/.env (so it never races the installer). LinkStack
# does not cache config, so values take effect on the next request.

# _write_line KEY FORMATTED_VALUE — replace the key's line in place (preserving
# position), or append it. Uses awk so the value is never interpreted as a regex
# or sed replacement — safe for passwords with |, &, \ etc.
_write_line() {
  f="/htdocs/.env"; key="$1"; val="$2"
  [ -f "$f" ] || return 0
  if grep -qE "^${key}=" "$f" 2>/dev/null; then
    K="$key" V="$val" awk 'BEGIN{k=ENVIRON["K"];v=ENVIRON["V"]}
      $0 ~ "^" k "=" {print k "=" v; next} {print}' "$f" > "${f}.tmp" 2>/dev/null \
      && mv "${f}.tmp" "$f" 2>/dev/null || rm -f "${f}.tmp" 2>/dev/null
  else
    printf '%s=%s\n' "$key" "$val" >> "$f" 2>/dev/null || true
  fi
}
# Booleans / simple tokens — written UNQUOTED so Laravel casts them
# (env('X') === true). Quoting would turn true/false into truthy strings.
set_env_raw() { _write_line "$1" "$2"; }
# Arbitrary strings (mail host/user/password/from) — written QUOTED and escaped.
set_env_str() {
  v=$(printf '%s' "$2" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  _write_line "$1" "\"${v}\""
}
set_env_str_if_set() { [ -n "${2:-}" ] && set_env_str "$1" "$2"; }

bootstrap_config() {
  [ "${LINKSTACK_MANAGE_ENV:-false}" = "true" ] || return 0
  if [ ! -f /htdocs/.env ]; then
    log "LINKSTACK_MANAGE_ENV=true but /htdocs/.env not present yet (pre-wizard); skipping"
    return 0
  fi
  log "bootstrapping managed keys into /htdocs/.env (merge — all other keys preserved)"

  # ── Reverse proxy ──
  [ "${LINKSTACK_FORCE_HTTPS:-}" = "true" ] && set_env_raw FORCE_HTTPS true

  # ── Branding policy: hide the "Powered by LinkStack" credit on all pages ──
  # Enforced from LINKSTACK_DISPLAY_CREDIT (default false). Set it to true to
  # keep the LinkStack credit.
  set_env_raw DISPLAY_CREDIT        "${LINKSTACK_DISPLAY_CREDIT:-false}"
  set_env_raw DISPLAY_CREDIT_FOOTER "${LINKSTACK_DISPLAY_CREDIT:-false}"

  # ── SMTP / mail: injected only when a host is provided (merge) ──
  if [ -n "${LINKSTACK_SMTP_HOST:-}" ]; then
    set_env_str    MAIL_MAILER       "${LINKSTACK_SMTP_MAILER:-smtp}"
    set_env_str    MAIL_HOST         "${LINKSTACK_SMTP_HOST}"
    set_env_str_if_set MAIL_PORT         "${LINKSTACK_SMTP_PORT:-}"
    set_env_str_if_set MAIL_USERNAME     "${LINKSTACK_SMTP_USERNAME:-}"
    set_env_str_if_set MAIL_PASSWORD     "${LINKSTACK_SMTP_PASSWORD:-}"
    set_env_str_if_set MAIL_ENCRYPTION   "${LINKSTACK_SMTP_ENCRYPTION:-}"
    set_env_str_if_set MAIL_FROM_ADDRESS "${LINKSTACK_SMTP_FROM_ADDRESS:-}"
    set_env_str_if_set MAIL_FROM_NAME    "${LINKSTACK_SMTP_FROM_NAME:-}"
    log "  applied SMTP config (host ${LINKSTACK_SMTP_HOST})"
  fi

  # ── External DB: injected only when explicitly enabled (SQLite by default) ──
  if [ "${LINKSTACK_DB_BRIDGE:-false}" = "true" ]; then
    set_env_str    DB_CONNECTION "${DB_CONNECTION:-mysql}"
    set_env_str_if_set DB_HOST     "${DB_HOST:-}"
    set_env_str_if_set DB_PORT     "${DB_PORT:-}"
    set_env_str_if_set DB_DATABASE "${DB_DATABASE:-}"
    set_env_str_if_set DB_USERNAME "${DB_USERNAME:-}"
    set_env_str_if_set DB_PASSWORD "${DB_PASSWORD:-}"
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
bootstrap_config
handoff "$@"
