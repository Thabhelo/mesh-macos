import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.showWelcome {
                WelcomeView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                MainAppView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.showWelcome)
    }
}

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Light theme background
            LightThemeBackground()
            
            NavigationSplitView {
                SidebarView()
            } detail: {
                DetailView()
            }
            .navigationSplitViewStyle(.balanced)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ConnectionStatusView()
                
                Button {
                    Task {
                        await appState.refreshData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .help("Refresh data")
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appState.showWelcome = true
                    }
                } label: {
                    Image(systemName: "house")
                        .font(.system(size: 14, weight: .medium))
                }
                .help("Back to Welcome")
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(selection: $appState.selectedTab) {
            Section {
                ForEach(AppTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            Text(tab.rawValue)
                                .font(MeshTheme.Typography.bodyFont)
                        } icon: {
                            Image(systemName: tab.icon)
                                .foregroundColor(appState.selectedTab == tab ? MeshTheme.Colors.primary : .secondary)
                        }
                    }
                }
            } header: {
                Text("Navigation")
                    .font(MeshTheme.Typography.captionFont)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
            }
            
            Section {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("Active Incidents")
                        .font(MeshTheme.Typography.bodyFont)
                    Spacer()
                    Text("\(appState.activeIncidentCount)")
                        .font(MeshTheme.Typography.headlineFont)
                        .foregroundColor(MeshTheme.Colors.foreground)
                }
                
                HStack {
                    Image(systemName: appState.systemStatus.icon)
                        .foregroundColor(appState.systemStatus.color)
                        .font(.system(size: 14))
                    Text("System Status")
                        .font(MeshTheme.Typography.bodyFont)
                    Spacer()
                    Text(appState.systemStatus.rawValue)
                        .font(MeshTheme.Typography.captionFont)
                        .fontWeight(.semibold)
                        .foregroundColor(appState.systemStatus.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(appState.systemStatus.color.opacity(0.15))
                        .cornerRadius(MeshTheme.Radius.sm)
                }
                
                if let hazard = appState.hazardScore {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(hazard.statusColor)
                            .font(.system(size: 14))
                        Text("Hazard Score")
                            .font(MeshTheme.Typography.bodyFont)
                        Spacer()
                        Text("\(hazard.overallScore)")
                            .font(MeshTheme.Typography.headlineFont)
                            .foregroundColor(hazard.statusColor)
                    }
                }
            } header: {
                Text("Quick Stats")
                    .font(MeshTheme.Typography.captionFont)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
            }
            
            if !appState.topSurgeAlerts.isEmpty {
                Section {
                    ForEach(appState.topSurgeAlerts) { alert in
                        Button {
                            appState.selectedTab = .surge
                        } label: {
                            HStack {
                                Circle()
                                    .fill(alert.severity.color)
                                    .frame(width: 10, height: 10)
                                Text(alert.districtName)
                                    .font(MeshTheme.Typography.bodyFont)
                                    .foregroundColor(MeshTheme.Colors.foreground)
                                    .lineLimit(1)
                                Spacer()
                                Text("+\(Int(alert.percentageIncrease))%")
                                    .font(MeshTheme.Typography.captionFont)
                                    .fontWeight(.semibold)
                                    .foregroundColor(alert.severity.color)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Surge Alerts")
                        .font(MeshTheme.Typography.captionFont)
                        .foregroundColor(MeshTheme.Colors.mutedForeground)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
        .background(Color.white.opacity(0.5))
    }
}

struct DetailView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            switch appState.selectedTab {
            case .dashboard:
                DashboardView()
            case .map:
                MapView()
            case .surge:
                SurgePredictionView()
            case .hazard:
                HazardAnalysisView()
            }
        }
    }
}

struct ConnectionStatusView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(appState.isConnected ? "Connected" : "Disconnected")
                .font(MeshTheme.Typography.captionFont)
                .foregroundColor(MeshTheme.Colors.foregroundSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: MeshTheme.Radius.sm)
                .fill(Color.white.opacity(0.8))
                .shadow(color: MeshTheme.Shadows.small, radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MeshTheme.Radius.sm)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            NotificationSettingsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section {
                Toggle("Show active incidents only", isOn: $appState.showActiveOnly)
                    .font(MeshTheme.Typography.bodyFont)
            } header: {
                Text("Display")
                    .font(MeshTheme.Typography.captionFont)
            }
            
            Section {
                Text("Agency Filters")
                    .font(MeshTheme.Typography.headlineFont)
                ForEach(AgencyType.allCases, id: \.self) { type in
                    Toggle(type.rawValue, isOn: Binding(
                        get: { appState.selectedAgencyTypes.contains(type) },
                        set: { isOn in
                            if isOn {
                                appState.selectedAgencyTypes.insert(type)
                            } else {
                                appState.selectedAgencyTypes.remove(type)
                            }
                        }
                    ))
                    .font(MeshTheme.Typography.bodyFont)
                }
            } header: {
                Text("Filters")
                    .font(MeshTheme.Typography.captionFont)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable notifications", isOn: $appState.notificationsEnabled)
                    .font(MeshTheme.Typography.bodyFont)
                Toggle("Critical alerts only", isOn: $appState.criticalAlertsOnly)
                    .font(MeshTheme.Typography.bodyFont)
                    .disabled(!appState.notificationsEnabled)
            } header: {
                Text("Notifications")
                    .font(MeshTheme.Typography.captionFont)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
}
