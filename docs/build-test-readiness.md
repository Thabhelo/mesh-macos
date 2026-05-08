# Build And Test Readiness

This project is validated with SwiftPM unit tests plus an Xcode app build. CI runs the same checks on pull requests and pushes to `main`.

## Required Tools

- macOS 14 or later
- Xcode 16 or later for the checked-in `Mesh.xcodeproj` format
- Swift 5.9 or later
- SwiftFormat for local lint checks

Confirm the active toolchain:

```bash
xcodebuild -version
swift --version
```

If multiple Xcode versions are installed, select a compatible version:

```bash
sudo xcode-select -s /Applications/Xcode.app
```

## Local Validation

Run unit tests:

```bash
swift test
```

Build the macOS app:

```bash
xcodebuild -project Mesh.xcodeproj -scheme Mesh -destination 'platform=macOS' build
```

Run the same formatting lint gate used by CI:

```bash
swiftformat Mesh Tests Package.swift --lint --rules duplicateImports,semicolons --swiftversion 5.9
```

## What The Tests Cover

- `APIClientTests`: DataSF URL construction, request headers, dispatched-call decoding, normalization, filtering, dropped malformed rows, and HTTP/decoding error mapping with mocked URL responses.
- `IncidentPollingServiceTests`: snapshot diffing for new, updated, and closed incidents, source freshness metadata propagation, and reset behavior.
- `OperationalIntelligenceServiceTests`: deterministic surge thresholds, trend buckets, priority ranking, hazard scoring, hazard history, and empty input handling.
- `ReplayScenarioServiceTests`: deterministic SF replay frames, replay compatibility with the `IncidentPollingResult` contract, and the Southern District surge/hazard decision point.

## CI

The GitHub Actions workflow is defined in `.github/workflows/ci.yml`. It runs on `macos-15` and selects the latest stable Xcode available on that runner so the project can be opened with a toolchain compatible with its checked-in project format.

CI runs:

```bash
swift test
xcodebuild -project Mesh.xcodeproj -scheme Mesh -destination 'platform=macOS' build
swiftformat Mesh Tests Package.swift --lint --rules duplicateImports,semicolons --swiftversion 5.9
```

CI intentionally uses mocked network responses for unit tests. It does not call DataSF or production services.

## Troubleshooting

- `The project 'Mesh' cannot be opened because it is in a future Xcode project file format`: use Xcode 16 or later, or update `.github/workflows/ci.yml` to a runner image with a newer Xcode.
- `PackageDescription` or manifest errors: make sure Xcode Command Line Tools point at a full Xcode install with `sudo xcode-select -s /Applications/Xcode.app`.
- Missing macOS SDK or destination errors: run `xcodebuild -showsdks` and confirm the active Xcode supports macOS 14 or later.
- SwiftPM resource warnings: `Package.swift` explicitly excludes `Info.plist` and `Mesh.entitlements` from the SwiftPM target because they are owned by the Xcode app target.
- Network-dependent test failures: the readiness tests should not make real network calls. If a test reaches the network, add a URLProtocol-backed mock response.
- SwiftFormat failures: fix duplicate imports or semicolons in the reported files, then rerun the lint command.
