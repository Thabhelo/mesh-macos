import SwiftUI
import Combine

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case map = "Map"
    case surge = "Surge Prediction"
    case hazard = "Hazard Analysis"
    
    var id: String { rawValue }

    static let productionTabs: [AppTab] = [.dashboard, .map]
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .map: return "map"
        case .surge: return "chart.line.uptrend.xyaxis"
        case .hazard: return "exclamationmark.triangle"
        }
    }
}

enum SystemStatus: String {
    case normal = "Normal"
    case elevated = "Elevated"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .elevated: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .elevated: return "exclamationmark.circle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}

enum DataConnectionState: Equatable {
    case loading
    case live
    case replay
    case stale
    case offline
    case error

    var label: String {
        switch self {
        case .loading: return "Loading"
        case .live: return "Live"
        case .replay: return "Training"
        case .stale: return "Stale"
        case .offline: return "Offline"
        case .error: return "Error"
        }
    }

    var color: Color {
        switch self {
        case .loading: return .orange
        case .live: return .green
        case .replay: return .blue
        case .stale: return .yellow
        case .offline, .error: return .red
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Published Properties
    
    @Published var selectedTab: AppTab = .dashboard
    @Published var selectedIncidentId: String?
    @Published var isConnected: Bool = false
    @Published var dataConnectionState: DataConnectionState = .loading
    @Published var lastIncidentRefreshAt: Date?
    @Published var incidentRefreshError: String?
    @Published var incidentRefreshRecoverySuggestion: String?
    @Published var sourceDataAsOf: Date?
    @Published var sourceDataLoadedAt: Date?
    @Published var incidentDataSource: IncidentDataSource = .meshBackend
    @Published var incidentDataSourceNotice: String?
    @Published var systemStatus: SystemStatus = .normal
    @Published var showWelcome: Bool = true
    @Published var dataMode: DataMode = .live
    @Published var replayPlaybackState: ReplayPlaybackState = .stopped
    @Published var replaySpeed: ReplaySpeed = .normal
    @Published var replayFrameIndex: Int = 0
    
    // Data
    @Published var incidents: [Incident] = []
    @Published var agencies: [Agency] = []
    @Published var districts: [District] = []
    @Published var surgeAlerts: [SurgeAlert] = []
    @Published var hazardScore: HazardScore?
    
    // Filters
    @Published var selectedAgencyTypes: Set<AgencyType> = Set(AgencyType.allCases)
    @Published var selectedDistricts: Set<String> = []
    @Published var showActiveOnly: Bool = true
    
    // Settings
    @Published var notificationsEnabled: Bool = true
    @Published var criticalAlertsOnly: Bool = false

    let liveDataSource = APIClient.productionDataSource
    
    // MARK: - Computed Properties
    
    var activeIncidentCount: Int {
        incidents.filter { $0.status.isOperationallyActive }.count
    }
    
    var filteredIncidents: [Incident] {
        incidents.filter { incident in
            let matchesAgency = selectedAgencyTypes.contains(incident.agencyType)
            let matchesDistrict = selectedDistricts.isEmpty || selectedDistricts.contains(incident.districtId)
            let matchesStatus = !showActiveOnly || incident.status.isOperationallyActive
            return matchesAgency && matchesDistrict && matchesStatus
        }
    }
    
    var topSurgeAlerts: [SurgeAlert] {
        Array(surgeAlerts.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity
            }
            return lhs.percentageIncrease > rhs.percentageIncrease
        }.prefix(3))
    }

    var availableAgencyTypes: [AgencyType] {
        let types = Set(incidents.map { $0.agencyType })
        let orderedTypes = AgencyType.allCases.filter { types.contains($0) }
        return orderedTypes.isEmpty ? [.police, .transit] : orderedTypes
    }
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    private var incidentPollingTask: Task<Void, Never>?
    private var replayPlaybackTask: Task<Void, Never>?
    private var replayScenarioAnchorDate = Date()
    private var isIncidentRefreshInFlight = false
    private var hasSeededSelectedDistricts = false

    var replayFrames: [ReplayScenarioFrame] {
        ReplayScenarioService.frames(anchorDate: replayScenarioAnchorDate)
    }

    var currentReplayFrame: ReplayScenarioFrame? {
        guard dataMode == .replay else { return nil }
        let frames = replayFrames
        guard frames.indices.contains(replayFrameIndex) else { return nil }
        return frames[replayFrameIndex]
    }
    
    private init() {
        // Live update subscriptions will be enabled when the real DataSF polling stream lands.
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() async {
        applyStaticData(agencies: [], districts: [])
        await refreshData()
    }
    
    func refreshData() async {
        guard dataMode == .live else { return }
        guard !isIncidentRefreshInFlight else { return }

        isIncidentRefreshInFlight = true
        if lastIncidentRefreshAt == nil {
            dataConnectionState = .loading
        }
        defer { isIncidentRefreshInFlight = false }

        do {
            let result = try await IncidentPollingService.shared.poll()
            applyIncidentPollingResult(result)
        } catch {
            markIncidentRefreshFailed(error)
            print("Failed to refresh incidents: \(error)")
        }
    }

    func startIncidentPolling() {
        guard dataMode == .live else { return }
        guard incidentPollingTask == nil else { return }

        incidentPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(IncidentPollingService.defaultPollingInterval * 1_000_000_000))
                } catch {
                    break
                }

                await self?.refreshData()
            }
        }
    }

    func stopIncidentPolling() {
        incidentPollingTask?.cancel()
        incidentPollingTask = nil
    }

    func enterReplayMode() {
        guard dataMode != .replay else { return }
        stopIncidentPolling()
        replayScenarioAnchorDate = Date()
        dataMode = .replay
        selectedTab = .dashboard
        replayPlaybackState = .stopped
        applyReplayFrame(at: 0)
    }

    func enterLiveMode() {
        stopReplayPlayback()
        dataMode = .live
        replayPlaybackState = .stopped
        dataConnectionState = lastIncidentRefreshAt == nil ? .loading : .live
        Task {
            await refreshData()
            startIncidentPolling()
        }
    }

    func replayStepForward() {
        applyReplayFrame(at: min(replayFrameIndex + 1, replayFrames.count - 1))
    }

    func replayStepBackward() {
        applyReplayFrame(at: max(replayFrameIndex - 1, 0))
    }

    func resetReplay() {
        stopReplayPlayback()
        replayScenarioAnchorDate = Date()
        replayPlaybackState = .stopped
        applyReplayFrame(at: 0)
    }

    func toggleReplayPlayback() {
        guard dataMode == .replay else { return }

        if replayPlaybackState == .playing {
            stopReplayPlayback()
            replayPlaybackState = .paused
        } else {
            startReplayPlayback()
        }
    }

    func cycleReplaySpeed() {
        let speeds = ReplaySpeed.allCases
        guard let index = speeds.firstIndex(of: replaySpeed) else {
            replaySpeed = .normal
            return
        }
        replaySpeed = speeds[(index + 1) % speeds.count]
    }
    
    func selectIncident(_ incident: Incident) {
        selectedIncidentId = incident.id
    }
    
    func clearSelection() {
        selectedIncidentId = nil
    }
    
    func dismissWelcome() {
        showWelcome = false
    }
    
    // MARK: - Private Methods

    private func applyStaticData(
        agencies loadedAgencies: [Agency],
        districts loadedDistricts: [District]
    ) {
        agencies = loadedAgencies
        districts = loadedDistricts
        selectedDistricts = Set(loadedDistricts.map { $0.id })
        hasSeededSelectedDistricts = !selectedDistricts.isEmpty
        updateDerivedIntelligence()
        updateSystemStatus()
    }

    private func applyIncidentPollingResult(_ result: IncidentPollingResult) {
        let shouldNotify = lastIncidentRefreshAt != nil

        incidents = result.incidents
        rebuildOperationalMetadata(from: result.incidents)
        lastIncidentRefreshAt = result.refreshedAt
        sourceDataAsOf = result.sourceDataAsOf
        sourceDataLoadedAt = result.sourceDataLoadedAt
        incidentDataSource = result.dataSource
        incidentDataSourceNotice = dataSourceNotice(for: result)
        incidentRefreshError = nil
        incidentRefreshRecoverySuggestion = nil
        dataConnectionState = dataMode == .replay ? .replay : freshnessState(for: result)
        isConnected = dataMode == .live && (dataConnectionState == .live || dataConnectionState == .stale)
        updateDerivedIntelligence(referenceDate: result.refreshedAt)

        if shouldNotify && dataMode == .live {
            notifyForCriticalNewIncidents(in: result.updates)
        }
        updateSystemStatus()
    }

    private func applyReplayFrame(at index: Int) {
        let frames = replayFrames
        guard !frames.isEmpty else { return }

        let clampedIndex = min(max(index, 0), frames.count - 1)
        replayFrameIndex = clampedIndex
        applyIncidentPollingResult(frames[clampedIndex].incidentResult)
        dataConnectionState = .replay
        incidentRefreshError = nil
        incidentRefreshRecoverySuggestion = nil
        incidentDataSourceNotice = nil
        isConnected = false
        selectedIncidentId = incidents.first?.id

        if clampedIndex == frames.count - 1 && replayPlaybackState == .playing {
            stopReplayPlayback()
            replayPlaybackState = .stopped
        }
    }

    private func startReplayPlayback() {
        stopReplayPlayback()
        replayPlaybackState = .playing
        replayPlaybackTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = UInt64((2.0 / replaySpeed.rawValue) * 1_000_000_000)
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    return
                }

                await MainActor.run {
                    guard self.dataMode == .replay else {
                        self.stopReplayPlayback()
                        return
                    }
                    self.replayStepForward()
                }
            }
        }
    }

    private func stopReplayPlayback() {
        replayPlaybackTask?.cancel()
        replayPlaybackTask = nil
    }

    private func notifyForCriticalNewIncidents(in updates: [IncidentUpdate]) {
        guard notificationsEnabled else { return }

        for update in updates where update.type == .new {
            guard let incident = update.incident, incident.severity == .critical else {
                continue
            }
            NotificationService.shared.sendIncidentNotification(incident)
        }
    }

    private func freshnessState(for result: IncidentPollingResult) -> DataConnectionState {
        let sourceFreshnessDate = result.sourceDataAsOf ?? result.sourceDataLoadedAt ?? result.refreshedAt
        if result.refreshedAt.timeIntervalSince(sourceFreshnessDate) > IncidentPollingService.staleAfter {
            return .stale
        }
        return .live
    }

    private func markIncidentRefreshFailed(_ error: Error) {
        incidentRefreshError = dataSourceErrorMessage(for: error)
        incidentRefreshRecoverySuggestion = recoverySuggestion(for: error)
        dataConnectionState = lastIncidentRefreshAt == nil ? .offline : .error
        isConnected = false
    }

    private func updateDerivedIntelligence(referenceDate: Date = Date()) {
        surgeAlerts = OperationalIntelligenceService.deriveSurgeAlerts(
            incidents: incidents,
            districts: districts,
            now: referenceDate
        )
        hazardScore = OperationalIntelligenceService.deriveHazardScore(
            incidents: incidents,
            districts: districts,
            surgeAlerts: surgeAlerts,
            now: referenceDate
        )
    }
    
    private func setupSubscriptions() {
        // Listen for WebSocket updates - use Task to avoid publishing during view updates
        WebSocketService.shared.incidentUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                Task { @MainActor in
                    self?.handleIncidentUpdate(update)
                }
            }
            .store(in: &cancellables)
        
        WebSocketService.shared.surgeUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alert in
                Task { @MainActor in
                    self?.handleSurgeUpdate(alert)
                }
            }
            .store(in: &cancellables)
        
        WebSocketService.shared.connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                Task { @MainActor in
                    self?.isConnected = connected
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleIncidentUpdate(_ update: IncidentUpdate) {
        switch update.type {
        case .new:
            if let incident = update.incident {
                incidents.insert(incident, at: 0)
                if incident.severity == .critical && notificationsEnabled {
                    NotificationService.shared.sendIncidentNotification(incident)
                }
            }
        case .updated:
            if let incident = update.incident,
               let index = incidents.firstIndex(where: { $0.id == incident.id }) {
                incidents[index] = incident
            }
        case .closed:
            if let incidentId = update.incidentId,
               let index = incidents.firstIndex(where: { $0.id == incidentId }) {
                incidents[index].status = .closed
            }
        }
        rebuildOperationalMetadata(from: incidents)
        updateDerivedIntelligence()
        updateSystemStatus()
    }
    
    private func handleSurgeUpdate(_ alert: SurgeAlert) {
        if let index = surgeAlerts.firstIndex(where: { $0.districtId == alert.districtId }) {
            surgeAlerts[index] = alert
        } else {
            surgeAlerts.append(alert)
        }
        
        if alert.severity == .critical && notificationsEnabled {
            NotificationService.shared.sendSurgeNotification(alert)
        }
        
        updateSystemStatus()
    }
    
    private func updateSystemStatus() {
        let criticalIncidents = incidents.filter { $0.status.isOperationallyActive && $0.severity == .critical }.count
        let criticalSurges = surgeAlerts.filter { $0.severity == .critical }.count
        let hazardLevel = hazardScore?.overallScore ?? 0
        
        if criticalIncidents > 5 || criticalSurges > 2 || hazardLevel > 80 {
            systemStatus = .critical
        } else if criticalIncidents > 2 || criticalSurges > 0 || hazardLevel > 60 {
            systemStatus = .elevated
        } else {
            systemStatus = .normal
        }
    }

    private func rebuildOperationalMetadata(from incidents: [Incident]) {
        agencies = OperationalMetadataBuilder.deriveAgencies(from: incidents)
        districts = OperationalMetadataBuilder.deriveDistricts(from: incidents)
        let liveDistrictIds = Set(incidents.map { $0.districtId })

        if hasSeededSelectedDistricts {
            selectedDistricts.formUnion(liveDistrictIds)
        } else {
            selectedDistricts = liveDistrictIds
            hasSeededSelectedDistricts = !liveDistrictIds.isEmpty
        }
    }
}

enum OperationalMetadataBuilder {
    static func deriveAgencies(from incidents: [Incident]) -> [Agency] {
        Dictionary(grouping: incidents, by: \.agencyId)
            .values
            .compactMap { agencyIncidents in
                guard let first = agencyIncidents.first else { return nil }
                let activeCount = agencyIncidents.filter { $0.status.isOperationallyActive }.count
                let totalCount = agencyIncidents.count
                return Agency(
                    id: first.agencyId,
                    name: first.agencyName,
                    type: first.agencyType,
                    shortName: shortName(for: first.agencyName),
                    contactPhone: nil,
                    contactEmail: nil,
                    headquarters: nil,
                    activeUnits: activeCount,
                    totalUnits: totalCount,
                    isConnected: true
                )
            }
            .sorted { $0.name < $1.name }
    }

    static func deriveDistricts(from incidents: [Incident]) -> [District] {
        Dictionary(grouping: incidents, by: \.districtId)
            .values
            .compactMap { districtIncidents in
                guard let first = districtIncidents.first else { return nil }
                let latitudes = districtIncidents.map(\.location.latitude)
                let longitudes = districtIncidents.map(\.location.longitude)
                guard
                    let minLatitude = latitudes.min(),
                    let maxLatitude = latitudes.max(),
                    let minLongitude = longitudes.min(),
                    let maxLongitude = longitudes.max()
                else {
                    return nil
                }

                let centerLatitude = latitudes.reduce(0, +) / Double(latitudes.count)
                let centerLongitude = longitudes.reduce(0, +) / Double(longitudes.count)
                let padding = 0.005
                let boundaryMinLatitude = minLatitude - padding
                let boundaryMaxLatitude = maxLatitude + padding
                let boundaryMinLongitude = minLongitude - padding
                let boundaryMaxLongitude = maxLongitude + padding
                let latitudeMiles = max(0.1, (boundaryMaxLatitude - boundaryMinLatitude) * 69)
                let longitudeMiles = max(
                    0.1,
                    (boundaryMaxLongitude - boundaryMinLongitude) * cos(centerLatitude * .pi / 180) * 69
                )

                return District(
                    id: first.districtId,
                    name: first.districtName,
                    shortName: first.districtName.replacingOccurrences(of: " District", with: ""),
                    population: 0,
                    areaSquareMiles: latitudeMiles * longitudeMiles,
                    center: .init(latitude: centerLatitude, longitude: centerLongitude),
                    boundaries: [
                        .init(latitude: boundaryMinLatitude, longitude: boundaryMinLongitude),
                        .init(latitude: boundaryMinLatitude, longitude: boundaryMaxLongitude),
                        .init(latitude: boundaryMaxLatitude, longitude: boundaryMaxLongitude),
                        .init(latitude: boundaryMaxLatitude, longitude: boundaryMinLongitude)
                    ],
                    activeIncidents: districtIncidents.filter { $0.status.isOperationallyActive }.count,
                    averageResponseTime: 0
                )
            }
            .sorted { $0.name < $1.name }
    }

    private static func shortName(for agencyName: String) -> String {
        let words = agencyName
            .split(separator: " ")
            .filter { word in
                !["and", "of", "the"].contains(word.lowercased())
            }
        let acronym = words.compactMap(\.first).map(String.init).joined()
        return acronym.isEmpty ? agencyName : acronym
    }
}

private extension AppState {
    private func dataSourceErrorMessage(for error: Error) -> String {
        guard let apiError = error as? APIError else {
            return "Unable to refresh \(liveDataSource.name): \(error.localizedDescription)"
        }

        switch apiError {
        case .invalidURL:
            return "The configured \(liveDataSource.name) endpoint is invalid."
        case .invalidResponse:
            return "\(liveDataSource.name) returned an invalid response."
        case .networkError(let underlyingError):
            return "Unable to reach \(liveDataSource.name): \(underlyingError.localizedDescription)"
        case .decodingError:
            return "\(liveDataSource.name) changed its response shape and could not be decoded."
        case .serverError(let statusCode, _):
            if statusCode == 429 {
                return "\(liveDataSource.name) rate-limited the request."
            }
            return "\(liveDataSource.name) returned HTTP \(statusCode)."
        case .unauthorized:
            return "\(liveDataSource.name) rejected the request."
        case .notFound:
            return "The \(liveDataSource.datasetIdentifier) dataset could not be found."
        }
    }

    private func dataSourceNotice(for result: IncidentPollingResult) -> String? {
        switch result.dataSource {
        case .meshBackend:
            return nil
        case .dataSFDevelopmentFallback:
            let reason = result.fallbackReason.map { " \($0)" } ?? ""
            return "Using DataSF direct mode.\(reason)"
        }
    }

    private func recoverySuggestion(for error: Error) -> String {
        guard let apiError = error as? APIError else {
            return "Check your network connection, then retry the refresh."
        }

        switch apiError {
        case .networkError:
            return "Check your network connection, then retry the refresh."
        case .serverError(let statusCode, _) where statusCode == 429:
            return "Wait a minute before retrying; DataSF is throttling requests."
        case .serverError:
            return "Retry shortly; if this persists, check DataSF service health."
        case .decodingError:
            return "DataSF may have changed fields. Update the decoder before relying on live monitoring."
        case .invalidURL, .invalidResponse, .unauthorized, .notFound:
            return "Verify the production data source configuration."
        }
    }
}
