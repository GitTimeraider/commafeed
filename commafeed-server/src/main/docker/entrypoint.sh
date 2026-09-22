#!/bin/sh
set -e

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if [ "$(id -u)" = "0" ]; then
    CURRENT_GID="$(getent group commafeed | cut -d: -f3)"
    CURRENT_UID="$(id -u commafeed)"

    if [ "$PGID" != "$CURRENT_GID" ]; then
        groupmod -o -g "$PGID" commafeed
    fi
    if [ "$PUID" != "$CURRENT_UID" ]; then
        usermod -o -u "$PUID" commafeed
    fi

    chown -R commafeed:commafeed /commafeed/data

    exec gosu commafeed:commafeed "$@"
else
    exec "$@"
fi
