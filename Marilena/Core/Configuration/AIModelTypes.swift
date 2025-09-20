import Foundation

public struct AIPricing: Codable {
    public let inputTokens: PricingTier
    public let outputTokens: PricingTier
    public let specialPricing: [String: PricingTier]?
    public let currency: String
    public let billingUnit: String

    public init(
        inputTokens: PricingTier,
        outputTokens: PricingTier,
        specialPricing: [String: PricingTier]? = nil,
        currency: String = "USD",
        billingUnit: String = "per 1M tokens"
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.specialPricing = specialPricing
        self.currency = currency
        self.billingUnit = billingUnit
    }
}

public struct PricingTier: Codable {
    public let price: Double
    public let description: String?
    public let conditions: String?

    public init(price: Double, description: String? = nil, conditions: String? = nil) {
        self.price = price
        self.description = description
        self.conditions = conditions
    }
}

public struct AIBenchmarks: Codable {
    public let coding: Double?
    public let reasoning: Double?
    public let math: Double?
    public let multimodal: Double?
    public let conversational: Double?
    public let speed: Double?
    public let overallScore: Double?
    public let benchmarkDate: Date?

    public init(
        coding: Double? = nil,
        reasoning: Double? = nil,
        math: Double? = nil,
        multimodal: Double? = nil,
        conversational: Double? = nil,
        speed: Double? = nil,
        overallScore: Double? = nil,
        benchmarkDate: Date? = nil
    ) {
        self.coding = coding
        self.reasoning = reasoning
        self.math = math
        self.multimodal = multimodal
        self.conversational = conversational
        self.speed = speed
        self.overallScore = overallScore
        self.benchmarkDate = benchmarkDate
    }
}

public struct AIAvailability: Codable {
    public let regions: [String]
    public let accessTiers: [AccessTier]
    public let rateLimits: RateLimits?
    public let status: AvailabilityStatus

    public init(
        regions: [String],
        accessTiers: [AccessTier],
        rateLimits: RateLimits? = nil,
        status: AvailabilityStatus
    ) {
        self.regions = regions
        self.accessTiers = accessTiers
        self.rateLimits = rateLimits
        self.status = status
    }
}

public enum AccessTier: String, Codable, CaseIterable {
    case free = "free"
    case pro = "pro"
    case enterprise = "enterprise"
    case api = "api"
    case beta = "beta"
    case experimental = "experimental"

    public var displayName: String {
        switch self {
        case .free: return "Free Tier"
        case .pro: return "Pro/Plus"
        case .enterprise: return "Enterprise"
        case .api: return "API Access"
        case .beta: return "Beta Access"
        case .experimental: return "Experimental"
        }
    }
}

public enum AvailabilityStatus: String, Codable {
    case available = "available"
    case limited = "limited"
    case beta = "beta"
    case comingSoon = "coming_soon"
    case deprecated = "deprecated"

    public var displayName: String {
        switch self {
        case .available: return "Generally Available"
        case .limited: return "Limited Access"
        case .beta: return "Beta"
        case .comingSoon: return "Coming Soon"
        case .deprecated: return "Deprecated"
        }
    }
}

public struct RateLimits: Codable {
    public let requestsPerMinute: Int?
    public let tokensPerMinute: Int?
    public let requestsPerDay: Int?
    public let tokensPerDay: Int?

    public init(
        requestsPerMinute: Int? = nil,
        tokensPerMinute: Int? = nil,
        requestsPerDay: Int? = nil,
        tokensPerDay: Int? = nil
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.tokensPerMinute = tokensPerMinute
        self.requestsPerDay = requestsPerDay
        self.tokensPerDay = tokensPerDay
    }
}