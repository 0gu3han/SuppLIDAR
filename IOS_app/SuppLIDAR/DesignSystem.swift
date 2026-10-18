import SwiftUI

// MARK: - Color Palette (The Celestial Atheneum)
extension Color {
    // Surfaces
    static let mSurface               = Color(hex: "#10141a") // Base environment
    static let mSurfaceContainerLow   = Color(hex: "#181c22")
    static let mSurfaceContainer      = Color(hex: "#1c2026") // Floor
    static let mSurfaceContainerHigh  = Color(hex: "#262a31") // Pedestal
    static let mSurfaceContainerHighest = Color(hex: "#31353c") // Focus
    static let mSurfaceContainerLowest = Color(hex: "#0a0e14")
    static let mSurfaceVariant        = Color(hex: "#31353c")

    // Brand
    static let mPrimary               = Color(hex: "#666fca")
    static let mPrimaryContainer      = Color(hex: "#0d2187")
    static let mSecondary             = Color(hex: "#71749a")
    static let mSecondaryContainer    = Color(hex: "#1ea296")
    static let mSecondaryFixedDim     = Color(hex: "#66d9cc") // Success teal

    // Content
    static let mOnSurface             = Color(hex: "#dfe2eb")
    static let mOutlineVariant        = Color(hex: "#454652")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Gradients

/// Primary CTA gradient — resolves as ShapeStyle so dot-syntax works in .background()
struct MentosPrimaryGradient: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        LinearGradient(
            colors: [Color.mPrimary, Color.mPrimaryContainer],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension ShapeStyle where Self == MentosPrimaryGradient {
    static var mGradient: MentosPrimaryGradient { MentosPrimaryGradient() }
}

// MARK: - Typography helpers
extension Font {
    /// Display: large architectural headline (approximates Space Grotesk)
    static func mDisplay(_ size: CGFloat = 48) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    /// Title: section headers (approximates Inter)
    static func mTitle(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .semibold)
    }
    /// Label: instrument-panel metadata — use ALL CAPS + tracking at call site
    static func mLabel(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium)
    }
    /// Body
    static func mBody(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular)
    }
}

// MARK: - Reusable Modifiers

/// "Sink" input field style — surface_container_lowest background, label above
struct SinkFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.mOnSurface)
            .tint(Color.mPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.mSurfaceContainerLowest,
                        in: RoundedRectangle(cornerRadius: 6))
    }
}

/// Glassmorphic card — surface_variant at 60% + ultra thin material
struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.mSurfaceVariant.opacity(0.6))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius)
                    )
            )
    }
}

/// Ambient indigo shadow for floating elements
struct MentisAmbientShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Color(hex: "#0e2288").opacity(0.2),
                    radius: 24, x: 0, y: 12)
    }
}

extension View {
    func sinkStyle() -> some View { modifier(SinkFieldStyle()) }
    func glassCard(radius: CGFloat = 16) -> some View { modifier(GlassCardStyle(cornerRadius: radius)) }
    func ambientShadow() -> some View { modifier(MentisAmbientShadow()) }
}

// MARK: - Primary CTA Button
struct MentisPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.mTitle(16))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(.mGradient, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
