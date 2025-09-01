import Foundation
import SwiftUI

/// Rappresenta una label/categoria per organizzare le email
public struct MailLabel: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let type: MailLabelType
    public let colorHex: String?
    public let parentId: String?
    public let providerMapping: [String: String] // Mappatura per diversi provider
    public let isVisible: Bool
    public let messageCount: Int

    /// Colore associato alla label
    public var color: Color {
        guard let hex = colorHex, let uiColor = UIColor(hex: hex) else {
            return defaultColorForType(type)
        }
        return Color(uiColor)
    }

    /// Nome visualizzato con gerarchia
    public var displayName: String {
        // In futuro potremmo implementare la gerarchia con parent
        name
    }

    /// Icona appropriata per il tipo di label
    public var iconName: String {
        switch type {
        case .inbox: return "tray"
        case .important: return "star.fill"
        case .sent: return "paperplane.fill"
        case .drafts: return "doc.fill"
        case .archive: return "archivebox.fill"
        case .trash: return "trash.fill"
        case .spam: return "exclamationmark.triangle.fill"
        case .personal: return "person.fill"
        case .work: return "briefcase.fill"
        case .social: return "person.2.fill"
        case .promotions: return "megaphone.fill"
        case .updates: return "bell.fill"
        case .custom: return "tag.fill"
        }
    }

    public init(
        id: String,
        name: String,
        type: MailLabelType,
        colorHex: String? = nil,
        parentId: String? = nil,
        providerMapping: [String: String] = [:],
        isVisible: Bool = true,
        messageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.colorHex = colorHex
        self.parentId = parentId
        self.providerMapping = providerMapping
        self.isVisible = isVisible
        self.messageCount = messageCount
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: MailLabel, rhs: MailLabel) -> Bool {
        lhs.id == rhs.id
    }

    /// Crea una label con il colore di default per il tipo
    public static func withDefaultColor(
        id: String,
        name: String,
        type: MailLabelType,
        parentId: String? = nil,
        providerMapping: [String: String] = [:]
    ) -> MailLabel {
        MailLabel(
            id: id,
            name: name,
            type: type,
            colorHex: defaultColorHexForType(type),
            parentId: parentId,
            providerMapping: providerMapping
        )
    }

    private func defaultColorForType(_ type: MailLabelType) -> Color {
        switch type {
        case .inbox: return .blue
        case .important: return .orange
        case .sent: return .green
        case .drafts: return .gray
        case .archive: return .purple
        case .trash: return .red
        case .spam: return .red
        case .personal: return .cyan
        case .work: return .indigo
        case .social: return .pink
        case .promotions: return .yellow
        case .updates: return .mint
        case .custom: return .gray
        }
    }

    private static func defaultColorHexForType(_ type: MailLabelType) -> String? {
        switch type {
        case .inbox: return "#007AFF"
        case .important: return "#FF9500"
        case .sent: return "#34C759"
        case .drafts: return "#8E8E93"
        case .archive: return "#AF52DE"
        case .trash: return "#FF3B30"
        case .spam: return "#FF3B30"
        case .personal: return "#32D74B"
        case .work: return "#5856D6"
        case .social: return "#FF2D55"
        case .promotions: return "#FFCC00"
        case .updates: return "#00C7BE"
        case .custom: return "#8E8E93"
        }
    }
}

/// Tipo di label
public enum MailLabelType: String, Codable, CaseIterable {
    case inbox
    case important
    case sent
    case drafts
    case archive
    case trash
    case spam
    case personal
    case work
    case social
    case promotions
    case updates
    case custom

    public var displayName: String {
        switch self {
        case .inbox: return "Posta in arrivo"
        case .important: return "Importante"
        case .sent: return "Inviata"
        case .drafts: return "Bozze"
        case .archive: return "Archiviata"
        case .trash: return "Cestino"
        case .spam: return "Spam"
        case .personal: return "Personale"
        case .work: return "Lavoro"
        case .social: return "Social"
        case .promotions: return "Promozioni"
        case .updates: return "Aggiornamenti"
        case .custom: return "Personalizzata"
        }
    }
}

// MARK: - UIColor Extension for Hex
private extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
