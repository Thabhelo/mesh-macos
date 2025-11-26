import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            MenuBarHeader()
            
            Divider()
            
            // Quick Stats
            MenuBarQuickStats()
            
            Divider()
            
            // Recent Incidents
            MenuBarRecentIncidents()
            
            Divider()
            
            // Surge Alerts
            if !appState.topSurgeAlerts.isEmpty {
                MenuBarSurgeAlerts()
                Divider()
            }
            
            // Actions
            MenuBarActions()
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MenuBarHeader: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Image(systemName: "shield.checkered")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text("Mesh")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.isConnected ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(appState.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // System status indicator
            HStack(spacing: 4) {
                Image(systemName: appState.systemStatus.icon)
                    .foregroundColor(appState.systemStatus.color)
                Text(appState.systemStatus.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(appState.systemStatus.color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(appState.systemStatus.color.opacity(0.15))
            .cornerRadius(6)
        }
        .padding()
    }
}

struct MenuBarQuickStats: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 16) {
            QuickStatItem(
                value: "\(appState.activeIncidentCount)",
                label: "Active",
                icon: "exclamationmark.circle.fill",
                color: .orange
            )
            
            QuickStatItem(
                value: "\(appState.surgeAlerts.filter { $0.severity >= .elevated }.count)",
                label: "Surges",
                icon: "chart.line.uptrend.xyaxis",
                color: .red
            )
            
            if let hazard = appState.hazardScore {
                QuickStatItem(
                    value: "\(hazard.overallScore)",
                    label: "Hazard",
                    icon: "shield.fill",
                    color: hazard.statusColor
                )
            }
        }
        .padding()
    }
}

struct QuickStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MenuBarRecentIncidents: View {
    @EnvironmentObject var appState: AppState
    
    private var recentIncidents: [Incident] {
        Array(appState.incidents
            .filter { $0.status == .active }
            .sorted { $0.reportedAt > $1.reportedAt }
            .prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Incidents")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(appState.activeIncidentCount) total")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if recentIncidents.isEmpty {
                HStack {
                    Spacer()
                    Text("No active incidents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(recentIncidents) { incident in
                    MenuBarIncidentRow(incident: incident)
                }
            }
        }
        .padding()
    }
}

struct MenuBarIncidentRow: View {
    let incident: Incident
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: incident.agencyType.icon)
                .font(.caption)
                .foregroundColor(incident.agencyType.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(incident.type)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(incident.address)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                SeverityDot(severity: incident.severity)
                
                Text(incident.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(6)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}

struct SeverityDot: View {
    let severity: IncidentSeverity
    
    var body: some View {
        Circle()
            .fill(severity.color)
            .frame(width: 8, height: 8)
    }
}

struct MenuBarSurgeAlerts: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("Surge Alerts")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            
            ForEach(appState.topSurgeAlerts) { alert in
                HStack {
                    Circle()
                        .fill(alert.severity.color)
                        .frame(width: 8, height: 8)
                    
                    Text(alert.districtName)
                        .font(.caption)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: alert.trend.icon)
                            .font(.caption2)
                        Text("+\(Int(alert.percentageIncrease))%")
                            .font(.caption)
                    }
                    .foregroundColor(alert.severity.color)
                }
            }
        }
        .padding()
    }
}

struct MenuBarActions: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "Mesh" || $0.contentView != nil }) {
                    window.makeKeyAndOrderFront(nil)
                }
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Dashboard")
                    Spacer()
                    Text("⌘D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Button {
                Task {
                    await AppState.shared.refreshData()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Data")
                    Spacer()
                    Text("⌘R")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Mesh")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

struct MenuBarIconView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.checkered")
            
            if appState.systemStatus != .normal {
                Circle()
                    .fill(appState.systemStatus.color)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

#Preview {
    MenuBarPopoverView()
        .environmentObject(AppState.shared)
}

