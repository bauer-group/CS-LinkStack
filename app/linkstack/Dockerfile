# =============================================================================
# LinkStack — Application Image (BAUER GROUP Build)
# =============================================================================
# Wraps the official linkstackorg/linkstack image (Alpine + Apache2 + PHP 8.3,
# web root /htdocs) with:
#
#   • Curated stock themes + the BAUER GROUP corporate theme, staged OUTSIDE
#     the /htdocs data volume and mirrored INTO it on every boot ("bake-and-sync").
#     Baking straight into /htdocs would be shadowed by the mounted named volume
#     on every boot after the first, so image theme updates would never appear.
#
#   • A wrapper entrypoint (bauergroup-provision.sh) that syncs the bundled themes,
#     optionally bridges reverse-proxy settings into /htdocs/.env, then hands off
#     to the upstream boot process (docker-entrypoint.sh → Apache).
#
# The upstream image runs as the non-root user apache:apache, so the sync uses
# `cp` (copies become apache-owned automatically) — no privileged chown needed.
#
# Build:
#   docker build -t linkstack:local ./app/linkstack
# =============================================================================

# Pin the upstream release for reproducibility. base-images.json tracks the
# digest of this tag and forces a rebuild when it moves.
ARG LINKSTACK_VERSION=latest
FROM linkstackorg/linkstack:${LINKSTACK_VERSION}

# Re-declare ARGs after FROM so they are usable in LABELs.
ARG LINKSTACK_VERSION

# =============================================================================
# Custom Labels
# =============================================================================

# Metadata
LABEL vendor="BAUER GROUP"
LABEL maintainer="Karl Bauer <karl.bauer@bauer-group.com>"

# OpenContainers Metadata
LABEL org.opencontainers.image.title="LinkStack"
LABEL org.opencontainers.image.vendor="BAUER GROUP"
LABEL org.opencontainers.image.authors="Karl Bauer <karl.bauer@bauer-group.com>"
LABEL org.opencontainers.image.source="https://github.com/bauer-group/CS-LinkStack"
LABEL org.opencontainers.image.url="https://github.com/bauer-group/CS-LinkStack"
LABEL org.opencontainers.image.documentation="https://github.com/bauer-group/CS-LinkStack#readme"
LABEL org.opencontainers.image.description="LinkStack (self-hosted link-in-bio) - BAUER GROUP Edition with corporate theme and curated themes"
# LinkStack itself is AGPL-3.0; this image bundles it. See NOTICE for details.
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"
LABEL org.opencontainers.image.version="0.1.0"

# Extended Labels
LABEL org.opencontainers.image.base.name="linkstackorg/linkstack:${LINKSTACK_VERSION}"
LABEL com.bauer-group.linkstack.version="${LINKSTACK_VERSION}"
LABEL com.bauer-group.features="theme-sync,corporate-theme,env-bridge"

# =============================================================================
# Stage themes OUTSIDE the /htdocs volume (image-internal staging path).
# The upstream image runs as the non-root user apache; the build-time staging
# below writes into root-owned paths, so switch to root for these steps and drop
# back to apache before the ENTRYPOINT.
USER root

# Curated stock themes (vendored, unzipped) + the corporate theme.
# vendor/ holds one folder per stock theme → copy its CONTENTS into the staging
# dir. The corporate theme is a single folder → copy it to an explicit target.
COPY themes/vendor/       /opt/linkstack/themes/
COPY themes/bauer-group/  /opt/linkstack/themes/bauer-group/

# Wrapper entrypoint.
COPY rootfs/ /

# Record which theme directories we manage (.bundled) and a content fingerprint
# of the staged themes (.version). The fingerprint is a SHA-256 over every staged
# theme file (content + path), so ANY change to the bundled themes — a new theme,
# a bumped version, an edited CSS file — changes the marker and forces a one-time
# re-sync on the next boot. It is deterministic and needs no CI build-arg. Staged
# files stay world-readable so the runtime apache user can read them.
RUN set -eux; \
    ls -1 /opt/linkstack/themes | grep -v -E '^\.' > /opt/linkstack/themes/.bundled; \
    find /opt/linkstack/themes -type f ! -name '.version' ! -name '.bundled' \
        -exec sha256sum {} + \
      | LC_ALL=C sort \
      | sha256sum \
      | cut -d' ' -f1 > /opt/linkstack/themes/.version; \
    chmod +x /usr/local/bin/bauergroup-provision.sh; \
    echo "Bundled themes:"; cat /opt/linkstack/themes/.bundled; \
    echo "Theme fingerprint: $(cat /opt/linkstack/themes/.version)"

# Runtime user (matches upstream). The ENTRYPOINT and Apache run as apache.
USER apache

ENTRYPOINT ["/usr/local/bin/bauergroup-provision.sh"]
# Setting ENTRYPOINT resets the inherited CMD to null, so re-declare the upstream
# CMD explicitly. The wrapper forwards it via `exec "$@"` after theme sync.
CMD ["/usr/local/bin/docker-entrypoint.sh"]
