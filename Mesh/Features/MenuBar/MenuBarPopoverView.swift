import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            MenuBarHeader()
            
            Divider()
                .background(MeshTheme.Colors.border)
            
            // Quick Stats
            MenuBarQuickStats()
            
            Divider()
                .background(MeshTheme.Colors.border)
            
            // Recent Incidents
            MenuBarRecentIncidents()
            
            Divider()
                .background(MeshTheme.Colors.border)
            
            // Surge Alerts
            if !appState.topSurgeAlerts.isEmpty {
                MenuBarSurgeAlerts()
                Divider()
                    .background(MeshTheme.Colors.border)
            }
            
            // Actions
            MenuBarActions()
        }
        .frame(width: 340)
        .background(Color.white)
        .preferredColorScheme(.light)
    }
}

struct MenuBarHeader: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            // Logo and title
            HStack(spacing: MeshTheme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: MeshTheme.Radius.sm)
                        .fill(MeshTheme.Colors.primaryGradient)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mesh")
                        .font(MeshTheme.Typography.headlineFont)
                        .foregroundColor(MeshTheme.Colors.foreground)
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(appState.dataConnectionState.color)
                            .frame(width: 7, height: 7)
                        Text(appState.dataMode == .replay ? "Replay Training" : appState.dataConnectionState.label)
                            .font(MeshTheme.Typography.caption2Font)
                            .foregroundColor(MeshTheme.Colors.mutedForeground)
                    }
                }
            }
            
            Spacer()
            
            // System status indicator
            HStack(spacing: 5) {
                Image(systemName: appState.systemStatus.icon)
                    .font(.system(size: 12))
                    .foregroundColor(appState.systemStatus.color)
                Text(appState.systemStatus.rawValue)
                    .font(MeshTheme.Typography.captionFont)
                    .foregroundColor(appState.systemStatus.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(appState.systemStatus.color.opacity(0.12))
            .cornerRadius(MeshTheme.Radius.sm)
        }
        .padding(MeshTheme.Spacing.md)
        .background(Color.white)
    }
}

struct MenuBarQuickStats: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: MeshTheme.Spacing.md) {
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
        .padding(MeshTheme.Spacing.md)
        .background(MeshTheme.Colors.backgroundSecondary.opacity(0.5))
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
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(MeshTheme.Colors.foreground)
            }
            
            Text(label)
                .font(MeshTheme.Typography.caption2Font)
                .foregroundColor(MeshTheme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MenuBarRecentIncidents: View {
    @EnvironmentObject var appState: AppState

    private var recentIncidents: [Incident] {
        let activeIncidents = appState.incidents.filter { $0.status.isOperationallyActive }
        return Array(activeIncidents.sorted { incident1, incident2 in
            if incident1.severity != incident2.severity {
                return incident1.severity > incident2.severity
            }
            return incident1.updatedAt > incident2.updatedAt
        }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MeshTheme.Spacing.sm) {
            HStack {
                Text(appState.dataMode == .replay ? "Replay Incidents" : "Recent Incidents")
                    .font(MeshTheme.Typography.captionFont)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                
                Spacer()
                
                Text("\(appState.activeIncidentCount) total")
                    .font(MeshTheme.Typography.caption2Font)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
            }
            
            if recentIncidents.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        Text("No active incidents")
                            .font(MeshTheme.Typography.captionFont)
                            .foregroundColor(MeshTheme.Colors.mutedForeground)
                    }
                    Spacer()
                }
                .padding(.vertical, MeshTheme.Spacing.sm)
            } else {
                ForEach(recentIncidents) { incident in
                    MenuBarIncidentRow(incident: incident)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: recentIncidents.map { $0.id })
            }
        }
        .padding(MeshTheme.Spacing.md)
        .background(Color.white)
    }
}

struct MenuBarIncidentRow: View {
    let incident: Incident
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: MeshTheme.Spacing.sm) {
            Image(systemName: incident.agencyType.icon)
                .font(.system(size: 13))
                .foregroundColor(incident.agencyType.color)
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(incident.type)
                    .font(MeshTheme.Typography.bodyFont)
                    .foregroundColor(MeshTheme.Colors.foreground)
                    .lineLimit(1)

                Text(incident.address)
                    .font(MeshTheme.Typography.captionFont)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Circle()
                    .fill(incident.severity.color)
                    .frame(width: 10, height: 10)

                Text(incident.timeAgo)
                    .font(MeshTheme.Typography.captionFont)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
            }
        }
        .padding(MeshTheme.Spacing.sm)
        .background(isHovered ? MeshTheme.Colors.backgroundSecondary : Color.clear)
        .cornerRadius(MeshTheme.Radius.sm)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct MenuBarSurgeAlerts: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: MeshTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Text("Surge Alerts")
                    .font(MeshTheme.Typography.captionFont)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
            }
            
            ForEach(appState.topSurgeAlerts) { alert in
                HStack {
                    Circle()
                        .fill(alert.severity.color)
                        .frame(width: 8, height: 8)
                    
                    Text(alert.districtName)
                        .font(MeshTheme.Typography.captionFont)
                        .foregroundColor(MeshTheme.Colors.foreground)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: alert.trend.icon)
                            .font(.system(size: 10))
                        Text("+\(Int(alert.percentageIncrease))%")
                            .font(MeshTheme.Typography.captionFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(alert.severity.color)
                }
            }
        }
        .padding(MeshTheme.Spacing.md)
        .background(MeshTheme.Colors.warning.opacity(0.05))
    }
}

struct MenuBarActions: View {
    @State private var isHoveringDashboard = false
    @State private var isHoveringRefresh = false
    @State private var isHoveringSettings = false
    @State private var isHoveringQuit = false
    
    var body: some View {
        VStack(spacing: 4) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("Mesh") || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    // Open new window if none exists
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                        .font(.system(size: 13))
                        .foregroundColor(MeshTheme.Colors.foreground)
                    Text("Open Dashboard")
                        .font(MeshTheme.Typography.bodyFont)
                        .foregroundColor(MeshTheme.Colors.foreground)
                    Spacer()
                    Text("⌘D")
                        .font(MeshTheme.Typography.caption2Font)
                        .foregroundColor(MeshTheme.Colors.mutedForeground)
                }
                .padding(.horizontal, MeshTheme.Spacing.md)
                .padding(.vertical, MeshTheme.Spacing.sm)
                .background(isHoveringDashboard ? MeshTheme.Colors.backgroundSecondary : Color.clear)
                .cornerRadius(MeshTheme.Radius.sm)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHoveringDashboard = hovering }
            
            Button {
                Task {
                    await AppState.shared.refreshData()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(MeshTheme.Colors.foreground)
                    Text("Refresh Data")
                        .font(MeshTheme.Typography.bodyFont)
                        .foregroundColor(MeshTheme.Colors.foreground)
                    Spacer()
                    Text("⌘R")
                        .font(MeshTheme.Typography.caption2Font)
                        .foregroundColor(MeshTheme.Colors.mutedForeground)
                }
                .padding(.horizontal, MeshTheme.Spacing.md)
                .padding(.vertical, MeshTheme.Spacing.sm)
                .background(isHoveringRefresh ? MeshTheme.Colors.backgroundSecondary : Color.clear)
                .cornerRadius(MeshTheme.Radius.sm)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHoveringRefresh = hovering }
            
            Divider()
                .padding(.horizontal, MeshTheme.Spacing.md)
                .background(MeshTheme.Colors.border)
            
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                HStack {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                        .foregroundColor(MeshTheme.Colors.foreground)
                    Text("Settings")
                        .font(MeshTheme.Typography.bodyFont)
                        .foregroundColor(MeshTheme.Colors.foreground)
                    Spacer()
                    Text("⌘,")
                        .font(MeshTheme.Typography.caption2Font)
                        .foregroundColor(MeshTheme.Colors.mutedForeground)
                }
                .padding(.horizontal, MeshTheme.Spacing.md)
                .padding(.vertical, MeshTheme.Spacing.sm)
                .background(isHoveringSettings ? MeshTheme.Colors.backgroundSecondary : Color.clear)
                .cornerRadius(MeshTheme.Radius.sm)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHoveringSettings = hovering }
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 13))
                        .foregroundColor(MeshTheme.Colors.danger)
                    Text("Quit Mesh")
                        .font(MeshTheme.Typography.bodyFont)
                        .foregroundColor(MeshTheme.Colors.danger)
                    Spacer()
                    Text("⌘Q")
                        .font(MeshTheme.Typography.caption2Font)
                        .foregroundColor(MeshTheme.Colors.mutedForeground)
                }
                .padding(.horizontal, MeshTheme.Spacing.md)
                .padding(.vertical, MeshTheme.Spacing.sm)
                .background(isHoveringQuit ? MeshTheme.Colors.danger.opacity(0.1) : Color.clear)
                .cornerRadius(MeshTheme.Radius.sm)
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHoveringQuit = hovering }
        }
        .padding(.vertical, MeshTheme.Spacing.sm)
        .background(Color.white)
    }
}

struct MenuBarIconView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 14))
            
            if appState.systemStatus != .normal {
                Circle()
                    .fill(appState.systemStatus.color)
                    .frame(width: 7, height: 7)
            }
        }
    }
}

#Preview {
    MenuBarPopoverView()
        .environmentObject(AppState.shared)
}
