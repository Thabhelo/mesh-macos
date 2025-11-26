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
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        // TODO: Configure with actual API base URL
        self.baseURL = URL(string: "https://api.mesh-platform.com/v1")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
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
        // For now, return sample data
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        return Incident.samples
        
        /*
        var queryItems: [URLQueryItem] = []
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let agencyType = agencyType {
            queryItems.append(URLQueryItem(name: "agencyType", value: agencyType.rawValue))
        }
        if let districtId = districtId {
            queryItems.append(URLQueryItem(name: "districtId", value: districtId))
        }
        
        return try await request(endpoint: "incidents", queryItems: queryItems.isEmpty ? nil : queryItems)
        */
    }
    
    func fetchIncident(id: String) async throws -> Incident {
        // For now, return sample data
        try await Task.sleep(nanoseconds: 200_000_000)
        if let incident = Incident.samples.first(where: { $0.id == id }) {
            return incident
        }
        throw APIError.notFound
        
        // return try await request(endpoint: "incidents/\(id)")
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
        // For now, return sample data
        try await Task.sleep(nanoseconds: 300_000_000)
        return SurgeAlert.samples
        
        // return try await request(endpoint: "surge-alerts")
    }
    
    func fetchSurgeTrendData(districtId: String, hours: Int = 24) async throws -> [SurgeTrendDataPoint] {
        // For now, return sample data
        try await Task.sleep(nanoseconds: 200_000_000)
        return SurgeTrendDataPoint.generateSampleData(hours: hours)
        
        /*
        let queryItems = [
            URLQueryItem(name: "districtId", value: districtId),
            URLQueryItem(name: "hours", value: String(hours))
        ]
        return try await request(endpoint: "surge-trends", queryItems: queryItems)
        */
    }
    
    // MARK: - Hazard Score
    
    func fetchHazardScore() async throws -> HazardScore {
        // For now, return sample data
        try await Task.sleep(nanoseconds: 300_000_000)
        return HazardScore.sample
        
        // return try await request(endpoint: "hazard-score")
    }
}

