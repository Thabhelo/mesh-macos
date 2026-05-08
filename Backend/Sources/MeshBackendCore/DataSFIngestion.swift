import Foundation

public struct DataSFIncidentSnapshot: Codable, Equatable {
    public let incidents: [IncidentPayload]
    public let sourceDataAsOf: Date?
    public let sourceDataLoadedAt: Date?
    public let fetchedAt: Date

    public init(
        incidents: [IncidentPayload],
        sourceDataAsOf: Date?,
        sourceDataLoadedAt: Date?,
        fetchedAt: Date
    ) {
        self.incidents = incidents
        self.sourceDataAsOf = sourceDataAsOf
        self.sourceDataLoadedAt = sourceDataLoadedAt
        self.fetchedAt = fetchedAt
    }

    public var freshness: FreshnessMetadata {
        FreshnessMetadata(
            fetchedAt: fetchedAt,
            sourceDataAsOf: sourceDataAsOf,
            sourceDataLoadedAt: sourceDataLoadedAt,
            staleAfterSeconds: MeshBackendDefaults.staleAfterSeconds
        )
    }
}

public enum MeshBackendDefaults {
    public static let dataSFLimit = 500
    public static let staleAfterSeconds: TimeInterval = 15 * 60
}

public struct DataSFDispatchedCall: Decodable, Equatable {
    public let id: String?
    public let receivedDatetime: String?
    public let entryDatetime: String?
    public let dispatchDatetime: String?
    public let enrouteDatetime: String?
    public let onsceneDatetime: String?
    public let closeDatetime: String?
    public let callTypeOriginalDescription: String?
    public let callTypeFinalDescription: String?
    public let priorityOriginal: String?
    public let priorityFinal: String?
    public let agency: String?
    public let disposition: String?
    public let sensitiveCall: Bool?
    public let intersectionName: String?
    public let intersectionPoint: DataSFPoint?
    public let analysisNeighborhood: String?
    public let policeDistrict: String?
    public let callLastUpdatedAt: String?
    public let dataAsOf: String?
    public let dataLoadedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case receivedDatetime = "received_datetime"
        case entryDatetime = "entry_datetime"
        case dispatchDatetime = "dispatch_datetime"
        case enrouteDatetime = "enroute_datetime"
        case onsceneDatetime = "onscene_datetime"
        case closeDatetime = "close_datetime"
        case callTypeOriginalDescription = "call_type_original_desc"
        case callTypeFinalDescription = "call_type_final_desc"
        case priorityOriginal = "priority_original"
        case priorityFinal = "priority_final"
        case agency
        case disposition
        case sensitiveCall = "sensitive_call"
        case intersectionName = "intersection_name"
        case intersectionPoint = "intersection_point"
        case analysisNeighborhood = "analysis_neighborhood"
        case policeDistrict = "police_district"
        case callLastUpdatedAt = "call_last_updated_at"
        case dataAsOf = "data_as_of"
        case dataLoadedAt = "data_loaded_at"
    }
}

public struct DataSFPoint: Decodable, Equatable {
    public let type: String?
    public let coordinates: [Double]

    public var coordinate: CoordinatePayload? {
        guard coordinates.count >= 2 else {
            return nil
        }
        return CoordinatePayload(latitude: coordinates[1], longitude: coordinates[0])
    }
}

public enum DataSFNormalizer {
    public static func snapshot(from data: Data, fetchedAt: Date) throws -> DataSFIncidentSnapshot {
        let calls = try JSONDecoder().decode([DataSFDispatchedCall].self, from: data)
        return DataSFIncidentSnapshot(
            incidents: calls.compactMap(normalize),
            sourceDataAsOf: newestDate(from: calls.map(\.dataAsOf)),
            sourceDataLoadedAt: newestDate(from: calls.map(\.dataLoadedAt)),
            fetchedAt: fetchedAt
        )
    }

    public static func normalize(_ call: DataSFDispatchedCall) -> IncidentPayload? {
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

        let rawType = call.callTypeFinalDescription
            ?? call.callTypeOriginalDescription
            ?? "Dispatched Call"
        let type = normalizeCallType(rawType)
        let agencyName = normalizeAgencyName(call.agency)
        let districtName = call.policeDistrict ?? call.analysisNeighborhood ?? MeshBackendContract.supportedRegionName
        let priority = call.priorityFinal ?? call.priorityOriginal

        return IncidentPayload(
            id: "datasf:gnap-fj3t:\(sourceId)",
            type: type,
            description: incidentDescription(for: call, fallbackType: type),
            agencyType: normalizeAgencyType(call.agency),
            agencyId: normalizedIdentifier(agencyName),
            agencyName: agencyName,
            districtId: normalizedIdentifier(districtName),
            districtName: districtName.capitalized,
            status: normalizeStatus(for: call),
            severity: normalizeSeverity(priority),
            location: coordinate,
            address: call.intersectionName ?? call.analysisNeighborhood ?? MeshBackendContract.supportedRegionName,
            reportedAt: reportedAt,
            updatedAt: parseDataSFDate(call.callLastUpdatedAt) ?? parseDataSFDate(call.closeDatetime) ?? reportedAt,
            respondingUnits: [],
            notes: []
        )
    }

    public static func parseDataSFDate(_ value: String?) -> Date? {
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

    private static func newestDate(from values: [String?]) -> Date? {
        values.compactMap(parseDataSFDate).max()
    }

    private static func normalizeStatus(for call: DataSFDispatchedCall) -> String {
        if parseDataSFDate(call.closeDatetime) != nil {
            return "Closed"
        }
        if parseDataSFDate(call.onsceneDatetime) != nil {
            return "On Scene"
        }
        if parseDataSFDate(call.dispatchDatetime) != nil || parseDataSFDate(call.enrouteDatetime) != nil {
            return "Responding"
        }
        return "Active"
    }

    private static func normalizeSeverity(_ priority: String?) -> Int {
        switch priority?.uppercased() {
        case "A": return 4
        case "B": return 3
        case "C": return 2
        case "I": return 1
        default: return 2
        }
    }

    private static func normalizeAgencyType(_ agency: String?) -> String {
        let normalized = agency?.lowercased() ?? ""
        if normalized.contains("mta") || normalized.contains("transportation") {
            return "Transit"
        }
        if normalized.contains("fire") {
            return "Fire"
        }
        if normalized.contains("ems") || normalized.contains("medical") || normalized.contains("ambulance") {
            return "EMS"
        }
        if normalized.contains("911") || normalized.contains("emergency management") {
            return "911"
        }
        return "Police"
    }

    private static func normalizeAgencyName(_ agency: String?) -> String {
        let normalized = agency?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if normalized.contains("municipal transportation") || normalized == "mta" {
            return "San Francisco Municipal Transportation Agency"
        }
        if normalized.contains("fire") {
            return "San Francisco Fire Department"
        }
        if normalized.contains("ems") || normalized.contains("medical") || normalized.contains("ambulance") {
            return "San Francisco EMS"
        }
        if normalized.contains("911") || normalized.contains("emergency management") {
            return "San Francisco Department of Emergency Management"
        }
        if normalized.contains("sheriff") {
            return "San Francisco Sheriff's Office"
        }
        if normalized.contains("police") {
            return "San Francisco Police Department"
        }
        return agency?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "San Francisco Public Safety"
    }

    private static func normalizeCallType(_ value: String) -> String {
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

    private static func normalizedIdentifier(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func incidentDescription(for call: DataSFDispatchedCall, fallbackType: String) -> String {
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
