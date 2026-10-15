# registry

Deployment for the private pesde registry at `registry.woblet.gg`. The
server is upstream `pesde-registry` built from a pinned tag; this repo holds
only how it is run. Package metadata lives in `wobletstudios/pesde-index`
(written by the registry, never by hand); package archives live in a Docker
volume on the VPS.

Pinned: pesde `v0.7.4+registry.0.2.3`. Upgrade the CLI pin in consuming
repos' `rokit.toml` and `PESDE_TAG` here together.

## Layout

- `Dockerfile` - two-stage build of `pesde-registry` from the upstream tag
- `.github/workflows/build.yml` - builds the Dockerfile on push and pushes
  `ghcr.io/wobletstudios/pesde-registry:<version>` (public package)
- `docker-compose.yml` - `registry` (loopback 8080) + `cloudflared` (prod profile)
- `.env.example` - every variable, with where each value comes from

The VPS never compiles anything; it pulls the image GitHub Actions built.

## First deploy

1. VPS: Ubuntu 24.04, SSH keys only, `ufw` default deny with SSH allowed,
   Docker from Docker's apt repo, a user in the `docker` group.
2. Cloudflare Zero Trust > Networks > Tunnels: create `woblet-registry`
   (Docker connector), copy the token. Public hostname
   `registry.woblet.gg` -> service `http://registry:8080`.
3. GitHub: fine-grained PAT scoped to `pesde-index`, Contents read/write.
4. On the VPS: `git clone` this repo, `cp .env.example .env`, fill it in,
   `chmod 600 .env`. Tokens: `openssl rand -hex 32` twice.
5. `docker compose --profile prod pull && docker compose --profile prod up -d`.
   The image must already exist on GHCR (green `build` run on Actions).
6. Check: `docker compose logs registry` shows the index cloned; the tunnel
   is healthy in the dashboard; `curl -I https://registry.woblet.gg/`
   answers from the app, not a Cloudflare 502/530.

## Clients

Once per machine, with the read token (or the write token on publishing
machines):

    pesde auth login --index https://github.com/wobletstudios/pesde-index --token <token>

Projects pin the index in their own `pesde.toml`:

    [indices]
    default = "https://github.com/wobletstudios/pesde-index"

## Runbook

- **Upgrade**: bump `PESDE_TAG` in `Dockerfile` and the image tag in
  `docker-compose.yml`; push; wait for the `build` workflow to go green;
  on the VPS `git pull`, `docker compose --profile prod pull`,
  `docker compose --profile prod up -d`.
- **Rotate a token**: edit `.env`, `docker compose up -d` (recreates the
  container), then every holder re-runs `pesde auth login`. Rotating the
  read token logs out all teammates and CI; do it rarely.
- **Rotate the PAT**: mint a new one, edit `GIT_PASSWORD`, `up -d`. An
  expired PAT silently breaks publishing; the index clone still works.
- **Backup**: the index is on GitHub. Archives are the only unrecoverable
  data: nightly, `docker run --rm -v registry_registry-data:/data -v "$PWD":/out debian tar czf /out/registry-data.tgz -C /data .`
  to R2 or a Hostinger snapshot.
- **Reset the index** (before the first real publish, after smoke tests):
  delete and recreate `pesde-index` with `config.toml`, then
  `docker compose restart registry` so it re-clones.

Publishes are permanent: a version can never be replaced or removed.
