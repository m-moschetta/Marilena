import Foundation

/// Comprehensive configuration for current AI models (2024)
/// Includes pricing, capabilities, and specifications for all major providers
/// Updated with the latest available models from OpenAI, Anthropic, Google, Meta, and others
@MainActor
public struct AIModelConfiguration: Codable, Identifiable, Hashable, Equatable {

    // MARK: - Basic Properties

    public let id: String
    public let name: String
    public let provider: AIModelProvider
    public let version: String
    public let releaseDate: Date
    public let description: String

    // MARK: - Technical Specifications

    public let contextWindow: Int
    public let maxOutputTokens: Int
    public let supportedModalities: [AIModality]
    public let capabilities: [AICapability]

    // MARK: - Pricing Structure

    public let pricing: AIPricing

    // MARK: - Performance Metrics

    public let benchmarks: AIBenchmarks

    // MARK: - Availability and Limits

    public let availability: AIAvailability

    // MARK: - Configuration Metadata

    public let knowledgeCutoff: Date?
    public let isExperimental: Bool
    public let requiresSpecialAccess: Bool
    public let tags: [String]

    public init(
        id: String,
        name: String,
        provider: AIModelProvider,
        version: String,
        releaseDate: Date,
        description: String,
        contextWindow: Int,
        maxOutputTokens: Int,
        supportedModalities: [AIModality],
        capabilities: [AICapability],
        pricing: AIPricing,
        benchmarks: AIBenchmarks,
        availability: AIAvailability,
        knowledgeCutoff: Date? = nil,
        isExperimental: Bool = false,
        requiresSpecialAccess: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.version = version
        self.releaseDate = releaseDate
        self.description = description
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.supportedModalities = supportedModalities
        self.capabilities = capabilities
        self.pricing = pricing
        self.benchmarks = benchmarks
        self.availability = availability
        self.knowledgeCutoff = knowledgeCutoff
        self.isExperimental = isExperimental
        self.requiresSpecialAccess = requiresSpecialAccess
        self.tags = tags
    }

    // MARK: - Hashable & Equatable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AIModelConfiguration, rhs: AIModelConfiguration) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Convenience Extensions

public extension AIModelConfiguration {

    /// Get all available models from the catalog
    static let allModels: [AIModelConfiguration] = AIModelCatalog.allModels

    /// Get models by provider
    static func models(for provider: AIModelProvider) -> [AIModelConfiguration] {
        return AIModelCatalog.models(for: provider)
    }

    /// Get models by capability
    static func models(with capability: AICapability) -> [AIModelConfiguration] {
        return AIModelCatalog.models(with: capability)
    }

    /// Get recommended models for email use case
    static var emailRecommended: [AIModelConfiguration] {
        return AIModelCatalog.emailRecommended
    }

    /// Get latest models (released in 2024)
    static var latest2024: [AIModelConfiguration] {
        return AIModelCatalog.latest2024
    }
}
