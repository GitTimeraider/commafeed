# CommaFeed

Docker image for [GitTimeraider/commafeed](https://github.com/GitTimeraider/commafeed), a fork of
[Athou/commafeed](https://github.com/Athou/commafeed) with `PUID`/`PGID` support.

## Quickstart

Start CommaFeed with its H2 embedded database. The app will be accessible on http://localhost:8082/

### docker

```
docker run --name commafeed --detach --publish 8082:8082 --restart unless-stopped \
    --volume /path/to/commafeed/data:/commafeed/data \
    --memory 256M ghcr.io/gittimeraider/commafeed:latest
```

### docker-compose

```
services:
  commafeed:
    image: ghcr.io/gittimeraider/commafeed:latest
    restart: unless-stopped
    volumes:
      - ./data:/commafeed/data
    deploy:
      resources:
        limits:
          memory: 256M
    ports:
      - 8082:8082
```

## Configuration

All [CommaFeed settings](https://athou.github.io/commafeed/documentation) (upstream documentation, which also applies to
this image) are optional and have sensible default values.

Settings are overrideable with environment variables. For instance, `commafeed.feed-refresh.interval-empirical` can be
set with the `COMMAFEED_FEED_REFRESH_INTERVAL_EMPIRICAL` variable.

When logging in, credentials are stored in an encrypted cookie. The encryption key is randomly generated at startup,
meaning that you will have to log back in after each restart of the application. To prevent this, you can set the
`QUARKUS_HTTP_AUTH_SESSION_ENCRYPTION_KEY` variable to a fixed value (min. 16 characters).
All other Quarkus settings can be found [here](https://quarkus.io/guides/all-config).

### Running as a specific user (PUID/PGID)

By default, the container starts as root, creates a `commafeed` user/group and immediately drops privileges to it
before running the application. You can control the user/group ID it drops to with the `PUID` and `PGID` environment
variables, which is useful to match the ownership of a bind-mounted `data` directory on the host (e.g. `99:100` on
unRAID, or the output of `id $USER` on a regular Linux host):

```
docker run --name commafeed --detach --publish 8082:8082 --restart unless-stopped \
    --volume /path/to/commafeed/data:/commafeed/data \
    --env PUID=99 --env PGID=100 \
    --memory 256M ghcr.io/gittimeraider/commafeed:latest
```

```
services:
  commafeed:
    image: ghcr.io/gittimeraider/commafeed:latest
    restart: unless-stopped
    environment:
      - PUID=99
      - PGID=100
    volumes:
      - ./data:/commafeed/data
    ports:
      - 8082:8082
```

Both variables default to `1000` if unset. If the container is started with a non-root user (e.g. via docker's
`--user` flag), `PUID`/`PGID` are ignored and the application simply runs as that user.

#### Using `--cap-drop=ALL` / `--security-opt=no-new-privileges:true`

`PUID`/`PGID` work by starting the container as root and dropping down to that user/group right before running the
application, which needs a couple of Linux capabilities (`CAP_SETUID`/`CAP_SETGID` to switch user, `CAP_CHOWN` to fix
up ownership of the data directory). `--cap-drop=ALL` removes those, so root inside the container can no longer drop
privileges at all, and the container will fail to start.

If you're already running the container with `--cap-drop=ALL` (or similar hardening), skip `PUID`/`PGID` entirely and
run directly as your target user/group with docker's own `--user` flag instead. This needs no capabilities, since
the container never runs as root in the first place:

```
docker run --name commafeed --detach --publish 8082:8082 --restart unless-stopped \
    --volume /path/to/commafeed/data:/commafeed/data \
    --user 99:100 \
    --cap-drop=ALL --security-opt=no-new-privileges:true \
    --memory 256M ghcr.io/gittimeraider/commafeed:latest
```

This only works if `/path/to/commafeed/data` is already owned by that user/group on the host (e.g. `chown -R 99:100
/path/to/commafeed/data`), since the container can no longer fix that up itself without `CAP_CHOWN`.

## Image and tags

A single image is published: H2 embedded database, native build, `linux/amd64` only. It's built and pushed on every
push to the repository (except commits that only change `.md` files), and can also be triggered manually from the
"Actions" tab on GitHub (select the `ci` workflow, then "Run workflow").

Tags:

- `latest`: the latest push to `master`
- `<branch>`: the latest push to that branch (e.g. `master`)
- `<branch>-<short-sha>`: pinned to one exact commit (e.g. `master-a1b2c3d`)

The image only includes the H2 database driver. To use PostgreSQL, MySQL or MariaDB instead, build from source with the
matching Maven profile (see the main README).

## FAQ

### Getting "Access to local address blocked" when adding a feed

CommaFeed blocks access to local resources by default to prevent [SSRF](https://en.wikipedia.org/wiki/Server-side_request_forgery) attacks.
If you want to subscribe to feeds that are only available on your local network, you can disable this security measure by setting the `COMMAFEED_HTTP_CLIENT_BLOCK_LOCAL_ADDRESSES` variable to `false`.
Do this only if you trust all users of your CommaFeed instance not to access private resources.
