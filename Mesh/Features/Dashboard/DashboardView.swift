import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedIncident: Incident?
    @State private var isLoading = false

    private var sortedIncidents: [Incident] {
        appState.filteredIncidents.sorted { incident1, incident2 in
            if incident1.severity != incident2.severity {
                return incident1.severity > incident2.severity
            }
            return incident1.updatedAt > incident2.updatedAt
        }
    }

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
                } else if appState.dataMode == .live,
                          let error = appState.incidentRefreshError,
                          appState.dataConnectionState == .offline || appState.dataConnectionState == .error {
                    IncidentRefreshErrorState(
                        message: error,
                        recoverySuggestion: appState.incidentRefreshRecoverySuggestion
                    ) {
                        Task {
                            await appState.refreshData()
                        }
                    }
                } else if appState.filteredIncidents.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle",
                        title: "No Active Incidents",
                        message: "All clear! No incidents match your current filters."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedIncidents) { incident in
                                IncidentCard(incident: incident, isSelected: selectedIncident?.id == incident.id)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedIncident = incident
                                            appState.selectIncident(incident)
                                        }
                                    }
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .scale.combined(with: .opacity)
                                    ))
                            }
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: sortedIncidents.map { $0.id })
                        .padding()
                    }
                }
            }
            .frame(minWidth: 650, idealWidth: 750)
            
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
        .onChange(of: appState.selectedIncidentId) { _, selectedIncidentId in
            guard let selectedIncidentId else { return }
            selectedIncident = appState.incidents.first { $0.id == selectedIncidentId }
        }
    }
}

struct IncidentRefreshErrorState: View {
    let message: String
    let recoverySuggestion: String?
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundColor(.red)

            Text("Live Incident Refresh Failed")
                .font(MeshTheme.Typography.title3)

            Text(message)
                .font(MeshTheme.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let recoverySuggestion {
                Text(recoverySuggestion)
                    .font(MeshTheme.Typography.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Retry Live Refresh", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct DashboardHeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(appState.dataMode == .replay ? "Training Drill Incidents" : "Real-Time Incidents")
                    .font(MeshTheme.Typography.title)
                
                Spacer()
                
                Text("\(appState.filteredIncidents.count) incidents")
                    .font(MeshTheme.Typography.title3)
                    .foregroundColor(.secondary)
            }
            
            // Quick filters
            HStack(spacing: 8) {
                ForEach(appState.availableAgencyTypes) { type in
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
                        .font(MeshTheme.Typography.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if let frame = appState.currentReplayFrame {
                WalkthroughDecisionCard(frame: frame)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct WalkthroughDecisionCard: View {
    let frame: ReplayScenarioFrame

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("San Francisco Response Drill", systemImage: "play.rectangle.fill")
                    .font(MeshTheme.Typography.headline)
                    .foregroundColor(.blue)

                Spacer()

                Text("Step \(frame.stepNumber)")
                    .font(MeshTheme.Typography.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }

            Text(frame.title)
                .font(MeshTheme.Typography.title3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                WalkthroughFact(title: "What changed", value: frame.whatChanged)
                WalkthroughFact(title: "Why it matters", value: frame.whyItMatters)
                WalkthroughFact(title: "Recommended action", value: frame.recommendedAction)
                WalkthroughFact(title: "Evidence", value: frame.evidence.joined(separator: " • "))
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct WalkthroughFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(MeshTheme.Typography.micro)
                .foregroundColor(.secondary)
            Text(value)
                .font(MeshTheme.Typography.callout)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                    .font(MeshTheme.Typography.caption)
                Text(title)
                    .font(MeshTheme.Typography.caption)
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

    private var priorityExplanation: String {
        var factors = ["\(incident.severity.label) severity"]

        if incident.status.isOperationallyActive {
            factors.append(incident.status.rawValue.lowercased())
        }
        if Date().timeIntervalSince(incident.updatedAt) <= 60 * 60 {
            factors.append("updated within 1h")
        }

        return "Priority: " + factors.joined(separator: " • ")
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Image(systemName: incident.agencyType.icon)
                    .font(MeshTheme.Typography.title2)
                    .foregroundColor(incident.agencyType.color)

                Circle()
                    .fill(incident.status.color)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(incident.type)
                        .font(MeshTheme.Typography.title3)

                    Spacer()

                    SeverityBadge(severity: incident.severity)
                }

                Text(incident.address)
                    .font(MeshTheme.Typography.title3)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack {
                    Text(incident.districtName)
                        .font(MeshTheme.Typography.body)
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(MeshTheme.Typography.callout)
                        Text(incident.timeAgo)
                            .font(MeshTheme.Typography.body)
                    }
                    .foregroundColor(.secondary)
                }
                
                if !incident.respondingUnits.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(MeshTheme.Typography.callout)
                            .foregroundColor(.secondary)

                        Text("\(incident.respondingUnits.count) units")
                            .font(MeshTheme.Typography.body)
                            .foregroundColor(.secondary)

                        ForEach(incident.respondingUnits.prefix(3)) { unit in
                            Text(unit.unitName)
                                .font(MeshTheme.Typography.callout)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(unit.agencyType.color.opacity(0.2))
                                .foregroundColor(unit.agencyType.color)
                                .cornerRadius(4)
                        }

                        if incident.respondingUnits.count > 3 {
                            Text("+\(incident.respondingUnits.count - 3)")
                                .font(MeshTheme.Typography.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Text(priorityExplanation)
                    .font(MeshTheme.Typography.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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
            .font(MeshTheme.Typography.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severity.color.opacity(0.2))
            .foregroundColor(severity.color)
            .cornerRadius(6)
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
                            .font(MeshTheme.Typography.title2)
                            .foregroundColor(incident.agencyType.color)
                        
                        VStack(alignment: .leading) {
                            Text(incident.type)
                                .font(MeshTheme.Typography.title2)
                            
                            Text(incident.agencyName)
                                .font(MeshTheme.Typography.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        SeverityBadge(severity: incident.severity)
                    }
                    
                    Text(incident.description)
                        .font(MeshTheme.Typography.body)
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
                                .font(MeshTheme.Typography.caption)
                                .foregroundColor(.secondary)
                            Text(incident.reportedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(MeshTheme.Typography.micro)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Location
                DetailSection(title: "Location") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(incident.address)
                            .font(MeshTheme.Typography.body)
                        
                        Text(incident.districtName)
                            .font(MeshTheme.Typography.caption)
                            .foregroundColor(.secondary)
                        
                        // Mini map preview
                        MiniMapPreview(coordinate: incident.coordinate)
                            .frame(height: 260)
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
                .font(MeshTheme.Typography.headline)
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
                .font(MeshTheme.Typography.bodySemibold)
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
                    .font(MeshTheme.Typography.bodySemibold)
                
                Text(unit.unitId)
                    .font(MeshTheme.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(unit.status)
                    .font(MeshTheme.Typography.caption)
                    .foregroundColor(.secondary)
                
                if let eta = unit.etaMinutes {
                    Text("ETA: \(eta) min")
                        .font(MeshTheme.Typography.caption)
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
                    .font(MeshTheme.Typography.caption)
                
                Spacer()
                
                Text(note.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(MeshTheme.Typography.micro)
                    .foregroundColor(.secondary)
            }
            
            Text(note.content)
                .font(MeshTheme.Typography.body)
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
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(MeshTheme.Typography.title3)
            
            Text(message)
                .font(MeshTheme.Typography.body)
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

