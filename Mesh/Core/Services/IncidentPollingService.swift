import Foundation

struct DataSFIncidentFetchResult {
    let incidents: [Incident]
    let sourceDataAsOf: Date?
    let sourceDataLoadedAt: Date?
    let fetchedAt: Date
}

struct IncidentPollingResult {
    let incidents: [Incident]
    let updates: [IncidentUpdate]
    let refreshedAt: Date
    let sourceDataAsOf: Date?
    let sourceDataLoadedAt: Date?
}

actor IncidentPollingService {
    static let shared = IncidentPollingService()

    static let defaultPollingInterval: TimeInterval = 10 * 60
    static let staleAfter: TimeInterval = 15 * 60

    private let apiClient: APIClient
    private var snapshotById: [String: Incident] = [:]

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func poll(limit: Int = 500) async throws -> IncidentPollingResult {
        let result = try await apiClient.fetchIncidentSnapshot(limit: limit)
        let currentById = Dictionary(uniqueKeysWithValues: result.incidents.map { ($0.id, $0) })
        let updates = diff(previous: snapshotById, current: currentById, timestamp: result.fetchedAt)
        let mergedSnapshot = mergeClosedIncidents(previous: snapshotById, current: currentById)

        snapshotById = Dictionary(uniqueKeysWithValues: mergedSnapshot.map { ($0.id, $0) })

        return IncidentPollingResult(
            incidents: mergedSnapshot,
            updates: updates,
            refreshedAt: result.fetchedAt,
            sourceDataAsOf: result.sourceDataAsOf,
            sourceDataLoadedAt: result.sourceDataLoadedAt
        )
    }

    func reset() {
        snapshotById = [:]
    }

    private func diff(
        previous: [String: Incident],
        current: [String: Incident],
        timestamp: Date
    ) -> [IncidentUpdate] {
        var updates: [IncidentUpdate] = []

        for incident in current.values {
            guard let oldIncident = previous[incident.id] else {
                updates.append(IncidentUpdate(type: .new, incident: incident, incidentId: incident.id, timestamp: timestamp))
                continue
            }

            if oldIncident.status.isOperationallyActive && !incident.status.isOperationallyActive {
                updates.append(IncidentUpdate(type: .closed, incident: incident, incidentId: incident.id, timestamp: timestamp))
            } else if oldIncident != incident {
                updates.append(IncidentUpdate(type: .updated, incident: incident, incidentId: incident.id, timestamp: timestamp))
            }
        }

        for oldIncident in previous.values where oldIncident.status.isOperationallyActive && current[oldIncident.id] == nil {
            updates.append(IncidentUpdate(type: .closed, incident: nil, incidentId: oldIncident.id, timestamp: timestamp))
        }

        return updates.sorted { $0.timestamp > $1.timestamp }
    }

    private func mergeClosedIncidents(
        previous: [String: Incident],
        current: [String: Incident]
    ) -> [Incident] {
        var merged = current

        for oldIncident in previous.values where oldIncident.status.isOperationallyActive && current[oldIncident.id] == nil {
            var closedIncident = oldIncident
            closedIncident.status = .closed
            closedIncident.updatedAt = Date()
            merged[closedIncident.id] = closedIncident
        }

        return merged.values.sorted { lhs, rhs in
            if lhs.status.isOperationallyActive != rhs.status.isOperationallyActive {
                return lhs.status.isOperationallyActive
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
