# Mesh Backend

This directory defines the production backend boundary for Mesh. The backend owns San Francisco public-safety ingestion, normalization, freshness tracking, derived signals, and stable API responses for the macOS client.

The backend currently includes:

- `Sources/MeshBackendCore/MeshBackendContract.swift` contains compile-checked response envelopes, source attribution, freshness metadata, health/error payloads, endpoint definitions, and the service skeleton.
- `Sources/MeshBackendCore/DataSFIngestion.swift` contains the backend-owned DataSF decoder and normalizer.
- `Sources/MeshBackendCore/MeshBackendRouter.swift` contains an in-memory/persisted snapshot store and API router.
- `Sources/MeshBackend/main.swift` runs a local HTTP service using the router.
- `openapi/mesh-api-v1.yaml` documents the HTTP API surface the macOS client consumes.

## Production Region

San Francisco is the only production region for this milestone.

- Region ID: `san-francisco`
- Primary incident source: DataSF dispatched calls
- Dataset: `gnap-fj3t`
- Source URL: `https://data.sfgov.org/resource/gnap-fj3t.json`

## API Shape

All backend responses use a versioned envelope:

```json
{
  "apiVersion": "v1",
  "regionId": "san-francisco",
  "regionName": "San Francisco",
  "data": {},
  "source": {
    "name": "DataSF Dispatched Calls",
    "datasetIdentifier": "gnap-fj3t",
    "url": "https://data.sfgov.org/resource/gnap-fj3t.json"
  },
  "freshness": {
    "fetchedAt": "2026-05-08T03:00:00Z",
    "sourceDataAsOf": "2026-05-08T02:58:00Z",
    "sourceDataLoadedAt": "2026-05-08T02:59:00Z",
    "staleAfterSeconds": 900
  }
}
```

The first live-update mechanism is polling-friendly snapshots. WebSocket or SSE streams can be added after the snapshot contracts are stable.

## Required Endpoints

- `GET /v1/incidents`
- `GET /v1/incidents/{id}`
- `GET /v1/agencies`
- `GET /v1/districts`
- `GET /v1/surge-alerts`
- `GET /v1/surge-trends`
- `GET /v1/hazard-score`
- `GET /v1/freshness`
- `GET /v1/health`

## Ingestion Responsibilities

The backend ingestion worker:

- Fetches DataSF `gnap-fj3t` on startup and every 10 minutes.
- Normalize rows into stable Mesh incident payloads.
- Deduplicate by DataSF source ID through stable incident IDs.
- Preserve late updates in the latest persisted snapshot.
- Track `data_as_of`, `data_loaded_at`, backend fetch time, and last successful ingest time.
- Record source downtime, rate limits, schema drift, and decode errors as structured health/error payloads.
- Persist the latest normalized snapshot to `.mesh-backend/incidents.json` by default.
- Keep replay/training fixtures compatible with the same normalized contracts.

## Local Development

Run the backend locally from the repository root:

```bash
swift run MeshBackend
```

The service listens on `PORT` or `8080` by default:

```bash
PORT=8081 MESH_BACKEND_SNAPSHOT_PATH=.mesh-backend/incidents.json swift run MeshBackend
```

Check the API:

```bash
curl http://127.0.0.1:8080/v1/health
curl http://127.0.0.1:8080/v1/incidents
```

Run tests:

```bash
swift test
```

## Deployment Notes

The service is a Swift executable with no third-party dependencies. A production deployment should:

- Set `PORT` from the platform runtime.
- Set `MESH_BACKEND_SNAPSHOT_PATH` to durable storage.
- Keep the process alive so the built-in 10-minute ingestion cadence continues to run.
- Add TLS, request authentication, structured log shipping, and process supervision at the hosting layer.
- Put the service behind `https://api.mesh-platform.com/v1` before removing local-development overrides.
