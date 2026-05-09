# MeshBackend — Swift NIO HTTP server (Linux). Suitable for cheap VPS deploys.
# Build: docker build -t mesh-backend .
# Run:   docker run --rm -p 8080:8080 -e MESH_BACKEND_SNAPSHOT_PATH=/data/incidents.json -v mesh-snap:/data mesh-backend

ARG SWIFT_VERSION=5.10-jammy
FROM swift:${SWIFT_VERSION} AS build
WORKDIR /src

COPY Package.swift Package.swift
COPY Backend Backend
COPY Mesh Mesh
COPY Tests Tests

RUN swift build -c release --product MeshBackend

FROM ubuntu:jammy
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
RUN useradd --system --home /nonexistent --shell /usr/sbin/nologin meshbackend

COPY --from=build /src/.build/release/MeshBackend /usr/local/bin/MeshBackend

ENV PORT=8080
ENV MESH_BACKEND_SNAPSHOT_PATH=/var/lib/mesh-backend/incidents.json

RUN mkdir -p /var/lib/mesh-backend && chown meshbackend /var/lib/mesh-backend

USER meshbackend
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/MeshBackend"]
