import Foundation

public enum MeshBackendContract {
    public static let apiVersion = "v1"
    public static let basePath = "/v1"
    public static let supportedRegionId = "san-francisco"
    public static let supportedRegionName = "San Francisco"
    public static let pollingSnapshotFirst = true

    public static let dataSFDispatchedCallsSource = SourceAttribution(
        name: "DataSF Dispatched Calls",
        datasetIdentifier: "gnap-fj3t",
        url: URL(string: "https://data.sfgov.org/resource/gnap-fj3t.json")!
    )

    public static let endpoints: [APIEndpoint] = [
        .get("/v1/incidents", summary: "List normalized incidents for a region"),
        .get("/v1/incidents/{id}", summary: "Fetch one normalized incident"),
        .get("/v1/agencies", summary: "List agencies derived from backend-owned sources"),
        .get("/v1/districts", summary: "List districts and operational metadata"),
        .get("/v1/surge-alerts", summary: "List current surge alerts"),
        .get("/v1/surge-trends", summary: "List surge trend points"),
        .get("/v1/hazard-score", summary: "Fetch current hazard score"),
        .get("/v1/freshness", summary: "Fetch source freshness metadata"),
        .get("/v1/health", summary: "Fetch backend and source health")
    ]
}

public struct APIEndpoint: Codable, Equatable {
    public let method: String
    public let path: String
    public let summary: String

    public static func get(_ path: String, summary: String) -> APIEndpoint {
        APIEndpoint(method: "GET", path: path, summary: summary)
    }
}

public struct APIEnvelope<Payload: Codable & Equatable>: Codable, Equatable {
    public let apiVersion: String
    public let regionId: String
    public let regionName: String
    public let data: Payload
    public let source: SourceAttribution
    public let freshness: FreshnessMetadata

    public init(
        apiVersion: String = MeshBackendContract.apiVersion,
        regionId: String = MeshBackendContract.supportedRegionId,
        regionName: String = MeshBackendContract.supportedRegionName,
        data: Payload,
        source: SourceAttribution,
        freshness: FreshnessMetadata
    ) {
        self.apiVersion = apiVersion
        self.regionId = regionId
        self.regionName = regionName
        self.data = data
        self.source = source
        self.freshness = freshness
    }
}

public struct SourceAttribution: Codable, Equatable {
    public let name: String
    public let datasetIdentifier: String
    public let url: URL

    public init(name: String, datasetIdentifier: String, url: URL) {
        self.name = name
        self.datasetIdentifier = datasetIdentifier
        self.url = url
    }
}

public struct FreshnessMetadata: Codable, Equatable {
    public let fetchedAt: Date
    public let sourceDataAsOf: Date?
    public let sourceDataLoadedAt: Date?
    public let staleAfterSeconds: TimeInterval

    public init(
        fetchedAt: Date,
        sourceDataAsOf: Date?,
        sourceDataLoadedAt: Date?,
        staleAfterSeconds: TimeInterval
    ) {
        self.fetchedAt = fetchedAt
        self.sourceDataAsOf = sourceDataAsOf
        self.sourceDataLoadedAt = sourceDataLoadedAt
        self.staleAfterSeconds = staleAfterSeconds
    }

    public func isStale(relativeTo referenceDate: Date) -> Bool {
        let sourceFreshnessDate = sourceDataAsOf ?? sourceDataLoadedAt ?? fetchedAt
        return referenceDate.timeIntervalSince(sourceFreshnessDate) > staleAfterSeconds
    }
}

public struct IncidentPayload: Codable, Equatable, Identifiable {
    public let id: String
    public let type: String
    public let description: String
    public let agencyType: String
    public let agencyId: String
    public let agencyName: String
    public let districtId: String
    public let districtName: String
    public let status: String
    public let severity: Int
    public let location: CoordinatePayload
    public let address: String
    public let reportedAt: Date
    public let updatedAt: Date
    public let respondingUnits: [RespondingUnitPayload]
    public let notes: [IncidentNotePayload]
}

public struct CoordinatePayload: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
}

public struct RespondingUnitPayload: Codable, Equatable, Identifiable {
    public let id: String
    public let unitId: String
    public let unitName: String
    public let agencyType: String
    public let status: String
    public let etaMinutes: Int?
}

public struct IncidentNotePayload: Codable, Equatable, Identifiable {
    public let id: String
    public let content: String
    public let author: String
    public let timestamp: Date
}

public struct BackendHealthPayload: Codable, Equatable {
    public let status: BackendHealthStatus
    public let checkedAt: Date
    public let sources: [SourceHealthPayload]
}

public enum BackendHealthStatus: String, Codable, Equatable {
    case healthy
    case degraded
    case down
}

public struct SourceHealthPayload: Codable, Equatable {
    public let source: SourceAttribution
    public let status: BackendHealthStatus
    public let lastSuccessfulIngestAt: Date?
    public let lastError: APIErrorPayload?
}

public struct APIErrorPayload: Codable, Equatable {
    public let code: APIErrorCode
    public let message: String
    public let retryAfterSeconds: Int?
}

public enum APIErrorCode: String, Codable, Equatable {
    case sourceUnavailable
    case rateLimited
    case schemaDrift
    case unauthorized
    case notFound
    case internalError
}

public struct MeshBackendServiceSkeleton {
    public let apiVersion: String
    public let primarySource: SourceAttribution
    public let endpoints: [APIEndpoint]

    public init(
        apiVersion: String = MeshBackendContract.apiVersion,
        primarySource: SourceAttribution = MeshBackendContract.dataSFDispatchedCallsSource,
        endpoints: [APIEndpoint] = MeshBackendContract.endpoints
    ) {
        self.apiVersion = apiVersion
        self.primarySource = primarySource
        self.endpoints = endpoints
    }

    public var supportsPollingSnapshots: Bool {
        MeshBackendContract.pollingSnapshotFirst
    }
}
