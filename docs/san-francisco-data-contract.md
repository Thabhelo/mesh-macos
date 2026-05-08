# San Francisco Data Contract

This document defines how San Francisco public data maps into Mesh macOS domain models. San Francisco is the only production region for the current milestone. Future cities must be added through explicit provider adapters and must not mix their data with San Francisco live mode.

## Production Region

The active region is defined in `Mesh/Core/Services/LocationService.swift`.

```swift
static let activeRegionName = "San Francisco"
static let activeRegionShortName = "SF"
static let activeRegionCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
```

All production incidents, agencies, districts, map defaults, surge context, hazard context, and replay/training data must be tied to this region unless a separate provider effort adds another city.

## Source Inventory

- Live incidents: DataSF `gnap-fj3t` dispatched calls. Backend ingestion is implemented in `Backend/Sources/MeshBackendCore/DataSFIngestion.swift`.
- Incident freshness: DataSF `data_as_of`, DataSF `data_loaded_at`, and backend fetch time. Exposed through `FreshnessMetadata`.
- Districts and neighborhoods: SF police districts and DataSF `police_district` / `analysis_neighborhood` fields. Derived from normalized live incidents.
- Agencies: DataSF `agency` plus backend normalization. Derived from normalized live incidents.
- Surge alerts and trends: future aggregation over DataSF live and replay windows. Gap tracked by issue #4.
- Hazard score: future service combining call activity, weather, traffic, outages, and events. Gap tracked by issue #4.
- Weather alerts: NOAA / Bay Area weather source. Not implemented.
- Traffic and road closures: SF or Bay Area public traffic source. Not implemented.
- Replay and training: future historical DataSF-derived replay provider. Gap tracked by issue #5.

Production live mode must not invent unavailable fields. Missing source-backed fields should be empty, marked as a documented gap, or provided only by explicit replay/training data.

## DataSF Dispatched Calls

Endpoint:

```text
https://data.sfgov.org/resource/gnap-fj3t.json
```

Current query:

```text
$limit=500
$order=call_last_updated_at DESC
```

The backend treats DataSF as a rolling source that updates roughly every 10 minutes. App polling is owned by `Mesh/Core/Services/IncidentPollingService.swift` and consumes the backend `/v1/incidents` snapshot.

## Incident Mapping

DataSF rows decode into `DataSFDispatchedCall` and normalize into `Incident` using these rules:

- `id`: `datasf:gnap-fj3t:{id}`.
- `type`: `call_type_final_desc`, else `call_type_original_desc`, normalized for readability.
- `description`: type plus priority, disposition, and sensitive-call flag when present.
- `agencyType`: `agency`; transportation/MTA maps to `transit`, otherwise currently `police`.
- `agencyId`: normalized `agencyName`.
- `agencyName`: normalized `agency`; known SF agencies get canonical names.
- `districtId`: normalized `police_district`, else `analysis_neighborhood`, else active region.
- `districtName`: `police_district`, else `analysis_neighborhood`, title-cased.
- `status`: `closed` if `close_datetime` exists; `onScene` if `onscene_datetime` exists; `responding` if `dispatch_datetime` or `enroute_datetime` exists; otherwise `active`.
- `severity`: priority `A` = `critical`, `B` = `high`, `C` = `medium`, `I` = `low`, unknown = `medium`.
- `location`: `intersection_point.coordinates`; rows without coordinates are omitted from live incidents.
- `address`: `intersection_name`, else `analysis_neighborhood`, else active region.
- `reportedAt`: first parseable value from `received_datetime`, `entry_datetime`, `dispatch_datetime`, `call_last_updated_at`.
- `updatedAt`: `call_last_updated_at`, else `close_datetime`, else `reportedAt`.
- `respondingUnits`: empty in public live mode; public DataSF rows do not expose unit assignments.
- `notes`: empty in public live mode.

Example normalized incident:

```json
{
  "id": "datasf:gnap-fj3t:123456",
  "type": "Traffic Collision",
  "description": "Traffic Collision | Priority B | Disposition REP",
  "agencyType": "Police",
  "agencyId": "san-francisco-police-department",
  "agencyName": "San Francisco Police Department",
  "districtId": "southern",
  "districtName": "Southern",
  "status": "Responding",
  "severity": 3,
  "location": {
    "latitude": 37.7763,
    "longitude": -122.3988
  },
  "address": "5TH ST \\ MARKET ST",
  "reportedAt": "2026-05-07T16:40:00Z",
  "updatedAt": "2026-05-07T16:48:00Z",
  "respondingUnits": [],
  "notes": []
}
```

## Backend API Contract

The production backend API contract is versioned as `v1` and documented in `Backend/openapi/mesh-api-v1.yaml`.

Backend responses must include:

- `apiVersion`
- `regionId`
- `regionName`
- `data`
- `source`
- `freshness`

The compile-checked Swift representation lives in `Backend/Sources/MeshBackendCore/MeshBackendContract.swift`. The backend owns these paths:

- `GET /v1/incidents`
- `GET /v1/incidents/{id}`
- `GET /v1/agencies`
- `GET /v1/districts`
- `GET /v1/surge-alerts`
- `GET /v1/surge-trends`
- `GET /v1/hazard-score`
- `GET /v1/freshness`
- `GET /v1/health`

API responses must preserve DataSF source attribution and freshness metadata so the macOS app can render live, stale, offline, and error states without direct DataSF coupling.

## Snapshot and Event Contract

`IncidentPollingService` maintains a snapshot keyed by normalized incident ID.

- New ID in current snapshot: emits `IncidentUpdate(type: .new)`.
- Existing ID with changed normalized fields: emits `IncidentUpdate(type: .updated)`.
- Existing active ID now non-active: emits `IncidentUpdate(type: .closed)`.
- Previously active ID missing from the rolling DataSF snapshot: preserves the previous incident as `closed`.

Repeated polls must not duplicate incidents.

## Freshness Contract

`DataSFIncidentFetchResult` carries:

- `incidents`: normalized incidents.
- `sourceDataAsOf`: newest DataSF `data_as_of`.
- `sourceDataLoadedAt`: newest DataSF `data_loaded_at`.
- `fetchedAt`: app fetch time.

`AppState` exposes:

- `dataConnectionState`
- `lastIncidentRefreshAt`
- `incidentRefreshError`

Current UI states are `Loading`, `Live`, `Stale`, `Offline`, and `Error`. `Stale` means DataSF responded but source freshness metadata is older than the app's stale threshold.

## Privacy and Redaction

The live DataSF pipeline only uses public open-data fields. It does not expose privileged CAD notes, personally identifying information, unit assignments, patient information, or private caller details.

Rules:

- Do not synthesize sensitive details that are absent from DataSF.
- Keep `respondingUnits` and `notes` empty in public live mode unless a future authorized provider supplies them.
- Treat `sensitive_call` as a display/context flag only; do not infer hidden details.
- Future CAD, NENA EIDO, or agency partner feeds must arrive through an adapter with explicit authorization, redaction, and retention rules.

## Provider Adapter Path

Future providers should normalize into the same app contracts:

- `Incident`
- `IncidentUpdate`
- `District`
- `SurgeAlert`
- `SurgeTrendDataPoint`
- `HazardScore`

Adapters should be region-scoped. A future city must provide its own source inventory, field mapping, freshness metadata, privacy rules, and replay/training compatibility before it can be enabled in production UI.

## Known Gaps

- The backend currently uses a local executable and file-backed snapshot persistence; production hosting is not yet provisioned.
- Production hosting, TLS, authentication enforcement, and log shipping are not yet provisioned.
- Surge alerts, surge trends, and hazard score are not yet backend-derived from live DataSF windows.
- Weather, traffic, district-boundary, and historical-baseline sources are identified but not integrated.
- Replay/training data is not yet loaded through the same provider path as live data.
