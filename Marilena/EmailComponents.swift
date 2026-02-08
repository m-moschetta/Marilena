import SwiftUI

// MARK: - Email Design System
/// Token di design centralizzati per il modulo Email

public enum EmailDesignTokens {
    // MARK: - Spacing (8pt grid)
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    public enum CornerRadius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
    }
    
    // MARK: - Avatar
    public enum Avatar {
        public static let small: CGFloat = 32
        public static let medium: CGFloat = 40
        public static let large: CGFloat = 48
    }
    
    // MARK: - Icon Sizes
    public enum IconSize {
        public static let sm: CGFloat = 16
        public static let md: CGFloat = 20
        public static let lg: CGFloat = 24
    }
    
    // MARK: - Colors (Semantic)
    public enum Colors {
        public static let primary = Color.primary
        public static let secondary = Color.secondary
        public static let accent = Color.blue
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
    }
}

// MARK: - Shared Components

/// Avatar per email con iniziali e gradient
public struct EmailAvatarView: View {
    public let email: String
    public var size: CGFloat = EmailDesignTokens.Avatar.medium
    public var gradient: [Color] = [.blue, .purple]
    
    public init(email: String, size: CGFloat = EmailDesignTokens.Avatar.medium, gradient: [Color] = [.blue, .purple]) {
        self.email = email
        self.size = size
        self.gradient = gradient
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var initials: String {
        let name: String
        
        if let range = email.range(of: "<") {
            name = String(email[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else {
            name = email
        }
        
        let components = name.components(separatedBy: " ")
        if components.count >= 2,
           !components[0].isEmpty,
           !components[1].isEmpty {
            let first = String(components[0].prefix(1)).uppercased()
            let second = String(components[1].prefix(1)).uppercased()
            return first + second
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

/// Badge per urgenza email
public struct EmailUrgencyBadge: View {
    public let urgency: EmailUrgency
    
    public init(urgency: EmailUrgency) {
        self.urgency = urgency
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: urgency.icon)
                .font(.caption2)
            Text(urgency.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(Color(urgency.color))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(urgency.color).opacity(0.1))
        .clipShape(Capsule())
    }
}

/// Card per visualizzazione analisi
public struct EmailAnalysisCard: View {
    public let title: String
    public let value: String
    public let icon: String
    public let color: Color
    
    public init(title: String, value: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: EmailDesignTokens.CornerRadius.sm))
    }
}

/// Badge categoria email
public struct EmailCategoryBadge: View {
    public let category: EmailCategory
    
    public init(category: EmailCategory) {
        self.category = category
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            Text(category.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(category.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(category.color.opacity(0.1))
        .clipShape(Capsule())
    }
}

/// Chip per filtri categoria
public struct EmailFilterChip: View {
    public let title: String
    public let icon: String?
    public let count: Int
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(
        title: String,
        icon: String? = nil,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.blue : Color.gray.opacity(0.5))
                    )
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

/// Pulsante azione rapida con icona e label
public struct EmailQuickActionButton: View {
    public let title: String
    public let icon: String
    public let color: Color
    public let action: () -> Void
    
    public init(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Indicatore non letto
public struct UnreadIndicator: View {
    public var size: CGFloat = 8
    public var color: Color = .blue
    
    public init(size: CGFloat = 8, color: Color = .blue) {
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// Indicatore allegato
public struct AttachmentIndicator: View {
    public var count: Int = 1
    
    public init(count: Int = 1) {
        self.count = count
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "paperclip")
                .font(.caption2)
            
            if count > 1 {
                Text("\(count)")
                    .font(.caption2)
            }
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Email Row Component

/// Row per lista email (stile Apple Mail)
public struct EmailRowView: View {
    public let email: EmailMessage
    public var onTap: (() -> Void)?
    
    public init(email: EmailMessage, onTap: (() -> Void)? = nil) {
        self.email = email
        self.onTap = onTap
    }
    
    public var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: EmailDesignTokens.Spacing.md) {
                // Avatar
                EmailAvatarView(
                    email: email.from,
                    size: EmailDesignTokens.Avatar.medium
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Top Row: Sender + Date + Unread
                    HStack(spacing: EmailDesignTokens.Spacing.sm) {
                        Text(senderDisplayName(email.from))
                            .font(.subheadline)
                            .fontWeight(email.isRead ? .regular : .semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Text(formatRelativeDate(email.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !email.isRead {
                                UnreadIndicator()
                            }
                        }
                    }
                    
                    // Subject
                    Text(email.subject)
                        .font(.subheadline)
                        .fontWeight(email.isRead ? .regular : .medium)
                        .foregroundColor(email.isRead ? .secondary : .primary)
                        .lineLimit(1)
                    
                    // Preview
                    Text(email.body.stripHTML())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Indicators Row
                    HStack(spacing: EmailDesignTokens.Spacing.md) {
                        if email.hasAttachments {
                            AttachmentIndicator()
                        }
                        
                        if let category = email.category {
                            EmailCategoryBadge(category: category)
                                .scaleEffect(0.85)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, EmailDesignTokens.Spacing.md)
            .padding(.vertical, EmailDesignTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessibilityLabel)")
        .accessibilityHint("Tocca per aprire l'email")
    }
    
    private var accessibilityLabel: String {
        let readStatus = email.isRead ? "Letta" : "Non letta"
        return "Email da \(senderDisplayName(email.from)), oggetto: \(email.subject), \(readStatus), \(formatRelativeDate(email.date))"
    }
    
    private func senderDisplayName(_ from: String) -> String {
        if let nameRange = from.range(of: " <") {
            return String(from[..<nameRange.lowerBound])
        }
        return from
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Ieri"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Empty State

/// Empty state per lista email vuota
public struct EmailEmptyStateView: View {
    public let icon: String
    public let title: String
    public let subtitle: String
    
    public init(
        icon: String = "envelope.open",
        title: String = "Nessuna email",
        subtitle: String = "Le tue email appariranno qui"
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
    
    public var body: some View {
        VStack(spacing: EmailDesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Loading State

/// Loading state per email
public struct EmailLoadingView: View {
    public let message: String
    
    public init(message: String = "Caricamento email...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: EmailDesignTokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.blue)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

// MARK: - Bottom Action Bar

/// Barra azioni bottom per detail view
public struct EmailBottomActionBar: View {
    public let onReply: () -> Void
    public let onForward: () -> Void
    public let onArchive: () -> Void
    public let onDelete: () -> Void
    
    public init(
        onReply: @escaping () -> Void,
        onForward: @escaping () -> Void,
        onArchive: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.onReply = onReply
        self.onForward = onForward
        self.onArchive = onArchive
        self.onDelete = onDelete
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            BottomBarButton(
                icon: "arrowshape.turn.up.left",
                label: "Rispondi",
                color: .blue,
                action: onReply
            )
            
            Divider()
                .frame(height: 24)
            
            BottomBarButton(
                icon: "arrowshape.turn.up.right",
                label: "Inoltra",
                color: .indigo,
                action: onForward
            )
            
            Divider()
                .frame(height: 24)
            
            BottomBarButton(
                icon: "archivebox",
                label: "Archivia",
                color: .green,
                action: onArchive
            )
            
            Divider()
                .frame(height: 24)
            
            BottomBarButton(
                icon: "trash",
                label: "Elimina",
                color: .red,
                action: onDelete
            )
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.separator)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }
}

private struct BottomBarButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Extensions

extension String {
    /// Rimuove tag HTML dalla stringa
    public func stripHTML() -> String {
        guard !self.isEmpty else { return self }
        
        // Rimuovi tag HTML
        var result = self
        
        // Rimuovi script e style
        if let scriptRange = result.range(of: "<script", options: .caseInsensitive) {
            if let endScriptRange = result.range(of: "</script>", options: .caseInsensitive, range: scriptRange.upperBound..<result.endIndex) {
                result.removeSubrange(scriptRange.lowerBound..<endScriptRange.upperBound)
            }
        }
        
        if let styleRange = result.range(of: "<style", options: .caseInsensitive) {
            if let endStyleRange = result.range(of: "</style>", options: .caseInsensitive, range: styleRange.upperBound..<result.endIndex) {
                result.removeSubrange(styleRange.lowerBound..<endStyleRange.upperBound)
            }
        }
        
        // Rimuovi tutti i tag HTML
        let pattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return result
        }
        
        let range = NSRange(result.startIndex..., in: result)
        let cleaned = regex.stringByReplacingMatches(
            in: result,
            options: [],
            range: range,
            withTemplate: ""
        )
        
        // Decodifica entità HTML comuni
        var finalResult = cleaned
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&hellip;", with: "...")
        
        // Normalizza spazi
        finalResult = finalResult
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return finalResult.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Avatar Preview
            HStack(spacing: 16) {
                EmailAvatarView(email: "Mario Rossi <mario@example.com>", size: 32)
                EmailAvatarView(email: "Mario Rossi <mario@example.com>", size: 40)
                EmailAvatarView(email: "Mario Rossi <mario@example.com>", size: 48)
            }
            
            // Badges Preview
            HStack(spacing: 8) {
                EmailUrgencyBadge(urgency: .high)
                EmailUrgencyBadge(urgency: .medium)
                EmailCategoryBadge(category: .work)
            }
            
            // Filter Chip Preview
            HStack(spacing: 8) {
                EmailFilterChip(
                    title: "Tutte",
                    count: 42,
                    isSelected: true,
                    action: {}
                )
                
                EmailFilterChip(
                    title: "Lavoro",
                    icon: "briefcase",
                    count: 12,
                    isSelected: false,
                    action: {}
                )
            }
            
            // Email Row Preview
            EmailRowView(
                email: EmailMessage(
                    id: "1",
                    accountId: "default",
                    from: "Mario Rossi <mario@example.com>",
                    to: ["me@example.com"],
                    subject: "Riunione di progetto domani",
                    body: "Ciao, ti confermo la riunione per domani alle 14:00.",
                    date: Date(),
                    isRead: false,
                    hasAttachments: true,
                    category: .work
                )
            )
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Empty State Preview
            EmailEmptyStateView()
                .frame(height: 200)
            
            // Bottom Bar Preview
            EmailBottomActionBar(
                onReply: {},
                onForward: {},
                onArchive: {},
                onDelete: {}
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
