import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ConnectionStatusView()
                
                Button {
                    Task {
                        await appState.refreshData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh data")
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List(selection: $appState.selectedTab) {
            Section("Navigation") {
                ForEach(AppTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            }
            
            Section("Quick Stats") {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Active Incidents")
                    Spacer()
                    Text("\(appState.activeIncidentCount)")
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: appState.systemStatus.icon)
                        .foregroundColor(appState.systemStatus.color)
                    Text("System Status")
                    Spacer()
                    Text(appState.systemStatus.rawValue)
                        .fontWeight(.semibold)
                        .foregroundColor(appState.systemStatus.color)
                }
                
                if let hazard = appState.hazardScore {
                    HStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(hazard.statusColor)
                        Text("Hazard Score")
                        Spacer()
                        Text("\(hazard.overallScore)")
                            .fontWeight(.semibold)
                            .foregroundColor(hazard.statusColor)
                    }
                }
            }
            
            if !appState.topSurgeAlerts.isEmpty {
                Section("Surge Alerts") {
                    ForEach(appState.topSurgeAlerts) { alert in
                        HStack {
                            Circle()
                                .fill(alert.severity.color)
                                .frame(width: 8, height: 8)
                            Text(alert.districtName)
                                .lineLimit(1)
                            Spacer()
                            Text("+\(Int(alert.percentageIncrease))%")
                                .font(.caption)
                                .foregroundColor(alert.severity.color)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
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
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(appState.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
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
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section {
                Toggle("Show active incidents only", isOn: $appState.showActiveOnly)
            } header: {
                Text("Display")
            }
            
            Section {
                Text("Agency Filters")
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
                }
            } header: {
                Text("Filters")
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
                Toggle("Critical alerts only", isOn: $appState.criticalAlertsOnly)
                    .disabled(!appState.notificationsEnabled)
            } header: {
                Text("Notifications")
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

