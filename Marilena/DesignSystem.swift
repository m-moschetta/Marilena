//
//  DesignSystem.swift
//  Marilena
//
//  Design System unificato per tutta l'app
//  Centralizza token e componenti per consistenza UI
//

import SwiftUI

// MARK: - Color Tokens
public enum DSColors {
    public static let primary = Color.blue
    public static let secondary = Color.purple
    public static let success = Color.green
    public static let warning = Color.orange
    public static let error = Color.red
    
    public static let background = Color(.systemBackground)
    public static let secondaryBackground = Color(.secondarySystemBackground)
    public static let tertiaryBackground = Color(.tertiarySystemBackground)
    public static let groupedBackground = Color(.systemGroupedBackground)
    
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
    public static let tertiaryText = Color(.tertiaryLabel)
    
    public static let separator = Color(.separator)
}

// MARK: - Typography (Semantic - Supporta Dynamic Type)
public enum DSTypography {
    public static let largeTitle = Font.largeTitle
    public static let title = Font.title
    public static let title2 = Font.title2
    public static let title3 = Font.title3
    public static let headline = Font.headline
    public static let subheadline = Font.subheadline
    public static let body = Font.body
    public static let callout = Font.callout
    public static let caption = Font.caption
    public static let caption2 = Font.caption2
}

// MARK: - Spacing (8pt Grid System)
public enum DSSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

// MARK: - Corner Radius
public enum DSCornerRadius {
    public static let sm: CGFloat = 4
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 12
    public static let xl: CGFloat = 16
    public static let pill: CGFloat = 9999
}

// MARK: - Shadows
public enum DSShadows {
    public static let sm = ShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    public static let md = ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    public static let lg = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    
    public struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        func apply(to view: some View) -> some View {
            view.shadow(color: color, radius: radius, x: x, y: y)
        }
    }
}

// MARK: - Unified Components

/// Filter Chip unificato - usato in Chat, Email, Registrazioni
public struct DSFilterChip: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void
    
    public init(
        title: String,
        count: Int? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : DSColors.primaryText.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.sm)
            .background(isSelected ? DSColors.primary : DSColors.secondaryBackground)
            .foregroundColor(isSelected ? .white : DSColors.primaryText)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Avatar View unificato - usato in Email, Chat, Profilo
public struct DSAvatarView: View {
    let text: String
    let color: Color
    var size: CGFloat
    
    public init(
        text: String,
        color: Color = .blue,
        size: CGFloat = 40
    ) {
        self.text = String(text.prefix(2)).uppercased()
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        Circle()
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(text)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

/// Empty State View unificato
public struct DSEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundColor(DSColors.primaryText)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .background(DSColors.primary, in: RoundedRectangle(cornerRadius: DSCornerRadius.md))
                        .foregroundStyle(.white)
                }
                .padding(.top, DSSpacing.sm)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.background)
    }
}

/// Loading View unificato
public struct DSLoadingView: View {
    let message: String
    
    public init(message: String = "Caricamento...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DSColors.primary)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

/// Badge unificato per stati/etichette
public struct DSBadge: View {
    let text: String
    let color: Color
    let icon: String?
    
    public init(
        text: String,
        color: Color = .blue,
        icon: String? = nil
    ) {
        self.text = text
        self.color = color
        self.icon = icon
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

/// Card container unificato
public struct DSCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let background: Color
    let showShadow: Bool
    
    public init(
        padding: CGFloat = DSSpacing.md,
        background: Color = DSColors.background,
        showShadow: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.background = background
        self.showShadow = showShadow
    }
    
    public var body: some View {
        content
            .padding(padding)
            .background(background)
            .cornerRadius(DSCornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.md)
                    .stroke(DSColors.separator.opacity(0.5), lineWidth: 0.5)
            )
            .applyIf(showShadow) { view in
                view.shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
    }
}

/// List Row container unificato
public struct DSListRow<Content: View>: View {
    let content: Content
    let showDivider: Bool
    
    public init(showDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.showDivider = showDivider
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
            
            if showDivider {
                Divider()
                    .padding(.leading, DSSpacing.md)
            }
        }
        .background(DSColors.background)
    }
}

/// Primary Button unificato
public struct DSPrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    public init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                }
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .background(isDisabled ? DSColors.primary.opacity(0.5) : DSColors.primary)
            .cornerRadius(DSCornerRadius.md)
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(.plain)
    }
}

/// Secondary Button unificato
public struct DSSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    public init(
        title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.medium))
                }
                
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(DSColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .background(DSColors.primary.opacity(0.1))
            .cornerRadius(DSCornerRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Accessibility Helpers
public extension View {
    /// Aggiunge label e hint accessibilità in modo type-safe
    func dsAccessibility(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Combina elementi figli per accessibilità
    func dsCombineAccessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - View Modifiers
public extension View {
    /// Applica una condizione in modo type-safe
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Applica padding standard
    func dsStandardPadding() -> some View {
        self.padding(DSSpacing.md)
    }
    
    /// Applica stile card standard
    func dsCardStyle(background: Color = DSColors.background, showShadow: Bool = true) -> some View {
        self
            .background(background)
            .cornerRadius(DSCornerRadius.md)
            .applyIf(showShadow) { view in
                view.shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
    }
}

// MARK: - Haptic Feedback
public enum DSHaptics {
    public static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    public static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    public static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    public static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: DSSpacing.lg) {
            // Filter Chips
            HStack(spacing: DSSpacing.sm) {
                DSFilterChip(title: "Tutte", count: 12, isSelected: true) {}
                DSFilterChip(title: "Non lette", count: 3, isSelected: false) {}
            }
            
            // Avatar
            HStack(spacing: DSSpacing.md) {
                DSAvatarView(text: "Mario Rossi", color: .blue, size: 32)
                DSAvatarView(text: "Mario Rossi", color: .blue, size: 40)
                DSAvatarView(text: "Mario Rossi", color: .blue, size: 48)
            }
            
            // Badge
            HStack(spacing: DSSpacing.sm) {
                DSBadge(text: "Urgente", color: .red, icon: "exclamationmark.circle")
                DSBadge(text: "Lavoro", color: .blue, icon: "briefcase")
                DSBadge(text: "Alto", color: .orange)
            }
            
            // Empty State
            DSEmptyStateView(
                icon: "envelope.open",
                title: "Nessuna email",
                subtitle: "Le tue email appariranno qui",
                actionTitle: "Nuova Email",
                action: {}
            )
            .frame(height: 300)
            
            // Loading
            DSLoadingView(message: "Caricamento email...")
                .frame(height: 200)
            
            // Card
            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Titolo Card")
                        .font(.headline)
                    Text("Contenuto della card con stile uniforme")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // Buttons
            VStack(spacing: DSSpacing.sm) {
                DSPrimaryButton(title: "Azione Primaria", icon: "checkmark") {}
                DSSecondaryButton(title: "Azione Secondaria", icon: "xmark") {}
                DSPrimaryButton(title: "Caricamento...", isLoading: true) {}
            }
        }
        .padding()
    }
    .background(DSColors.groupedBackground)
}
