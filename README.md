# Mesh for macOS

Native macOS application for the Mesh Public Safety Platform - providing real-time interoperability intelligence for emergency response agencies in Birmingham, Alabama.

## Features

### Menu Bar Companion
- System status indicator (green/yellow/red)
- Quick view of active incidents and surge alerts
- One-click access to the full dashboard
- Critical notifications

### Real-Time Dashboard
- Live incident feed from police, fire, EMS, and 911
- Filterable by agency type, district, and severity
- Detailed incident information with responding units
- Real-time updates via WebSocket

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
│   │   ├── Networking/         # API client and WebSocket
│   │   ├── Models/             # Data models
│   │   └── Services/           # Notification and location services
│   ├── Shared/
│   │   └── Components/         # Reusable UI components
│   └── Resources/
│       └── Assets.xcassets     # App icons and colors
├── Package.swift               # Swift Package manifest
├── project.yml                 # XcodeGen project definition
└── README.md
```

## Architecture

- **UI Framework**: SwiftUI with macOS 14+ features
- **State Management**: Observable with @Observable and @EnvironmentObject
- **Networking**: Async/await with URLSession
- **Real-time Updates**: WebSocket via URLSessionWebSocketTask
- **Maps**: MapKit with SwiftUI integration
- **Charts**: Swift Charts for data visualization
- **Notifications**: UserNotifications framework

## Configuration

### API Endpoint

The API endpoint is configured in `Core/Networking/APIClient.swift`. Update the `baseURL` for your environment:

```swift
self.baseURL = URL(string: "https://api.mesh-platform.com/v1")!
```

### WebSocket

WebSocket connection is configured in `Core/Networking/WebSocketService.swift`:

```swift
private let baseURL = URL(string: "wss://api.mesh-platform.com/ws")!
```

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
- Location: Birmingham, Alabama

