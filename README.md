# Mesh for macOS

Native macOS application for the Mesh Public Safety Platform - providing live public-safety incident awareness for San Francisco, California.

## Features

### Menu Bar Companion
- System status indicator (green/yellow/red)
- Data freshness state for DataSF incident polling
- Quick view of active incidents and surge alerts
- One-click access to the full dashboard
- Critical notifications

### Real-Time Dashboard
- Live DataSF incident feed from San Francisco dispatched-call records
- Filterable by agency type, district, and severity
- Detailed incident information with responding units
- Manual refresh plus automatic polling every 10 minutes

### Interactive Map
- MapKit visualization with incident markers
- District boundary overlays
- Color-coded incident pins by agency type
- Click-to-view incident details

### Surge Prediction
- AI-powered call volume analysis
- District-level surge indicators
- Historical trend visualization
- Predictive alerts with confidence scores

### Hazard Analysis
- Unified hazard score (0-100)
- Multi-factor breakdown (weather, traffic, incidents, infrastructure, events)
- Historical comparisons
- District-level risk assessment

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for development)

## Development Setup

### Prerequisites

Install the required development tools:

```bash
# Xcode build server for IDE integration
brew install xcode-build-server

# Pretty-print xcodebuild output
brew install xcbeautify

# Code formatting
brew install swiftformat
```

### Cursor IDE Setup

1. Install the [Swift Language Support](https://marketplace.visualstudio.com/items?itemName=chrisatwindsurf.swift-vscode) extension
2. Install the [Sweetpad](https://sweetpad.hyzyla.dev/) extension

### Building with Xcode

1. Generate the Xcode project (if using XcodeGen):
   ```bash
   xcodegen generate
   ```

2. Open the project:
   ```bash
   open Mesh.xcodeproj
   ```

3. Build and run (⌘+R)

### Building with Sweetpad

1. Open the project folder in Cursor
2. Run `Sweetpad: Generate Build Server Config` from the command palette
3. Build once to enable autocomplete and jump-to-definition
4. Press F5 to build and run with debugging

## Project Structure

```
mesh-macos/
├── Mesh/
│   ├── App/                    # App entry point and configuration
│   │   ├── MeshApp.swift       # Main app with menu bar + window
│   │   ├── AppDelegate.swift   # App lifecycle and notifications
│   │   ├── AppState.swift      # Global app state management
│   │   └── ContentView.swift   # Main content view
│   ├── Features/
│   │   ├── Dashboard/          # Incident dashboard
│   │   ├── Map/                # MapKit visualization
│   │   ├── SurgePrediction/    # Surge analysis
│   │   ├── HazardAnalysis/     # Hazard scoring
│   │   └── MenuBar/            # Menu bar popover
│   ├── Core/
│   │   ├── Networking/         # API client and legacy WebSocket shell
│   │   ├── Models/             # Data models
│   │   └── Services/           # Polling, notification, and location services
│   ├── Shared/
│   │   └── Components/         # Reusable UI components
│   └── Resources/
│       └── Assets.xcassets     # App icons and colors
├── Mesh.xcodeproj              # Xcode project
└── README.md
```

## Architecture

- **UI Framework**: SwiftUI with macOS 14+ features
- **State Management**: `ObservableObject` app state shared through `@EnvironmentObject`
- **Networking**: Async/await with URLSession
- **Incident Updates**: DataSF snapshot polling and diffing
- **Maps**: MapKit with SwiftUI integration
- **Charts**: Swift Charts for data visualization
- **Notifications**: UserNotifications framework

## Incident Data Pipeline

Production incidents are loaded from the San Francisco DataSF dispatched-calls dataset `gnap-fj3t` in `Core/Networking/APIClient.swift`.

`Core/Services/IncidentPollingService.swift` owns the polling snapshot:

- Fetches the latest DataSF incidents on launch and every 10 minutes.
- Keys incidents by stable DataSF ID to avoid duplicates across repeated polls.
- Diffs each snapshot into `new`, `updated`, and `closed` `IncidentUpdate` events.
- Preserves records that disappear from a later active snapshot as `Closed`, so the `Active only` filter can hide them without losing lifecycle history.
- Carries DataSF freshness metadata from `data_as_of` and `data_loaded_at`.

`App/AppState.swift` owns app-facing lifecycle and state:

- `loadInitialData()` loads static supporting data, then performs the first incident poll.
- `startIncidentPolling()` starts the recurring 10-minute refresh loop.
- `refreshData()` is used by toolbar, menu bar, and command-menu manual refresh actions.
- `dataConnectionState`, `lastIncidentRefreshAt`, and `incidentRefreshError` drive UI truthfulness.

The freshness states shown in the toolbar and menu bar are:

- `Loading`: no successful incident poll has completed yet.
- `Live`: the latest DataSF response was fetched successfully and source freshness is within the stale threshold.
- `Stale`: DataSF responded, but its source freshness metadata is older than the stale threshold.
- `Offline`: the initial incident poll failed.
- `Error`: a later refresh failed after at least one successful poll.

The legacy `WebSocketService` remains as a disconnected shell for future backend streaming work. Production startup does not call `connect()`, `startSimulation()`, or random sample event generation.

## Configuration

### Production Region

The production region is San Francisco, California. Incidents, agencies, districts, map defaults, surge context, and hazard context should all stay tied to San Francisco unless a new production region is explicitly added.

Region defaults live in `Core/Services/LocationService.swift`:

```swift
static let activeRegionName = "San Francisco"
static let activeRegionCenter = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
```

Additional cities should be added as separate provider/data-access efforts once approved local emergency or CAD data is available.

### API Endpoint

The Mesh API endpoint is configured in `Core/Networking/APIClient.swift`. It is currently retained for future backend endpoints and sample-backed supporting data:

```swift
self.baseURL = URL(string: "https://api.mesh-platform.com/v1")!
```

### DataSF Endpoint

The production incident endpoint is also configured in `Core/Networking/APIClient.swift`:

```swift
self.dataSFIncidentsURL = URL(string: "https://data.sfgov.org/resource/gnap-fj3t.json")!
```

Requests order by `call_last_updated_at DESC` and default to a 500-record limit.

### WebSocket Shell

The legacy WebSocket endpoint is configured in `Core/Networking/WebSocketService.swift`, but it is not part of the production incident pipeline:

```swift
private let baseURL = URL(string: "wss://api.mesh-platform.com/ws")!
```

## Testing

Build the app with:

```bash
xcodebuild -project Mesh.xcodeproj -scheme Mesh -destination 'platform=macOS' build
```

Manual verification:

- Launch the app and confirm the connection badge moves from `Loading` to `Live` or `Stale`.
- Confirm the badge shows a last-refresh timestamp after the first successful poll.
- Use the toolbar refresh button, menu bar refresh action, or `Command-R`; incidents should refresh without duplicating existing records.
- Toggle `Show active incidents only`; closed incidents should be hidden when enabled.
- Leave the app running to confirm the automatic 10-minute refresh advances the last-refresh timestamp.

Regression check for fake simulation code:

```bash
rg "startSimulation|simulateRandomUpdate|Incident\\.samples\\.randomElement|SurgeAlert\\.samples\\.randomElement"
```

Expected result: no matches.

## Data Models

### Incident
- Type, description, severity
- Agency information
- Location (coordinates and address)
- Responding units
- Status updates

### Surge Alert
- District information
- Current vs expected call volume
- Trend direction
- Contributing factors

### Hazard Score
- Overall score (0-100)
- Component breakdown
- District-level scores
- Historical comparison

## License

Proprietary - Mesh Platform 2025

## Contact

- Email: thabheloduve@gmail.com
- Location: San Francisco, California

