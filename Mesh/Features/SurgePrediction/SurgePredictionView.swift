import SwiftUI
import Charts

struct SurgePredictionView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDistrict: District?
    @State private var trendData: [SurgeTrendDataPoint] = []
    @State private var timeRange: TimeRange = .day
    
    enum TimeRange: String, CaseIterable {
        case hours6 = "6H"
        case hours12 = "12H"
        case day = "24H"
        case week = "7D"
        
        var hours: Int {
            switch self {
            case .hours6: return 6
            case .hours12: return 12
            case .day: return 24
            case .week: return 168
            }
        }
    }
    
    var body: some View {
        HSplitView {
            // Main content
            VStack(spacing: 0) {
                // Header
                SurgeHeaderView(timeRange: $timeRange)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Overview cards
                        SurgeOverviewCards()
                        
                        // Trend chart
                        SurgeTrendChart(data: trendData, timeRange: timeRange)
                            .frame(height: 250)
                        
                        // District grid
                        DistrictSurgeGrid(
                            districts: appState.districts,
                            incidents: appState.incidents,
                            surgeAlerts: appState.surgeAlerts,
                            selectedDistrict: $selectedDistrict
                        )
                    }
                    .padding()
                }
            }
            .frame(minWidth: 600)
            
            // Detail sidebar
            if let district = selectedDistrict {
                DistrictDetailView(district: district)
                    .frame(width: 350)
            } else {
                EmptyStateView(
                    icon: "building.2",
                    title: "Select a District",
                    message: "Choose a district to view detailed surge information"
                )
                .frame(width: 350)
            }
        }
        .onAppear {
            loadTrendData()
        }
        .onChange(of: timeRange) { _, _ in
            loadTrendData()
        }
        .onChange(of: selectedDistrict?.id) { _, _ in
            loadTrendData()
        }
        .onChange(of: appState.incidents) { _, _ in
            loadTrendData()
        }
    }
    
    private func loadTrendData() {
        trendData = OperationalIntelligenceService.deriveSurgeTrendData(
            incidents: appState.incidents,
            districts: appState.districts,
            districtId: selectedDistrict?.id ?? "all",
            hours: timeRange.hours
        )
    }
}

struct SurgeHeaderView: View {
    @Binding var timeRange: SurgePredictionView.TimeRange
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Surge Prediction")
                    .font(MeshTheme.Typography.title)

                Text("Real-time call volume analysis and predictions")
                    .font(MeshTheme.Typography.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Picker("Time Range", selection: $timeRange) {
                ForEach(SurgePredictionView.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SurgeOverviewCards: View {
    @EnvironmentObject var appState: AppState
    
    private var criticalCount: Int {
        appState.surgeAlerts.filter { $0.severity == .critical }.count
    }
    
    private var elevatedCount: Int {
        appState.surgeAlerts.filter { $0.severity >= .elevated }.count
    }
    
    private var avgIncrease: Double {
        let alerts = appState.surgeAlerts.filter { $0.severity >= .elevated }
        guard !alerts.isEmpty else { return 0 }
        return alerts.reduce(0) { $0 + $1.percentageIncrease } / Double(alerts.count)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            SurgeOverviewCard(
                title: "Critical Surges",
                value: "\(criticalCount)",
                subtitle: "Requires immediate attention",
                icon: "exclamationmark.octagon.fill",
                color: .red
            )
            
            SurgeOverviewCard(
                title: "Elevated Districts",
                value: "\(elevatedCount)",
                subtitle: "Above normal thresholds",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
            
            SurgeOverviewCard(
                title: "Avg Volume Increase",
                value: String(format: "+%.0f%%", avgIncrease),
                subtitle: "Across affected districts",
                icon: "arrow.up.right",
                color: .yellow
            )
            
            SurgeOverviewCard(
                title: "Districts Monitored",
                value: "\(appState.districts.count)",
                subtitle: "Real-time tracking",
                icon: "building.2.fill",
                color: .green
            )
        }
    }
}

struct SurgeOverviewCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(MeshTheme.Typography.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(MeshTheme.Typography.body)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(MeshTheme.Typography.metricLarge)
                .monospacedDigit()

            Text(subtitle)
                .font(MeshTheme.Typography.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct SurgeTrendChart: View {
    let data: [SurgeTrendDataPoint]
    let timeRange: SurgePredictionView.TimeRange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Call Volume Trend")
                .font(MeshTheme.Typography.title2)
            
            if data.isEmpty {
                ProgressView("Loading trend data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(data) { point in
                        // Expected volume line
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Expected", point.expectedVolume)
                        )
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        
                        // Actual volume area
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Actual", point.callVolume)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        // Actual volume line
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Actual", point.callVolume)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: timeRange == .week ? .day : .hour, count: timeRange == .hours6 ? 1 : 3)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: timeRange == .week ? .dateTime.weekday(.abbreviated) : .dateTime.hour())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .top) {
                    HStack(spacing: 20) {
                        LegendItem(color: .blue, label: "Actual Volume")
                        LegendItem(color: .gray, label: "Expected Volume", isDashed: true)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    var isDashed: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            if isDashed {
                Rectangle()
                    .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [4, 2]))
                    .frame(width: 20, height: 2)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 20, height: 3)
            }
            Text(label)
                .font(MeshTheme.Typography.body)
                .foregroundColor(.secondary)
        }
    }
}

struct DistrictSurgeGrid: View {
    let districts: [District]
    let incidents: [Incident]
    let surgeAlerts: [SurgeAlert]
    @Binding var selectedDistrict: District?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("District Status")
                .font(MeshTheme.Typography.title2)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(districts) { district in
                    DistrictSurgeCard(
                        district: district,
                        activeIncidentCount: activeIncidentCount(for: district),
                        alert: surgeAlerts.first { $0.districtId == district.id },
                        isSelected: selectedDistrict?.id == district.id
                    )
                    .onTapGesture {
                        withAnimation {
                            selectedDistrict = district
                        }
                    }
                }
            }
        }
    }

    private func activeIncidentCount(for district: District) -> Int {
        incidents.filter {
            $0.status.isOperationallyActive && ($0.districtId == district.id || $0.districtName == district.name)
        }.count
    }
}

struct DistrictSurgeCard: View {
    let district: District
    let activeIncidentCount: Int
    let alert: SurgeAlert?
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(district.shortName)
                    .font(MeshTheme.Typography.title2)

                Spacer()

                if let alert = alert {
                    Image(systemName: alert.severity.icon)
                        .font(MeshTheme.Typography.title3)
                        .foregroundColor(alert.severity.color)
                }
            }

            Text(district.name)
                .font(MeshTheme.Typography.body)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Active")
                        .font(MeshTheme.Typography.callout)
                        .foregroundColor(.secondary)
                    Text("\(activeIncidentCount)")
                        .font(MeshTheme.Typography.metricSmall)
                        .monospacedDigit()
                }

                Spacer()

                if let alert = alert {
                    VStack(alignment: .trailing) {
                        Text("Surge")
                            .font(MeshTheme.Typography.callout)
                            .foregroundColor(.secondary)
                        Text("+\(Int(alert.percentageIncrease))%")
                            .font(MeshTheme.Typography.metricSmall)
                            .monospacedDigit()
                            .foregroundColor(alert.severity.color)
                    }
                }
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

struct DistrictDetailView: View {
    let district: District
    @EnvironmentObject var appState: AppState
    
    private var alert: SurgeAlert? {
        appState.surgeAlerts.first { $0.districtId == district.id }
    }

    private var activeIncidentCount: Int {
        appState.incidents.filter {
            $0.status.isOperationallyActive && ($0.districtId == district.id || $0.districtName == district.name)
        }.count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(district.name)
                        .font(MeshTheme.Typography.title)

                    if let alert = alert {
                        HStack {
                            Image(systemName: alert.severity.icon)
                            Text(alert.severity.label)
                            Text("• \(alert.timeAgo)")
                        }
                        .font(MeshTheme.Typography.title3)
                        .foregroundColor(alert.severity.color)
                    } else {
                        Text("Normal operations")
                            .font(MeshTheme.Typography.title3)
                            .foregroundColor(.green)
                    }
                }
                
                Divider()
                
                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatBox(title: "Population", value: "\(district.population.formatted())")
                    StatBox(title: "Area", value: String(format: "%.1f sq mi", district.areaSquareMiles))
                    StatBox(title: "Active Incidents", value: "\(activeIncidentCount)")
                    StatBox(title: "Avg Response", value: String(format: "%.1f min", district.averageResponseTime))
                }
                
                // Surge details if present
                if let alert = alert {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Surge Details")
                            .font(MeshTheme.Typography.headline)
                        
                        HStack {
                            Text("Current Volume")
                            Spacer()
                            Text("\(alert.currentCallVolume) calls")
                                .font(MeshTheme.Typography.bodySemibold)
                        }
                        .font(MeshTheme.Typography.title3)

                        HStack {
                            Text("Expected Volume")
                            Spacer()
                            Text("\(alert.expectedCallVolume) calls")
                        }
                        .font(MeshTheme.Typography.title3)
                        .foregroundColor(.secondary)

                        HStack {
                            Text("Trend")
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: alert.trend.icon)
                                Text(alert.trend.rawValue)
                            }
                            .foregroundColor(alert.trend.color)
                        }
                        .font(MeshTheme.Typography.title3)

                        HStack {
                            Text("Confidence")
                            Spacer()
                            Text(alert.formattedConfidence)
                                .font(MeshTheme.Typography.bodySemibold)
                        }
                        .font(MeshTheme.Typography.title3)

                        if let peakTime = alert.predictedPeakTime {
                            HStack {
                                Text("Predicted Peak")
                                Spacer()
                                Text(peakTime.formatted(date: .omitted, time: .shortened))
                                    .font(MeshTheme.Typography.bodySemibold)
                            }
                            .font(MeshTheme.Typography.title3)
                        }
                    }
                    .padding()
                    .background(alert.severity.color.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Contributing factors
                    if !alert.contributingFactors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contributing Factors")
                                .font(MeshTheme.Typography.headline)
                            
                            ForEach(alert.contributingFactors, id: \.self) { factor in
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.secondary)
                                    Text(factor)
                                        .font(MeshTheme.Typography.body)
                                }
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

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(MeshTheme.Typography.body)
                .foregroundColor(.secondary)
            Text(value)
                .font(MeshTheme.Typography.title2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    SurgePredictionView()
        .environmentObject(AppState.shared)
        .frame(width: 1000, height: 700)
}

