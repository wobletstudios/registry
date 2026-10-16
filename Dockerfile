# Builds pesde's registry server from a pinned upstream tag. The registry
# crate only exists on release tags and version branches, not on main.
ARG PESDE_TAG=v0.7.4+registry.0.2.3

FROM rust:1-bookworm AS build
ARG PESDE_TAG
RUN apt-get update \
    && apt-get install -y --no-install-recommends pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$PESDE_TAG" https://github.com/pesde-pkg/pesde.git /src
WORKDIR /src
# Upstream bug (pesde-pkg/pesde#79): FS storage sends `Content-Encoding: gzip`
# on archives whose body IS the gzip. Cloudflare decompresses it for clients
# that do not advertise gzip, and the pesde CLI then fails with "Invalid gzip
# header". Drop that header line before building. Remove once upstream fixes it.
RUN sed -i '/CONTENT_ENCODING, "gzip"/d' registry/src/storage/fs.rs \
    && sed -i 's/{CONTENT_ENCODING, CONTENT_LENGTH, CONTENT_TYPE}/{CONTENT_LENGTH, CONTENT_TYPE}/' registry/src/storage/fs.rs \
    && ! grep -q CONTENT_ENCODING registry/src/storage/fs.rs
RUN cargo build --release -p pesde-registry

FROM debian:bookworm-slim
# git: the registry commits package metadata to the index repository
# libssl3 / ca-certificates: TLS for GitHub (index pushes)
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --create-home pesde \
    && mkdir -p /var/lib/pesde-registry/data /var/lib/pesde-registry/storage \
    && chown -R pesde:pesde /var/lib/pesde-registry
COPY --from=build /src/target/release/pesde-registry /usr/local/bin/pesde-registry

USER pesde
WORKDIR /home/pesde
# Inside the container the server must bind all interfaces; compose maps the
# port to loopback on the host and cloudflared reaches it over the compose network
ENV ADDRESS=0.0.0.0 \
    PORT=8080 \
    DATA_DIR=/var/lib/pesde-registry/data \
    FS_STORAGE_ROOT=/var/lib/pesde-registry/storage
VOLUME /var/lib/pesde-registry
EXPOSE 8080
CMD ["pesde-registry"]
