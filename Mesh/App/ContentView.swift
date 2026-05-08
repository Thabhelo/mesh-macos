import SwiftUI

// MARK: - Main Content View
// Handles routing between Welcome and Main App views

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            if appState.showWelcome {
                WelcomeView()
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                MainAppView()
                    .transition(.opacity)
                    .zIndex(0)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.showWelcome)
    }
}

// MARK: - Main App View

struct MainAppView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Light theme background
            LightThemeBackground()
            
            // Main content
            NavigationSplitView {
                AppSidebar()
            } detail: {
                DetailView()
            }
            .navigationSplitViewStyle(.balanced)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Back to Home button
                Button {
                    Task { @MainActor in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            appState.showWelcome = true
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 12, weight: .medium))
                        Text("Home")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(MeshTheme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Back to Welcome")
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                ConnectionStatusView()

                Button {
                    if appState.dataMode == .live {
                        appState.enterReplayMode()
                    } else {
                        appState.enterLiveMode()
                    }
                } label: {
                    Text(appState.dataMode == .live ? "Start Drill" : "Return Live")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(appState.dataMode == .live ? MeshTheme.Colors.primary : .blue)
                }
                .buttonStyle(.plain)
                .help(appState.dataMode == .live ? "Start a San Francisco training drill" : "Return to live monitoring")
                
                Button {
                    Task {
                        await appState.refreshData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                }
                .help("Refresh data")
                .disabled(appState.dataMode == .replay)
            }
        }
    }
}

// MARK: - App Sidebar

struct AppSidebar: View {
    @EnvironmentObject var appState: AppState

    private var visibleTabs: [AppTab] {
        appState.dataMode == .replay ? AppTab.allCases : AppTab.productionTabs
    }
    
    var body: some View {
        List(selection: $appState.selectedTab) {
            // Navigation Section
            Section {
                ForEach(visibleTabs) { tab in
                    NavigationLink(value: tab) {
                        HStack(spacing: 12) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 15))
                                .foregroundColor(appState.selectedTab == tab ? MeshTheme.Colors.primary : MeshTheme.Colors.foregroundSecondary)
                                .frame(width: 22)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(MeshTheme.Colors.foreground)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("NAVIGATION")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                    .tracking(0.5)
            }

            Section {
                DataModeControl()
            } header: {
                Text("MONITORING MODE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                    .tracking(0.5)
            }
            
            // Quick Stats Section
            Section {
                StatRow(
                    icon: "exclamationmark.circle.fill",
                    iconColor: .orange,
                    label: "Active Incidents",
                    value: "\(appState.activeIncidentCount)"
                )
                
                StatRow(
                    icon: appState.systemStatus.icon,
                    iconColor: appState.systemStatus.color,
                    label: "System Status",
                    value: appState.systemStatus.rawValue,
                    valueColor: appState.systemStatus.color
                )
                
            } header: {
                Text("QUICK STATS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                    .tracking(0.5)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 260)
        .background(Color.white.opacity(0.6))
    }
}

struct DataModeControl: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(appState.dataMode.label, systemImage: appState.dataMode == .live ? "antenna.radiowaves.left.and.right" : "play.rectangle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(appState.dataMode == .live ? .green : .blue)

                Text(appState.dataMode.detail)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)

                if appState.dataMode == .live {
                    Text("\(appState.liveDataSource.regionName) • \(appState.liveDataSource.name)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                if appState.dataMode == .live {
                    appState.enterReplayMode()
                } else {
                    appState.enterLiveMode()
                }
            } label: {
                Text(appState.dataMode == .live ? "Start Training Drill" : "Return to Live Monitoring")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if appState.dataMode == .replay {
                ReplayControls()
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReplayControls: View {
    @EnvironmentObject var appState: AppState

    private var currentStepText: String {
        "Step \(appState.replayFrameIndex + 1) of \(appState.replayFrames.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentStepText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.blue)

            HStack(spacing: 6) {
                Button {
                    appState.replayStepBackward()
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(appState.replayFrameIndex == 0)

                Button {
                    appState.toggleReplayPlayback()
                } label: {
                    Image(systemName: appState.replayPlaybackState == .playing ? "pause.fill" : "play.fill")
                }

                Button {
                    appState.replayStepForward()
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(appState.replayFrameIndex >= appState.replayFrames.count - 1)

                Button(appState.replaySpeed.label) {
                    appState.cycleReplaySpeed()
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))

                Button {
                    appState.resetReplay()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if let frame = appState.currentReplayFrame {
                Text(frame.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MeshTheme.Colors.foreground)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var valueColor: Color? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(MeshTheme.Colors.foreground)
            
            Spacer()
            
            if let color = valueColor {
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .cornerRadius(6)
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(MeshTheme.Colors.foreground)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detail View

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
        .background(MeshTheme.Colors.backgroundSecondary.opacity(0.3))
    }
}

// MARK: - Connection Status View

struct ConnectionStatusView: View {
    @EnvironmentObject var appState: AppState

    private var detailText: String? {
        ConnectionStatusDetailFormatter.detailText(
            dataMode: appState.dataMode,
            connectionState: appState.dataConnectionState,
            error: appState.incidentRefreshError,
            recoverySuggestion: appState.incidentRefreshRecoverySuggestion,
            lastIncidentRefreshAt: appState.lastIncidentRefreshAt
        )
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.dataConnectionState.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(appState.dataConnectionState.label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(MeshTheme.Colors.foregroundSecondary)

                if let detailText {
                    Text(detailText)
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundColor(MeshTheme.Colors.mutedForeground)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.9))
                .shadow(color: MeshTheme.Shadows.small, radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(MeshTheme.Colors.border, lineWidth: 1)
        )
        .help(detailText ?? "\(appState.liveDataSource.regionName) live monitoring via \(appState.liveDataSource.name)")
    }
}

enum ConnectionStatusDetailFormatter {
    static func detailText(
        dataMode: DataMode,
        connectionState: DataConnectionState,
        error: String?,
        recoverySuggestion: String?,
        lastIncidentRefreshAt: Date?,
        relativeTo referenceDate: Date = Date()
    ) -> String? {
        if dataMode == .replay {
            return "Training drill, not live monitoring"
        }

        if let error, connectionState == .error || connectionState == .offline {
            guard let recoverySuggestion, !recoverySuggestion.isEmpty else {
                return error
            }
            return "\(error) \(recoverySuggestion)"
        }

        guard let lastIncidentRefreshAt else {
            return nil
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastIncidentRefreshAt, relativeTo: referenceDate))"
    }
}

// MARK: - Settings View

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
        .frame(width: 500, height: 400)
        .preferredColorScheme(.light)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Region", value: appState.liveDataSource.regionName)
                    .font(.system(size: 14, design: .rounded))

                LabeledContent("Source", value: appState.liveDataSource.name)
                    .font(.system(size: 14, design: .rounded))

                LabeledContent("Dataset", value: appState.liveDataSource.datasetIdentifier)
                    .font(.system(size: 14, design: .rounded))

                LabeledContent("Cadence", value: appState.liveDataSource.updateCadence)
                    .font(.system(size: 14, design: .rounded))

                if let sourceDataAsOf = appState.sourceDataAsOf {
                    LabeledContent("Source as of", value: sourceDataAsOf.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14, design: .rounded))
                }
            } header: {
                Text("Live Data Source")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }

            Section {
                Toggle("Show active incidents only", isOn: $appState.showActiveOnly)
                    .font(.system(size: 14, design: .rounded))
            } header: {
                Text("Display Options")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            
            Section {
                ForEach(appState.availableAgencyTypes, id: \.self) { type in
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
                    .font(.system(size: 14, design: .rounded))
                }
            } header: {
                Text("Agency Filters")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 14, design: .rounded))
                
                Toggle("Critical alerts only", isOn: $appState.criticalAlertsOnly)
                    .font(.system(size: 14, design: .rounded))
                    .disabled(!appState.notificationsEnabled)
            } header: {
                Text("Notification Preferences")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
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
