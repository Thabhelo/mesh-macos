import SwiftUI
import Charts

struct HazardAnalysisView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedComponent: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall score card
                if let hazard = appState.hazardScore {
                    OverallHazardCard(hazard: hazard)
                    
                    // Component breakdown
                    ComponentBreakdownSection(
                        hazard: hazard,
                        selectedComponent: $selectedComponent
                    )
                    
                    // Historical comparison
                    HistoricalComparisonSection(hazard: hazard)
                    
                    // District heat map
                    DistrictHazardSection(hazard: hazard)
                } else {
                    ProgressView("Loading hazard data...")
                        .frame(maxWidth: .infinity, maxHeight: 400)
                }
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

struct OverallHazardCard: View {
    let hazard: HazardScore
    
    var body: some View {
        HStack(spacing: 24) {
            // Score gauge
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: Double(hazard.overallScore) / 100)
                        .stroke(hazard.statusColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(hazard.overallScore)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(hazard.statusLabel)
                    .font(.headline)
                    .foregroundColor(hazard.statusColor)
            }
            .padding(.trailing)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Regional Hazard Score")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Last updated \(hazard.lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                HStack(spacing: 24) {
                    HazardChangeIndicator(
                        label: "vs Yesterday",
                        change: hazard.changeFromYesterday
                    )
                    
                    HazardChangeIndicator(
                        label: "vs Last Week",
                        change: hazard.overallScore - hazard.historicalComparison.lastWeekAverage
                    )
                    
                    HazardChangeIndicator(
                        label: "vs Last Month",
                        change: hazard.overallScore - hazard.historicalComparison.lastMonthAverage
                    )
                }
            }
            
            Spacer()
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

struct HazardChangeIndicator: View {
    let label: String
    let change: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                    .font(.caption)
                Text("\(abs(change))")
                    .fontWeight(.semibold)
            }
            .foregroundColor(change > 5 ? .red : change < -5 ? .green : .secondary)
        }
    }
}

struct ComponentBreakdownSection: View {
    let hazard: HazardScore
    @Binding var selectedComponent: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contributing Factors")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                ForEach(hazard.components.allComponents, id: \.name) { component in
                    ComponentCard(
                        name: component.name,
                        score: component.score,
                        isSelected: selectedComponent == component.name
                    )
                    .onTapGesture {
                        withAnimation {
                            selectedComponent = selectedComponent == component.name ? nil : component.name
                        }
                    }
                }
            }
            
            // Detail panel for selected component
            if let selectedName = selectedComponent,
               let component = hazard.components.allComponents.first(where: { $0.name == selectedName }) {
                ComponentDetailPanel(name: component.name, score: component.score)
            }
        }
    }
}

struct ComponentCard: View {
    let name: String
    let score: HazardScore.ComponentScore
    let isSelected: Bool
    
    private var icon: String {
        switch name {
        case "Weather": return "cloud.sun.fill"
        case "Traffic": return "car.fill"
        case "Incident Activity": return "exclamationmark.circle.fill"
        case "Infrastructure": return "bolt.fill"
        case "Special Events": return "calendar.badge.exclamationmark"
        default: return "questionmark.circle"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(score.color)
                
                Spacer()
                
                Image(systemName: score.trend.icon)
                    .font(.caption)
                    .foregroundColor(score.trend.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(score.score)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(score.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Weight bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(score.color)
                        .frame(width: geo.size.width * score.weight)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
            
            Text("\(Int(score.weight * 100))% weight")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(isSelected ? score.color.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? score.color : Color.clear, lineWidth: 2)
        )
    }
}

struct ComponentDetailPanel: View {
    let name: String
    let score: HazardScore.ComponentScore
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.headline)
                
                Text(score.details)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text("Trend:")
                    Image(systemName: score.trend.icon)
                    Text(score.trend.rawValue)
                }
                .font(.subheadline)
                .foregroundColor(score.trend.color)
                
                Text("Weighted contribution: \(String(format: "%.1f", score.weightedScore))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(score.color.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(score.color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct HistoricalComparisonSection: View {
    let hazard: HazardScore
    
    // Generate mock historical data
    private var historicalData: [(date: Date, score: Int)] {
        var data: [(Date, Int)] = []
        let calendar = Calendar.current
        
        for i in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let baseScore = hazard.historicalComparison.lastWeekAverage
            let variance = Int.random(in: -10...10)
            data.append((date, max(0, min(100, baseScore + variance))))
        }
        
        // Add current score
        data.append((Date(), hazard.overallScore))
        
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("7-Day Trend")
                .font(.title3)
                .fontWeight(.semibold)
            
            Chart(historicalData, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Score", item.score)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Score", item.score)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Score", item.score)
                )
                .foregroundStyle(.blue)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(10)
        }
    }
}

struct DistrictHazardSection: View {
    let hazard: HazardScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("District Risk Levels")
                .font(.title3)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(hazard.districtScores) { district in
                    DistrictHazardCard(district: district)
                }
            }
        }
    }
}

struct DistrictHazardCard: View {
    let district: HazardScore.DistrictHazardScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(district.districtName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(district.score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(district.color)
            }
            
            Text("Primary: \(district.primaryRisk)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(district.color)
                        .frame(width: geo.size.width * Double(district.score) / 100)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
    }
}

#Preview {
    HazardAnalysisView()
        .environmentObject(AppState.shared)
        .frame(width: 1000, height: 800)
}

