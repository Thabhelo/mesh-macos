import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedIncident: Incident?
    @State private var isLoading = false
    
    var body: some View {
        HSplitView {
            // Incident List
            VStack(spacing: 0) {
                // Header with filters
                DashboardHeaderView()
                
                Divider()
                
                // Incident list
                if isLoading {
                    ProgressView("Loading incidents...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if appState.filteredIncidents.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "No Active Incidents",
                        message: "All clear! No incidents match your current filters."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.filteredIncidents) { incident in
                                IncidentCard(incident: incident, isSelected: selectedIncident?.id == incident.id)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedIncident = incident
                                            appState.selectIncident(incident)
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(minWidth: 400, idealWidth: 500)
            
            // Detail Panel
            if let incident = selectedIncident {
                IncidentDetailView(incident: incident)
                    .frame(minWidth: 350, idealWidth: 450)
            } else {
                EmptyStateView(
                    icon: "hand.point.left",
                    title: "Select an Incident",
                    message: "Choose an incident from the list to view details"
                )
                .frame(minWidth: 350, idealWidth: 450)
            }
        }
        .onAppear {
            if let firstIncident = appState.filteredIncidents.first {
                selectedIncident = firstIncident
            }
        }
    }
}

struct DashboardHeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Real-Time Incidents")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(appState.filteredIncidents.count) incidents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Quick filters
            HStack(spacing: 8) {
                ForEach(AgencyType.allCases) { type in
                    FilterChip(
                        title: type.rawValue,
                        icon: type.icon,
                        color: type.color,
                        isSelected: appState.selectedAgencyTypes.contains(type)
                    ) {
                        if appState.selectedAgencyTypes.contains(type) {
                            appState.selectedAgencyTypes.remove(type)
                        } else {
                            appState.selectedAgencyTypes.insert(type)
                        }
                    }
                }
                
                Spacer()
                
                Toggle(isOn: $appState.showActiveOnly) {
                    Text("Active only")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? color.opacity(0.2) : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct IncidentCard: View {
    let incident: Incident
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Agency type indicator
            VStack {
                Image(systemName: incident.agencyType.icon)
                    .font(.title2)
                    .foregroundColor(incident.agencyType.color)
                
                Circle()
                    .fill(incident.status.color)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 40)
            
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(incident.type)
                        .font(.headline)
                    
                    Spacer()
                    
                    SeverityBadge(severity: incident.severity)
                }
                
                Text(incident.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(incident.districtName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(incident.timeAgo)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Responding units
                if !incident.respondingUnits.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(incident.respondingUnits.count) units")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(incident.respondingUnits.prefix(3)) { unit in
                            Text(unit.unitName)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(unit.agencyType.color.opacity(0.2))
                                .foregroundColor(unit.agencyType.color)
                                .cornerRadius(4)
                        }
                        
                        if incident.respondingUnits.count > 3 {
                            Text("+\(incident.respondingUnits.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

struct SeverityBadge: View {
    let severity: IncidentSeverity
    
    var body: some View {
        Text(severity.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severity.color.opacity(0.2))
            .foregroundColor(severity.color)
            .cornerRadius(4)
    }
}

struct IncidentDetailView: View {
    let incident: Incident
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: incident.agencyType.icon)
                            .font(.title)
                            .foregroundColor(incident.agencyType.color)
                        
                        VStack(alignment: .leading) {
                            Text(incident.type)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(incident.agencyName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        SeverityBadge(severity: incident.severity)
                    }
                    
                    Text(incident.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Status and timing
                DetailSection(title: "Status") {
                    HStack {
                        StatusIndicator(status: incident.status)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Reported \(incident.timeAgo)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(incident.reportedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Location
                DetailSection(title: "Location") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(incident.address)
                            .font(.body)
                        
                        Text(incident.districtName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Mini map preview
                        MiniMapPreview(coordinate: incident.coordinate)
                            .frame(height: 150)
                            .cornerRadius(8)
                    }
                }
                
                // Responding Units
                if !incident.respondingUnits.isEmpty {
                    DetailSection(title: "Responding Units (\(incident.respondingUnits.count))") {
                        VStack(spacing: 8) {
                            ForEach(incident.respondingUnits) { unit in
                                RespondingUnitRow(unit: unit)
                            }
                        }
                    }
                }
                
                // Notes
                if let notes = incident.notes, !notes.isEmpty {
                    DetailSection(title: "Notes") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(notes) { note in
                                NoteRow(note: note)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content
        }
    }
}

struct StatusIndicator: View {
    let status: IncidentStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
            
            Text(status.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.15))
        .cornerRadius(6)
    }
}

struct RespondingUnitRow: View {
    let unit: Incident.RespondingUnit
    
    var body: some View {
        HStack {
            Image(systemName: unit.agencyType.icon)
                .foregroundColor(unit.agencyType.color)
                .frame(width: 24)
            
            VStack(alignment: .leading) {
                Text(unit.unitName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(unit.unitId)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(unit.status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let eta = unit.etaMinutes {
                    Text("ETA: \(eta) min")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}

struct NoteRow: View {
    let note: Incident.IncidentNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.author)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(note.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(note.content)
                .font(.body)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState.shared)
        .frame(width: 1000, height: 700)
}

