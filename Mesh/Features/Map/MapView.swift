import SwiftUI
import MapKit

enum MapStyleOption: String, CaseIterable, Hashable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"
    
    var mapStyle: MapStyle {
        switch self {
        case .standard: return .standard
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        }
    }
}

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: LocationService.activeRegionCenter,
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    ))
    @State private var selectedIncident: Incident?
    @State private var showDistrictOverlay = true
    @State private var mapStyleOption: MapStyleOption = .standard
    
    var body: some View {
        HSplitView {
            // Map
            ZStack(alignment: .topLeading) {
                Map(position: $cameraPosition, selection: $selectedIncident) {
                    // District overlays
                    if showDistrictOverlay {
                        ForEach(appState.districts) { district in
                            MapPolygon(coordinates: district.boundaryCoordinates)
                                .foregroundStyle(district.densityColor.opacity(0.2))
                                .stroke(district.densityColor, lineWidth: 2)
                        }
                    }
                    
                    // Incident markers
                    ForEach(appState.filteredIncidents) { incident in
                        Annotation(incident.type, coordinate: incident.coordinate) {
                            IncidentMapMarker(incident: incident, isSelected: selectedIncident?.id == incident.id)
                                .onTapGesture {
                                    withAnimation {
                                        selectedIncident = incident
                                    }
                                }
                        }
                        .tag(incident)
                    }
                }
                .mapStyle(mapStyleOption.mapStyle)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapZoomStepper()
                }
                
                // Map controls overlay
                VStack(alignment: .leading, spacing: 8) {
                    MapControlPanel(
                        showDistrictOverlay: $showDistrictOverlay,
                        mapStyleOption: $mapStyleOption,
                        onCenterRegion: centerOnActiveRegion
                    )
                    
                    Spacer()
                    
                    // Legend
                    MapLegend()
                }
                .padding()
            }
            .frame(minWidth: 500)
            
            // Sidebar
            MapSidebar(selectedIncident: $selectedIncident)
                .frame(width: 350)
        }
    }
    
    private func centerOnActiveRegion() {
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: LocationService.activeRegionCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
            ))
        }
    }
}

struct IncidentMapMarker: View {
    let incident: Incident
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Outer ring for critical incidents
            if incident.severity == .critical {
                Circle()
                    .stroke(incident.severity.color, lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .opacity(0.5)
            }
            
            // Main marker
            Circle()
                .fill(incident.agencyType.color)
                .frame(width: isSelected ? 32 : 24, height: isSelected ? 32 : 24)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Image(systemName: incident.agencyType.icon)
                .font(.system(size: isSelected ? 14 : 10))
                .foregroundColor(.white)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct MapControlPanel: View {
    @Binding var showDistrictOverlay: Bool
    @Binding var mapStyleOption: MapStyleOption
    @State private var isExpanded = false
    
    let onCenterRegion: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Toggle button
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(MeshTheme.Typography.title3)
                    .padding(8)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(8)
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // District overlay toggle
                    Toggle(isOn: $showDistrictOverlay) {
                        Label("District Overlay", systemImage: "square.dashed")
                            .font(MeshTheme.Typography.body)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Divider()

                    Text("Map Style")
                        .font(MeshTheme.Typography.body)
                        .foregroundColor(.secondary)
                    
                    Picker("Style", selection: $mapStyleOption) {
                        ForEach(MapStyleOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    
                    Divider()
                    
                    Button {
                        onCenterRegion()
                    } label: {
                        Label("Center on \(LocationService.activeRegionName)", systemImage: "location.fill")
                            .font(MeshTheme.Typography.body)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(8)
                .shadow(radius: 4)
                .frame(width: 200)
            }
        }
    }
}

struct MapLegend: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legend")
                .font(MeshTheme.Typography.bodySemibold)
                .foregroundColor(.secondary)

            ForEach(appState.availableAgencyTypes) { type in
                HStack(spacing: 6) {
                    Circle()
                        .fill(type.color)
                        .frame(width: 12, height: 12)
                    Text(type.rawValue)
                        .font(MeshTheme.Typography.callout)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

struct MapSidebar: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedIncident: Incident?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Incidents")
                    .font(MeshTheme.Typography.title2)

                Spacer()

                Text("\(appState.filteredIncidents.count)")
                    .font(MeshTheme.Typography.title3)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // List
            if appState.filteredIncidents.isEmpty {
                EmptyStateView(
                    icon: "map",
                    title: "No Incidents",
                    message: "No incidents match your current filters"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.filteredIncidents) { incident in
                            MapIncidentRow(
                                incident: incident,
                                isSelected: selectedIncident?.id == incident.id
                            )
                            .onTapGesture {
                                withAnimation {
                                    selectedIncident = incident
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Selected incident detail
            if let incident = selectedIncident {
                Divider()
                
                MapIncidentDetail(incident: incident)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct MapIncidentRow: View {
    let incident: Incident
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(incident.agencyType.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(incident.type)
                    .font(MeshTheme.Typography.bodySemibold)
                    .lineLimit(1)

                Text(incident.address)
                    .font(MeshTheme.Typography.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(incident.timeAgo)
                .font(MeshTheme.Typography.callout)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}

struct MapIncidentDetail: View {
    let incident: Incident
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: incident.agencyType.icon)
                    .font(MeshTheme.Typography.title3)
                    .foregroundColor(incident.agencyType.color)

                Text(incident.type)
                    .font(MeshTheme.Typography.title3)

                Spacer()

                SeverityBadge(severity: incident.severity)
            }

            Text(incident.address)
                .font(MeshTheme.Typography.body)
                .foregroundColor(.secondary)

            Text(incident.description)
                .font(MeshTheme.Typography.body)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                StatusIndicator(status: incident.status)

                Spacer()

                Text("\(incident.respondingUnits.count) units responding")
                    .font(MeshTheme.Typography.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MiniMapPreview: View {
    let coordinate: CLLocationCoordinate2D
    
    var body: some View {
        Map(position: .constant(.region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))) {
            Marker("", coordinate: coordinate)
                .tint(.red)
        }
        .mapStyle(.standard)
        .disabled(true)
    }
}

#Preview {
    MapView()
        .environmentObject(AppState.shared)
        .frame(width: 1000, height: 700)
}

