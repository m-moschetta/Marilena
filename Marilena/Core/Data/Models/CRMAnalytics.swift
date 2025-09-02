import Foundation
import SwiftUI

// MARK: - CRM Analytics Models

public struct CRMAnalytics: Codable {
    public let totalContacts: Int
    public let activeContacts: Int
    public let weeklyActiveContacts: Int
    public let monthlyActiveContacts: Int
    public let relationshipStrengthDistribution: RelationshipStrengthDistribution
    public let sourceDistribution: SourceDistribution
    public let topContactsByInteractions: [TopContactMetric]
    public let averageInteractionsPerContact: Double
    public let relationshipHealthScore: Double
    public let contactGrowthRate: Double
    public let lastUpdated: Date
    
    public init(
        totalContacts: Int = 0,
        activeContacts: Int = 0,
        weeklyActiveContacts: Int = 0,
        monthlyActiveContacts: Int = 0,
        relationshipStrengthDistribution: RelationshipStrengthDistribution = RelationshipStrengthDistribution(),
        sourceDistribution: SourceDistribution = SourceDistribution(),
        topContactsByInteractions: [TopContactMetric] = [],
        averageInteractionsPerContact: Double = 0.0,
        relationshipHealthScore: Double = 0.0,
        contactGrowthRate: Double = 0.0,
        lastUpdated: Date = Date()
    ) {
        self.totalContacts = totalContacts
        self.activeContacts = activeContacts
        self.weeklyActiveContacts = weeklyActiveContacts
        self.monthlyActiveContacts = monthlyActiveContacts
        self.relationshipStrengthDistribution = relationshipStrengthDistribution
        self.sourceDistribution = sourceDistribution
        self.topContactsByInteractions = topContactsByInteractions
        self.averageInteractionsPerContact = averageInteractionsPerContact
        self.relationshipHealthScore = relationshipHealthScore
        self.contactGrowthRate = contactGrowthRate
        self.lastUpdated = lastUpdated
    }
    
    // Computed properties per insights
    public var activeContactsPercentage: Double {
        guard totalContacts > 0 else { return 0.0 }
        return Double(activeContacts) / Double(totalContacts) * 100.0
    }
    
    public var healthScoreColor: Color {
        switch relationshipHealthScore {
        case 80...100: return .green
        case 50...79: return .orange
        default: return .red
        }
    }
    
    public var healthScoreStatus: String {
        switch relationshipHealthScore {
        case 80...100: return "Ottimo"
        case 60...79: return "Buono"
        case 40...59: return "Sufficiente"
        default: return "Richiede attenzione"
        }
    }
    
    public var growthTrend: GrowthTrend {
        switch contactGrowthRate {
        case 15...: return .rapid
        case 5...14.99: return .steady
        case 1...4.99: return .slow
        case 0...0.99: return .stagnant
        default: return .declining
        }
    }
}

public struct RelationshipStrengthDistribution: Codable {
    public let low: Int
    public let medium: Int
    public let high: Int
    
    public init(low: Int = 0, medium: Int = 0, high: Int = 0) {
        self.low = low
        self.medium = medium
        self.high = high
    }
    
    public var total: Int { low + medium + high }
    
    public var lowPercentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(low) / Double(total) * 100.0
    }
    
    public var mediumPercentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(medium) / Double(total) * 100.0
    }
    
    public var highPercentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(high) / Double(total) * 100.0
    }
}

public struct SourceDistribution: Codable {
    public let email: Int
    public let calendar: Int
    public let manual: Int
    
    public init(email: Int = 0, calendar: Int = 0, manual: Int = 0) {
        self.email = email
        self.calendar = calendar
        self.manual = manual
    }
    
    public var total: Int { email + calendar + manual }
    
    public var emailPercentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(email) / Double(total) * 100.0
    }
    
    public var calendarPercentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(calendar) / Double(total) * 100.0
    }
    
    public var manualPercentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(manual) / Double(total) * 100.0
    }
}

public struct TopContactMetric: Codable, Identifiable {
    public let id = UUID()
    public let name: String
    public let interactions: Int
    public let lastInteraction: Date?
    
    public init(name: String, interactions: Int, lastInteraction: Date?) {
        self.name = name
        self.interactions = interactions
        self.lastInteraction = lastInteraction
    }
    
    enum CodingKeys: String, CodingKey {
        case name, interactions, lastInteraction
    }
}

public enum ContactAnalyticsCategory: String, CaseIterable {
    case mostActive = "most_active"
    case recentInteractions = "recent_interactions" 
    case highValue = "high_value"
    case needsAttention = "needs_attention"
    
    public var displayName: String {
        switch self {
        case .mostActive: return "Più Attivi"
        case .recentInteractions: return "Interazioni Recenti"
        case .highValue: return "Alto Valore"
        case .needsAttention: return "Necessitano Attenzione"
        }
    }
    
    public var icon: String {
        switch self {
        case .mostActive: return "chart.bar.fill"
        case .recentInteractions: return "clock.fill"
        case .highValue: return "star.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .mostActive: return .blue
        case .recentInteractions: return .green
        case .highValue: return .yellow
        case .needsAttention: return .red
        }
    }
}

public enum GrowthTrend: String, CaseIterable {
    case rapid = "rapid"
    case steady = "steady"
    case slow = "slow"
    case stagnant = "stagnant"
    case declining = "declining"
    
    public var displayName: String {
        switch self {
        case .rapid: return "Crescita Rapida"
        case .steady: return "Crescita Costante"
        case .slow: return "Crescita Lenta"
        case .stagnant: return "Stagnante"
        case .declining: return "In Declino"
        }
    }
    
    public var icon: String {
        switch self {
        case .rapid: return "arrow.up.right.circle.fill"
        case .steady: return "arrow.up.circle.fill"
        case .slow: return "arrow.up.circle"
        case .stagnant: return "minus.circle"
        case .declining: return "arrow.down.circle.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .rapid: return .green
        case .steady: return .blue
        case .slow: return .orange
        case .stagnant: return .gray
        case .declining: return .red
        }
    }
}

// MARK: - Analytics Insights

public struct CRMInsight {
    public let title: String
    public let message: String
    public let category: InsightCategory
    public let priority: InsightPriority
    public let actionable: Bool
    
    public init(title: String, message: String, category: InsightCategory, priority: InsightPriority, actionable: Bool = false) {
        self.title = title
        self.message = message
        self.category = category
        self.priority = priority
        self.actionable = actionable
    }
}

public enum InsightCategory: String, CaseIterable {
    case activity = "activity"
    case relationships = "relationships"
    case growth = "growth"
    case opportunities = "opportunities"
    
    public var displayName: String {
        switch self {
        case .activity: return "Attività"
        case .relationships: return "Relazioni"
        case .growth: return "Crescita"
        case .opportunities: return "Opportunità"
        }
    }
    
    public var color: Color {
        switch self {
        case .activity: return .blue
        case .relationships: return .purple
        case .growth: return .green
        case .opportunities: return .orange
        }
    }
}

public enum InsightPriority: String, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    public var displayName: String {
        switch self {
        case .high: return "Alta"
        case .medium: return "Media"
        case .low: return "Bassa"
        }
    }
    
    public var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}