#!/bin/sh
set -e

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if [ "$(id -u)" = "0" ]; then
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
