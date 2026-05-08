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

            QuickStatsHUD()
                .padding(.trailing, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .allowsHitTesting(false)
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
                            .font(MeshTheme.Typography.caption)
                        Text("Home")
                            .font(MeshTheme.Typography.caption)
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
                    Task {
                        await appState.refreshData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(MeshTheme.Typography.caption)
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

    private var elevatedSurgeCount: Int {
        appState.surgeAlerts.filter { $0.severity >= .elevated }.count
    }

    private var hazardValue: String {
        guard let hazard = appState.hazardScore else { return "--" }
        return "\(hazard.overallScore)"
    }
    
    var body: some View {
        List(selection: $appState.selectedTab) {
            Section {
                DataModeControl()
            } header: {
                Text("DRILL")
                    .font(MeshTheme.Typography.sectionLabel)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                    .tracking(0.5)
            }

            Section {
                OperationalMetricCard(
                    tab: .dashboard,
                    title: "Incidents",
                    value: "\(appState.activeIncidentCount)",
                    subtitle: "active now",
                    icon: "exclamationmark.circle.fill",
                    tint: .orange
                )

                OperationalMetricCard(
                    tab: .map,
                    title: "Map",
                    value: "\(appState.districts.count)",
                    subtitle: "districts",
                    icon: "map.fill",
                    tint: .blue
                )

                OperationalMetricCard(
                    tab: .surge,
                    title: "Surge",
                    value: "\(elevatedSurgeCount)",
                    subtitle: "elevated alerts",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: .orange
                )

                OperationalMetricCard(
                    tab: .hazard,
                    title: "Hazard",
                    value: hazardValue,
                    subtitle: appState.hazardScore?.statusLabel ?? "calculating",
                    icon: "exclamationmark.triangle.fill",
                    tint: appState.hazardScore?.statusColor ?? MeshTheme.Colors.mutedForeground
                )
            } header: {
                Text("OPERATIONS")
                    .font(MeshTheme.Typography.sectionLabel)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                    .tracking(0.5)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 260)
        .background(Color.white.opacity(0.6))
    }
}

struct OperationalMetricCard: View {
    @EnvironmentObject var appState: AppState

    let tab: AppTab
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    private var isSelected: Bool {
        appState.selectedTab == tab
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                appState.selectedTab = tab
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tint.opacity(isSelected ? 0.18 : 0.10))
                    Image(systemName: icon)
                        .font(MeshTheme.Typography.caption)
                        .foregroundColor(tint)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MeshTheme.Typography.bodySemibold)
                        .foregroundColor(MeshTheme.Colors.foreground)
                    Text(subtitle)
                        .font(MeshTheme.Typography.micro)
                        .foregroundColor(MeshTheme.Colors.mutedForeground)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(value)
                    .font(MeshTheme.Typography.metricSmall)
                    .foregroundColor(isSelected ? tint : MeshTheme.Colors.foreground)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? tint.opacity(0.42) : MeshTheme.Colors.border.opacity(0.65), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct QuickStatsHUD: View {
    @EnvironmentObject var appState: AppState

    private var elevatedSurges: Int {
        appState.surgeAlerts.filter { $0.severity >= .elevated }.count
    }

    var body: some View {
        HStack(spacing: 14) {
            HUDMetric(
                label: "Active",
                value: "\(appState.activeIncidentCount)",
                color: .orange
            )

            HUDMetric(
                label: "System",
                value: appState.systemStatus.rawValue,
                color: appState.systemStatus.color
            )

            HUDMetric(
                label: "Surge",
                value: "\(elevatedSurges)",
                color: elevatedSurges > 0 ? .orange : MeshTheme.Colors.mutedForeground
            )

            if let hazard = appState.hazardScore {
                HUDMetric(
                    label: "Hazard",
                    value: "\(hazard.overallScore)",
                    color: hazard.statusColor
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassmorphism(cornerRadius: 18, opacity: 0.22)
        .opacity(0.74)
    }
}

struct HUDMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(MeshTheme.Typography.micro)
                .foregroundColor(MeshTheme.Colors.mutedForeground)
                .tracking(0.7)
            Text(value)
                .font(MeshTheme.Typography.metricTiny)
                .foregroundColor(color)
                .monospacedDigit()
        }
        .frame(minWidth: 48, alignment: .leading)
    }
}

struct DataModeControl: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(appState.dataMode.label, systemImage: appState.dataMode == .live ? "antenna.radiowaves.left.and.right" : "play.rectangle.fill")
                    .font(MeshTheme.Typography.callout)
                    .foregroundColor(appState.dataMode == .live ? .green : .blue)

                Text(appState.dataMode.detail)
                    .font(MeshTheme.Typography.caption)
                    .foregroundColor(MeshTheme.Colors.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)

                if appState.dataMode == .live {
                    Text("\(appState.liveDataSource.regionName) • \(appState.incidentDataSource.label)")
                        .font(MeshTheme.Typography.caption)
                        .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let notice = appState.incidentDataSourceNotice {
                    Text(notice)
                        .font(MeshTheme.Typography.micro)
                        .foregroundColor(.orange)
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
                .font(MeshTheme.Typography.sectionLabel)
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
                .font(MeshTheme.Typography.sectionLabel)

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
                    .font(MeshTheme.Typography.caption)
                    .foregroundColor(MeshTheme.Colors.foreground)
                    .lineLimit(2)
            }
        }
    }
}

private extension IncidentDataSource {
    var label: String {
        switch self {
        case .meshBackend:
            return "Mesh Backend"
        case .dataSFDevelopmentFallback:
            return "DataSF Direct Fallback"
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
                .font(MeshTheme.Typography.callout)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(label)
                .font(MeshTheme.Typography.body)
                .foregroundColor(MeshTheme.Colors.foreground)
            
            Spacer()
            
            if let color = valueColor {
                Text(value)
                    .font(MeshTheme.Typography.caption)
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .cornerRadius(6)
            } else {
                Text(value)
                    .font(MeshTheme.Typography.bodySemibold)
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
                    .font(MeshTheme.Typography.caption)
                    .foregroundColor(MeshTheme.Colors.foregroundSecondary)

                if let detailText {
                    Text(detailText)
                        .font(MeshTheme.Typography.micro)
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
                    .font(MeshTheme.Typography.body)

                LabeledContent("Source", value: appState.liveDataSource.name)
                    .font(MeshTheme.Typography.body)

                LabeledContent("Dataset", value: appState.liveDataSource.datasetIdentifier)
                    .font(MeshTheme.Typography.body)

                LabeledContent("Cadence", value: appState.liveDataSource.updateCadence)
                    .font(MeshTheme.Typography.body)

                if let sourceDataAsOf = appState.sourceDataAsOf {
                    LabeledContent("Source as of", value: sourceDataAsOf.formatted(date: .abbreviated, time: .shortened))
                        .font(MeshTheme.Typography.body)
                }
            } header: {
                Text("Live Data Source")
                    .font(MeshTheme.Typography.caption)
            }

            Section {
                Toggle("Show active incidents only", isOn: $appState.showActiveOnly)
                    .font(MeshTheme.Typography.body)
            } header: {
                Text("Display Options")
                    .font(MeshTheme.Typography.caption)
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
                    .font(MeshTheme.Typography.body)
                }
            } header: {
                Text("Agency Filters")
                    .font(MeshTheme.Typography.caption)
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
                    .font(MeshTheme.Typography.body)
                
                Toggle("Critical alerts only", isOn: $appState.criticalAlertsOnly)
                    .font(MeshTheme.Typography.body)
                    .disabled(!appState.notificationsEnabled)
            } header: {
                Text("Notification Preferences")
                    .font(MeshTheme.Typography.caption)
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
