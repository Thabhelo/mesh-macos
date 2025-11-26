import SwiftUI
import Combine

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case map = "Map"
    case surge = "Surge Prediction"
    case hazard = "Hazard Analysis"
    
    var id: String { rawValue }
    
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

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Published Properties
    
    @Published var selectedTab: AppTab = .dashboard
    @Published var selectedIncidentId: String?
    @Published var isConnected: Bool = false
    @Published var systemStatus: SystemStatus = .normal
    
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
    
    // MARK: - Computed Properties
    
    var activeIncidentCount: Int {
        incidents.filter { $0.status == .active }.count
    }
    
    var filteredIncidents: [Incident] {
        incidents.filter { incident in
            let matchesAgency = selectedAgencyTypes.contains(incident.agencyType)
            let matchesDistrict = selectedDistricts.isEmpty || selectedDistricts.contains(incident.districtId)
            let matchesStatus = !showActiveOnly || incident.status == .active
            return matchesAgency && matchesDistrict && matchesStatus
        }
    }
    
    var topSurgeAlerts: [SurgeAlert] {
        Array(surgeAlerts.sorted { $0.severity.rawValue > $1.severity.rawValue }.prefix(3))
    }
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() async {
        do {
            // Load agencies
            agencies = try await APIClient.shared.fetchAgencies()
            
            // Load districts
            districts = try await APIClient.shared.fetchDistricts()
            selectedDistricts = Set(districts.map { $0.id })
            
            // Load initial incidents
            incidents = try await APIClient.shared.fetchIncidents()
            
            // Load surge alerts
            surgeAlerts = try await APIClient.shared.fetchSurgeAlerts()
            
            // Load hazard score
            hazardScore = try await APIClient.shared.fetchHazardScore()
            
            // Update system status
            updateSystemStatus()
            
        } catch {
            print("Failed to load initial data: \(error)")
        }
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func selectIncident(_ incident: Incident) {
        selectedIncidentId = incident.id
    }
    
    func clearSelection() {
        selectedIncidentId = nil
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Listen for WebSocket updates
        WebSocketService.shared.incidentUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.handleIncidentUpdate(update)
            }
            .store(in: &cancellables)
        
        WebSocketService.shared.surgeUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] alert in
                self?.handleSurgeUpdate(alert)
            }
            .store(in: &cancellables)
        
        WebSocketService.shared.connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
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
        let criticalIncidents = incidents.filter { $0.status == .active && $0.severity == .critical }.count
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
}

