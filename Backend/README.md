# Mesh Backend

This directory defines the production backend boundary for Mesh. The backend owns San Francisco public-safety ingestion, normalization, freshness tracking, derived signals, and stable API responses for the macOS client.

This first slice is intentionally contract-first:

- `Sources/MeshBackendCore/MeshBackendContract.swift` contains compile-checked response envelopes, source attribution, freshness metadata, health/error payloads, endpoint definitions, and the service skeleton.
- `openapi/mesh-api-v1.yaml` documents the HTTP API surface the macOS client should migrate toward.

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

The backend ingestion worker must:

- Poll DataSF `gnap-fj3t` on the source cadence.
- Normalize rows into stable Mesh incident payloads.
- Deduplicate by DataSF source ID.
- Preserve late updates and close records that leave the rolling window.
- Track `data_as_of`, `data_loaded_at`, backend fetch time, and last successful ingest time.
- Record source downtime, rate limits, schema drift, and decode errors as structured health/error payloads.
- Keep replay/training fixtures compatible with the same normalized contracts.

## Local Development

Run contract tests from the repository root:

```bash
swift test
```

The next backend slice should add a runnable service target and an ingestion adapter implementation behind this contract. Until then, the macOS app continues to call DataSF directly while the backend API stabilizes.
