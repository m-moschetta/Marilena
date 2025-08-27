import SwiftUI

// MARK: - Liquid Glass Compatibility Extensions

/// Estensioni per la compatibilità con iOS 26 Liquid Glass
/// Fornisce fallback per iOS 18+ quando le API non sono disponibili
public struct LiquidGlassCompatibility {
    
    // MARK: - Glass Effect Modifiers
    
    /// Applica l'effetto Liquid Glass se disponibile, altrimenti usa un fallback
    public static func glassEffect<T: View>(
        _ view: T,
        style: GlassEffectStyle = .regular,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        // Per ora usiamo sempre il fallback finché le API di iOS 26 non sono stabili
        return view.legacyGlassEffect(tint: tint)
    }
    
    /// Contenitore per effetti di vetro con fallback
    public static func glassEffectContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        // Per ora usiamo sempre il contenuto diretto finché le API di iOS 26 non sono stabili
        return content()
    }
    
    /// Stile del pulsante con fallback
    public static func glassButtonStyle() -> some ButtonStyle {
        if #available(iOS 26.0, *) {
            // Per iOS 26, usa uno stile personalizzato che simula il glass
            return LegacyGlassButtonStyle()
        } else {
            return .legacyGlass
        }
    }
}

// MARK: - Glass Effect Style

/// Stili per l'effetto vetro
public enum GlassEffectStyle {
    case regular
    case prominent
    case subtle
}

// MARK: - Legacy Glass Effect

extension View {
    /// Fallback per l'effetto vetro su iOS 18+
    func legacyGlassEffect(tint: Color? = nil) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground).opacity(0.8),
                                Color(.systemGray6).opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Legacy Button Style

struct LegacyGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .legacyGlassEffect()
    }
}

extension ButtonStyle where Self == LegacyGlassButtonStyle {
    static var legacyGlass: LegacyGlassButtonStyle {
        LegacyGlassButtonStyle()
    }
}

// MARK: - Convenience Modifiers

extension View {
    /// Modificatore conveniente per Liquid Glass con fallback
    func liquidGlassEffect(
        style: GlassEffectStyle = .regular,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        LiquidGlassCompatibility.glassEffect(
            self,
            style: style,
            tint: tint,
            interactive: interactive
        )
    }
    
    /// Contenitore conveniente per Liquid Glass
    func liquidGlassContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        LiquidGlassCompatibility.glassEffectContainer(content: content)
    }
}

// MARK: - Button Extensions

extension Button {
    /// Stile conveniente per pulsanti Liquid Glass
    func liquidGlassStyle() -> some View {
        self.buttonStyle(LiquidGlassCompatibility.glassButtonStyle())
    }
} 