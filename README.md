# registry

Private pesde registry at `registry.woblet.gg`. Upstream `pesde-registry`
built from a pinned tag, run with Docker Compose behind a Cloudflare Tunnel.
Package metadata lives in `wobletstudios/pesde-index`; archives in a Docker
volume on the VPS.

Pinned: pesde `v0.7.4+registry.0.2.3`.

## Deploy

    cp .env.example .env && chmod 600 .env   # fill it in
    docker compose --profile prod pull
    docker compose --profile prod up -d

## Clients

    pesde auth login --index https://github.com/wobletstudios/pesde-index --token <token>

## Runbook

- **Upgrade**: bump `PESDE_TAG` in `Dockerfile` and the tag in `docker-compose.yml`,
  push, wait for the `build` workflow, then `pull` and `up -d` on the VPS.
- **Rotate a token**: edit `.env`, `docker compose up -d`, holders re-login.
- **Backup**: volume `registry_registry-data` is the only unrecoverable data.
- **Reset the index**: recreate `pesde-index` with `config.toml`, then
  `docker compose restart registry`.

Publishes are permanent.
