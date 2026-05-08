import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown error")"
        case .unauthorized:
            return "Unauthorized - please log in again"
        case .notFound:
            return "Resource not found"
        }
    }
}

actor APIClient {
    static let shared = APIClient()
    
    private let baseURL: URL
    private let dataSFIncidentsURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let now: () -> Date
    
    init(
        baseURL: URL = URL(string: "https://api.mesh-platform.com/v1")!,
        dataSFIncidentsURL: URL = URL(string: "https://data.sfgov.org/resource/gnap-fj3t.json")!,
        session: URLSession = APIClient.defaultSession(),
        now: @escaping () -> Date = Date.init
    ) {
        self.baseURL = baseURL
        self.dataSFIncidentsURL = dataSFIncidentsURL
        self.session = session
        self.now = now

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    private static func defaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }
    
    // MARK: - Generic Request
    
    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // TODO: Add authentication token
        // request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return try decoder.decode(T.self, from: data)
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                let message = String(data: data, encoding: .utf8)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Incidents
    
    func fetchIncidents(
        status: IncidentStatus? = nil,
        agencyType: AgencyType? = nil,
        districtId: String? = nil
    ) async throws -> [Incident] {
        let result = try await fetchDataSFIncidentSnapshot()
        let incidents = result.incidents
        return incidents.filter { incident in
            let matchesStatus = status == nil || incident.status == status
            let matchesAgency = agencyType == nil || incident.agencyType == agencyType
            let matchesDistrict = districtId == nil || incident.districtId == districtId
            return matchesStatus && matchesAgency && matchesDistrict
        }
    }
    
    func fetchIncident(id: String) async throws -> Incident {
        if let incident = try await fetchIncidents().first(where: { $0.id == id }) {
            return incident
        }
        throw APIError.notFound
    }
    
    // MARK: - Agencies
    
    func fetchAgencies() async throws -> [Agency] {
        // For now, return sample data
        try await Task.sleep(nanoseconds: 300_000_000)
        return Agency.samples
        
        // return try await request(endpoint: "agencies")
    }
    
    // MARK: - Districts
    
    func fetchDistricts() async throws -> [District] {
        // For now, return sample data
        try await Task.sleep(nanoseconds: 300_000_000)
        return District.samples
        
        // return try await request(endpoint: "districts")
    }
    
    // MARK: - Surge Alerts
    
    func fetchSurgeAlerts() async throws -> [SurgeAlert] {
        // Surge alerts are derived in AppState from the live incident snapshot until the backend owns this endpoint.
        return []
    }
    
    func fetchSurgeTrendData(districtId: String, hours: Int = 24) async throws -> [SurgeTrendDataPoint] {
        // Surge trend charts are derived from the current live incident snapshot in the UI.
        return []
    }
    
    // MARK: - Hazard Score
    
    func fetchHazardScore() async throws -> HazardScore {
        // Hazard scoring is derived in AppState from incidents and surge signals until the backend owns this endpoint.
        return OperationalIntelligenceService.deriveHazardScore(incidents: [], districts: [], surgeAlerts: [])
    }

    // MARK: - DataSF Incidents

    func fetchDataSFIncidentSnapshot(limit: Int = 500) async throws -> DataSFIncidentFetchResult {
        var components = URLComponents(url: dataSFIncidentsURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "$limit", value: String(limit)),
            URLQueryItem(name: "$order", value: "call_last_updated_at DESC")
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mesh macOS (San Francisco public-safety monitor)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                let calls = try decoder.decode([DataSFDispatchedCall].self, from: data)
                return DataSFIncidentFetchResult(
                    incidents: calls.compactMap(normalizeDataSFCall),
                    sourceDataAsOf: newestDate(from: calls.map(\.dataAsOf)),
                    sourceDataLoadedAt: newestDate(from: calls.map(\.dataLoadedAt)),
                    fetchedAt: now()
                )
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                let message = String(data: data, encoding: .utf8)
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func normalizeDataSFCall(_ call: DataSFDispatchedCall) -> Incident? {
        guard let sourceId = call.id, !sourceId.isEmpty else {
            return nil
        }

        guard let coordinate = call.intersectionPoint?.coordinate else {
            return nil
        }

        let reportedAt = parseDataSFDate(call.receivedDatetime)
            ?? parseDataSFDate(call.entryDatetime)
            ?? parseDataSFDate(call.dispatchDatetime)
            ?? parseDataSFDate(call.callLastUpdatedAt)

        guard let reportedAt else {
            return nil
        }

        let updatedAt = parseDataSFDate(call.callLastUpdatedAt)
            ?? parseDataSFDate(call.closeDatetime)
            ?? reportedAt

        let rawType = call.callTypeFinalDescription
            ?? call.callTypeOriginalDescription
            ?? "Dispatched Call"
        let type = normalizeCallType(rawType)
        let agencyName = normalizeAgencyName(call.agency)
        let districtName = call.policeDistrict ?? call.analysisNeighborhood ?? LocationService.activeRegionName
        let priority = call.priorityFinal ?? call.priorityOriginal
        let status = normalizeStatus(for: call)

        return Incident(
            id: "datasf:gnap-fj3t:\(sourceId)",
            type: type,
            description: incidentDescription(for: call, fallbackType: type),
            agencyType: normalizeAgencyType(call.agency),
            agencyId: normalizedIdentifier(agencyName),
            agencyName: agencyName,
            districtId: normalizedIdentifier(districtName),
            districtName: districtName.capitalized,
            status: status,
            severity: normalizeSeverity(priority),
            location: Incident.Location(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: call.intersectionName ?? call.analysisNeighborhood ?? LocationService.activeRegionName,
            reportedAt: reportedAt,
            updatedAt: updatedAt,
            respondingUnits: [],
            notes: []
        )
    }

    private func normalizeStatus(for call: DataSFDispatchedCall) -> IncidentStatus {
        if parseDataSFDate(call.closeDatetime) != nil {
            return .closed
        }
        if parseDataSFDate(call.onsceneDatetime) != nil {
            return .onScene
        }
        if parseDataSFDate(call.dispatchDatetime) != nil || parseDataSFDate(call.enrouteDatetime) != nil {
            return .responding
        }
        return .active
    }

    private func normalizeSeverity(_ priority: String?) -> IncidentSeverity {
        switch priority?.uppercased() {
        case "A":
            return .critical
        case "B":
            return .high
        case "C":
            return .medium
        case "I":
            return .low
        default:
            return .medium
        }
    }

    private func normalizeAgencyType(_ agency: String?) -> AgencyType {
        let normalized = agency?.lowercased() ?? ""
        if normalized.contains("mta") || normalized.contains("transportation") {
            return .transit
        }
        return .police
    }

    private func normalizeAgencyName(_ agency: String?) -> String {
        let normalized = agency?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        if normalized.contains("municipal transportation") || normalized == "mta" {
            return "San Francisco Municipal Transportation Agency"
        }
        if normalized.contains("sheriff") {
            return "San Francisco Sheriff's Office"
        }
        if normalized.contains("police") {
            return "San Francisco Police Department"
        }

        return agency?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "San Francisco Public Safety"
    }

    private func normalizeCallType(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "W/CITY", with: "WITH CITY")
            .replacingOccurrences(of: "W/", with: "WITH ")
            .replacingOccurrences(of: "H&R", with: "HIT AND RUN")
            .replacingOccurrences(of: "TRAF", with: "TRAFFIC")
            .replacingOccurrences(of: "VEH", with: "VEHICLE")
            .replacingOccurrences(of: "SUSP", with: "SUSPICIOUS")
            .replacingOccurrences(of: "PERS", with: "PERSON")
            .replacingOccurrences(of: "ADW", with: "ASSAULT WITH DEADLY WEAPON")
            .replacingOccurrences(of: "AGG", with: "AGGRAVATED")
            .replacingOccurrences(of: "UNKN", with: "UNKNOWN")
            .replacingOccurrences(of: "UNK", with: "UNKNOWN")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
            .lowercased()
            .split(separator: " ")
            .map { word in
                if word.count <= 3 && word.allSatisfy({ $0.isLetter }) {
                    return word.uppercased()
                }
                return word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private func normalizedIdentifier(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func incidentDescription(for call: DataSFDispatchedCall, fallbackType: String) -> String {
        var parts: [String] = [fallbackType]
        if let priority = call.priorityFinal ?? call.priorityOriginal {
            parts.append("Priority \(priority.uppercased())")
        }
        if let disposition = call.disposition, !disposition.isEmpty {
            parts.append("Disposition \(disposition)")
        }
        if call.sensitiveCall == true {
            parts.append("Sensitive call")
        }
        return parts.joined(separator: " | ")
    }

    private func parseDataSFDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value)
    }

    private func newestDate(from values: [String?]) -> Date? {
        values.compactMap(parseDataSFDate).max()
    }
}

private struct DataSFDispatchedCall: Decodable {
    let id: String?
    let cadNumber: String?
    let receivedDatetime: String?
    let entryDatetime: String?
    let dispatchDatetime: String?
    let enrouteDatetime: String?
    let onsceneDatetime: String?
    let closeDatetime: String?
    let callTypeOriginal: String?
    let callTypeOriginalDescription: String?
    let callTypeFinal: String?
    let callTypeFinalDescription: String?
    let priorityOriginal: String?
    let priorityFinal: String?
    let agency: String?
    let disposition: String?
    let onviewFlag: String?
    let sensitiveCall: Bool?
    let intersectionName: String?
    let intersectionPoint: DataSFPoint?
    let supervisorDistrict: String?
    let analysisNeighborhood: String?
    let policeDistrict: String?
    let callLastUpdatedAt: String?
    let dataAsOf: String?
    let dataLoadedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cadNumber = "cad_number"
        case receivedDatetime = "received_datetime"
        case entryDatetime = "entry_datetime"
        case dispatchDatetime = "dispatch_datetime"
        case enrouteDatetime = "enroute_datetime"
        case onsceneDatetime = "onscene_datetime"
        case closeDatetime = "close_datetime"
        case callTypeOriginal = "call_type_original"
        case callTypeOriginalDescription = "call_type_original_desc"
        case callTypeFinal = "call_type_final"
        case callTypeFinalDescription = "call_type_final_desc"
        case priorityOriginal = "priority_original"
        case priorityFinal = "priority_final"
        case agency
        case disposition
        case onviewFlag = "onview_flag"
        case sensitiveCall = "sensitive_call"
        case intersectionName = "intersection_name"
        case intersectionPoint = "intersection_point"
        case supervisorDistrict = "supervisor_district"
        case analysisNeighborhood = "analysis_neighborhood"
        case policeDistrict = "police_district"
        case callLastUpdatedAt = "call_last_updated_at"
        case dataAsOf = "data_as_of"
        case dataLoadedAt = "data_loaded_at"
    }
}

private struct DataSFPoint: Decodable {
    let type: String?
    let coordinates: [Double]

    var coordinate: (latitude: Double, longitude: Double)? {
        guard coordinates.count >= 2 else {
            return nil
        }
        return (latitude: coordinates[1], longitude: coordinates[0])
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

