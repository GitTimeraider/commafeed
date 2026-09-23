#!/bin/sh
set -e

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if [ "$(id -u)" = "0" ]; then
    # Switching from root to PUID:PGID needs CAP_SETUID (bit 7) and CAP_SETGID (bit 6),
    # which --cap-drop=ALL removes. Fail with instructions instead of gosu's bare EPERM.
    CAP_EFF="$(sed -n 's/^CapEff:[[:space:]]*//p' /proc/self/status)"
    if [ -n "$CAP_EFF" ] && [ $(( 0x$CAP_EFF & 0xC0 )) -ne $(( 0xC0 )) ]; then
        cat >&2 <<EOF
entrypoint: cannot switch from root to PUID:PGID (${PUID}:${PGID}): the container is missing the
entrypoint: SETUID/SETGID capabilities (usually because of --cap-drop=ALL).
entrypoint:
entrypoint: Fix it in one of these ways:
entrypoint:  1. Recommended: remove PUID/PGID and let Docker start the container as that user,
entrypoint:     e.g. add: --user ${PUID}:${PGID}
entrypoint:     (unRAID: Edit container > Advanced View > Extra Parameters)
entrypoint:     Your data directory must already be owned by ${PUID}:${PGID} on the host.
entrypoint:  2. Keep PUID/PGID and allow only the capabilities needed to switch user:
entrypoint:     --cap-drop=ALL --cap-add=SETUID --cap-add=SETGID
EOF
        exit 1
    fi

    CURRENT_GID="$(getent group commafeed | cut -d: -f3)"
    CURRENT_UID="$(id -u commafeed)"

    # Edit /etc/passwd and /etc/group directly instead of using usermod/groupmod:
    # those also try to chown the commafeed user's home directory tree, which
    # needs CAP_CHOWN and aborts this script (via set -e) when the container is
    # run with --cap-drop=ALL. A plain text edit to files root already owns
    # doesn't need that capability.
    if [ "$PGID" != "$CURRENT_GID" ]; then
        sed -i "s/^\(commafeed:[^:]*:\)[0-9]*:/\1${PGID}:/" /etc/group
    fi
    if [ "$PUID" != "$CURRENT_UID" ]; then
        sed -i "s/^\(commafeed:[^:]*:\)[0-9]*:[0-9]*:/\1${PUID}:${PGID}:/" /etc/passwd
    fi

    # Best-effort: this is a no-op (and needs CAP_CHOWN) if the data directory
    # is already owned by PUID:PGID, e.g. pre-chowned on the host.
    chown -R commafeed:commafeed /commafeed/data 2>/dev/null || \
        echo "entrypoint: could not chown /commafeed/data (missing CAP_CHOWN?), continuing" >&2

    exec gosu commafeed:commafeed "$@"
else
    exec "$@"
fi
