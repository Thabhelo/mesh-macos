import SwiftUI

// MARK: - Welcome View (Landing Page)
// Clean, minimal design matching meshofdata.org hero section

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAnimated = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                LightThemeBackground()
                
                // Main layout
                VStack(spacing: 0) {
                    // Navigation Bar
                    WelcomeNavBar(geometry: geometry)
                    
                    // Hero Content
                    HeroSection(geometry: geometry)
                    
                    // Footer
                    WelcomeFooter()
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                isAnimated = true
            }
        }
    }
}

// MARK: - Navigation Bar

struct WelcomeNavBar: View {
    let geometry: GeometryProxy
    @EnvironmentObject var appState: AppState
    @State private var isHoveringEnter = false
    
    private let navHeight: CGFloat = 56
    
    var body: some View {
        HStack(spacing: 0) {
            // Logo
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MeshTheme.Colors.primaryGradient)
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: "shield.checkered")
                        .font(MeshTheme.Typography.headline)
                        .foregroundColor(.white)
                }
                
                Text("Mesh")
                    .font(MeshTheme.Typography.title2)
                    .foregroundColor(MeshTheme.Colors.foreground)
            }
            
            Spacer()
            
            // Enter Dashboard Button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    appState.showWelcome = false
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Enter Dashboard")
                        .font(MeshTheme.Typography.callout)
                    Image(systemName: "arrow.right")
                        .font(MeshTheme.Typography.callout)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    MeshTheme.Colors.primaryGradient
                )
                .cornerRadius(10)
                .shadow(
                    color: MeshTheme.Colors.primary.opacity(isHoveringEnter ? 0.5 : 0.3),
                    radius: isHoveringEnter ? 16 : 10,
                    x: 0,
                    y: isHoveringEnter ? 6 : 4
                )
                .scaleEffect(isHoveringEnter ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    isHoveringEnter = hovering
                }
            }
        }
        .padding(.horizontal, 36)
        .frame(height: navHeight)
        .background(
            ZStack {
                // Glassmorphism navbar
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                
                // Bottom border
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(MeshTheme.Colors.border)
                        .frame(height: 1)
                }
            }
        )
    }
}

// MARK: - Hero Section

struct HeroSection: View {
    let geometry: GeometryProxy
    @EnvironmentObject var appState: AppState
    @State private var isAnimated = false
    @State private var isHoveringPrimary = false
    @State private var isHoveringSecondary = false
    
    // Layout calculations
    private var contentWidth: CGFloat {
        min(geometry.size.width - 96, 1400) // Max width with padding
    }
    
    private var leftColumnWidth: CGFloat {
        contentWidth * 0.48
    }
    
    private var rightColumnWidth: CGFloat {
        contentWidth * 0.52
    }
    
    private var verticalCenter: CGFloat {
        (geometry.size.height - 64 - 56) / 2 // Account for nav and footer
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 48)
            
            // Left Column - Text Content
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                VStack(alignment: .leading, spacing: 28) {
                    // Status Badge
                    statusBadge
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 20)
                    
                    // Main Title
                    titleSection
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.1), value: isAnimated)
                    
                    // Description
                    descriptionText
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: isAnimated)
                    
                    // Action Buttons
                    actionButtons
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimated)
                }
                .frame(width: leftColumnWidth, alignment: .leading)
                
                Spacer()
            }
            
            // Right Column - Orbital
            ZStack {
                ImprovedOrbitalView()
                    .frame(width: rightColumnWidth, height: geometry.size.height - 120)
                    .opacity(isAnimated ? 1 : 0)
                    .scaleEffect(isAnimated ? 1 : 0.9)
                    .animation(.easeOut(duration: 1.0).delay(0.2), value: isAnimated)
            }
            .frame(width: rightColumnWidth)
            
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation {
                isAnimated = true
            }
        }
    }
    
    // MARK: - Sub-components
    
    private var statusBadge: some View {
        HStack(spacing: 10) {
            // Pulsing dot
            Circle()
                .fill(MeshTheme.Colors.primary)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(MeshTheme.Colors.primary.opacity(0.4), lineWidth: 2)
                        .scaleEffect(1.5)
                )
            
            Text("Now Monitoring Public Safety in San Francisco")
                .font(MeshTheme.Typography.caption)
                .foregroundColor(MeshTheme.Colors.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white)
                .shadow(color: MeshTheme.Colors.primary.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(MeshTheme.Colors.primary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Real-Time Public Safety")
                .font(MeshTheme.Typography.display)
                .foregroundColor(MeshTheme.Colors.foreground)
                .lineSpacing(4)
            
            Text("Interoperability")
                .font(MeshTheme.Typography.display)
                .foregroundStyle(MeshTheme.Colors.primaryGradient)
        }
    }
    
    private var descriptionText: some View {
        Text("Mesh unifies fragmented emergency response across fire, police, EMS, and emergency management with real-time operational intelligence that saves lives.")
            .font(MeshTheme.Typography.bodyLarge)
            .foregroundColor(MeshTheme.Colors.foregroundSecondary)
            .lineSpacing(8)
            .frame(maxWidth: 480, alignment: .leading)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Primary - Enter Dashboard
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    appState.showWelcome = false
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Enter Dashboard")
                        .font(MeshTheme.Typography.headline)
                    Image(systemName: "arrow.right")
                        .font(MeshTheme.Typography.callout)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(MeshTheme.Colors.primaryGradient)
                .cornerRadius(12)
                .shadow(
                    color: MeshTheme.Colors.primary.opacity(isHoveringPrimary ? 0.5 : 0.35),
                    radius: isHoveringPrimary ? 20 : 14,
                    x: 0,
                    y: isHoveringPrimary ? 8 : 6
                )
                .scaleEffect(isHoveringPrimary ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    isHoveringPrimary = hovering
                }
            }
            
            // Secondary - Learn More
            Button {
                if let url = URL(string: "https://meshofdata.org/platform") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Learn More")
                    .font(MeshTheme.Typography.headline)
                    .foregroundColor(MeshTheme.Colors.foreground)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(
                        color: Color.black.opacity(isHoveringSecondary ? 0.12 : 0.08),
                        radius: isHoveringSecondary ? 14 : 10,
                        x: 0,
                        y: isHoveringSecondary ? 6 : 4
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(MeshTheme.Colors.border, lineWidth: 1)
                    )
                    .scaleEffect(isHoveringSecondary ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.2)) {
                    isHoveringSecondary = hovering
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Improved Orbital View

struct ImprovedOrbitalView: View {
    @State private var rotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var pulse: CGFloat = 1.0
    @State private var floatOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) * 0.85
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // Outer glow rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            MeshTheme.Colors.primary.opacity(0.08 - Double(index) * 0.02),
                            lineWidth: 1.5
                        )
                        .frame(width: size + CGFloat(index) * 60, height: size + CGFloat(index) * 60)
                        .position(center)
                        .scaleEffect(pulse + CGFloat(index) * 0.02)
                }
                
                // Ambient glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                MeshTheme.Colors.primary.opacity(0.12),
                                MeshTheme.Colors.secondary.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.2,
                            endRadius: size * 0.7
                        )
                    )
                    .frame(width: size * 1.4, height: size * 1.4)
                    .position(center)
                    .blur(radius: 40)
                
                // Main orb body
                ZStack {
                    // Base gradient orb
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    MeshTheme.Colors.primary,
                                    MeshTheme.Colors.secondary,
                                    MeshTheme.Colors.primary.opacity(0.9),
                                    MeshTheme.Colors.secondary.opacity(0.8),
                                    MeshTheme.Colors.primary
                                ],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            )
                        )
                        .frame(width: size * 0.6, height: size * 0.6)
                        .blur(radius: 25)
                        .rotationEffect(.degrees(rotation))
                    
                    // Inner core
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    MeshTheme.Colors.secondary.opacity(0.9),
                                    MeshTheme.Colors.primary.opacity(0.6),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.25
                            )
                        )
                        .frame(width: size * 0.5, height: size * 0.5)
                        .blur(radius: 15)
                        .rotationEffect(.degrees(-innerRotation))
                    
                    // Highlight reflection
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.7),
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size * 0.28, height: size * 0.15)
                        .blur(radius: 8)
                        .offset(x: -size * 0.08, y: -size * 0.12)
                }
                .position(center)
                .offset(y: floatOffset)
                
                // Orbiting particles
                ForEach(0..<6) { index in
                    Circle()
                        .fill(MeshTheme.Colors.primary.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .blur(radius: 2)
                        .offset(x: size * 0.4)
                        .rotationEffect(.degrees(rotation + Double(index) * 60))
                        .position(center)
                }
            }
        }
        .onAppear {
            // Slow rotation
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            // Counter rotation for depth
            withAnimation(.linear(duration: 35).repeatForever(autoreverses: false)) {
                innerRotation = 360
            }
            // Gentle pulse
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulse = 1.05
            }
            // Float animation
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                floatOffset = -10
            }
        }
    }
}

// MARK: - Footer

struct WelcomeFooter: View {
    @State private var isHoveringPrivacy = false
    @State private var isHoveringTerms = false
    @State private var isHoveringContact = false
    
    private let footerHeight: CGFloat = 56
    
    var body: some View {
        HStack(spacing: 0) {
            // Copyright
            Text("© 2025 Mesh Platform")
                .font(MeshTheme.Typography.caption)
                .foregroundColor(MeshTheme.Colors.mutedForeground)
            
            Text(" • ")
                .foregroundColor(MeshTheme.Colors.mutedForeground)
            
            Text("San Francisco, California")
                .font(MeshTheme.Typography.caption)
                .foregroundColor(MeshTheme.Colors.mutedForeground)
            
            Spacer()
            
            // Links
            HStack(spacing: 24) {
                FooterLink(text: "Privacy", url: "https://meshofdata.org/privacy")
                FooterLink(text: "Terms", url: "https://meshofdata.org/terms")
                FooterLink(text: "Contact", url: "https://meshofdata.org/contact")
            }
        }
        .padding(.horizontal, 48)
        .frame(height: footerHeight)
        .background(
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                
                // Top border
                VStack {
                    Rectangle()
                        .fill(MeshTheme.Colors.border)
                        .frame(height: 1)
                    Spacer()
                }
            }
        )
    }
}

struct FooterLink: View {
    let text: String
    let url: String
    @State private var isHovered = false
    
    var body: some View {
        Button {
            if let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        } label: {
            Text(text)
                .font(MeshTheme.Typography.caption)
                .foregroundColor(isHovered ? MeshTheme.Colors.primary : MeshTheme.Colors.foregroundSecondary)
                .underline(isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState.shared)
}
