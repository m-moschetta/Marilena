import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Combine

/// Manager centralizzato per gestire l'accessibilità nell'app
@MainActor
public class AccessibilityManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = AccessibilityManager()
    
    // MARK: - Published Properties
    @Published public var isVoiceOverEnabled = false
    @Published public var isDynamicTypeEnabled = false
    @Published public var isReduceMotionEnabled = false
    @Published public var isReduceTransparencyEnabled = false
    @Published public var preferredContentSizeCategory: ContentSizeCategory = .medium
    
    // MARK: - Private Properties
    private var observers: [NSObjectProtocol] = []
    
    // MARK: - Initialization
    private init() {
        updateAccessibilitySettings()
        setupAccessibilityObservers()
    }
    
    deinit {
        // Rimuovi observers in modo sync per deinit
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Configura un elemento UI per l'accessibilità
    public func configureAccessibility(
        for view: some View,
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        value: String? = nil
    ) -> some View {
        view
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityValue(value ?? "")
    }
    
    /// Configura accessibilità per bottoni
    public func configureButton(
        for view: some View,
        label: String,
        hint: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        view
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .disabled(!isEnabled)
    }
    
    /// Configura accessibilità per elementi di navigazione
    public func configureNavigation(
        for view: some View,
        label: String,
        hint: String? = nil
    ) -> some View {
        view
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isHeader)
    }
    
    /// Announce per VoiceOver
    public func announce(_ message: String) {
        guard isVoiceOverEnabled else { return }
        
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    /// Screen changed notification
    public func screenChanged(focusOn element: Any? = nil) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: element)
        }
    }
    
    /// Layout changed notification
    public func layoutChanged(focusOn element: Any? = nil) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
    
    // MARK: - Font Scaling
    
    /// Ottiene font scalato per accessibilità
    public func scaledFont(_ font: Font) -> Font {
        if isDynamicTypeEnabled {
            return font
        }
        return font
    }
    
    /// Ottiene dimensione font personalizzata
    public func scaledFontSize(_ baseSize: CGFloat) -> CGFloat {
        let multiplier = getFontSizeMultiplier()
        return baseSize * multiplier
    }
    
    private func getFontSizeMultiplier() -> CGFloat {
        switch preferredContentSizeCategory {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.6
        case .accessibilityLarge: return 1.8
        case .accessibilityExtraLarge: return 2.0
        case .accessibilityExtraExtraLarge: return 2.2
        case .accessibilityExtraExtraExtraLarge: return 2.4
        @unknown default: return 1.0
        }
    }
    
    // MARK: - Animation Control
    
    /// Controlla se le animazioni dovrebbero essere ridotte
    public var shouldReduceMotion: Bool {
        return isReduceMotionEnabled
    }
    
    /// Durata animazione adattata
    public func animationDuration(_ baseDuration: Double) -> Double {
        return shouldReduceMotion ? baseDuration * 0.1 : baseDuration
    }
    
    // MARK: - Color Contrast
    
    /// Ottiene colore con contrasto migliorato se necessario
    public func contrastAdjustedColor(_ color: Color) -> Color {
        if isReduceTransparencyEnabled {
            // Aumenta l'opacità per migliore contrasto
            return color.opacity(1.0)
        }
        return color
    }
    
    // MARK: - Private Methods
    
    private func updateAccessibilitySettings() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isDynamicTypeEnabled = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory)
    }
    
    private func setupAccessibilityObservers() {
        // VoiceOver status
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.voiceOverStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
                    print("♿ AccessibilityManager: VoiceOver \(UIAccessibility.isVoiceOverRunning ? "abilitato" : "disabilitato")")
                }
            }
        )
        
        // Dynamic Type
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIContentSizeCategory.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isDynamicTypeEnabled = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
                    self?.preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory)
                    print("♿ AccessibilityManager: Dynamic Type cambiato a \(UIApplication.shared.preferredContentSizeCategory.rawValue)")
                }
            }
        )
        
        // Reduce Motion
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
                    print("♿ AccessibilityManager: Reduce Motion \(UIAccessibility.isReduceMotionEnabled ? "abilitato" : "disabilitato")")
                }
            }
        )
        
        // Reduce Transparency
        observers.append(
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
                    print("♿ AccessibilityManager: Reduce Transparency \(UIAccessibility.isReduceTransparencyEnabled ? "abilitato" : "disabilitato")")
                }
            }
        )
    }
    
    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}

// MARK: - Extensions

extension ContentSizeCategory {
    init(_ uiContentSizeCategory: UIContentSizeCategory) {
        switch uiContentSizeCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: self = .medium
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applica configurazione accessibilità standard
    public func standardAccessibility(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        AccessibilityManager.shared.configureAccessibility(
            for: self,
            label: label,
            hint: hint,
            traits: traits
        )
    }
    
    /// Applica configurazione accessibilità per bottoni
    public func buttonAccessibility(
        label: String,
        hint: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        AccessibilityManager.shared.configureButton(
            for: self,
            label: label,
            hint: hint,
            isEnabled: isEnabled
        )
    }
    
    /// Applica configurazione accessibilità per header
    public func headerAccessibility(
        label: String,
        hint: String? = nil
    ) -> some View {
        AccessibilityManager.shared.configureNavigation(
            for: self,
            label: label,
            hint: hint
        )
    }
    
    /// Applica animazioni rispettose dell'accessibilità
    public func accessibleAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        let manager = AccessibilityManager.shared
        let adaptedAnimation = manager.shouldReduceMotion ? nil : animation
        return self.animation(adaptedAnimation, value: value)
    }
}