import SwiftUI
import CoreText

// MARK: - Mesh Design System
// Matching the marketing website at meshofdata.org with Glassmorphism

struct MeshTheme {
    // MARK: - Colors (matching CSS variables)
    
    struct Colors {
        // Primary: HSL 25 95% 53% -> Orange
        static let primary = Color(red: 0.98, green: 0.45, blue: 0.09)
        static let primaryLight = Color(red: 0.99, green: 0.55, blue: 0.20)
        static let primaryDark = Color(red: 0.85, green: 0.35, blue: 0.05)
        
        // Secondary: HSL 39 100% 57% -> Golden Yellow
        static let secondary = Color(red: 1.0, green: 0.76, blue: 0.03)
        static let secondaryLight = Color(red: 1.0, green: 0.82, blue: 0.20)
        
        // Light theme backgrounds
        static let background = Color.white
        static let backgroundSecondary = Color(red: 0.98, green: 0.97, blue: 0.96)
        static let cardBackground = Color.white.opacity(0.7)
        static let glassBackground = Color.white.opacity(0.6)
        
        // Text colors for light theme
        static let foreground = Color(red: 0.1, green: 0.15, blue: 0.2)
        static let foregroundSecondary = Color(red: 0.4, green: 0.45, blue: 0.5)
        static let mutedForeground = Color(red: 0.55, green: 0.58, blue: 0.62)
        
        // Borders
        static let border = Color(red: 0.9, green: 0.88, blue: 0.85)
        static let borderLight = Color.white.opacity(0.5)
        
        // Status colors
        static let success = Color(red: 0.13, green: 0.77, blue: 0.37)
        static let warning = Color(red: 1.0, green: 0.6, blue: 0.0)
        static let danger = Color(red: 0.93, green: 0.26, blue: 0.21)
        
        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let backgroundGradient = LinearGradient(
            colors: [background, backgroundSecondary],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let glassGradient = LinearGradient(
            colors: [Color.white.opacity(0.8), Color.white.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let glowGradient = RadialGradient(
            colors: [primary.opacity(0.2), primary.opacity(0.05), Color.clear],
            center: .center,
            startRadius: 0,
            endRadius: 300
        )
    }
    
    // MARK: - Typography
    
    struct Typography {
        private enum PlexSans {
            static let regular = "IBMPlexSans-Regular"
            static let medium = "IBMPlexSans-Medium"
            static let semibold = "IBMPlexSans-SemiBold"
            static let bold = "IBMPlexSans-Bold"
        }

        static func registerBundledFonts() {
            [
                "IBMPlexSans-Regular",
                "IBMPlexSans-Medium",
                "IBMPlexSans-SemiBold",
                "IBMPlexSans-Bold"
            ].forEach { fileName in
                guard let url = Bundle.main.url(forResource: fileName, withExtension: "ttf", subdirectory: "Fonts") else {
                    return
                }
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }

        private static func plex(_ name: String, size: CGFloat) -> Font {
            .custom(name, size: size)
        }

        static let display = plex(PlexSans.bold, size: 54)
        static let title = plex(PlexSans.bold, size: 34)
        static let title2 = plex(PlexSans.semibold, size: 26)
        static let title3 = plex(PlexSans.semibold, size: 21)
        static let headline = plex(PlexSans.semibold, size: 17)
        static let body = plex(PlexSans.regular, size: 14)
        static let bodySemibold = plex(PlexSans.semibold, size: 14)
        static let callout = plex(PlexSans.medium, size: 13)
        static let caption = plex(PlexSans.medium, size: 12)
        static let micro = plex(PlexSans.medium, size: 10)
        static let sectionLabel = plex(PlexSans.semibold, size: 10)
        static let metricLarge = plex(PlexSans.bold, size: 34)
        static let metricSmall = plex(PlexSans.bold, size: 22)
        static let metricTiny = plex(PlexSans.semibold, size: 14)

        static let displayFont = display
        static let titleFont = title
        static let title2Font = title2
        static let title3Font = title3
        static let headlineFont = headline
        static let bodyFont = body
        static let bodyLarge = plex(PlexSans.regular, size: 16)
        static let calloutFont = callout
        static let captionFont = caption
        static let caption2Font = micro
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let small = Color.black.opacity(0.08)
        static let medium = Color.black.opacity(0.12)
        static let large = Color.black.opacity(0.16)
        static let glow = Colors.primary.opacity(0.3)
    }
}

// MARK: - Glassmorphism View Modifier

struct GlassmorphismStyle: ViewModifier {
    var cornerRadius: CGFloat = MeshTheme.Radius.lg
    var opacity: CGFloat = 0.7
    var blur: CGFloat = 20
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Frosted glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    // White overlay for light theme
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(opacity))
                    
                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: MeshTheme.Shadows.medium, radius: 20, x: 0, y: 10)
    }
}

struct GlassmorphismCard: ViewModifier {
    var padding: CGFloat = MeshTheme.Spacing.lg
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .modifier(GlassmorphismStyle())
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(padding: CGFloat = MeshTheme.Spacing.lg) -> some View {
        modifier(GlassmorphismCard(padding: padding))
    }
    
    func glassmorphism(cornerRadius: CGFloat = MeshTheme.Radius.lg, opacity: CGFloat = 0.7) -> some View {
        modifier(GlassmorphismStyle(cornerRadius: cornerRadius, opacity: opacity))
    }
    
    func meshCard() -> some View {
        self
            .padding(MeshTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: MeshTheme.Radius.lg)
                    .fill(Color.white)
                    .shadow(color: MeshTheme.Shadows.medium, radius: 15, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MeshTheme.Radius.lg)
                    .stroke(MeshTheme.Colors.border, lineWidth: 1)
            )
    }
    
    func meshPrimaryButton() -> some View {
        self
            .font(MeshTheme.Typography.headlineFont)
            .foregroundColor(.white)
            .padding(.horizontal, MeshTheme.Spacing.lg)
            .padding(.vertical, MeshTheme.Spacing.md)
            .background(
                MeshTheme.Colors.primaryGradient
                    .shadow(.inner(color: Color.white.opacity(0.3), radius: 2, x: 0, y: 1))
            )
            .cornerRadius(MeshTheme.Radius.md)
            .shadow(color: MeshTheme.Colors.primary.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    func meshSecondaryButton() -> some View {
        self
            .font(MeshTheme.Typography.headlineFont)
            .foregroundColor(MeshTheme.Colors.primary)
            .padding(.horizontal, MeshTheme.Spacing.lg)
            .padding(.vertical, MeshTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: MeshTheme.Radius.md)
                    .fill(Color.white)
                    .shadow(color: MeshTheme.Shadows.small, radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MeshTheme.Radius.md)
                    .stroke(MeshTheme.Colors.primary.opacity(0.3), lineWidth: 1.5)
            )
    }
    
    func meshGradientText() -> some View {
        self.foregroundStyle(MeshTheme.Colors.primaryGradient)
    }
}

// MARK: - Pulsing Animation

struct PulsingCircle: View {
    @State private var isAnimating = false
    let color: Color
    
    init(color: Color = MeshTheme.Colors.primary) {
        self.color = color
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .scaleEffect(isAnimating ? 1.3 : 0.9)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Animated Orb Background

struct AnimatedOrbBackground: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            MeshTheme.Colors.primary.opacity(0.15),
                            MeshTheme.Colors.secondary.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .blur(radius: 60)
                .scaleEffect(scale)
            
            // Rotating gradient orb
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            MeshTheme.Colors.primary.opacity(0.8),
                            MeshTheme.Colors.secondary.opacity(0.6),
                            MeshTheme.Colors.primary.opacity(0.7),
                            MeshTheme.Colors.secondary.opacity(0.5),
                            MeshTheme.Colors.primary.opacity(0.8)
                        ],
                        center: .center
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .rotationEffect(.degrees(rotation))
                .offset(y: offset)
            
            // Inner bright core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            MeshTheme.Colors.secondary.opacity(0.6),
                            MeshTheme.Colors.primary.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 30)
            
            // Highlight
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 140, height: 80)
                .blur(radius: 20)
                .offset(x: -30, y: -60)
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                scale = 1.15
            }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                offset = 15
            }
        }
    }
}

// MARK: - Light Theme Background

struct LightThemeBackground: View {
    var body: some View {
        ZStack {
            // Pure white base
            Color.white
            
            // Very subtle warm tint
            LinearGradient(
                colors: [
                    Color.white,
                    Color(red: 0.995, green: 0.985, blue: 0.975)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Subtle accent glow at top-right
            RadialGradient(
                colors: [
                    MeshTheme.Colors.primary.opacity(0.04),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - App Background (for main app views)

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.98)
            
            // Subtle mesh pattern overlay (optional)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.5),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}
