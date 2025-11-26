import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAnimated = false
    @State private var isHoveringPrimary = false
    @State private var isHoveringSecondary = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Light theme background
                LightThemeBackground()
                
                // Animated orb positioned to the right
                AnimatedOrbBackground()
                    .offset(x: geometry.size.width * 0.3, y: -20)
                    .opacity(0.9)
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: MeshTheme.Spacing.xxl + 20) {
                        // Hero Section
                        heroSection
                            .padding(.top, MeshTheme.Spacing.xl)
                        
                        // Stats Section
                        statsSection
                        
                        // Capabilities Section
                        capabilitiesSection
                        
                        // CTA Section
                        ctaSection
                        
                        Spacer(minLength: MeshTheme.Spacing.xl)
                    }
                    .padding(.horizontal, MeshTheme.Spacing.xxl)
                    .padding(.vertical, MeshTheme.Spacing.xl)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 750)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimated = true
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        HStack(alignment: .center, spacing: MeshTheme.Spacing.xxl) {
            VStack(alignment: .leading, spacing: MeshTheme.Spacing.lg) {
                // Status badge with glassmorphism
                HStack(spacing: MeshTheme.Spacing.sm) {
                    PulsingCircle(color: MeshTheme.Colors.primary)
                    Text("Now Powering Public Safety in Birmingham")
                        .font(MeshTheme.Typography.calloutFont)
                        .foregroundColor(MeshTheme.Colors.primary)
                }
                .padding(.horizontal, MeshTheme.Spacing.md)
                .padding(.vertical, MeshTheme.Spacing.sm + 2)
                .glassmorphism(cornerRadius: MeshTheme.Radius.full, opacity: 0.8)
                .opacity(isAnimated ? 1 : 0)
                .offset(y: isAnimated ? 0 : 20)
                
                // Title
                VStack(alignment: .leading, spacing: MeshTheme.Spacing.xs) {
                    Text("Real-Time Public Safety")
                        .font(MeshTheme.Typography.displayFont)
                        .foregroundColor(MeshTheme.Colors.foreground)
                    
                    Text("Interoperability")
                        .font(MeshTheme.Typography.displayFont)
                        .foregroundStyle(MeshTheme.Colors.primaryGradient)
                }
                .opacity(isAnimated ? 1 : 0)
                .offset(y: isAnimated ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.1), value: isAnimated)
                
                // Description
                Text("Mesh unifies fragmented emergency response across fire, police, EMS, and emergency management with AI-powered operational intelligence that saves lives.")
                    .font(MeshTheme.Typography.bodyLarge)
                    .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                    .lineSpacing(8)
                    .frame(maxWidth: 520)
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(0.2), value: isAnimated)
                
                // Action Buttons
                HStack(spacing: MeshTheme.Spacing.md) {
                    // Primary Button - Enter Dashboard
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.showWelcome = false
                        }
                    } label: {
                        HStack(spacing: MeshTheme.Spacing.sm) {
                            Text("Enter Dashboard")
                                .font(MeshTheme.Typography.headlineFont)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, MeshTheme.Spacing.lg + 4)
                        .padding(.vertical, MeshTheme.Spacing.md + 2)
                        .background(
                            MeshTheme.Colors.primaryGradient
                        )
                        .cornerRadius(MeshTheme.Radius.md)
                        .shadow(color: MeshTheme.Colors.primary.opacity(isHoveringPrimary ? 0.5 : 0.35), radius: isHoveringPrimary ? 16 : 12, x: 0, y: isHoveringPrimary ? 8 : 6)
                        .scaleEffect(isHoveringPrimary ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.2)) {
                            isHoveringPrimary = hovering
                        }
                    }
                    
                    // Secondary Button - Learn More
                    Button {
                        if let url = URL(string: "https://meshofdata.org/platform") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Learn More")
                            .font(MeshTheme.Typography.headlineFont)
                            .foregroundColor(MeshTheme.Colors.primary)
                            .padding(.horizontal, MeshTheme.Spacing.lg + 4)
                            .padding(.vertical, MeshTheme.Spacing.md + 2)
                            .background(Color.white)
                            .cornerRadius(MeshTheme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: MeshTheme.Radius.md)
                                    .stroke(MeshTheme.Colors.primary.opacity(isHoveringSecondary ? 0.6 : 0.3), lineWidth: 1.5)
                            )
                            .shadow(color: MeshTheme.Shadows.small, radius: isHoveringSecondary ? 12 : 8, x: 0, y: 4)
                            .scaleEffect(isHoveringSecondary ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.2)) {
                            isHoveringSecondary = hovering
                        }
                    }
                }
                .padding(.top, MeshTheme.Spacing.sm)
                .opacity(isAnimated ? 1 : 0)
                .offset(y: isAnimated ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimated)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 200)
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(spacing: MeshTheme.Spacing.lg + 4) {
            VStack(spacing: MeshTheme.Spacing.sm) {
                Text("Birmingham by the Numbers")
                    .font(MeshTheme.Typography.titleFont)
                    .foregroundColor(MeshTheme.Colors.foreground)
                
                Text("Understanding the scale and complexity of Birmingham's emergency response landscape.")
                    .font(MeshTheme.Typography.bodyLarge)
                    .foregroundColor(MeshTheme.Colors.foregroundSecondary)
            }
            .multilineTextAlignment(.center)
            
            HStack(spacing: MeshTheme.Spacing.lg) {
                GlassStatCard(
                    value: "~70%",
                    description: "of 911 centers report limited or no ability to share real-time data with other emergency response agencies",
                    source: "APCO"
                )
                
                GlassStatCard(
                    value: "50%+",
                    description: "of U.S. 911 centers still rely on manual radio or phone relay to pass information between agencies",
                    source: "National 911 Program"
                )
                
                GlassStatCard(
                    value: "80%",
                    description: "of first responders believe that interoperability across agencies, regardless of network or device, is urgently needed",
                    source: "Verizon Frontline"
                )
            }
        }
        .opacity(isAnimated ? 1 : 0)
        .animation(.easeOut(duration: 0.8).delay(0.4), value: isAnimated)
    }
    
    // MARK: - Capabilities Section
    
    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: MeshTheme.Spacing.lg + 4) {
            VStack(alignment: .leading, spacing: MeshTheme.Spacing.sm) {
                Text("Mesh Insight Engine")
                    .font(MeshTheme.Typography.titleFont)
                    .foregroundColor(MeshTheme.Colors.foreground)
                
                Text("Three mission-critical capabilities powered by AI, providing operations-focused intelligence without surveillance or individual-level prediction.")
                    .font(MeshTheme.Typography.bodyLarge)
                    .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                    .frame(maxWidth: 650)
            }
            
            HStack(spacing: MeshTheme.Spacing.lg) {
                GlassCapabilityCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Incident Surge Prediction",
                    description: "AI-powered detection of rising call volumes in districts before they become critical.",
                    features: ["Real-time pattern analysis", "Predictive alerts", "District-level insights"],
                    onTap: {
                        appState.showWelcome = false
                        appState.selectedTab = .surge
                    }
                )
                
                GlassCapabilityCard(
                    icon: "bolt.fill",
                    title: "Resource Load Balancing",
                    description: "Smart recommendations for optimal resource deployment across the region.",
                    features: ["Dynamic rebalancing", "Overload prevention", "Cross-agency coordination"],
                    onTap: {
                        appState.showWelcome = false
                        appState.selectedTab = .dashboard
                    }
                )
                
                GlassCapabilityCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Hazard Analysis",
                    description: "Multi-source data fusion revealing escalating conditions and emerging threats.",
                    features: ["Weather integration", "Traffic monitoring", "Real-time scoring"],
                    onTap: {
                        appState.showWelcome = false
                        appState.selectedTab = .hazard
                    }
                )
            }
        }
        .opacity(isAnimated ? 1 : 0)
        .animation(.easeOut(duration: 0.8).delay(0.5), value: isAnimated)
    }
    
    // MARK: - CTA Section
    
    private var ctaSection: some View {
        VStack(spacing: MeshTheme.Spacing.lg) {
            Text("Ethical, Transparent, Community-First")
                .font(MeshTheme.Typography.titleFont)
                .foregroundColor(MeshTheme.Colors.foreground)
            
            Text("Mesh avoids surveillance, facial recognition, and individual-level prediction. All intelligence is operations-focused, auditable, and aligned with community privacy standards.")
                .font(MeshTheme.Typography.bodyLarge)
                .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 650)
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.showWelcome = false
                }
            } label: {
                HStack(spacing: MeshTheme.Spacing.sm) {
                    Text("Explore the Platform")
                        .font(MeshTheme.Typography.headlineFont)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, MeshTheme.Spacing.lg + 4)
                .padding(.vertical, MeshTheme.Spacing.md + 2)
                .background(MeshTheme.Colors.primaryGradient)
                .cornerRadius(MeshTheme.Radius.md)
                .shadow(color: MeshTheme.Colors.primary.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, MeshTheme.Spacing.xl)
        .padding(.horizontal, MeshTheme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .glassmorphism(cornerRadius: MeshTheme.Radius.xl, opacity: 0.5)
        .overlay(
            VStack {
                Rectangle()
                    .fill(MeshTheme.Colors.primaryGradient.opacity(0.3))
                    .frame(height: 2)
                Spacer()
            }
        )
        .opacity(isAnimated ? 1 : 0)
        .animation(.easeOut(duration: 0.8).delay(0.6), value: isAnimated)
    }
}

// MARK: - Glass Stat Card

struct GlassStatCard: View {
    let value: String
    let description: String
    let source: String
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: MeshTheme.Spacing.md + 4) {
            Text(value)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(MeshTheme.Colors.primaryGradient)
            
            Text(description)
                .font(MeshTheme.Typography.calloutFont)
                .foregroundColor(MeshTheme.Colors.foreground)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
            
            Text("(\(source))")
                .font(MeshTheme.Typography.caption2Font)
                .foregroundColor(MeshTheme.Colors.mutedForeground)
        }
        .padding(MeshTheme.Spacing.lg + 4)
        .frame(maxWidth: .infinity)
        .glassmorphism(cornerRadius: MeshTheme.Radius.xl, opacity: isHovered ? 0.85 : 0.7)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Glass Capability Card

struct GlassCapabilityCard: View {
    let icon: String
    let title: String
    let description: String
    let features: [String]
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: MeshTheme.Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: MeshTheme.Radius.md)
                        .fill(MeshTheme.Colors.primary.opacity(isHovered ? 0.2 : 0.1))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(MeshTheme.Colors.primary)
                }
                
                // Title
                Text(title)
                    .font(MeshTheme.Typography.title3Font)
                    .foregroundColor(MeshTheme.Colors.foreground)
                
                // Description
                Text(description)
                    .font(MeshTheme.Typography.bodyFont)
                    .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                    .lineSpacing(5)
                
                // Features
                VStack(alignment: .leading, spacing: MeshTheme.Spacing.sm) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: MeshTheme.Spacing.sm) {
                            Circle()
                                .fill(MeshTheme.Colors.primary)
                                .frame(width: 6, height: 6)
                            
                            Text(feature)
                                .font(MeshTheme.Typography.calloutFont)
                                .foregroundColor(MeshTheme.Colors.foregroundSecondary)
                        }
                    }
                }
                .padding(.top, MeshTheme.Spacing.xs)
                
                Spacer()
                
                // Hover indicator
                HStack {
                    Spacer()
                    Text("Open →")
                        .font(MeshTheme.Typography.captionFont)
                        .foregroundColor(MeshTheme.Colors.primary)
                        .opacity(isHovered ? 1 : 0)
                }
            }
            .padding(MeshTheme.Spacing.lg + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 280)
            .glassmorphism(cornerRadius: MeshTheme.Radius.lg, opacity: isHovered ? 0.85 : 0.65)
            .overlay(
                RoundedRectangle(cornerRadius: MeshTheme.Radius.lg)
                    .stroke(isHovered ? MeshTheme.Colors.primary.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState.shared)
}
